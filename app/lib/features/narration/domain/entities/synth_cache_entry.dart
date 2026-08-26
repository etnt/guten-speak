/// A single indexed entry in the narration synthesis cache: the rendered audio
/// for one narration unit of a book in a specific voice.
///
/// The tuple `(bookId, voiceId, unitIndex)` is the primary key. [unitHash] is a
/// deterministic hash of the unit's source text, used to detect when a cached
/// clip is stale (e.g. the book text changed on re-download) so it can be
/// re-rendered rather than replayed incorrectly.
class SynthCacheEntry {
  const SynthCacheEntry({
    required this.bookId,
    required this.voiceId,
    required this.unitIndex,
    required this.unitHash,
    required this.file,
    required this.bytes,
    required this.createdAt,
  });

  final int bookId;
  final String voiceId;
  final int unitIndex;
  final String unitHash;

  /// Absolute path to the rendered WAV clip on disk.
  final String file;

  /// Size of the clip in bytes (for storage accounting).
  final int bytes;

  final DateTime createdAt;
}
