/// Timing and audio facts returned for one completed synthesis.
///
/// Reports both a native-compute real-time factor and a complete-pipeline
/// real-time factor, so a faster native path that spends the win on
/// post-processing or file writes cannot look better than it is. User-visible
/// latency is measured to a validated, atomically published WAV — not merely
/// the engine's first callback.
class TtsSynthesisResult {
  const TtsSynthesisResult({
    required this.engineId,
    required this.profileId,
    required this.sampleCount,
    required this.sampleRate,
    required this.nativeGenerateMillis,
    required this.postProcessMillis,
    required this.wavWriteMillis,
    required this.requestToCompleteMillis,
    this.requestToFirstChunkMillis,
    this.cacheWarm,
  });

  /// Engine that produced this clip.
  final String engineId;

  /// Synthesis-profile id (SHA-256) this clip was rendered under.
  final String profileId;

  /// Number of PCM samples written.
  final int sampleCount;

  /// Output sample rate in Hz.
  final int sampleRate;

  /// Time to the first streamed chunk. `null` for engines (like sherpa) whose
  /// native call is not incremental.
  final int? requestToFirstChunkMillis;

  /// Wall-clock time spent in native generation/streaming.
  final int nativeGenerateMillis;

  /// Time spent trimming/fading and otherwise post-processing samples.
  final int postProcessMillis;

  /// Time spent encoding and writing the WAV.
  final int wavWriteMillis;

  /// End-to-end time from request acceptance to the atomically published,
  /// validated WAV file.
  final int requestToCompleteMillis;

  /// Whether the engine's voice/KV cache was warm, when it can be determined
  /// reliably. `null` when unknown.
  final bool? cacheWarm;

  /// Generated audio duration in seconds.
  double get audioSeconds => sampleRate > 0 ? sampleCount / sampleRate : 0.0;

  /// Native-compute real-time factor: `< 1.0` means faster than real time.
  double get nativeRealTimeFactor {
    final seconds = audioSeconds;
    return seconds > 0 ? (nativeGenerateMillis / 1000.0) / seconds : 0.0;
  }

  /// Complete-pipeline real-time factor to the published file.
  double get pipelineRealTimeFactor {
    final seconds = audioSeconds;
    return seconds > 0 ? (requestToCompleteMillis / 1000.0) / seconds : 0.0;
  }

  /// Flat map for JSONL benchmark output.
  Map<String, Object?> toJson() => <String, Object?>{
    'engineId': engineId,
    'profileId': profileId,
    'sampleCount': sampleCount,
    'sampleRate': sampleRate,
    'requestToFirstChunkMillis': requestToFirstChunkMillis,
    'nativeGenerateMillis': nativeGenerateMillis,
    'postProcessMillis': postProcessMillis,
    'wavWriteMillis': wavWriteMillis,
    'requestToCompleteMillis': requestToCompleteMillis,
    'cacheWarm': cacheWarm,
    'audioSeconds': audioSeconds,
    'nativeRealTimeFactor': nativeRealTimeFactor,
    'pipelineRealTimeFactor': pipelineRealTimeFactor,
  };
}
