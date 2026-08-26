import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../../../core/network/dio_error_mapper.dart';
import '../../../../core/network/failure.dart';
import '../../../../core/network/result.dart';
import '../../../../core/utils/text_cleaner_service.dart';
import '../../../catalog/data/models/book_summary.dart';
import '../../domain/entities/library_book.dart';
import '../../domain/entities/reading_progress.dart';
import '../../domain/repositories/library_repository.dart';
import '../datasources/book_download_data_source.dart';
import '../datasources/library_local_data_source.dart';

/// Filesystem + SQLite backed [LibraryRepository].
///
/// Downloads land in `<booksDir>/<id>/`: raw bytes stream to `download.part`,
/// then the cleaned text is written atomically (temp file → rename) to
/// `text.txt`, which is the [LibraryBook.path].
class LibraryRepositoryImpl implements LibraryRepository {
  LibraryRepositoryImpl({
    required this.local,
    required this.download,
    required Directory booksDirectory,
    this.cleaner = const TextCleanerService(),
  }) : _booksDir = booksDirectory;

  final LibraryLocalDataSource local;
  final BookDownloadDataSource download;
  final Directory _booksDir;
  final TextCleanerService cleaner;

  static const String _partFileName = 'download.part';
  static const String _textFileName = 'text.txt';

  @override
  Future<Result<List<LibraryBook>>> getLibrary() => _guard(local.getBooks);

  @override
  Future<Result<LibraryBook?>> getBook(int id) =>
      _guard(() => local.getBook(id));

  @override
  Future<Result<LibraryBook>> downloadBook(
    BookSummary book, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) {
    return _guard(() async {
      final primaryUrl = book.plainTextUrl;
      if (primaryUrl == null) {
        throw const ServerFailure(
          'No plain-text edition is available for this title.',
        );
      }
      final fallbackUrl =
          'https://www.gutenberg.org/ebooks/${book.id}.txt.utf-8';

      final bookDir = Directory(p.join(_booksDir.path, '${book.id}'));
      await bookDir.create(recursive: true);
      await _ensureWritable(bookDir);

      final partFile = File(p.join(bookDir.path, _partFileName));
      await _downloadWithFallback(
        primaryUrl: primaryUrl,
        fallbackUrl: primaryUrl == fallbackUrl ? null : fallbackUrl,
        destination: partFile,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );

      final bytes = await partFile.readAsBytes();
      final raw = utf8.decode(bytes, allowMalformed: true);
      final cleaned = cleaner.clean(raw);

      final textFile = File(p.join(bookDir.path, _textFileName));
      final tmpFile = File('${textFile.path}.tmp');
      await tmpFile.writeAsString(cleaned, flush: true);
      await tmpFile.rename(textFile.path);
      if (await partFile.exists()) {
        await partFile.delete();
      }

      final libraryBook = LibraryBook(
        id: book.id,
        title: book.title,
        author: book.authorNames,
        path: textFile.path,
        language: book.languages.isEmpty ? null : book.languages.first,
        coverUrl: book.coverImageUrl,
        downloadedAt: DateTime.now(),
      );
      await local.upsertBook(libraryBook);
      return libraryBook;
    });
  }

  @override
  Future<Result<void>> deleteBook(int id) {
    return _guard(() async {
      await local.deleteBook(id);
      final bookDir = Directory(p.join(_booksDir.path, '$id'));
      if (await bookDir.exists()) {
        await bookDir.delete(recursive: true);
      }
    });
  }

  @override
  Future<Result<String>> readBookText(LibraryBook book) {
    return _guard(() async {
      final file = File(book.path);
      if (!await file.exists()) {
        throw const CacheFailure('The downloaded text is missing.');
      }
      return file.readAsString();
    });
  }

  @override
  Future<Result<ReadingProgress?>> getProgress(int bookId) =>
      _guard(() => local.getProgress(bookId));

  @override
  Future<Result<void>> saveProgress(int bookId, int paragraphIndex) {
    return _guard(
      () => local.saveProgress(
        ReadingProgress(
          bookId: bookId,
          paragraphIndex: paragraphIndex,
          updatedAt: DateTime.now(),
        ),
      ),
    );
  }

  /// Downloads from [primaryUrl]; on a non-cancellation failure, discards the
  /// partial file and retries once from [fallbackUrl] (when provided).
  Future<void> _downloadWithFallback({
    required String primaryUrl,
    required String? fallbackUrl,
    required File destination,
    required void Function(int received, int total)? onProgress,
    required CancelToken? cancelToken,
  }) async {
    try {
      await download.download(
        url: primaryUrl,
        destination: destination,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel || fallbackUrl == null) rethrow;
      if (await destination.exists()) {
        await destination.delete();
      }
      await download.download(
        url: fallbackUrl,
        destination: destination,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    }
  }

  /// Best-effort writability/space precheck: write and delete a probe file.
  ///
  /// A proper free-space check (for the large narration model in Phase C) needs
  /// a platform plugin; for small text files this catches read-only or
  /// completely-full targets.
  Future<void> _ensureWritable(Directory dir) async {
    final probe = File(p.join(dir.path, '.probe'));
    try {
      await probe.writeAsString('ok', flush: true);
    } on FileSystemException {
      throw const CacheFailure(
        'Not enough free space or the storage is not writable.',
      );
    } finally {
      if (await probe.exists()) {
        await probe.delete();
      }
    }
  }

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on DioException catch (e) {
      return ResultFailure(mapDioException(e));
    } on Failure catch (f) {
      return ResultFailure(f);
    } on FileSystemException catch (e) {
      return ResultFailure(CacheFailure(e.message));
    } catch (_) {
      return const ResultFailure(UnknownFailure());
    }
  }
}
