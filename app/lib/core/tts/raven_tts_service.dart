import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:pocket_tts_raven/pocket_tts_raven.dart';

import 'tts_text_processing.dart';
import 'wav_io.dart';

/// Result of one Raven clone + synthesize call, with per-stage timings so
/// callers report the same synthesis facts across engines.
class RavenSpeakResult {
  const RavenSpeakResult({
    required this.sampleRate,
    required this.sampleCount,
    required this.firstChunkMillis,
    required this.nativeGenerateMillis,
    required this.postProcessMillis,
    required this.wavWriteMillis,
    required this.completeMillis,
  });

  final int sampleRate;
  final int sampleCount;

  /// Time from stream start to the first PCM chunk (Raven is incremental).
  final int firstChunkMillis;

  /// Wall-clock time spent streaming native audio (start to end-of-stream).
  final int nativeGenerateMillis;

  /// Time spent trimming/fading and joining retry phrases.
  final int postProcessMillis;

  /// Time spent encoding and writing the WAV.
  final int wavWriteMillis;

  /// End-to-end time inside the worker, from request to written file.
  final int completeMillis;
}

/// Structured failure raised by the Raven worker, carrying a stable [reason]
/// token the engine maps onto a [TtsFailureCategory] without parsing messages.
class RavenSpeakException implements Exception {
  const RavenSpeakException(this.reason, this.message);

  /// One of: `create_failed`, `stream_start_failed`, `native_error`,
  /// `cancelled`, `output_too_long`.
  final String reason;
  final String message;

  @override
  String toString() => 'RavenSpeakException($reason): $message';
}

/// Owns the native Pocket TTS Raven engine in a dedicated background isolate.
///
/// All native work (loading the ~160 MB int8 models and streaming audio) is
/// blocking and CPU-heavy, so it runs off the UI isolate. Raven streams and is
/// genuinely interruptible: [cancel] aborts the in-flight synthesis within one
/// decode batch.
///
/// The isolate protocol is a request/response RPC over ports. The worker uses
/// `ReceivePort.listen` (not `await for`) so a `cancel` message is delivered
/// while a `speak` future is still in flight, and the streaming loop polls with
/// short event-loop yields so it can observe that cancellation promptly.
class RavenTtsService {
  Isolate? _isolate;
  SendPort? _toWorker;
  ReceivePort? _fromWorker;
  final Completer<void> _handshake = Completer<void>();
  final Map<int, Completer<Map<String, dynamic>>> _pending =
      <int, Completer<Map<String, dynamic>>>{};
  int _nextId = 0;
  bool _initialized = false;
  bool _dead = false;

  bool get isReady => _initialized;

  /// Loads the Raven models into memory inside a worker isolate. Call once
  /// before [speak].
  Future<void> init({
    required String modelsDir,
    required String voicesDir,
    required String tokenizerPath,
    String precision = 'int8',
    double temperature = 0.20,
    int lsdSteps = 4,
    int numThreads = 0,
  }) async {
    if (_isolate != null) return;

    final fromWorker = ReceivePort();
    _fromWorker = fromWorker;
    // onError/onExit funnel to the same port so a worker that dies (e.g. a
    // failed dlopen or a native crash) fails the handshake and every pending
    // RPC promptly, instead of leaving callers awaiting a reply that will never
    // come.
    _isolate = await Isolate.spawn(
      _ravenWorkerMain,
      fromWorker.sendPort,
      onError: fromWorker.sendPort,
      onExit: fromWorker.sendPort,
    );
    fromWorker.listen(_onWorkerMessage);
    await _handshake.future;

    final res = await _send(<String, dynamic>{
      'cmd': 'init',
      'modelsDir': modelsDir,
      'voicesDir': voicesDir,
      'tokenizerPath': tokenizerPath,
      'precision': precision,
      'temperature': temperature,
      'lsdSteps': lsdSteps,
      'numThreads': numThreads,
    });
    if (res['error'] != null) {
      throw RavenSpeakException('create_failed', res['error'] as String);
    }
    _initialized = true;
  }

