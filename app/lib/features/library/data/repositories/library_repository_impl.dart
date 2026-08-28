import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_error_mapper.dart';
import '../../../../core/network/failure.dart';
import '../../../../core/network/result.dart';
import '../../../../core/utils/epub_parser.dart';
import '../../../../core/utils/text_cleaner_service.dart';
import '../../../catalog/data/models/book_summary.dart';
import '../../domain/entities/book_content.dart';
import '../../domain/entities/library_book.dart';
import '../../domain/entities/reading_progress.dart';
import '../../domain/repositories/library_repository.dart';
import '../book_content_loader.dart';
import '../datasources/book_download_data_source.dart';
import '../datasources/library_local_data_source.dart';

/// Filesystem + SQLite backed [LibraryRepository].
///
/// Downloads land in `<booksDir>/<id>/`. The preferred format is an EPUB saved
/// as `book.epub` (parsed and cached on download); when no EPUB edition exists
/// the download falls back to cleaned plain text written atomically to
/// `text.txt`. [LibraryBook.path] points at whichever primary artifact was
/// stored.
class LibraryRepositoryImpl implements LibraryRepository {
  LibraryRepositoryImpl({
    required this.local,
    required this.download,
    required Directory booksDirectory,
    this.cleaner = const TextCleanerService(),
    this.contentLoader = const BookContentLoader(),
  }) : _booksDir = booksDirectory;

  final LibraryLocalDataSource local;
  final BookDownloadDataSource download;
  final Directory _booksDir;
  final TextCleanerService cleaner;
  final BookContentLoader contentLoader;

  static const String _partFileName = 'download.part';
  static const String _epubPartFileName = 'download.epub.part';
  static const String _textFileName = BookContentLoader.textFileName;

  @override
  Future<Result<List<LibraryBook>>> getLibrary() => _guard(local.getBooks);

  @override
  Future<Result<List<LibraryBook>>> getRecentlyReadBooks({int limit = 10}) =>
      _guard(() => local.getRecentlyReadBooks(limit: limit));

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
      final bookDir = Directory(p.join(_booksDir.path, '${book.id}'));
      await bookDir.create(recursive: true);
      await _ensureWritable(bookDir);

      // Prefer an EPUB (real publisher TOC); fall back to plain text.
      final epubPath = await _tryDownloadEpub(
        bookDir: bookDir,
        bookId: book.id,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
      final storedPath =
          epubPath ??
          await _downloadPlainText(
            book: book,
            bookDir: bookDir,
            onProgress: onProgress,
            cancelToken: cancelToken,
          );

      final libraryBook = LibraryBook(
        id: book.id,
        title: book.title,
        author: book.authorNames,
        path: storedPath,
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
  Future<Result<LibraryBook>> importEpub(String sourcePath) {
    return _guard(() async {
      final source = File(sourcePath);
      if (!await source.exists()) {
        throw const ValidationFailure('The selected file no longer exists.');
      }

      // Negative ids keep imported books from colliding with Gutenberg ids.
      final id = -DateTime.now().millisecondsSinceEpoch;
      final bookDir = Directory(p.join(_booksDir.path, '$id'));
      await bookDir.create(recursive: true);
      await _ensureWritable(bookDir);

      final epubFile = File(
        p.join(bookDir.path, BookContentLoader.epubFileName),
      );
      await source.copy(epubFile.path);

      final EpubDocument doc;
      try {
        doc = const EpubParser().parse(await epubFile.readAsBytes());
      } catch (_) {
        await bookDir.delete(recursive: true);
        throw const ValidationFailure(
          "This file isn't a readable EPUB. DRM-protected books can't be "
          'imported.',
        );
      }
      if (doc.paragraphs.isEmpty) {
        await bookDir.delete(recursive: true);
        throw const ValidationFailure(
          'This EPUB has no readable text to import.',
        );
      }

      await contentLoader.writeCache(
        bookDir,
        BookContent(paragraphs: doc.paragraphs, toc: doc.toc),
      );

      final title = _cleanMeta(doc.title) ?? _titleFromPath(sourcePath);
      final author = _cleanMeta(doc.author) ?? 'Unknown author';
      final libraryBook = LibraryBook(
        id: id,
        title: title,
        author: author,
        path: epubFile.path,
        language: _cleanMeta(doc.language),
        downloadedAt: DateTime.now(),
      );
      await local.upsertBook(libraryBook);
      return libraryBook;
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
  Future<Result<BookContent>> readBookContent(LibraryBook book) {
    return _guard(() async {
      final bookDir = Directory(p.join(_booksDir.path, '${book.id}'));
      return contentLoader.load(bookDir);
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

  /// Attempts to download and validate the book's EPUB edition.
  ///
  /// Streams the EPUB to `book.epub`, then parses it (warming the `content.json`
  /// cache) to confirm it is usable. Returns the stored EPUB path on success, or
  /// `null` when no EPUB exists / it can't be parsed so the caller falls back to
  /// plain text. Cancellation propagates.
  Future<String?> _tryDownloadEpub({
    required Directory bookDir,
    required int bookId,
    required void Function(int received, int total)? onProgress,
    required CancelToken? cancelToken,
  }) async {
    final partFile = File(p.join(bookDir.path, _epubPartFileName));
    try {
      await download.download(
        url: AppConstants.epubUrl(bookId),
        destination: partFile,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      await _deleteIfExists(partFile);
      return null;
    }

    final epubFile = File(p.join(bookDir.path, BookContentLoader.epubFileName));
    final cacheFile = File(
      p.join(bookDir.path, BookContentLoader.contentCacheName),
    );
    await partFile.rename(epubFile.path);
    // Drop any cache from a previous download so the new EPUB is re-parsed.
    await _deleteIfExists(cacheFile);
    try {
      // Parses and caches; throws if the archive isn't a usable EPUB.
      await contentLoader.load(bookDir);
      return epubFile.path;
    } catch (_) {
      await _deleteIfExists(epubFile);
      await _deleteIfExists(cacheFile);
      return null;
    }
  }

  /// Downloads the book's plain-text edition, cleans it and writes `text.txt`
  /// atomically. Returns the stored text path.
  Future<String> _downloadPlainText({
    required BookSummary book,
    required Directory bookDir,
    required void Function(int received, int total)? onProgress,
    required CancelToken? cancelToken,
  }) async {
    final primaryUrl = book.plainTextUrl ?? AppConstants.plainTextUrl(book.id);
    final fallbackUrl = AppConstants.plainTextUrl(book.id);

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
    await _deleteIfExists(partFile);
    // Remove any EPUB artifacts from a previous download so the loader uses
    // this plain text rather than stale cached EPUB content.
    await _deleteIfExists(
      File(p.join(bookDir.path, BookContentLoader.epubFileName)),
    );
    await _deleteIfExists(
      File(p.join(bookDir.path, BookContentLoader.contentCacheName)),
    );
    return textFile.path;
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
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

  /// Trims EPUB metadata, returning `null` when it is missing or blank.
  String? _cleanMeta(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// Derives a display title from a file path when the EPUB has no title, e.g.
  /// `/downloads/Moby Dick.epub` -> `Moby Dick`.
  String _titleFromPath(String path) {
    final name = p.basenameWithoutExtension(path).trim();
    return name.isEmpty ? 'Imported book' : name;
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
