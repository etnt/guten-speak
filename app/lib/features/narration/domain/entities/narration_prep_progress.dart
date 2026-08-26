/// The phase of preparing narration: downloading + extracting the PocketTTS
/// model, then loading it into the worker isolate.
enum NarrationPrepPhase {
  /// Nothing started; the model may or may not be installed yet.
  idle,

  /// Downloading the ~470 MB model archive.
  downloading,

  /// Decompressing and unpacking the archive.
  extracting,

  /// Loading the model into the TTS worker isolate.
  loading,

  /// Model is loaded and the engine is ready to synthesize.
  ready,

  /// Preparation failed.
  error;

  /// Whether preparation is actively running.
  bool get isBusy =>
      this == NarrationPrepPhase.downloading ||
      this == NarrationPrepPhase.extracting ||
      this == NarrationPrepPhase.loading;
}

/// Progress of the one-time model download + engine load that gates narration.
class NarrationPrepProgress {
  const NarrationPrepProgress({required this.phase, this.fraction, this.error});

  const NarrationPrepProgress.idle() : this(phase: NarrationPrepPhase.idle);

  const NarrationPrepProgress.downloading(double? fraction)
    : this(phase: NarrationPrepPhase.downloading, fraction: fraction);

  const NarrationPrepProgress.extracting()
    : this(phase: NarrationPrepPhase.extracting);

  const NarrationPrepProgress.loading()
    : this(phase: NarrationPrepPhase.loading);

  const NarrationPrepProgress.ready() : this(phase: NarrationPrepPhase.ready);

  const NarrationPrepProgress.error(String message)
    : this(phase: NarrationPrepPhase.error, error: message);

  final NarrationPrepPhase phase;

  /// Download completion fraction (0..1); null when the total is unknown or the
  /// phase has no measurable progress.
  final double? fraction;

  /// Error message when [phase] is [NarrationPrepPhase.error].
  final String? error;

  bool get isReady => phase == NarrationPrepPhase.ready;
}
