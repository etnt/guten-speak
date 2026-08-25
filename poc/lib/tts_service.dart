import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import 'model_manager.dart';

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
class TtsService {
  Isolate? _isolate;
  SendPort? _toWorker;
  ReceivePort? _fromWorker;
  final Completer<void> _handshake = Completer<void>();
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};
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

    final res = await _send({
      'cmd': 'init',
      'paths': {
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
  /// fixes the random noise so repeated runs are reproducible while tuning
  /// (pass a negative value for a random seed).
  Future<SpeakResult> speak({
    required String text,
    required String referenceWavPath,
    required String outputWavPath,
    int numSteps = 16,
    double temperature = 0.5,
    int seed = 1234,
  }) async {
    if (!_initialized) {
      throw StateError('TtsService.init() must be called before speak().');
    }
    final res = await _send({
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
    _toWorker!.send({...message, 'id': id});
    return completer.future;
  }

  Future<void> dispose() async {
    if (_isolate != null) {
      try {
        await _send({'cmd': 'dispose'}).timeout(
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
          toMain.send({'id': id, 'ok': true});
          break;

        case 'speak':
          final engine = tts;
          if (engine == null) {
            throw StateError('init must run before speak');
          }
          final wave = _readWavAsFloat32(map['ref'] as String, normalize: true);
          final numSteps = map['numSteps'] as int;
          final temperature = map['temperature'] as double;
          final seed = map['seed'] as int;

          final genConfig = sherpa_onnx.OfflineTtsGenerationConfig(
            sid: 0,
            speed: 1.0,
            numSteps: numSteps,
            referenceAudio: wave.samples,
            referenceSampleRate: wave.sampleRate,
            extra: {
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

          toMain.send({
            'id': id,
            'sampleRate': audio.sampleRate,
            'audioSeconds': seconds,
            'generateMillis': stopwatch.elapsedMilliseconds,
          });
          break;

        case 'dispose':
          tts?.free();
          tts = null;
          toMain.send({'id': id, 'ok': true});
          port.close();
          return;

        default:
          toMain.send({'id': id, 'error': 'unknown command: $cmd'});
      }
    } catch (e) {
      toMain.send({'id': id, 'error': e.toString()});
    }
  }
}

/// Decoded mono PCM audio as normalized floats in [-1, 1].
class _Wave {
  const _Wave({required this.samples, required this.sampleRate});
  final Float32List samples;
  final int sampleRate;
}

/// Minimal, tolerant WAV reader.
///
/// Unlike sherpa-onnx's `readWave`, this handles a `fmt ` chunk larger than 16
/// bytes (e.g. WAVE_FORMAT_EXTENSIBLE, which the macOS recorder emits) and
/// IEEE float samples, and it downmixes multi-channel audio to mono.
///
/// When [normalize] is true, the audio is peak-normalized so a quietly recorded
/// reference still yields a strong voice embedding.
_Wave _readWavAsFloat32(String path, {bool normalize = false}) {
  final file = File(path);
  if (!file.existsSync()) {
    throw Exception('Reference audio not found: $path');
  }
  final bytes = file.readAsBytesSync();
  final data = ByteData.sublistView(bytes);

  if (bytes.length < 12 ||
      _tag(bytes, 0) != 'RIFF' ||
      _tag(bytes, 8) != 'WAVE') {
    throw Exception('Not a RIFF/WAVE file: $path');
  }

  int format = 1; // 1 = PCM, 3 = IEEE float, 0xFFFE = extensible
  int channels = 1;
  int sampleRate = 0;
  int bitsPerSample = 16;
  int dataOffset = -1;
  int dataSize = 0;

  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = _tag(bytes, offset);
    final size = data.getUint32(offset + 4, Endian.little);
    final body = offset + 8;
    if (id == 'fmt ') {
      format = data.getUint16(body, Endian.little);
      channels = data.getUint16(body + 2, Endian.little);
      sampleRate = data.getUint32(body + 4, Endian.little);
      bitsPerSample = data.getUint16(body + 14, Endian.little);
      if (format == 0xFFFE && size >= 40) {
        // Extensible: real format is the first 2 bytes of the SubFormat GUID.
        format = data.getUint16(body + 24, Endian.little);
      }
    } else if (id == 'data') {
      dataOffset = body;
      dataSize = size;
      break;
    }
    // Chunks are word-aligned (padded to even size).
    offset = body + size + (size.isOdd ? 1 : 0);
  }

  if (dataOffset < 0 || sampleRate == 0) {
    throw Exception('Missing fmt/data chunk in WAV: $path');
  }
  if (dataOffset + dataSize > bytes.length) {
    dataSize = bytes.length - dataOffset;
  }

  final bytesPerSample = bitsPerSample ~/ 8;
  if (bytesPerSample == 0 || channels == 0) {
    throw Exception('Invalid WAV format: $path');
  }
  final frameCount = dataSize ~/ (bytesPerSample * channels);
  final out = Float32List(frameCount);

  double readSample(int byteIndex) {
    switch (format) {
      case 3: // IEEE float
        if (bitsPerSample == 64) {
          return data.getFloat64(byteIndex, Endian.little);
        }
        return data.getFloat32(byteIndex, Endian.little);
      default: // PCM integer
        switch (bitsPerSample) {
          case 8:
            return (bytes[byteIndex] - 128) / 128.0;
          case 16:
            return data.getInt16(byteIndex, Endian.little) / 32768.0;
          case 24:
            final b0 = bytes[byteIndex];
            final b1 = bytes[byteIndex + 1];
            final b2 = bytes[byteIndex + 2];
            var v = b0 | (b1 << 8) | (b2 << 16);
            if (v & 0x800000 != 0) v |= ~0xFFFFFF; // sign-extend
            return v / 8388608.0;
          case 32:
            return data.getInt32(byteIndex, Endian.little) / 2147483648.0;
          default:
            throw Exception('Unsupported bit depth: $bitsPerSample');
        }
    }
  }

  for (var i = 0; i < frameCount; i++) {
    final frameStart = dataOffset + i * bytesPerSample * channels;
    if (channels == 1) {
      out[i] = readSample(frameStart);
    } else {
      var sum = 0.0;
      for (var c = 0; c < channels; c++) {
        sum += readSample(frameStart + c * bytesPerSample);
      }
      out[i] = sum / channels;
    }
  }

  if (normalize && out.isNotEmpty) {
    return _Wave(samples: _conditionReference(out), sampleRate: sampleRate);
  }

  return _Wave(samples: out, sampleRate: sampleRate);
}

/// Prepares a recorded reference clip so it yields a usable speaker embedding.
///
/// Phone recordings are often quiet with lots of dead air (e.g. RMS ≈ −35 dBFS,
/// >50% near-silence). Feeding that straight in makes the embedding collapse to
/// noise and PocketTTS runs away generating white noise. We (1) trim leading and
/// trailing near-silence so the embedding is computed over speech, and
/// (2) normalize using a high percentile (not the absolute peak) so a single
/// transient doesn't cap the gain, then hard-clip the rare overshoots.
Float32List _conditionReference(Float32List samples) {
  var peak = 0.0;
  for (final s in samples) {
    final a = s.abs();
    if (a > peak) peak = a;
  }
  if (peak <= 1e-4) return samples; // effectively silent; nothing to do

  // Trim leading/trailing samples below -34 dB relative to the peak.
  final gate = peak * 0.02;
  var start = 0;
  while (start < samples.length && samples[start].abs() < gate) {
    start++;
  }
  var end = samples.length - 1;
  while (end > start && samples[end].abs() < gate) {
    end--;
  }
  final trimmed = (start > 0 || end < samples.length - 1)
      ? Float32List.sublistView(samples, start, end + 1)
      : samples;
  if (trimmed.isEmpty) return samples;

  // Robust level: 99th-percentile magnitude ignores rare spikes so quiet
  // speech is actually lifted instead of being limited by one transient.
  final mags = Float32List(trimmed.length);
  for (var i = 0; i < trimmed.length; i++) {
    mags[i] = trimmed[i].abs();
  }
  mags.sort();
  final p99 = mags[((mags.length - 1) * 0.99).floor()];
  if (p99 <= 1e-4) return trimmed;

  var gain = 0.9 / p99;
  if (gain < 1.0) gain = 1.0; // never make an already-strong recording quieter
  if (gain > 12.0) gain = 12.0; // avoid amplifying pure noise without bound
  for (var i = 0; i < trimmed.length; i++) {
    var v = trimmed[i] * gain;
    if (v > 1.0) {
      v = 1.0;
    } else if (v < -1.0) {
      v = -1.0;
    }
    trimmed[i] = v;
  }
  return trimmed;
}

String _tag(Uint8List bytes, int offset) =>
    String.fromCharCodes(bytes.sublist(offset, offset + 4));
