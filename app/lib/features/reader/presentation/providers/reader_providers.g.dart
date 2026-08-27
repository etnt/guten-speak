// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$readerContentHash() => r'fc396ceb6f1d68547d0ce381c7920bc9bf4e3583';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Loads a downloaded book's paragraphs and table of contents for the reader.
///
/// Requires the book to already be in the library; the "Read" action downloads
/// it first. Content resolution (EPUB vs. cleaned plain text) is handled by the
/// repository.
///
/// Copied from [readerContent].
@ProviderFor(readerContent)
const readerContentProvider = ReaderContentFamily();

/// Loads a downloaded book's paragraphs and table of contents for the reader.
///
/// Requires the book to already be in the library; the "Read" action downloads
/// it first. Content resolution (EPUB vs. cleaned plain text) is handled by the
/// repository.
///
/// Copied from [readerContent].
class ReaderContentFamily extends Family<AsyncValue<ReaderContent>> {
  /// Loads a downloaded book's paragraphs and table of contents for the reader.
  ///
  /// Requires the book to already be in the library; the "Read" action downloads
  /// it first. Content resolution (EPUB vs. cleaned plain text) is handled by the
  /// repository.
  ///
  /// Copied from [readerContent].
  const ReaderContentFamily();

  /// Loads a downloaded book's paragraphs and table of contents for the reader.
  ///
  /// Requires the book to already be in the library; the "Read" action downloads
  /// it first. Content resolution (EPUB vs. cleaned plain text) is handled by the
  /// repository.
  ///
  /// Copied from [readerContent].
  ReaderContentProvider call(int bookId) {
    return ReaderContentProvider(bookId);
  }

  @override
  ReaderContentProvider getProviderOverride(
    covariant ReaderContentProvider provider,
  ) {
    return call(provider.bookId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'readerContentProvider';
}

/// Loads a downloaded book's paragraphs and table of contents for the reader.
///
/// Requires the book to already be in the library; the "Read" action downloads
/// it first. Content resolution (EPUB vs. cleaned plain text) is handled by the
/// repository.
///
/// Copied from [readerContent].
class ReaderContentProvider extends AutoDisposeFutureProvider<ReaderContent> {
  /// Loads a downloaded book's paragraphs and table of contents for the reader.
  ///
  /// Requires the book to already be in the library; the "Read" action downloads
  /// it first. Content resolution (EPUB vs. cleaned plain text) is handled by the
  /// repository.
  ///
  /// Copied from [readerContent].
  ReaderContentProvider(int bookId)
    : this._internal(
        (ref) => readerContent(ref as ReaderContentRef, bookId),
        from: readerContentProvider,
        name: r'readerContentProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$readerContentHash,
        dependencies: ReaderContentFamily._dependencies,
        allTransitiveDependencies:
            ReaderContentFamily._allTransitiveDependencies,
        bookId: bookId,
      );

  ReaderContentProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.bookId,
  }) : super.internal();

  final int bookId;

  @override
  Override overrideWith(
    FutureOr<ReaderContent> Function(ReaderContentRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ReaderContentProvider._internal(
        (ref) => create(ref as ReaderContentRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        bookId: bookId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<ReaderContent> createElement() {
    return _ReaderContentProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ReaderContentProvider && other.bookId == bookId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, bookId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ReaderContentRef on AutoDisposeFutureProviderRef<ReaderContent> {
  /// The parameter `bookId` of this provider.
  int get bookId;
}

class _ReaderContentProviderElement
    extends AutoDisposeFutureProviderElement<ReaderContent>
    with ReaderContentRef {
  _ReaderContentProviderElement(super.provider);

  @override
  int get bookId => (origin as ReaderContentProvider).bookId;
}

String _$readerControllerHash() => r'a982eedf8ddd625054192c75e7406e95de0ee04a';

/// Imperative reader actions (e.g. persisting scroll position).
///
/// Copied from [ReaderController].
@ProviderFor(ReaderController)
final readerControllerProvider =
    NotifierProvider<ReaderController, void>.internal(
      ReaderController.new,
      name: r'readerControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$readerControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ReaderController = Notifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
