// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'narration_player_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$narrationAudioHandlerHash() =>
    r'e09e300a89d7242149f1e798f7527306cd7925a0';

/// The singleton background narration player, initialized inside
/// `audio_service` so it survives backgrounding and drives the media
/// notification. Created lazily on first listen and disposed with the app.
///
/// Copied from [narrationAudioHandler].
@ProviderFor(narrationAudioHandler)
final narrationAudioHandlerProvider =
    FutureProvider<NarrationAudioHandler>.internal(
      narrationAudioHandler,
      name: r'narrationAudioHandlerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$narrationAudioHandlerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NarrationAudioHandlerRef = FutureProviderRef<NarrationAudioHandler>;
String _$narrationPlaybackHash() => r'1b583f3db0fd6589ea24f749cdb8440b0b8d8028';

/// The live playback snapshot for UI (player screen + mini-player). Seeds with
/// the handler's current state, then follows its updates.
///
/// Copied from [narrationPlayback].
@ProviderFor(narrationPlayback)
final narrationPlaybackProvider =
    AutoDisposeStreamProvider<NarrationPlaybackState>.internal(
      narrationPlayback,
      name: r'narrationPlaybackProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$narrationPlaybackHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NarrationPlaybackRef =
    AutoDisposeStreamProviderRef<NarrationPlaybackState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
