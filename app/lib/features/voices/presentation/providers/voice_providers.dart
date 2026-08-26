import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../narration/presentation/providers/synth_cache_providers.dart';
import '../../data/datasources/voice_library_data_source.dart';
import '../../domain/entities/voice.dart';

part 'voice_providers.g.dart';

/// The loaded voice library (built-ins materialized + user voices), kept alive
/// for the app's lifetime.
@Riverpod(keepAlive: true)
Future<VoiceLibrary> voiceLibrary(Ref ref) async {
  final library = VoiceLibrary();
  await library.load();
  return library;
}

/// The current list of voices, and mutations (import/remove) that keep it in
/// sync with the on-disk library and clear the selection when needed.
@Riverpod(keepAlive: true)
class VoicesController extends _$VoicesController {
  @override
  Future<List<Voice>> build() async {
    final library = await ref.watch(voiceLibraryProvider.future);
    return library.voices;
  }

  /// Imports a `.wav` at [sourceWavPath] under [name] and selects it.
  Future<Voice> addVoice({
    required String name,
    required String sourceWavPath,
  }) async {
    final library = await ref.read(voiceLibraryProvider.future);
    final voice = await library.add(name: name, sourceWavPath: sourceWavPath);
    state = AsyncData<List<Voice>>(library.voices);
    ref.read(selectedVoiceProvider.notifier).select(voice);
    return voice;
  }

  /// Deletes a user voice; if it was selected, the selection is cleared so the
  /// UI falls back to the first available voice. Any narration audio previously
  /// rendered in this voice is invalidated so its clips don't orphan on disk.
  Future<void> removeVoice(String id) async {
    final library = await ref.read(voiceLibraryProvider.future);
    await library.remove(id);
    state = AsyncData<List<Voice>>(library.voices);
    final selected = ref.read(selectedVoiceProvider);
    if (selected?.id == id) {
      ref.read(selectedVoiceProvider.notifier).clear();
    }
    final cache = await ref.read(synthCacheProvider.future);
    await cache.invalidateVoice(id);
  }
}

/// The voice chosen for narration. Null until the user (or the narration screen)
/// picks one; consumers should fall back to the first available voice.
@Riverpod(keepAlive: true)
class SelectedVoice extends _$SelectedVoice {
  @override
  Voice? build() => null;

  void select(Voice voice) => state = voice;

  void clear() => state = null;
}
