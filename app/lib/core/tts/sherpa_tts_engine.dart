import 'dart:async';

import 'model_manager.dart';
import 'synthesis_profile.dart';
import 'tts_engine.dart';
import 'tts_service.dart';
import 'tts_synthesis_request.dart';
import 'tts_synthesis_result.dart';
import 'tts_text_processing.dart';
import 'wav_io.dart';

/// The current sherpa-onnx PocketTTS backend, adapted to the [TtsEngine]
/// boundary without changing its audio behavior.
///
/// This is the baseline engine the Raven candidate is measured against. It owns
/// a [TtsService] (the persistent isolate + native handle) and maps its
/// per-stage timings onto the common [TtsSynthesisResult].
///
/// Its native call is not incremental and not interruptible, so
/// [cancelCurrentSynthesis] is a best-effort no-op: an in-flight synthesis runs
/// to completion (the scheduler already relies on this) and its clip is still
/// cached.
class SherpaTtsEngine implements TtsEngine {
  SherpaTtsEngine({
    required this._paths,
    TtsService? service,
    this.numSteps = 28,
    this.temperature = 0.20,
    this.seed = 1234,
    this.modelDescriptor = kSherpaBaselineModelDescriptor,
  }) : _service = service ?? TtsService();

  /// Stable descriptor for the January 2026 fp32 sherpa PocketTTS model. Sherpa
  /// installs a single archive rather than a hashed manifest, so this string
  /// stands in for the model identity in the synthesis profile.
  static const String kSherpaBaselineModelDescriptor =
      'sherpa-pocket-fp32-2026-01';

  final PocketModelPaths _paths;
  final TtsService _service;

  /// Flow-matching ODE solver step count (quality vs. speed).
  final int numSteps;

  /// Sampling temperature (lower sticks closer to the cloned voice).
  final double temperature;

  /// Fixed noise seed for reproducible output.
  final int seed;

  /// Model identity used in the synthesis profile.
  final String modelDescriptor;

  @override
  String get engineId => 'sherpa_onnx';

  @override
  bool get isReady => _service.isReady;

  @override
  SynthesisProfile get synthesisProfile => SynthesisProfile(
    engineId: engineId,
    engineRevision: '1.13.6',
    onnxRuntimeVersion: '1.27.1',
    modelManifestSha: modelDescriptor,
    precision: 'fp32',
    solverSteps: numSteps,
    temperatureMilli: (temperature * 1000).round(),
    seed: seed,
    maxFrames: 160,
    sampleRate: 24000,
    // Per-voice scoping is a Phase 4 cache concern; the baseline profile is
    // voice-agnostic and the benchmark records the voice id separately.
    voiceContentSha: '',
    textPolicyVersion: kTtsTextPolicyVersion,
    audioPolicyVersion: kTtsAudioPolicyVersion,
  );

  @override
  Future<void> initialize() => _service.init(_paths);

  @override
  Future<TtsSynthesisResult> synthesize(TtsSynthesisRequest request) async {
    if (!_service.isReady) {
      throw const TtsSynthesisException(
        TtsFailureCategory.nativeInitFailed,
        'SherpaTtsEngine.initialize() must run before synthesize().',
      );
    }

    // Request-to-complete-file wall time at the boundary (includes the isolate
    // round-trip), which is the user-visible latency to the published WAV.
    final complete = Stopwatch()..start();
    final SpeakResult result;
    try {
      result = await _service.speak(
        text: request.text,
        referenceWavPath: request.referenceWavPath,
        outputWavPath: request.outputWavPath,
        numSteps: numSteps,
        temperature: temperature,
        seed: seed,
      );
    } catch (error) {
      throw TtsSynthesisException(
        _classify(error),
        error.toString(),
      );
    }
    complete.stop();

    return TtsSynthesisResult(
      engineId: engineId,
      profileId: synthesisProfile.id,
      sampleCount: result.sampleCount,
      sampleRate: result.sampleRate,
      // requestToFirstChunkMillis stays null: sherpa's native call is not
      // incremental, so there is no first-chunk timing to report.
      nativeGenerateMillis: result.nativeGenerateMillis,
      postProcessMillis: result.postProcessMillis,
      wavWriteMillis: result.wavWriteMillis,
      requestToCompleteMillis: complete.elapsedMilliseconds,
    );
  }

  @override
  Future<void> cancelCurrentSynthesis() async {
    // No-op: the native generate call is not interruptible. The scheduler
    // allows an in-flight synthesis to finish; its clip is still cached.
  }

  @override
  Future<void> dispose() => _service.dispose();

  TtsFailureCategory _classify(Object error) {
    final message = error.toString();
    if (message.contains('implausibly long')) {
      return TtsFailureCategory.outputTooLong;
    }
    return TtsFailureCategory.nativeStreamFailed;
  }
}
