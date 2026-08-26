import 'dart:async';
import 'dart:isolate';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import 'model_manager.dart';
import 'wav_io.dart';

/// Result of a single clone + synthesize call.
class SpeakResult {
  const SpeakResult({
    required this.sampleRate,
    required this.audioSeconds,
    required this.generateMillis,
  });

  final int sampleRate;

  /// Duration of the generated audio in seconds.
  final double audioSeconds;

  /// Wall-clock time spent inside `generateWithConfig`, in milliseconds.
  final int generateMillis;

  /// Real-time factor: < 1.0 means faster than real time.
  double get realTimeFactor =>
      audioSeconds > 0 ? (generateMillis / 1000.0) / audioSeconds : 0;
}

/// Thin wrapper around sherpa-onnx PocketTTS zero-shot voice cloning.
///
/// PocketTTS clones a voice from a short reference clip and needs **no**
/// reference transcript.
///
/// All native work (loading the ~470 MB fp32 model and synthesizing audio) is
/// blocking and CPU-heavy, so it runs inside a dedicated background isolate.
/// Doing it on the UI isolate froze the app long enough to trigger Android's
/// "application doesn't respond" (ANR) dialog.
///
/// The isolate protocol is a request/response RPC over ports: the first worker
/// message hands back its [SendPort] (handshake), then every command
/// (`init`/`speak`/`dispose`) carries a numeric `id` the worker echoes so
/// concurrent calls can be correlated. Errors come back as `{id, error}`.
class TtsService {
  Isolate? _isolate;
  SendPort? _toWorker;
  ReceivePort? _fromWorker;
  final Completer<void> _handshake = Completer<void>();
  final Map<int, Completer<Map<String, dynamic>>> _pending =
      <int, Completer<Map<String, dynamic>>>{};
  int _nextId = 0;
  bool _initialized = false;

  bool get isReady => _initialized;

  /// Loads the model into memory inside a worker isolate. Call once before
  /// [speak].
  Future<void> init(PocketModelPaths paths) async {
    if (_isolate != null) return;

    final fromWorker = ReceivePort();
    _fromWorker = fromWorker;
    _isolate = await Isolate.spawn(_ttsWorkerMain, fromWorker.sendPort);
    fromWorker.listen(_onWorkerMessage);
    await _handshake.future;

    final res = await _send(<String, dynamic>{
      'cmd': 'init',
      'paths': <String, String>{
        'lmFlow': paths.lmFlow,
        'lmMain': paths.lmMain,
        'encoder': paths.encoder,
        'decoder': paths.decoder,
        'textConditioner': paths.textConditioner,
        'vocabJson': paths.vocabJson,
        'tokenScoresJson': paths.tokenScoresJson,
      },
    });
    if (res['error'] != null) {
      throw Exception('TTS init failed: ${res['error']}');
    }
    _initialized = true;
  }

  /// Generates [text] in the voice of [referenceWavPath] and writes the audio
  /// to [outputWavPath]. Returns timing info for evaluation.
  ///
  /// [temperature] controls sampling randomness: lower values stick closer to
  /// the cloned voice (less drift), higher values sound more varied. [seed]
  /// fixes the random noise so repeated runs are reproducible (pass a negative
  /// value for a random seed). The defaults are the PoC's tuned values.
  Future<SpeakResult> speak({
    required String text,
    required String referenceWavPath,
    required String outputWavPath,
    int numSteps = 28,
    double temperature = 0.20,
    int seed = 1234,
  }) async {
    if (!_initialized) {
      throw StateError('TtsService.init() must be called before speak().');
    }
    final res = await _send(<String, dynamic>{
      'cmd': 'speak',
      'text': text,
      'ref': referenceWavPath,
      'out': outputWavPath,
      'numSteps': numSteps,
      'temperature': temperature,
      'seed': seed,
    });
    if (res['error'] != null) {
      throw Exception('TTS speak failed: ${res['error']}');
    }
    return SpeakResult(
      sampleRate: res['sampleRate'] as int,
      audioSeconds: res['audioSeconds'] as double,
      generateMillis: res['generateMillis'] as int,
    );
  }

