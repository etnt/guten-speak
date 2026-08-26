import 'package:dio/dio.dart' show CancelToken;

import '../../../../core/network/result.dart';
import '../../data/models/book_summary.dart';
import '../../data/models/gutendex_response.dart';

/// Domain-facing contract for browsing and searching the Project Gutenberg
/// catalog. Implementations return a [Result] so callers handle failures
/// explicitly instead of catching exceptions.
abstract interface class CatalogRepository {
  /// Fetches a page of books, optionally filtered by [search], [topic],
  /// [languages] and [page]. Pass a [cancelToken] to abort the request.
  Future<Result<GutendexResponse>> getBooks({
    String? search,
    String? topic,
    List<String>? languages,
    int? page,
    CancelToken? cancelToken,
  });

  /// Fetches the most popular titles (default Gutendex ordering).
  Future<Result<GutendexResponse>> getPopularBooks({int? page});

  /// Fetches a single book by its Project Gutenberg id.
  Future<Result<BookSummary>> getBookById(int id);
}
