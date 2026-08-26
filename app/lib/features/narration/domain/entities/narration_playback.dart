/// The lifecycle of narrated playback for the currently loaded book.
enum NarrationStatus {
  /// Nothing loaded.
  idle,

  /// A book/voice is being loaded (scheduler spinning up).
  loading,

  /// Pre-rendering the whole selection to disk before playback so it plays
  /// without pauses (on-device synthesis is slower than real time).
  preparing,

  /// Waiting on the scheduler to render the current unit before it can play.
  buffering,

  /// Actively playing a unit's audio.
  playing,

  /// Loaded and ready but paused by the user.
  paused,

  /// Played through the prepared head start; stopped and waiting for the user
  /// to choose how much to prepare next before continuing.
  awaitingHeadStart,

  /// Reached the end of the book.
  completed,

  /// A synthesis or playback error stopped playback.
  error,
}

/// Immutable snapshot of the narration player, surfaced to the UI (player
/// screen + mini-player) via a stream.
class NarrationPlaybackState {
  const NarrationPlaybackState({
    this.status = NarrationStatus.idle,
    this.bookId,
    this.bookTitle = '',
    this.voiceId,
    this.voiceName = '',
    this.unitIndex = 0,
    this.unitCount = 0,
    this.currentText = '',
    this.speed = 1.0,
    this.error,
    this.preparedCount = 0,
    this.prepTarget = 0,
    this.etaSeconds,
  });

  final NarrationStatus status;
  final int? bookId;
  final String bookTitle;
  final String? voiceId;
  final String voiceName;
  final int unitIndex;
  final int unitCount;
  final String currentText;
  final double speed;
  final String? error;

  /// Units rendered to disk so far during the [NarrationStatus.preparing]
  /// phase.
  final int preparedCount;

  /// Total units that must be rendered before playback can start gaplessly.
  final int prepTarget;

  /// Rough estimate of the remaining preparation time, in seconds; null until
  /// at least one unit has been timed.
  final int? etaSeconds;

  /// A book is loaded (whether playing, paused, or buffering).
  bool get isActive => bookId != null && status != NarrationStatus.idle;

  bool get isPlaying => status == NarrationStatus.playing;

  bool get isPreparing => status == NarrationStatus.preparing;

  /// Played out the prepared head start and is waiting for the user to pick the
  /// next head-start size before continuing.
  bool get isAwaitingHeadStart => status == NarrationStatus.awaitingHeadStart;

  bool get isBuffering =>
      status == NarrationStatus.buffering || status == NarrationStatus.loading;

  /// Fraction of the preparation pass complete, in `[0, 1]`.
  double get prepFraction =>
      prepTarget == 0 ? 0 : (preparedCount / prepTarget).clamp(0.0, 1.0);

  /// Fraction through the book by unit index, in `[0, 1]`.
  double get progress => unitCount == 0 ? 0 : (unitIndex + 1) / unitCount;

  NarrationPlaybackState copyWith({
    NarrationStatus? status,
    int? bookId,
    String? bookTitle,
    String? voiceId,
    String? voiceName,
    int? unitIndex,
    int? unitCount,
    String? currentText,
    double? speed,
    String? error,
    int? preparedCount,
    int? prepTarget,
    int? etaSeconds,
  }) {
    return NarrationPlaybackState(
      status: status ?? this.status,
      bookId: bookId ?? this.bookId,
      bookTitle: bookTitle ?? this.bookTitle,
      voiceId: voiceId ?? this.voiceId,
      voiceName: voiceName ?? this.voiceName,
      unitIndex: unitIndex ?? this.unitIndex,
      unitCount: unitCount ?? this.unitCount,
      currentText: currentText ?? this.currentText,
      speed: speed ?? this.speed,
      error: error,
      preparedCount: preparedCount ?? this.preparedCount,
      prepTarget: prepTarget ?? this.prepTarget,
      etaSeconds: etaSeconds,
    );
  }
}
