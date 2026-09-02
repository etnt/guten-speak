import '../../../core/tts/model_manager.dart';
import '../../../core/tts/raven_model_manager.dart';
import '../../narration/data/repositories/synth_cache.dart';
import '../../voices/data/datasources/voice_library_data_source.dart';
import '../domain/entities/storage_usage.dart';

/// Stable engine ids used to target per-engine model deletion.
const String kRavenModelId = 'raven';
const String kSherpaModelId = 'sherpa';

/// Computes on-device storage usage for the app's large removable assets (TTS
/// models, narrated audio, imported voices) and performs the delete/clear
/// actions surfaced by the storage manager screen.
class StorageManager {
  StorageManager({
    required this._sherpaManager,
    required this._ravenManager,
    required this._synthCache,
    required this._voiceLibrary,
  });

  final ModelManager _sherpaManager;
  final RavenModelManager _ravenManager;
  final SynthCache _synthCache;
  final VoiceLibrary _voiceLibrary;

  /// Builds a usage snapshot. [bookTitles] maps a book id to its display title
  /// so per-book audio rows can be labelled; ids missing from the map fall back
  /// to `Book <id>`.
  Future<StorageUsage> usage(Map<int, String> bookTitles) async {
    final models = <ModelUsage>[
      ModelUsage(
        id: kRavenModelId,
        label: 'Raven neural voice',
        installed: await _ravenManager.isInstalled(),
        bytes: await _ravenManager.onDiskBytes(),
      ),
      ModelUsage(
        id: kSherpaModelId,
        label: 'Sherpa neural voice',
        installed: await _sherpaManager.isInstalled(),
        bytes: await _sherpaManager.onDiskBytes(),
      ),
    ];
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
      models: models,
      perBookAudio: perBook,
      voiceCount: voiceCount,
      voicesBytes: voicesBytes,
    );
  }

  /// Deletes the [engineId] TTS model from disk (re-downloaded on the next
  /// narration opt-in with that engine).
  Future<void> deleteModel(String engineId) {
    switch (engineId) {
      case kRavenModelId:
        return _ravenManager.deleteFromDisk();
      case kSherpaModelId:
        return _sherpaManager.deleteFromDisk();
      default:
        throw ArgumentError.value(engineId, 'engineId', 'Unknown engine');
    }
  }

  /// Removes all narrated audio for [bookId].
  Future<void> deleteBookAudio(int bookId) =>
      _synthCache.invalidateBook(bookId);

  /// Removes every book's narrated audio.
  Future<void> clearAllAudio() => _synthCache.clearAll();
}
