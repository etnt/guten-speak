import '../../../core/tts/model_manager.dart';
import '../../narration/data/repositories/synth_cache.dart';
import '../../voices/data/datasources/voice_library_data_source.dart';
import '../domain/entities/storage_usage.dart';

/// Computes on-device storage usage for the app's large removable assets (TTS
/// model, narrated audio, imported voices) and performs the delete/clear
/// actions surfaced by the storage manager screen.
class StorageManager {
  StorageManager({
    required this._modelManager,
    required this._synthCache,
    required this._voiceLibrary,
  });

  final ModelManager _modelManager;
  final SynthCache _synthCache;
  final VoiceLibrary _voiceLibrary;

  /// Builds a usage snapshot. [bookTitles] maps a book id to its display title
  /// so per-book audio rows can be labelled; ids missing from the map fall back
  /// to `Book <id>`.
  Future<StorageUsage> usage(Map<int, String> bookTitles) async {
    final modelInstalled = await _modelManager.isInstalled();
    final modelBytes = await _modelManager.onDiskBytes();
    final bytesPerBook = await _synthCache.bytesPerBook();
    final voicesBytes = await _voiceLibrary.userVoicesBytes();
    final voiceCount = _voiceLibrary.voices.where((v) => !v.builtIn).length;

    final perBook = <BookAudioUsage>[
      for (final entry in bytesPerBook.entries)
        BookAudioUsage(
          bookId: entry.key,
          title: bookTitles[entry.key] ?? 'Book ${entry.key}',
          bytes: entry.value,
        ),
    ]..sort((a, b) => b.bytes.compareTo(a.bytes));

    return StorageUsage(
      modelInstalled: modelInstalled,
      modelBytes: modelBytes,
      perBookAudio: perBook,
      voiceCount: voiceCount,
      voicesBytes: voicesBytes,
    );
  }

  /// Deletes the TTS model from disk (re-downloaded on the next narration
  /// opt-in).
  Future<void> deleteModel() => _modelManager.deleteFromDisk();

  /// Removes all narrated audio for [bookId].
  Future<void> deleteBookAudio(int bookId) =>
      _synthCache.invalidateBook(bookId);

  /// Removes every book's narrated audio.
  Future<void> clearAllAudio() => _synthCache.clearAll();
}
