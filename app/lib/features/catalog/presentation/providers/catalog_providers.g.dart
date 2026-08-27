// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$gutendexRemoteDataSourceHash() =>
    r'a6ab8951ae4c6bcf3af680ed8ed446e17c2495fc';

/// Remote data source bound to the shared Dio client.
///
/// Copied from [gutendexRemoteDataSource].
@ProviderFor(gutendexRemoteDataSource)
final gutendexRemoteDataSourceProvider =
    AutoDisposeProvider<GutendexRemoteDataSource>.internal(
      gutendexRemoteDataSource,
      name: r'gutendexRemoteDataSourceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$gutendexRemoteDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef GutendexRemoteDataSourceRef =
    AutoDisposeProviderRef<GutendexRemoteDataSource>;
String _$catalogRepositoryHash() => r'9221f85602142dba1a0cdba3daa84afcc66fe32b';

/// Catalog repository used across the Discover, Search and Detail screens.
///
/// Copied from [catalogRepository].
@ProviderFor(catalogRepository)
final catalogRepositoryProvider =
    AutoDisposeProvider<CatalogRepository>.internal(
      catalogRepository,
      name: r'catalogRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$catalogRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CatalogRepositoryRef = AutoDisposeProviderRef<CatalogRepository>;
String _$localCatalogDataSourceHash() =>
    r'98b2002b12113ef261cc90a0be9822c3ae69adfe';

/// Offline catalog (SQLite FTS index) used for search and book detail.
///
/// Copied from [localCatalogDataSource].
@ProviderFor(localCatalogDataSource)
final localCatalogDataSourceProvider =
    FutureProvider<LocalCatalogDataSource>.internal(
      localCatalogDataSource,
      name: r'localCatalogDataSourceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$localCatalogDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LocalCatalogDataSourceRef = FutureProviderRef<LocalCatalogDataSource>;
String _$catalogImportServiceHash() =>
    r'c3e108a569a748bf3128f966fd6d1c4bda14464c';

/// Service that downloads and indexes Project Gutenberg's catalog locally.
///
/// Copied from [catalogImportService].
@ProviderFor(catalogImportService)
final catalogImportServiceProvider =
    FutureProvider<CatalogImportService>.internal(
      catalogImportService,
      name: r'catalogImportServiceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$catalogImportServiceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CatalogImportServiceRef = FutureProviderRef<CatalogImportService>;
String _$popularBooksHash() => r'6d0bfa55719442a1eecdefaff3b9629fab6767ed';

/// Most popular titles for the Discover carousel.
///
/// Throws the underlying [Failure] on error so the UI can render it via
/// [AsyncValue].
///
/// Copied from [popularBooks].
@ProviderFor(popularBooks)
final popularBooksProvider =
    AutoDisposeFutureProvider<List<BookSummary>>.internal(
      popularBooks,
      name: r'popularBooksProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$popularBooksHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PopularBooksRef = AutoDisposeFutureProviderRef<List<BookSummary>>;
String _$booksByTopicHash() => r'e17d8923582ea7a5ffdb29eb73970e5144d71ee1';

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

/// Books for a given curated subject/topic, keyed by [topic].
///
/// Copied from [booksByTopic].
@ProviderFor(booksByTopic)
const booksByTopicProvider = BooksByTopicFamily();

/// Books for a given curated subject/topic, keyed by [topic].
///
/// Copied from [booksByTopic].
class BooksByTopicFamily extends Family<AsyncValue<List<BookSummary>>> {
  /// Books for a given curated subject/topic, keyed by [topic].
  ///
  /// Copied from [booksByTopic].
  const BooksByTopicFamily();

  /// Books for a given curated subject/topic, keyed by [topic].
  ///
  /// Copied from [booksByTopic].
  BooksByTopicProvider call(String topic) {
    return BooksByTopicProvider(topic);
  }

  @override
  BooksByTopicProvider getProviderOverride(
    covariant BooksByTopicProvider provider,
  ) {
    return call(provider.topic);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'booksByTopicProvider';
}

/// Books for a given curated subject/topic, keyed by [topic].
///
/// Copied from [booksByTopic].
class BooksByTopicProvider
    extends AutoDisposeFutureProvider<List<BookSummary>> {
  /// Books for a given curated subject/topic, keyed by [topic].
  ///
  /// Copied from [booksByTopic].
  BooksByTopicProvider(String topic)
    : this._internal(
        (ref) => booksByTopic(ref as BooksByTopicRef, topic),
        from: booksByTopicProvider,
        name: r'booksByTopicProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$booksByTopicHash,
        dependencies: BooksByTopicFamily._dependencies,
        allTransitiveDependencies:
            BooksByTopicFamily._allTransitiveDependencies,
        topic: topic,
      );

  BooksByTopicProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.topic,
  }) : super.internal();

  final String topic;

  @override
  Override overrideWith(
    FutureOr<List<BookSummary>> Function(BooksByTopicRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: BooksByTopicProvider._internal(
        (ref) => create(ref as BooksByTopicRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        topic: topic,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<BookSummary>> createElement() {
    return _BooksByTopicProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is BooksByTopicProvider && other.topic == topic;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, topic.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin BooksByTopicRef on AutoDisposeFutureProviderRef<List<BookSummary>> {
  /// The parameter `topic` of this provider.
  String get topic;
}

class _BooksByTopicProviderElement
    extends AutoDisposeFutureProviderElement<List<BookSummary>>
    with BooksByTopicRef {
  _BooksByTopicProviderElement(super.provider);

  @override
  String get topic => (origin as BooksByTopicProvider).topic;
}

String _$bookDetailHash() => r'f923846fd19e65d77e0f71d0e7226431249819ab';

/// A single book's full metadata, keyed by Project Gutenberg [id].
///
/// Resolved from the local catalog first (offline, reliable), falling back to
/// the remote Gutendex API only if the id isn't in the local index.
///
/// Copied from [bookDetail].
@ProviderFor(bookDetail)
const bookDetailProvider = BookDetailFamily();

/// A single book's full metadata, keyed by Project Gutenberg [id].
///
/// Resolved from the local catalog first (offline, reliable), falling back to
/// the remote Gutendex API only if the id isn't in the local index.
///
/// Copied from [bookDetail].
class BookDetailFamily extends Family<AsyncValue<BookSummary>> {
  /// A single book's full metadata, keyed by Project Gutenberg [id].
  ///
  /// Resolved from the local catalog first (offline, reliable), falling back to
  /// the remote Gutendex API only if the id isn't in the local index.
  ///
  /// Copied from [bookDetail].
  const BookDetailFamily();

  /// A single book's full metadata, keyed by Project Gutenberg [id].
  ///
  /// Resolved from the local catalog first (offline, reliable), falling back to
  /// the remote Gutendex API only if the id isn't in the local index.
  ///
  /// Copied from [bookDetail].
  BookDetailProvider call(int id) {
    return BookDetailProvider(id);
  }

  @override
  BookDetailProvider getProviderOverride(
    covariant BookDetailProvider provider,
  ) {
    return call(provider.id);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'bookDetailProvider';
}

/// A single book's full metadata, keyed by Project Gutenberg [id].
///
/// Resolved from the local catalog first (offline, reliable), falling back to
/// the remote Gutendex API only if the id isn't in the local index.
///
/// Copied from [bookDetail].
class BookDetailProvider extends AutoDisposeFutureProvider<BookSummary> {
  /// A single book's full metadata, keyed by Project Gutenberg [id].
  ///
  /// Resolved from the local catalog first (offline, reliable), falling back to
  /// the remote Gutendex API only if the id isn't in the local index.
  ///
  /// Copied from [bookDetail].
  BookDetailProvider(int id)
    : this._internal(
        (ref) => bookDetail(ref as BookDetailRef, id),
        from: bookDetailProvider,
        name: r'bookDetailProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$bookDetailHash,
        dependencies: BookDetailFamily._dependencies,
        allTransitiveDependencies: BookDetailFamily._allTransitiveDependencies,
        id: id,
      );

  BookDetailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final int id;

  @override
  Override overrideWith(
    FutureOr<BookSummary> Function(BookDetailRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: BookDetailProvider._internal(
        (ref) => create(ref as BookDetailRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<BookSummary> createElement() {
    return _BookDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is BookDetailProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin BookDetailRef on AutoDisposeFutureProviderRef<BookSummary> {
  /// The parameter `id` of this provider.
  int get id;
}

class _BookDetailProviderElement
    extends AutoDisposeFutureProviderElement<BookSummary>
    with BookDetailRef {
  _BookDetailProviderElement(super.provider);

  @override
  int get id => (origin as BookDetailProvider).id;
}

String _$catalogImportHash() => r'e405fef6c0dd1362ef5efa2087e2cd017430695c';

/// Drives the one-time import of the catalog into the local index and exposes
/// its progress. [ensure] is idempotent — a no-op once the catalog is ready or
/// while an import is already running.
///
/// Copied from [CatalogImport].
@ProviderFor(CatalogImport)
final catalogImportProvider =
    NotifierProvider<CatalogImport, CatalogImportProgress>.internal(
      CatalogImport.new,
      name: r'catalogImportProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$catalogImportHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$CatalogImport = Notifier<CatalogImportProgress>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
