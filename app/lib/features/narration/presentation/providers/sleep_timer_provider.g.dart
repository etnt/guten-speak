// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sleep_timer_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sleepTimerControllerHash() =>
    r'e15de961e262772895e85ccbf9f0e0f09d79ec00';

/// Controls the sleep timer: when enabled the timer fires after the configured
/// period without user interaction in the reader, pausing narration and saving
/// a bookmark at the current paragraph.
///
/// State is `true` while the countdown is actively running, `false` otherwise.
///
/// Copied from [SleepTimerController].
@ProviderFor(SleepTimerController)
final sleepTimerControllerProvider =
    NotifierProvider<SleepTimerController, bool>.internal(
      SleepTimerController.new,
      name: r'sleepTimerControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$sleepTimerControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SleepTimerController = Notifier<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
