/// Narrated-audio usage for a single book: its title (resolved from the
/// library when possible) and the bytes its cached clips occupy on disk.
class BookAudioUsage {
  const BookAudioUsage({
    required this.bookId,
    required this.title,
    required this.bytes,
  });

  final int bookId;
  final String title;
  final int bytes;
}

/// A snapshot of on-device storage used by the app's large, removable assets:
/// the TTS model, narrated audio (per book), and imported voices.
class StorageUsage {
  const StorageUsage({
    required this.modelInstalled,
    required this.modelBytes,
    required this.perBookAudio,
    required this.voiceCount,
    required this.voicesBytes,
  });

  final bool modelInstalled;
  final int modelBytes;

  /// Per-book narrated-audio usage, largest first.
  final List<BookAudioUsage> perBookAudio;

  final int voiceCount;
  final int voicesBytes;

  /// Total bytes of narrated audio across every book.
  int get audioBytes => perBookAudio.fold(0, (sum, usage) => sum + usage.bytes);

  /// Combined bytes of everything the storage manager can remove.
  int get totalBytes => modelBytes + audioBytes + voicesBytes;
}
