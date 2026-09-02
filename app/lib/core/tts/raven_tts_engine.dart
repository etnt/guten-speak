import 'dart:async';

import 'package:path/path.dart' as p;

import 'raven_tts_service.dart';
import 'synthesis_profile.dart';
import 'tts_engine.dart';
import 'tts_synthesis_request.dart';
import 'tts_synthesis_result.dart';
import 'tts_text_processing.dart';
import 'wav_io.dart';

/// Directory-based model layout for the Pocket TTS Raven engine.
///
/// Unlike sherpa (which lists individual ONNX file paths), Raven's C API takes
/// three roots and discovers the precision-specific graphs itself:
///   * [modelsDir] — holds the `*_int8.onnx` graphs plus `bos_before_voice.npy`.
///   * [voicesDir] — holds the reference `.wav` clips; embeddings are cached to
///     a `.cache` subfolder that must be writable.
///   * [tokenizerPath] — the SentencePiece `tokenizer.model`.
class RavenModelPaths {
  const RavenModelPaths({
    required this.modelsDir,
    required this.voicesDir,
    required this.tokenizerPath,
  });

  final String modelsDir;
  final String voicesDir;
  final String tokenizerPath;
}

/// The Pocket TTS Raven candidate engine, on the shared [TtsEngine] boundary.
///
/// Runs the winning production configuration from the A/B listening test:
/// int8 weights, a 4-step flow solver, and temperature 0.20. It owns a
/// [RavenTtsService] (persistent isolate + native handle) and, unlike sherpa,
/// streams incrementally and is genuinely interruptible, so
/// [cancelCurrentSynthesis] actually aborts the in-flight clip.
class RavenTtsEngine implements TtsEngine {
  RavenTtsEngine({
    required this._paths,
    required this.modelManifestSha,
    RavenTtsService? service,
    this.precision = 'int8',
    this.lsdSteps = 4,
    this.temperature = 0.20,
    this.numThreads = 0,
  }) : _service = service ?? RavenTtsService();

  /// Upstream Raven native revision this build vendors (short SHA).
  static const String kEngineRevision = 'abd26158';

  final RavenModelPaths _paths;
  final RavenTtsService _service;

  /// SHA-256 of the installed Raven model manifest (cache identity).
  final String modelManifestSha;

  /// Weight precision: the winning config is int8.
  final String precision;

  /// Flow-matching ODE solver step count: the winning config is 4.
  final int lsdSteps;

  /// Sampling temperature: the winning config is 0.20.
  final double temperature;

  /// Native intra-op thread budget; 0 lets Raven pick (~half the cores).
  final int numThreads;

  @override
  String get engineId => 'pocket_tts_raven';

  @override
  bool get isReady => _service.isReady;

  @override
  SynthesisProfile get synthesisProfile => SynthesisProfile(
    engineId: engineId,
    engineRevision: kEngineRevision,
    onnxRuntimeVersion: '1.23.2',
    modelManifestSha: modelManifestSha,
    precision: precision,
    solverSteps: lsdSteps,
    temperatureMilli: (temperature * 1000).round(),
    // Raven seeds from wall-clock time, so output is not reproducible; a
    // fixed sentinel keeps the profile stable across runs.
    seed: 0,
    // Raven bounds generation by end-of-stream, not a fixed frame cap.
    maxFrames: 0,
    sampleRate: 24000,
    // Per-voice scoping is a Phase 4 cache concern; the profile is
    // voice-agnostic and the benchmark records the voice id separately.
    voiceContentSha: '',
    textPolicyVersion: kTtsTextPolicyVersion,
    audioPolicyVersion: kTtsAudioPolicyVersion,
  );

  @override
  Future<void> initialize() => _service.init(
    modelsDir: _paths.modelsDir,
    voicesDir: _paths.voicesDir,
    tokenizerPath: _paths.tokenizerPath,
    precision: precision,
    temperature: temperature,
    lsdSteps: lsdSteps,
    numThreads: numThreads,
  );

  @override
  Future<TtsSynthesisResult> synthesize(TtsSynthesisRequest request) async {
    if (!_service.isReady) {
      throw const TtsSynthesisException(
        TtsFailureCategory.nativeInitFailed,
        'RavenTtsEngine.initialize() must run before synthesize().',
      );
    }

    // Raven clones from a voice file inside its voices dir, addressed by name.
    final voice = p.basename(request.referenceWavPath);

    final complete = Stopwatch()..start();
    final RavenSpeakResult result;
    try {
      result = await _service.speak(
        text: request.text,
        voice: voice,
        outputWavPath: request.outputWavPath,
      );
    } on RavenSpeakException catch (error) {
      throw TtsSynthesisException(_classify(error.reason), error.message);
    } catch (error) {
      throw TtsSynthesisException(
        TtsFailureCategory.nativeStreamFailed,
        error.toString(),
      );
    }
    complete.stop();

    return TtsSynthesisResult(
      engineId: engineId,
      profileId: synthesisProfile.id,
      sampleCount: result.sampleCount,
      sampleRate: result.sampleRate,
      requestToFirstChunkMillis: result.firstChunkMillis,
      nativeGenerateMillis: result.nativeGenerateMillis,
      postProcessMillis: result.postProcessMillis,
      wavWriteMillis: result.wavWriteMillis,
      requestToCompleteMillis: complete.elapsedMilliseconds,
    );
  }

  @override
  Future<void> cancelCurrentSynthesis() async {
    // Raven is interruptible: abort the in-flight decode. The pending
    // synthesize() future completes with a cancelled TtsSynthesisException and
    // no WAV is published.
    _service.cancel();
  }

  @override
  Future<void> dispose() => _service.dispose();

  TtsFailureCategory _classify(String reason) {
    switch (reason) {
      case 'create_failed':
        return TtsFailureCategory.nativeInitFailed;
      case 'stream_start_failed':
        return TtsFailureCategory.voiceInvalid;
      case 'cancelled':
        return TtsFailureCategory.cancelled;
      case 'output_too_long':
        return TtsFailureCategory.outputTooLong;
      case 'native_error':
      default:
        return TtsFailureCategory.nativeStreamFailed;
    }
  }
}
