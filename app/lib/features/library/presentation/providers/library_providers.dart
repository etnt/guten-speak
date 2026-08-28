import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/user_agent_interceptor.dart';
import '../../../../core/storage/app_database.dart';
import '../../../catalog/data/models/book_summary.dart';
import '../../data/datasources/book_download_data_source.dart';
import '../../data/datasources/library_local_data_source.dart';
import '../../data/repositories/library_repository_impl.dart';
import '../../domain/entities/download_state.dart';
import '../../domain/entities/library_book.dart';
import '../../domain/entities/reading_progress.dart';
import '../../domain/repositories/library_repository.dart';

part 'library_providers.g.dart';

/// `<appDocuments>/books`, created on first access. Downloaded book files live
/// under `<booksDirectory>/<gutenbergId>/`.
@Riverpod(keepAlive: true)
Future<Directory> booksDirectory(Ref ref) async {
  final documents = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(documents.path, 'books'));
  await dir.create(recursive: true);
  return dir;
}

/// A dedicated Dio for large file downloads (long receive timeout, no JSON
/// base URL) that still sends the app's User-Agent.
@riverpod
Dio bookDownloadDio(Ref ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(minutes: 3),
    ),
  );
  dio.interceptors.add(const UserAgentInterceptor());
  ref.onDispose(dio.close);
  return dio;
}

@riverpod
BookDownloadDataSource bookDownloadDataSource(Ref ref) =>
    BookDownloadDataSource(ref.watch(bookDownloadDioProvider));

@Riverpod(keepAlive: true)
Future<LibraryRepository> libraryRepository(Ref ref) async {
  final database = await ref.watch(appDatabaseProvider.future);
  final booksDir = await ref.watch(booksDirectoryProvider.future);
  return LibraryRepositoryImpl(
    local: LibraryLocalDataSource(database),
    download: ref.watch(bookDownloadDataSourceProvider),
    booksDirectory: booksDir,
  );
}

/// The user's downloaded books, newest first.
@riverpod
Future<List<LibraryBook>> libraryBooks(Ref ref) async {
  final repo = await ref.watch(libraryRepositoryProvider.future);
  final result = await repo.getLibrary();
  return result.when(
    onSuccess: (books) => books,
    onFailure: (failure) => throw failure,
  );
}

/// Up to ten downloaded books ordered by their last Reader activity.
@riverpod
Future<List<LibraryBook>> recentlyReadBooks(Ref ref) async {
  final repo = await ref.watch(libraryRepositoryProvider.future);
  final result = await repo.getRecentlyReadBooks();
  return result.when(
    onSuccess: (books) => books,
    onFailure: (failure) => throw failure,
  );
}

/// The downloaded record for [bookId], or `null` when it is not in the library.
@riverpod
Future<LibraryBook?> libraryBook(Ref ref, int bookId) async {
  final repo = await ref.watch(libraryRepositoryProvider.future);
  final result = await repo.getBook(bookId);
  return result.when(
    onSuccess: (book) => book,
    onFailure: (failure) => throw failure,
  );
}

/// Drives (and reports progress of) a single book download, keyed by book id.
@riverpod
class BookDownloadController extends _$BookDownloadController {
  CancelToken? _cancelToken;

  @override
  DownloadState build(int bookId) {
    ref.onDispose(() => _cancelToken?.cancel());
    return const DownloadState();
  }

  /// Starts downloading [book]; returns the stored record on success or `null`
  /// on failure/cancellation. Safe to ignore the return value and watch [state].
  Future<LibraryBook?> start(BookSummary book) async {
    if (state.isDownloading) return null;
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    state = const DownloadState(
      status: DownloadStatus.downloading,
      progress: -1,
    );

    final repo = await ref.read(libraryRepositoryProvider.future);
    final result = await repo.downloadBook(
      book,
      cancelToken: cancelToken,
      onProgress: (received, total) {
        state = state.copyWith(
          status: DownloadStatus.downloading,
          progress: total > 0 ? received / total : -1,
        );
      },
    );

    return result.when(
      onSuccess: (libraryBook) {
        state = DownloadState(
          status: DownloadStatus.completed,
          progress: 1,
          book: libraryBook,
        );
        ref.invalidate(libraryBooksProvider);
        ref.invalidate(libraryBookProvider(bookId));
        return libraryBook;
      },
      onFailure: (failure) {
        state = DownloadState(status: DownloadStatus.failed, failure: failure);
        return null;
      },
    );
  }

  /// Cancels an in-flight download.
  void cancel() => _cancelToken?.cancel();
}

/// Imports a local `.epub` file into the library. [state] is `true` while an
/// import is in progress so the UI can show a spinner and disable the action.
@riverpod
class BookImportController extends _$BookImportController {
  @override
  bool build() => false;

  /// Imports the `.epub` at [sourcePath]. Returns the stored record on success;
  /// rethrows a [Failure] on error for the caller to surface.
  Future<LibraryBook?> importFromFile(String sourcePath) async {
    if (state) return null;
    state = true;
    try {
      final repo = await ref.read(libraryRepositoryProvider.future);
      final result = await repo.importEpub(sourcePath);
      return result.when(
        onSuccess: (book) {
          ref.invalidate(libraryBooksProvider);
          return book;
        },
        onFailure: (failure) => throw failure,
      );
    } finally {
      state = false;
    }
  }
}

/// The saved reading position for [bookId], if any.
@riverpod
Future<ReadingProgress?> readingProgress(Ref ref, int bookId) async {
  final repo = await ref.watch(libraryRepositoryProvider.future);
  final result = await repo.getProgress(bookId);
  return result.when(
    onSuccess: (progress) => progress,
    onFailure: (failure) => throw failure,
  );
}