  /// Generates [text] in [voice] (a filename inside the engine's voices dir)
  /// and writes the audio to [outputWavPath]. Returns per-stage timings.
  Future<RavenSpeakResult> speak({
    required String text,
    required String voice,
    required String outputWavPath,
  }) async {
    if (!_initialized) {
      throw StateError('RavenTtsService.init() must be called before speak().');
    }
    final res = await _send(<String, dynamic>{
      'cmd': 'speak',
      'text': text,
      'voice': voice,
      'out': outputWavPath,
    });
    if (res['error'] != null) {
      throw RavenSpeakException(
        (res['reason'] as String?) ?? 'native_error',
        res['error'] as String,
      );
    }
    return RavenSpeakResult(
      sampleRate: res['sampleRate'] as int,
      sampleCount: res['sampleCount'] as int,
      firstChunkMillis: res['firstChunkMillis'] as int,
      nativeGenerateMillis: res['nativeGenerateMillis'] as int,
      postProcessMillis: res['postProcessMillis'] as int,
      wavWriteMillis: res['wavWriteMillis'] as int,
      completeMillis: res['completeMillis'] as int,
    );
  }

  /// Requests cancellation of the in-flight synthesis, if any. Fire-and-forget:
  /// the pending [speak] future completes with a `cancelled` exception.
  void cancel() {
    final worker = _toWorker;
    if (worker == null) return;
    worker.send(<String, dynamic>{'cmd': 'cancel', 'id': -1});
  }

  void _onWorkerMessage(dynamic message) {
    if (message is SendPort) {
      _toWorker = message;
      if (!_handshake.isCompleted) _handshake.complete();
      return;
    }
    if (message is List) {
      // Uncaught error from the worker isolate: [errorString, stackString].
      final reason = _initialized ? 'native_error' : 'create_failed';
      final detail = message.isNotEmpty
          ? message.first?.toString() ?? 'Raven worker isolate error'
          : 'Raven worker isolate error';
      _failAll(RavenSpeakException(reason, detail));
      return;
    }
    if (message == null) {
      // onExit. Unexpected while work is outstanding (dispose closes the port
      // before killing the isolate, so a clean shutdown is not seen here).
      if (!_handshake.isCompleted || _pending.isNotEmpty) {
        final reason = _initialized ? 'native_error' : 'create_failed';
        _failAll(
          RavenSpeakException(
            reason,
            'Raven worker isolate exited unexpectedly',
          ),
        );
      }
      return;
    }
    final map = Map<String, dynamic>.from(message as Map);
    final id = map['id'] as int;
    if (id < 0) return; // cancel acks / async notices carry no waiter
    _pending.remove(id)?.complete(map);
  }

  /// Fails the handshake and every in-flight RPC with [error]. Called when the
  /// worker isolate dies so awaiting callers get a prompt, classified failure
  /// rather than hanging forever.
  void _failAll(Object error) {
    _dead = true;
    if (!_handshake.isCompleted) _handshake.completeError(error);
    final pending = _pending.values.toList();
    _pending.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) completer.completeError(error);
    }
  }

  Future<Map<String, dynamic>> _send(Map<String, dynamic> message) {
    if (_dead) {
      throw const RavenSpeakException(
        'native_error',
        'Raven worker isolate is no longer running.',
      );
    }
    final id = _nextId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _toWorker!.send(<String, dynamic>{...message, 'id': id});
    return completer.future;
  }

  Future<void> dispose() async {
    if (_isolate != null) {
      try {
        await _send(<String, dynamic>{'cmd': 'dispose'}).timeout(
          const Duration(seconds: 5),
          onTimeout: () => <String, dynamic>{},
        );
      } catch (_) {
        // Best-effort; we kill the isolate below regardless.
      }
    }
    _fromWorker?.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _toWorker = null;
    _fromWorker = null;
    _initialized = false;
  }
}

/// Sample rate of all Raven output (mono float32 PCM @ 24 kHz).
const int _kRavenSampleRate = 24000;

