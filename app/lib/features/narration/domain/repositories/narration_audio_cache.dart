import '../../../../core/utils/narration_segmenter.dart';

/// The storage surface the look-ahead scheduler depends on.
///
/// Abstracting it (rather than binding the scheduler directly to the
/// sqflite-backed `SynthCache`) keeps the scheduler pure and unit-testable with
/// an in-memory fake.
abstract interface class NarrationAudioCache {
  /// Returns the on-disk path of a previously rendered clip for [unit] in this
  /// `(bookId, voiceId, synthesisProfileId)` triple, or null if it is missing
  /// or stale (its text hash no longer matches). A stale/missing entry is
  /// treated as not cached so the scheduler re-renders it.
  Future<String?> cachedPath(
    int bookId,
    String voiceId,
    String synthesisProfileId,
    NarrationUnit unit,
  );

  /// Ensures the parent directory exists and returns the path a fresh clip for
  /// `(bookId, voiceId, synthesisProfileId, unitIndex)` should be written to.
  Future<String> reservePath(
    int bookId,
    String voiceId,
    String synthesisProfileId,
    int unitIndex,
  );

  /// Records (or updates) the cache index row for a freshly rendered [unit]
  /// after its clip has been written to the path from [reservePath].
  Future<void> record(
    int bookId,
    String voiceId,
    String synthesisProfileId,
    NarrationUnit unit,
  );

  /// Rolling-window eviction: deletes cached clips and index rows for this
  /// `(bookId, voiceId, synthesisProfileId)` triple whose unit index falls
  /// outside `[lo, hi]`.
  Future<void> evictOutsideWindow(
    int bookId,
    String voiceId,
    String synthesisProfileId, {
    required int lo,
    required int hi,
  });
}
