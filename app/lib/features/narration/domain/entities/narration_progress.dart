/// A resume point for narrated playback of a book: the last unit reached in a
/// given voice and the play position within that unit's clip.
class NarrationProgress {
  const NarrationProgress({
    required this.bookId,
    required this.voiceId,
    required this.unitIndex,
    required this.positionMs,
    required this.updatedAt,
  });

  final int bookId;
  final String voiceId;
  final int unitIndex;
  final int positionMs;
  final DateTime updatedAt;
}