/// Entry point for the background Raven isolate.
///
/// Owns the native Raven handle for the lifetime of the isolate so the models
/// are loaded once and reused across [RavenTtsService.speak] calls.
void _ravenWorkerMain(SendPort toMain) {
  final port = ReceivePort();
  toMain.send(port.sendPort);

  final bindings = PocketTtsRavenBindings(openPocketTtsRavenLibrary());
  Pointer<Void> handle = nullptr;
  var cancelRequested = false;

  port.listen((dynamic message) async {
    final map = Map<String, dynamic>.from(message as Map);
    final id = map['id'] as int;
    final cmd = map['cmd'] as String;

    if (cmd == 'cancel') {
      // Observed by the streaming loop between polls; no reply expected.
      cancelRequested = true;
      return;
    }

    try {
      switch (cmd) {
        case 'init':
          final modelsDir = map['modelsDir'] as String;
          final voicesDir = map['voicesDir'] as String;
          final tokenizerPath = map['tokenizerPath'] as String;
          final precision = map['precision'] as String;
          final temperature = map['temperature'] as double;
          final lsdSteps = map['lsdSteps'] as int;
          final numThreads = map['numThreads'] as int;

          final cModels = modelsDir.toNativeUtf8();
          final cVoices = voicesDir.toNativeUtf8();
          final cTokenizer = tokenizerPath.toNativeUtf8();
          final cPrecision = precision.toNativeUtf8();
          try {
            handle = bindings.ptt_create(
              cModels.cast<Char>(),
              cVoices.cast<Char>(),
              cTokenizer.cast<Char>(),
              cPrecision.cast<Char>(),
              temperature,
              lsdSteps,
              numThreads,
            );
          } finally {
            malloc.free(cModels);
            malloc.free(cVoices);
            malloc.free(cTokenizer);
            malloc.free(cPrecision);
          }
          if (handle == nullptr) {
            toMain.send(<String, dynamic>{
              'id': id,
              'reason': 'create_failed',
              'error': 'ptt_create returned NULL (check model paths/precision)',
            });
            break;
          }
          toMain.send(<String, dynamic>{'id': id, 'ok': true});
          break;

        case 'speak':
          if (handle == nullptr) {
            throw StateError('init must run before speak');
          }
          cancelRequested = false;
          final voice = map['voice'] as String;
          final outPath = map['out'] as String;
          final text = normalizeTtsText(map['text'] as String);

          final complete = Stopwatch()..start();
          final nativeGen = Stopwatch();
          final post = Stopwatch();
          var firstChunkMillis = 0;

          // Streams one phrase to a single Float32List, applying the shared
          // runaway rejection. Returns null when the audio is implausibly long.
          Future<Float32List?> generatePlausible(
            String phrase, {
            required int attempts,
          }) async {
            final plausibleSeconds = plausibleAudioSeconds(phrase);
            for (var attempt = 0; attempt < attempts; attempt++) {
              final streamStartMs = complete.elapsed.inMilliseconds;
              nativeGen.start();
              final result = await _streamPhrase(
                bindings: bindings,
                handle: handle,
                text: phrase,
                voice: voice,
                isCancelled: () => cancelRequested,
              );
              nativeGen.stop();
              if (firstChunkMillis == 0 && result.firstChunkMillis >= 0) {
                firstChunkMillis = streamStartMs + result.firstChunkMillis;
              }
              final maxSamples = (plausibleSeconds * _kRavenSampleRate).round();
              if (result.samples.length <= maxSamples) {
                return result.samples;
              }
            }
            return null;
          }

          var generated = await generatePlausible(text, attempts: 1);
          if (generated == null) {
            final parts = <Float32List>[];
            final phrases = splitTtsRetryPhrases(text);
            for (final phrase in phrases) {
              final part = await generatePlausible(phrase, attempts: 2);
              if (part == null) {
                throw const RavenSpeakException(
                  'output_too_long',
                  'Raven produced implausibly long audio for a retry phrase.',
                );
              }
              post.start();
              parts.add(trimAndFadeClip(part, _kRavenSampleRate));
              post.stop();
            }
            post.start();
            generated = _joinPhrases(parts, _kRavenSampleRate);
            post.stop();
          }

          post.start();
          final samples = trimAndFadeClip(generated, _kRavenSampleRate);
          post.stop();

          final write = Stopwatch()..start();
          writeWavPcm16Atomic(outPath, samples, _kRavenSampleRate);
          write.stop();
          complete.stop();

          toMain.send(<String, dynamic>{
            'id': id,
            'sampleRate': _kRavenSampleRate,
            'sampleCount': samples.length,
            'firstChunkMillis': firstChunkMillis,
            'nativeGenerateMillis': nativeGen.elapsedMilliseconds,
            'postProcessMillis': post.elapsedMilliseconds,
            'wavWriteMillis': write.elapsedMilliseconds,
            'completeMillis': complete.elapsedMilliseconds,
          });
          break;

        case 'dispose':
          if (handle != nullptr) {
            bindings.ptt_destroy(handle);
            handle = nullptr;
          }
          toMain.send(<String, dynamic>{'id': id, 'ok': true});
          port.close();
          return;

        default:
          toMain.send(<String, dynamic>{
            'id': id,
            'error': 'unknown command: $cmd',
          });
      }
    } on RavenSpeakException catch (e) {
      toMain.send(<String, dynamic>{
        'id': id,
        'reason': e.reason,
        'error': e.message,
      });
    } catch (e) {
      toMain.send(<String, dynamic>{'id': id, 'error': e.toString()});
    }
  });
}

