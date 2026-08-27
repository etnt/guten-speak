import 'package:dio/dio.dart';

import '../../../../core/network/result.dart';
import '../../../catalog/data/models/book_summary.dart';
import '../entities/book_content.dart';
import '../entities/library_book.dart';
import '../entities/reading_progress.dart';

/// Contract for downloading, persisting and reading locally-stored books.
abstract interface class LibraryRepository {
  /// All downloaded books, newest first.
  Future<Result<List<LibraryBook>>> getLibrary();

  /// The downloaded record for [id], or `null` if it is not in the library.
  Future<Result<LibraryBook?>> getBook(int id);

  /// Downloads [book]'s plain text, cleans it, stores it on disk and records it
  /// in the library. Reports byte progress via [onProgress].
  Future<Result<LibraryBook>> downloadBook(
    BookSummary book, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  });

  /// Removes [id] from the library and deletes its files.
  Future<Result<void>> deleteBook(int id);

  /// Imports a local `.epub` file at [sourcePath] into the library: copies it
  /// in, parses it (assigning a synthetic negative id so it never collides with
  /// a Project Gutenberg id) and records it. Fails when the file isn't a
  /// readable EPUB (e.g. DRM-protected).
  Future<Result<LibraryBook>> importEpub(String sourcePath);

  /// Reads the cleaned text of a downloaded [book].
  Future<Result<String>> readBookText(LibraryBook book);

  /// Reads a downloaded [book]'s structured content (paragraphs + TOC),
  /// preferring a parsed EPUB over plain text.
  Future<Result<BookContent>> readBookContent(LibraryBook book);

  /// The saved reading position for [bookId], if any.
  Future<Result<ReadingProgress?>> getProgress(int bookId);

  /// Persists the reading position for [bookId] at [paragraphIndex].
  Future<Result<void>> saveProgress(int bookId, int paragraphIndex);
}
