import 'synthesis_profile.dart';
import 'tts_synthesis_request.dart';
import 'tts_synthesis_result.dart';

/// Structured, engine-independent failure categories. Kept as a stable enum so
/// logs and benchmarks classify failures without parsing native stderr.
enum TtsFailureCategory {
  modelInvalid,
  voiceInvalid,
  nativeInitFailed,
  nativeStreamFailed,
  cancelled,
  outputTooLong,
  invalidSamples,
  wavWriteFailed,
  wavValidationFailed,
  shutdownTimeout,
}

/// Thrown by a [TtsEngine] when a synthesis fails, carrying a structured
/// [category] so callers never have to interpret free-form messages.
class TtsSynthesisException implements Exception {
  const TtsSynthesisException(this.category, this.message);

  final TtsFailureCategory category;
  final String message;

  @override
  String toString() => 'TtsSynthesisException(${category.name}): $message';
}

/// The stable app-side boundary every TTS backend implements.
///
/// Configuration (model paths, step count, temperature, thread budget) is
/// supplied when the engine is constructed, so [initialize] needs no
/// engine-specific argument. The scheduler, cache, and player depend only on
/// this contract and never on a concrete engine.
abstract class TtsEngine {
  /// Stable engine identifier, e.g. `sherpa_onnx` or `pocket_tts_raven`.
  String get engineId;

  /// The canonical profile describing this engine's fixed configuration.
  SynthesisProfile get synthesisProfile;

  /// Whether the engine has been initialized and can synthesize.
  bool get isReady;

  /// Loads the model/runtime into memory. Call once before [synthesize].
  Future<void> initialize();

  /// Renders one request to its output WAV and returns timing/audio facts.
  ///
  /// Throws [TtsSynthesisException] with a structured category on failure. A
  /// cancelled or failed request must never leave a cacheable final file.
  Future<TtsSynthesisResult> synthesize(TtsSynthesisRequest request);

  /// Requests cancellation of the in-flight synthesis, if any.
  Future<void> cancelCurrentSynthesis();

  /// Releases the model/runtime and any worker resources.
  Future<void> dispose();
}
