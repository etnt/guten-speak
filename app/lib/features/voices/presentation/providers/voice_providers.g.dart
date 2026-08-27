// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voice_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$voiceLibraryHash() => r'10cf5304c08e52b98ec89842e744cb354cab791b';

/// The loaded voice library (built-ins materialized + user voices), kept alive
/// for the app's lifetime.
///
/// Copied from [voiceLibrary].
@ProviderFor(voiceLibrary)
final voiceLibraryProvider = FutureProvider<VoiceLibrary>.internal(
  voiceLibrary,
  name: r'voiceLibraryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$voiceLibraryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef VoiceLibraryRef = FutureProviderRef<VoiceLibrary>;
String _$voicesControllerHash() => r'3fba69ad6b63b3277d0f1bc5c3cd618e5848da3a';

/// The current list of voices, and mutations (import/remove) that keep it in
/// sync with the on-disk library and clear the selection when needed.
///
/// Copied from [VoicesController].
@ProviderFor(VoicesController)
final voicesControllerProvider =
    AsyncNotifierProvider<VoicesController, List<Voice>>.internal(
      VoicesController.new,
      name: r'voicesControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$voicesControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$VoicesController = AsyncNotifier<List<Voice>>;
String _$selectedVoiceHash() => r'2b03ecc6c00d51ccee2cea58ba50bea6144314c3';

/// The voice chosen for narration. Restored from the persisted default on first
/// build; consumers should fall back to the first available voice when null.
///
/// Copied from [SelectedVoice].
@ProviderFor(SelectedVoice)
final selectedVoiceProvider = NotifierProvider<SelectedVoice, Voice?>.internal(
  SelectedVoice.new,
  name: r'selectedVoiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$selectedVoiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$SelectedVoice = Notifier<Voice?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