  void _onWorkerMessage(dynamic message) {
    if (message is SendPort) {
      _toWorker = message;
      if (!_handshake.isCompleted) _handshake.complete();
      return;
    }
    final map = Map<String, dynamic>.from(message as Map);
    final id = map['id'] as int;
    _pending.remove(id)?.complete(map);
  }

  Future<Map<String, dynamic>> _send(Map<String, dynamic> message) {
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

/// Entry point for the background TTS isolate.
///
/// Owns the native [sherpa_onnx.OfflineTts] for the lifetime of the isolate so
/// the model is loaded once and reused across [TtsService.speak] calls.
Future<void> _ttsWorkerMain(SendPort toMain) async {
  final port = ReceivePort();
  toMain.send(port.sendPort);

  sherpa_onnx.OfflineTts? tts;

  await for (final message in port) {
    final map = Map<String, dynamic>.from(message as Map);
    final id = map['id'] as int;
    final cmd = map['cmd'] as String;
    try {
      switch (cmd) {
        case 'init':
          await sherpa_onnx.initBindingsAsync();
          final p = Map<String, dynamic>.from(map['paths'] as Map);
          final pocket = sherpa_onnx.OfflineTtsPocketModelConfig(
            lmFlow: p['lmFlow'] as String,
            lmMain: p['lmMain'] as String,
            encoder: p['encoder'] as String,
            decoder: p['decoder'] as String,
            textConditioner: p['textConditioner'] as String,
            vocabJson: p['vocabJson'] as String,
            tokenScoresJson: p['tokenScoresJson'] as String,
          );
          tts = sherpa_onnx.OfflineTts(
            sherpa_onnx.OfflineTtsConfig(
              model: sherpa_onnx.OfflineTtsModelConfig(
                pocket: pocket,
                numThreads: 4,
                debug: false,
              ),
            ),
          );
          toMain.send(<String, dynamic>{'id': id, 'ok': true});
          break;

        case 'speak':
          final engine = tts;
          if (engine == null) {
            throw StateError('init must run before speak');
          }
          final wave = readWavAsFloat32(map['ref'] as String, normalize: true);
          final numSteps = map['numSteps'] as int;
          final temperature = map['temperature'] as double;
          final seed = map['seed'] as int;

          final genConfig = sherpa_onnx.OfflineTtsGenerationConfig(
            numSteps: numSteps,
            referenceAudio: wave.samples,
            referenceSampleRate: wave.sampleRate,
            extra: <String, Object>{
              'max_reference_audio_len': 12,
              'temperature': temperature,
              'seed': seed,
            },
          );

          final stopwatch = Stopwatch()..start();
          final audio = engine.generateWithConfig(
            text: map['text'] as String,
            config: genConfig,
          );
          stopwatch.stop();

          sherpa_onnx.writeWave(
            filename: map['out'] as String,
            samples: audio.samples,
            sampleRate: audio.sampleRate,
          );

          final seconds = audio.sampleRate > 0
              ? audio.samples.length / audio.sampleRate
              : 0.0;

          toMain.send(<String, dynamic>{
            'id': id,
            'sampleRate': audio.sampleRate,
            'audioSeconds': seconds,
            'generateMillis': stopwatch.elapsedMilliseconds,
          });
          break;

        case 'dispose':
          tts?.free();
          tts = null;
          toMain.send(<String, dynamic>{'id': id, 'ok': true});
          port.close();
          return;

        default:
          toMain.send(<String, dynamic>{
            'id': id,
            'error': 'unknown command: $cmd',
          });
      }
    } catch (e) {
      toMain.send(<String, dynamic>{'id': id, 'error': e.toString()});
    }
  }
}
