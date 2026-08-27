// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'storage_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$storageManagerHash() => r'e2ae71e43fd1666b87d0c90e2743ae276886ff2b';

/// The storage manager, wired to the model, narrated-audio cache and voice
/// library.
///
/// Copied from [storageManager].
@ProviderFor(storageManager)
final storageManagerProvider =
    AutoDisposeFutureProvider<StorageManager>.internal(
      storageManager,
      name: r'storageManagerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$storageManagerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef StorageManagerRef = AutoDisposeFutureProviderRef<StorageManager>;
String _$storageUsageHash() => r'60c4825a05b54cd94193d04175ef8882fa1fbdb8';

/// A usage snapshot for the storage screen. Recomputed whenever the library
/// changes (so titles stay current) or the controller invalidates it after a
/// delete.
///
/// Copied from [storageUsage].
@ProviderFor(storageUsage)
final storageUsageProvider = AutoDisposeFutureProvider<StorageUsage>.internal(
  storageUsage,
  name: r'storageUsageProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$storageUsageHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef StorageUsageRef = AutoDisposeFutureProviderRef<StorageUsage>;
String _$storageControllerHash() => r'f44309147fcdfc20f137b21dc944f32769881c7c';

/// Performs storage delete/clear actions and refreshes the usage snapshot.
///
/// Copied from [StorageController].
@ProviderFor(StorageController)
final storageControllerProvider =
    AutoDisposeNotifierProvider<StorageController, void>.internal(
      StorageController.new,
      name: r'storageControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$storageControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$StorageController = AutoDisposeNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
