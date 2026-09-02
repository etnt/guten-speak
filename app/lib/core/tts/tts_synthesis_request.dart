/// A single unit-of-narration synthesis request handed to a [TtsEngine].
///
/// Engine-independent: it carries only what any engine needs to turn one
/// reading unit into one WAV file. The engine's fixed configuration (model
/// paths, step count, temperature, thread budget) is supplied at construction,
/// not per request.
class TtsSynthesisRequest {
  const TtsSynthesisRequest({
    required this.requestId,
    required this.text,
    required this.voiceId,
    required this.referenceWavPath,
    required this.outputWavPath,
  });

  /// Correlates the request with its result, logs, and any cancellation.
  final String requestId;

  /// The reading unit's text, before engine-specific normalization.
  final String text;

  /// Stable Guten-Speak voice identifier this clip is rendered in.
  final String voiceId;

  /// Path to the reference/voice WAV the engine clones from.
  final String referenceWavPath;

  /// Path the engine must write the finished, validated WAV to.
  final String outputWavPath;
}
