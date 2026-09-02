// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tts_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$ravenModelManagerHash() => r'3f5c5ea27f2eaf7b5de8a06cca0bd91f83229f01';

/// Downloads/locates the on-device Raven model (from the guten-speak release
/// area only). Raven is the app's sole narration engine at runtime (int8,
/// 4-step flow, temperature 0.20 — the winning production config).
///
/// Copied from [ravenModelManager].
@ProviderFor(ravenModelManager)
final ravenModelManagerProvider = Provider<RavenModelManager>.internal(
  ravenModelManager,
  name: r'ravenModelManagerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$ravenModelManagerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RavenModelManagerRef = ProviderRef<RavenModelManager>;
String _$modelInstalledHash() => r'15ddbb4e020d77bb02f0cdeafb13aa057a5cfb99';

/// Whether the Raven model is already installed, so the UI can show "Prepare"
/// vs a ready state without kicking off a download.
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
String _$narrationEngineHash() => r'2366f2ef7d00228748b970d5091798ff00639131';

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