/// One streamed phrase: all chunks concatenated plus the time to first chunk.
class _PhraseStream {
  const _PhraseStream(this.samples, this.firstChunkMillis);
  final Float32List samples;

  /// Milliseconds from stream start to first chunk, or -1 if no chunk arrived.
  final int firstChunkMillis;
}

/// Streams a single phrase via the Raven C API, yielding to the event loop
/// between polls so an incoming cancel is observed. Throws [RavenSpeakException]
/// on a NULL stream, native terminal error, or cancellation.
Future<_PhraseStream> _streamPhrase({
  required PocketTtsRavenBindings bindings,
  required Pointer<Void> handle,
  required String text,
  required String voice,
  required bool Function() isCancelled,
}) async {
  final cText = text.toNativeUtf8();
  final cVoice = voice.toNativeUtf8();
  final outSamples = malloc<Pointer<Float>>();
  final outLen = malloc<Int>();
  const int msgBufLen = 256;
  final msgBuf = malloc<Char>(msgBufLen);

  Pointer<Void> ctx = nullptr;
  final chunks = <Float32List>[];
  var totalLen = 0;
  final sw = Stopwatch()..start();
  var firstChunkMillis = -1;

  try {
    ctx = bindings.ptt_stream_start(
      handle,
      cText.cast<Char>(),
      cVoice.cast<Char>(),
    );
    if (ctx == nullptr) {
      throw RavenSpeakException(
        'stream_start_failed',
        'ptt_stream_start returned NULL for voice "$voice"',
      );
    }

    var stopped = false;
    while (true) {
      final r = bindings.ptt_stream_poll(ctx, outSamples, outLen);
      if (r == 1) {
        final int n = outLen.value;
        final Pointer<Float> ptr = outSamples.value;
        if (n > 0 && ptr != nullptr) {
          if (firstChunkMillis < 0) firstChunkMillis = sw.elapsedMilliseconds;
          chunks.add(Float32List.fromList(ptr.asTypedList(n)));
          totalLen += n;
        }
        if (ptr != nullptr) bindings.ptt_free_audio(ptr);
        continue;
      }
      if (r == 0) break; // finished

      // r == -1: nothing ready yet.
      if (isCancelled() && !stopped) {
        bindings.ptt_stream_stop(ctx);
        stopped = true;
      }
      // Yield so the isolate can deliver a queued cancel and the generator
      // thread can enqueue the next chunk.
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }

    // Terminal error contract (see native patch 0001): non-zero => the stream
    // ended because generation threw.
    final int errCode = bindings.ptt_stream_error(ctx, msgBuf, msgBufLen);
    final bool cancelled = isCancelled();

    if (cancelled) {
      throw const RavenSpeakException('cancelled', 'Synthesis cancelled.');
    }
    if (errCode != 0) {
      final msg = msgBuf.cast<Utf8>().toDartString();
      throw RavenSpeakException(
        'native_error',
        msg.isEmpty ? 'Raven stream failed (code $errCode)' : msg,
      );
    }

    final out = Float32List(totalLen);
    var offset = 0;
    for (final c in chunks) {
      out.setRange(offset, offset + c.length, c);
      offset += c.length;
    }
    return _PhraseStream(out, firstChunkMillis);
  } finally {
    if (ctx != nullptr) bindings.ptt_stream_end(ctx);
    malloc.free(cText);
    malloc.free(cVoice);
    malloc.free(outSamples);
    malloc.free(outLen);
    malloc.free(msgBuf);
  }
}

/// Joins independently faded retry phrases with a short natural pause.
Float32List _joinPhrases(List<Float32List> phrases, int sampleRate) {
  if (phrases.isEmpty) return Float32List(0);
  if (phrases.length == 1) return phrases.single;
  final pauseSamples = (sampleRate * 0.08).round();
  final totalSamples =
      phrases.fold<int>(0, (sum, part) => sum + part.length) +
      pauseSamples * (phrases.length - 1);
  final joined = Float32List(totalSamples);
  var offset = 0;
  for (final phrase in phrases) {
    joined.setRange(offset, offset + phrase.length, phrase);
    offset += phrase.length + pauseSamples;
  }
  return joined;
}
