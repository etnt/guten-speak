// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'synth_cache_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$narrationAudioDirectoryHash() =>
    r'dc7e423870e956c410cfe6a6af30238eb77548a0';

/// `<appDocuments>/audio`, created on first access. Rendered narration clips
/// live under `<audio>/<bookId>/<voiceId>/unit_<index>.wav`.
///
/// Copied from [narrationAudioDirectory].
@ProviderFor(narrationAudioDirectory)
final narrationAudioDirectoryProvider = FutureProvider<Directory>.internal(
  narrationAudioDirectory,
  name: r'narrationAudioDirectoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$narrationAudioDirectoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NarrationAudioDirectoryRef = FutureProviderRef<Directory>;
String _$synthCacheHash() => r'95c4f7a6ae8e22a3ed542179cca060e1d68c88f2';

/// The disk-backed narration synthesis cache (per-unit clips + sqflite index).
///
/// Copied from [synthCache].
@ProviderFor(synthCache)
final synthCacheProvider = FutureProvider<SynthCache>.internal(
  synthCache,
  name: r'synthCacheProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$synthCacheHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SynthCacheRef = FutureProviderRef<SynthCache>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
