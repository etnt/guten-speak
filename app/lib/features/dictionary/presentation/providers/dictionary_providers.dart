import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/dictionary_manager.dart';
import '../../data/dictionary_repository.dart';
import '../../domain/entities/dictionary_entry.dart';

/// Singleton manager for the optional WordNet dictionary download.
final dictionaryManagerProvider = Provider<DictionaryManager>(
  (ref) => DictionaryManager(),
);

/// Whether the dictionary is installed. Invalidated after a download or delete.
final dictionaryInstalledProvider = FutureProvider<bool>((ref) async {
  return ref.watch(dictionaryManagerProvider).isInstalled();
});

/// Size of the installed dictionary in bytes (0 when not installed).
final dictionaryBytesProvider = FutureProvider<int>((ref) async {
  return ref.watch(dictionaryManagerProvider).installedBytes();
});

/// Opens the dictionary database read-only when installed, else null. Closed
/// automatically when disposed (e.g. after the dictionary is deleted).
final dictionaryDatabaseProvider = FutureProvider<Database?>((ref) async {
  final manager = ref.watch(dictionaryManagerProvider);
  if (!await manager.isInstalled()) return null;
  final db = await openReadOnlyDatabase(await manager.databasePath());
  ref.onDispose(db.close);
  return db;
});

/// The repository over the open database, or null when not installed.
final dictionaryRepositoryProvider = FutureProvider<DictionaryRepository?>((
  ref,
) async {
  final db = await ref.watch(dictionaryDatabaseProvider.future);
  if (db == null) return null;
  return DictionaryRepository(db);
});

/// Definitions for a single [word]. Empty when not installed or not found.
final wordLookupProvider = FutureProvider.family<List<DictionarySense>, String>(
  (ref, word) async {
    final repo = await ref.watch(dictionaryRepositoryProvider.future);
    if (repo == null) return const [];
    return repo.lookup(word);
  },
);

/// Progress of the one-time dictionary download.
enum DictionaryDownloadPhase { idle, downloading, error }

class DictionaryDownloadState {
  const DictionaryDownloadState({
    this.phase = DictionaryDownloadPhase.idle,
    this.fraction,
    this.error,
  });

  final DictionaryDownloadPhase phase;
  final double? fraction;
  final String? error;

  bool get isDownloading => phase == DictionaryDownloadPhase.downloading;
}

class DictionaryDownloadController
    extends StateNotifier<DictionaryDownloadState> {
  DictionaryDownloadController(this._ref)
    : super(const DictionaryDownloadState());

  final Ref _ref;
  bool _cancelRequested = false;

  Future<void> download() async {
    if (state.isDownloading) return;
    _cancelRequested = false;
    state = const DictionaryDownloadState(
      phase: DictionaryDownloadPhase.downloading,
    );
    try {
      await _ref
          .read(dictionaryManagerProvider)
          .ensureDictionary(
            onProgress: (fraction) => state = DictionaryDownloadState(
              phase: DictionaryDownloadPhase.downloading,
              fraction: fraction,
            ),
            isCancelled: () => _cancelRequested,
          );
      state = const DictionaryDownloadState();
      _ref.invalidate(dictionaryInstalledProvider);
      _ref.invalidate(dictionaryBytesProvider);
      _ref.invalidate(dictionaryDatabaseProvider);
    } on DictionaryDownloadCancelled {
      state = const DictionaryDownloadState();
    } catch (e) {
      state = DictionaryDownloadState(
        phase: DictionaryDownloadPhase.error,
        error: e.toString(),
      );
    }
  }

  void cancel() => _cancelRequested = true;

  Future<void> remove() async {
    await _ref.read(dictionaryManagerProvider).delete();
    state = const DictionaryDownloadState();
    _ref.invalidate(dictionaryInstalledProvider);
    _ref.invalidate(dictionaryBytesProvider);
    _ref.invalidate(dictionaryDatabaseProvider);
  }
}

final dictionaryDownloadControllerProvider =
    StateNotifierProvider<
      DictionaryDownloadController,
      DictionaryDownloadState
    >(DictionaryDownloadController.new);
