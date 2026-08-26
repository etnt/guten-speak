// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tts_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$modelManagerHash() => r'95d6ad03a96f213a3268a6a0375444d72b125b61';

/// Downloads/locates the on-device PocketTTS model.
///
/// Copied from [modelManager].
@ProviderFor(modelManager)
final modelManagerProvider = Provider<ModelManager>.internal(
  modelManager,
  name: r'modelManagerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$modelManagerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ModelManagerRef = ProviderRef<ModelManager>;
String _$ttsServiceHash() => r'3d6ead8766eef71e074d1b7e78692be25e236cdc';

/// The persistent TTS worker (owns the native engine in a background isolate).
/// Created lazily and disposed with the provider.
///
/// Copied from [ttsService].
@ProviderFor(ttsService)
final ttsServiceProvider = Provider<TtsService>.internal(
  ttsService,
  name: r'ttsServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$ttsServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef TtsServiceRef = ProviderRef<TtsService>;
String _$modelInstalledHash() => r'9d28d5718d888da5be1da024efaa2ab87f2da9c1';

/// Whether the model is already installed, so the UI can show "Prepare" vs a
/// ready state without kicking off a download.
///
/// Copied from [modelInstalled].
@ProviderFor(modelInstalled)
final modelInstalledProvider = AutoDisposeFutureProvider<bool>.internal(
  modelInstalled,
  name: r'modelInstalledProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$modelInstalledHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ModelInstalledRef = AutoDisposeFutureProviderRef<bool>;
String _$narrationEngineHash() => r'a2d8ab7305a649885b1e556182bde21627eaf7b9';

/// Drives the opt-in model download + engine load that gates narration, and
/// exposes its progress. [prepare] is idempotent and resumable; [cancel] aborts
/// an in-flight download (partial bytes are kept for a later resume).
///
/// Copied from [NarrationEngine].
@ProviderFor(NarrationEngine)
final narrationEngineProvider =
    NotifierProvider<NarrationEngine, NarrationPrepProgress>.internal(
      NarrationEngine.new,
      name: r'narrationEngineProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$narrationEngineHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$NarrationEngine = Notifier<NarrationPrepProgress>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
