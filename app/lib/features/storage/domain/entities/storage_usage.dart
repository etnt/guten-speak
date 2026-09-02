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

/// On-disk usage for a single TTS engine's downloaded model.
class ModelUsage {
  const ModelUsage({
    required this.id,
    required this.label,
    required this.installed,
    required this.bytes,
  });

  /// Stable engine identifier used to target deletion (e.g. `raven`, `sherpa`).
  final String id;

  /// Human-readable engine name for the storage row.
  final String label;

  final bool installed;
  final int bytes;
}

/// A snapshot of on-device storage used by the app's large, removable assets:
/// the TTS models (one per engine), narrated audio (per book), and imported
/// voices.
class StorageUsage {
  const StorageUsage({
    required this.models,
    required this.perBookAudio,
    required this.voiceCount,
    required this.voicesBytes,
  });

  /// Per-engine downloaded model usage.
  final List<ModelUsage> models;

  /// Per-book narrated-audio usage, largest first.
  final List<BookAudioUsage> perBookAudio;

  final int voiceCount;
  final int voicesBytes;

  /// Total bytes of downloaded engine models on disk.
  int get modelsBytes => models.fold(0, (sum, m) => sum + m.bytes);

  /// Whether any engine model is installed.
  bool get anyModelInstalled => models.any((m) => m.installed);

  /// Total bytes of narrated audio across every book.
  int get audioBytes => perBookAudio.fold(0, (sum, usage) => sum + usage.bytes);

  /// Combined bytes of everything the storage manager can remove.
  int get totalBytes => modelsBytes + audioBytes + voicesBytes;
}
