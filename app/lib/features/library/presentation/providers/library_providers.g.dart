// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$booksDirectoryHash() => r'40c30fbeff59c800184762b9ef485bd8f0f99d0f';

/// `<appDocuments>/books`, created on first access. Downloaded book files live
/// under `<booksDirectory>/<gutenbergId>/`.
///
/// Copied from [booksDirectory].
@ProviderFor(booksDirectory)
final booksDirectoryProvider = FutureProvider<Directory>.internal(
  booksDirectory,
  name: r'booksDirectoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$booksDirectoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BooksDirectoryRef = FutureProviderRef<Directory>;
String _$bookDownloadDioHash() => r'a1c3547c7dec0c2a8894290d53c210ad0992c7cd';

/// A dedicated Dio for large file downloads (long receive timeout, no JSON
/// base URL) that still sends the app's User-Agent.
///
/// Copied from [bookDownloadDio].
@ProviderFor(bookDownloadDio)
final bookDownloadDioProvider = AutoDisposeProvider<Dio>.internal(
  bookDownloadDio,
  name: r'bookDownloadDioProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$bookDownloadDioHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BookDownloadDioRef = AutoDisposeProviderRef<Dio>;
String _$bookDownloadDataSourceHash() =>
    r'a9ddaf3ed065ce00aa7c3358f94e78df86f52919';

/// See also [bookDownloadDataSource].
@ProviderFor(bookDownloadDataSource)
final bookDownloadDataSourceProvider =
    AutoDisposeProvider<BookDownloadDataSource>.internal(
      bookDownloadDataSource,
      name: r'bookDownloadDataSourceProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$bookDownloadDataSourceHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BookDownloadDataSourceRef =
    AutoDisposeProviderRef<BookDownloadDataSource>;
String _$libraryRepositoryHash() => r'ece7c64bdf08c66dcdfb1241c38faddc4be11d95';

/// See also [libraryRepository].
@ProviderFor(libraryRepository)
final libraryRepositoryProvider = FutureProvider<LibraryRepository>.internal(
  libraryRepository,
  name: r'libraryRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$libraryRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LibraryRepositoryRef = FutureProviderRef<LibraryRepository>;
String _$libraryBooksHash() => r'd395bc92ed872b61024b12b1c49446a23c6cb33e';

/// The user's downloaded books, newest first.
///
/// Copied from [libraryBooks].
@ProviderFor(libraryBooks)
final libraryBooksProvider =
    AutoDisposeFutureProvider<List<LibraryBook>>.internal(
      libraryBooks,
      name: r'libraryBooksProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$libraryBooksHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LibraryBooksRef = AutoDisposeFutureProviderRef<List<LibraryBook>>;
String _$recentlyReadBooksHash() => r'e3099836336f4dc2cea8290c1f2232cd3616f920';

/// Up to ten downloaded books ordered by their last Reader activity.
///
/// Copied from [recentlyReadBooks].
@ProviderFor(recentlyReadBooks)
final recentlyReadBooksProvider =
    AutoDisposeFutureProvider<List<LibraryBook>>.internal(
      recentlyReadBooks,
      name: r'recentlyReadBooksProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$recentlyReadBooksHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RecentlyReadBooksRef = AutoDisposeFutureProviderRef<List<LibraryBook>>;
String _$libraryBookHash() => r'62829b386fd09218cb98bed47dce0424e79e2459';

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

/// The downloaded record for [bookId], or `null` when it is not in the library.
///
/// Copied from [libraryBook].
@ProviderFor(libraryBook)
const libraryBookProvider = LibraryBookFamily();

/// The downloaded record for [bookId], or `null` when it is not in the library.
///
/// Copied from [libraryBook].
class LibraryBookFamily extends Family<AsyncValue<LibraryBook?>> {
  /// The downloaded record for [bookId], or `null` when it is not in the library.
  ///
  /// Copied from [libraryBook].
  const LibraryBookFamily();

  /// The downloaded record for [bookId], or `null` when it is not in the library.
  ///
  /// Copied from [libraryBook].
  LibraryBookProvider call(int bookId) {
    return LibraryBookProvider(bookId);
  }

  @override
  LibraryBookProvider getProviderOverride(
    covariant LibraryBookProvider provider,
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
  String? get name => r'libraryBookProvider';
}

/// The downloaded record for [bookId], or `null` when it is not in the library.
///
/// Copied from [libraryBook].
class LibraryBookProvider extends AutoDisposeFutureProvider<LibraryBook?> {
  /// The downloaded record for [bookId], or `null` when it is not in the library.
  ///
  /// Copied from [libraryBook].
  LibraryBookProvider(int bookId)
    : this._internal(
        (ref) => libraryBook(ref as LibraryBookRef, bookId),
        from: libraryBookProvider,
        name: r'libraryBookProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$libraryBookHash,
        dependencies: LibraryBookFamily._dependencies,
        allTransitiveDependencies: LibraryBookFamily._allTransitiveDependencies,
        bookId: bookId,
      );

  LibraryBookProvider._internal(
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
    FutureOr<LibraryBook?> Function(LibraryBookRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: LibraryBookProvider._internal(
        (ref) => create(ref as LibraryBookRef),
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
  AutoDisposeFutureProviderElement<LibraryBook?> createElement() {
    return _LibraryBookProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is LibraryBookProvider && other.bookId == bookId;
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
mixin LibraryBookRef on AutoDisposeFutureProviderRef<LibraryBook?> {
  /// The parameter `bookId` of this provider.
  int get bookId;
}

class _LibraryBookProviderElement
    extends AutoDisposeFutureProviderElement<LibraryBook?>
    with LibraryBookRef {
  _LibraryBookProviderElement(super.provider);

  @override
  int get bookId => (origin as LibraryBookProvider).bookId;
}

String _$readingProgressHash() => r'7e962b513fc5cfe5fc95bbdd6a65c973cb4029c2';

/// The saved reading position for [bookId], if any.
///
/// Copied from [readingProgress].
@ProviderFor(readingProgress)
const readingProgressProvider = ReadingProgressFamily();

/// The saved reading position for [bookId], if any.
///
/// Copied from [readingProgress].
class ReadingProgressFamily extends Family<AsyncValue<ReadingProgress?>> {
  /// The saved reading position for [bookId], if any.
  ///
  /// Copied from [readingProgress].
  const ReadingProgressFamily();

  /// The saved reading position for [bookId], if any.
  ///
  /// Copied from [readingProgress].
  ReadingProgressProvider call(int bookId) {
    return ReadingProgressProvider(bookId);
  }

  @override
  ReadingProgressProvider getProviderOverride(
    covariant ReadingProgressProvider provider,
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
  String? get name => r'readingProgressProvider';
}

/// The saved reading position for [bookId], if any.
///
/// Copied from [readingProgress].
class ReadingProgressProvider
    extends AutoDisposeFutureProvider<ReadingProgress?> {
  /// The saved reading position for [bookId], if any.
  ///
  /// Copied from [readingProgress].
  ReadingProgressProvider(int bookId)
    : this._internal(
        (ref) => readingProgress(ref as ReadingProgressRef, bookId),
        from: readingProgressProvider,
        name: r'readingProgressProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$readingProgressHash,
        dependencies: ReadingProgressFamily._dependencies,
        allTransitiveDependencies:
            ReadingProgressFamily._allTransitiveDependencies,
        bookId: bookId,
      );

  ReadingProgressProvider._internal(
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
    FutureOr<ReadingProgress?> Function(ReadingProgressRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ReadingProgressProvider._internal(
        (ref) => create(ref as ReadingProgressRef),
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
  AutoDisposeFutureProviderElement<ReadingProgress?> createElement() {
    return _ReadingProgressProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ReadingProgressProvider && other.bookId == bookId;
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
mixin ReadingProgressRef on AutoDisposeFutureProviderRef<ReadingProgress?> {
  /// The parameter `bookId` of this provider.
  int get bookId;
}

class _ReadingProgressProviderElement
    extends AutoDisposeFutureProviderElement<ReadingProgress?>
    with ReadingProgressRef {
  _ReadingProgressProviderElement(super.provider);

  @override
  int get bookId => (origin as ReadingProgressProvider).bookId;
}

String _$bookmarksHash() => r'3fbb94293c0a7d713f3c1e6b396054297d68d6a8';

/// All bookmarks for [bookId], in reading order.
///
/// Copied from [bookmarks].
@ProviderFor(bookmarks)
const bookmarksProvider = BookmarksFamily();

/// All bookmarks for [bookId], in reading order.
///
/// Copied from [bookmarks].
class BookmarksFamily extends Family<AsyncValue<List<Bookmark>>> {
  /// All bookmarks for [bookId], in reading order.
  ///
  /// Copied from [bookmarks].
  const BookmarksFamily();

  /// All bookmarks for [bookId], in reading order.
  ///
  /// Copied from [bookmarks].
  BookmarksProvider call(int bookId) {
    return BookmarksProvider(bookId);
  }

  @override
  BookmarksProvider getProviderOverride(covariant BookmarksProvider provider) {
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
  String? get name => r'bookmarksProvider';
}

/// All bookmarks for [bookId], in reading order.
///
/// Copied from [bookmarks].
class BookmarksProvider extends AutoDisposeFutureProvider<List<Bookmark>> {
  /// All bookmarks for [bookId], in reading order.
  ///
  /// Copied from [bookmarks].
  BookmarksProvider(int bookId)
    : this._internal(
        (ref) => bookmarks(ref as BookmarksRef, bookId),
        from: bookmarksProvider,
        name: r'bookmarksProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$bookmarksHash,
        dependencies: BookmarksFamily._dependencies,
        allTransitiveDependencies: BookmarksFamily._allTransitiveDependencies,
        bookId: bookId,
      );

  BookmarksProvider._internal(
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
    FutureOr<List<Bookmark>> Function(BookmarksRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: BookmarksProvider._internal(
        (ref) => create(ref as BookmarksRef),
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
  AutoDisposeFutureProviderElement<List<Bookmark>> createElement() {
    return _BookmarksProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is BookmarksProvider && other.bookId == bookId;
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
mixin BookmarksRef on AutoDisposeFutureProviderRef<List<Bookmark>> {
  /// The parameter `bookId` of this provider.
  int get bookId;
}

class _BookmarksProviderElement
    extends AutoDisposeFutureProviderElement<List<Bookmark>>
    with BookmarksRef {
  _BookmarksProviderElement(super.provider);

  @override
  int get bookId => (origin as BookmarksProvider).bookId;
}

String _$bookDownloadControllerHash() =>
    r'950e4ca623cac098edda1b6440d0068559a5277b';

abstract class _$BookDownloadController
    extends BuildlessAutoDisposeNotifier<DownloadState> {
  late final int bookId;

  DownloadState build(int bookId);
}

/// Drives (and reports progress of) a single book download, keyed by book id.
///
/// Copied from [BookDownloadController].
@ProviderFor(BookDownloadController)
const bookDownloadControllerProvider = BookDownloadControllerFamily();

/// Drives (and reports progress of) a single book download, keyed by book id.
///
/// Copied from [BookDownloadController].
class BookDownloadControllerFamily extends Family<DownloadState> {
  /// Drives (and reports progress of) a single book download, keyed by book id.
  ///
  /// Copied from [BookDownloadController].
  const BookDownloadControllerFamily();

  /// Drives (and reports progress of) a single book download, keyed by book id.
  ///
  /// Copied from [BookDownloadController].
  BookDownloadControllerProvider call(int bookId) {
    return BookDownloadControllerProvider(bookId);
  }

  @override
  BookDownloadControllerProvider getProviderOverride(
    covariant BookDownloadControllerProvider provider,
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
  String? get name => r'bookDownloadControllerProvider';
}

/// Drives (and reports progress of) a single book download, keyed by book id.
///
/// Copied from [BookDownloadController].
class BookDownloadControllerProvider
    extends
        AutoDisposeNotifierProviderImpl<BookDownloadController, DownloadState> {
  /// Drives (and reports progress of) a single book download, keyed by book id.
  ///
  /// Copied from [BookDownloadController].
  BookDownloadControllerProvider(int bookId)
    : this._internal(
        () => BookDownloadController()..bookId = bookId,
        from: bookDownloadControllerProvider,
        name: r'bookDownloadControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$bookDownloadControllerHash,
        dependencies: BookDownloadControllerFamily._dependencies,
        allTransitiveDependencies:
            BookDownloadControllerFamily._allTransitiveDependencies,
        bookId: bookId,
      );

  BookDownloadControllerProvider._internal(
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
  DownloadState runNotifierBuild(covariant BookDownloadController notifier) {
    return notifier.build(bookId);
  }

  @override
  Override overrideWith(BookDownloadController Function() create) {
    return ProviderOverride(
      origin: this,
      override: BookDownloadControllerProvider._internal(
        () => create()..bookId = bookId,
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
  AutoDisposeNotifierProviderElement<BookDownloadController, DownloadState>
  createElement() {
    return _BookDownloadControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is BookDownloadControllerProvider && other.bookId == bookId;
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
mixin BookDownloadControllerRef
    on AutoDisposeNotifierProviderRef<DownloadState> {
  /// The parameter `bookId` of this provider.
  int get bookId;
}

class _BookDownloadControllerProviderElement
    extends
        AutoDisposeNotifierProviderElement<
          BookDownloadController,
          DownloadState
        >
    with BookDownloadControllerRef {
  _BookDownloadControllerProviderElement(super.provider);

  @override
  int get bookId => (origin as BookDownloadControllerProvider).bookId;
}

String _$bookImportControllerHash() =>
    r'5ae65e481919878e7997df30a916762e555343ad';

/// Imports a local `.epub` file into the library. [state] is `true` while an
/// import is in progress so the UI can show a spinner and disable the action.
///
/// Copied from [BookImportController].
@ProviderFor(BookImportController)
final bookImportControllerProvider =
    AutoDisposeNotifierProvider<BookImportController, bool>.internal(
      BookImportController.new,
      name: r'bookImportControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$bookImportControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$BookImportController = AutoDisposeNotifier<bool>;
String _$bookmarkControllerHash() =>
    r'c24f1157bd2465b7a7d035e94cc517d916fb8d5d';

/// Adds and removes bookmarks, invalidating [bookmarksProvider] for the book.
///
/// Copied from [BookmarkController].
@ProviderFor(BookmarkController)
final bookmarkControllerProvider =
    AutoDisposeNotifierProvider<BookmarkController, void>.internal(
      BookmarkController.new,
      name: r'bookmarkControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$bookmarkControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$BookmarkController = AutoDisposeNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
