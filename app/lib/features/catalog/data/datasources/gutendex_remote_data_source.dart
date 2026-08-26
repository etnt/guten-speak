import 'package:dio/dio.dart';

import '../../../../core/constants/app_constants.dart';
import '../models/book_summary.dart';
import '../models/gutendex_response.dart';

/// Thin wrapper over the Gutendex REST API. Translates typed arguments into
/// query parameters and decodes JSON into models. Network errors surface as
/// [DioException] and are mapped to failures in the repository layer.
class GutendexRemoteDataSource {
  const GutendexRemoteDataSource(this._dio);

  final Dio _dio;

  /// Fetches a page of books. With no arguments this returns the most popular
  /// titles (Gutendex sorts by descending download count by default).
  Future<GutendexResponse> fetchBooks({
    String? search,
    String? topic,
    List<String>? languages,
    int? page,
    String? sort,
    CancelToken? cancelToken,
  }) async {
    final query = <String, dynamic>{
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (topic != null && topic.isNotEmpty) 'topic': topic,
      if (languages != null && languages.isNotEmpty)
        'languages': languages.join(','),
      'page': ?page,
      'sort': ?sort,
    };

    // Note the trailing slash: Gutendex issues an APPEND_SLASH 301 redirect for
    // `/books?...` and that redirect can hang indefinitely for some queries
    // (observed with `search=`), tripping Dio's receive timeout. Requesting the
    // canonical `/books/` avoids the redirect entirely.
    final data = await _getWithRetry(
      '${AppConstants.booksPath}/',
      queryParameters: query,
      cancelToken: cancelToken,
    );
    return GutendexResponse.fromJson(data);
  }

  /// Fetches a single book by its Project Gutenberg id.
  Future<BookSummary> fetchBookById(int id, {CancelToken? cancelToken}) async {
    // Trailing slash again avoids the APPEND_SLASH redirect (see [fetchBooks]).
    final data = await _getWithRetry(
      '${AppConstants.booksPath}/$id/',
      cancelToken: cancelToken,
    );
    return BookSummary.fromJson(data);
  }

  /// GETs [path] and returns the decoded JSON map, retrying transient timeouts.
  ///
  /// Gutendex is intermittently flaky: it sometimes accepts the connection but
  /// never sends a byte (0-byte receive timeout), independent of the request,
  /// and can stall several times in a row before succeeding. A real response
  /// normally arrives in well under a second, so we use a short per-attempt
  /// receive timeout and retry several times — a hung attempt aborts quickly and
  /// the next one usually lands, instead of failing after the global timeout.
  Future<Map<String, dynamic>> _getWithRetry(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    const maxAttempts = 6;
    for (var attempt = 1; ; attempt++) {
      try {
        final response = await _dio.get<Map<String, dynamic>>(
          path,
          queryParameters: queryParameters,
          cancelToken: cancelToken,
          options: Options(receiveTimeout: const Duration(seconds: 5)),
        );
        return response.data ?? const {};
      } on DioException catch (error) {
        if (CancelToken.isCancel(error) ||
            attempt >= maxAttempts ||
            !_isTransientTimeout(error)) {
          rethrow;
        }
      }
    }
  }

  /// Whether a [DioException] is a transient timeout worth retrying (Gutendex
  /// occasionally stalls before sending any response bytes).
  bool _isTransientTimeout(DioException error) =>
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.connectionError;
}
