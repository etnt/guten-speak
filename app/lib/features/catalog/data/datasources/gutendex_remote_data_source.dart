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

    final response = await _dio.get<Map<String, dynamic>>(
      AppConstants.booksPath,
      queryParameters: query,
      cancelToken: cancelToken,
    );
    return GutendexResponse.fromJson(response.data ?? const {});
  }

  /// Fetches a single book by its Project Gutenberg id.
  Future<BookSummary> fetchBookById(int id, {CancelToken? cancelToken}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '${AppConstants.booksPath}/$id',
      cancelToken: cancelToken,
    );
    return BookSummary.fromJson(response.data ?? const {});
  }
}
