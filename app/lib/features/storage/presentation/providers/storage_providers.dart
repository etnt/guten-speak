import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../library/presentation/providers/library_providers.dart';
import '../../../narration/presentation/providers/synth_cache_providers.dart';
import '../../../narration/presentation/providers/tts_providers.dart';
import '../../../voices/presentation/providers/voice_providers.dart';
import '../../data/storage_manager.dart';
import '../../domain/entities/storage_usage.dart';

part 'storage_providers.g.dart';

/// The storage manager, wired to the model, narrated-audio cache and voice
/// library.
@riverpod
Future<StorageManager> storageManager(Ref ref) async {
  final synthCache = await ref.watch(synthCacheProvider.future);
  final voiceLibrary = await ref.watch(voiceLibraryProvider.future);
  return StorageManager(
    modelManager: ref.watch(modelManagerProvider),
    synthCache: synthCache,
    voiceLibrary: voiceLibrary,
  );
}

/// A usage snapshot for the storage screen. Recomputed whenever the library
/// changes (so titles stay current) or the controller invalidates it after a
/// delete.
@riverpod
Future<StorageUsage> storageUsage(Ref ref) async {
  final manager = await ref.watch(storageManagerProvider.future);
  final books = await ref.watch(libraryBooksProvider.future);
  final titles = <int, String>{for (final b in books) b.id: b.title};
  return manager.usage(titles);
}

/// Performs storage delete/clear actions and refreshes the usage snapshot.
@riverpod
class StorageController extends _$StorageController {
  @override
  void build() {}

  Future<void> deleteModel() async {
    final manager = await ref.read(storageManagerProvider.future);
    await manager.deleteModel();
    ref.invalidate(modelInstalledProvider);
    ref.invalidate(storageUsageProvider);
  }

  Future<void> deleteBookAudio(int bookId) async {
    final manager = await ref.read(storageManagerProvider.future);
    await manager.deleteBookAudio(bookId);
    ref.invalidate(storageUsageProvider);
  }

  Future<void> clearAllAudio() async {
    final manager = await ref.read(storageManagerProvider.future);
    await manager.clearAllAudio();
    ref.invalidate(storageUsageProvider);
  }
}
