import 'package:dio/dio.dart';

import '../../../../core/network/dio_error_mapper.dart';
import '../../../../core/network/failure.dart';
import '../../../../core/network/result.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../datasources/gutendex_remote_data_source.dart';
import '../models/book_summary.dart';
import '../models/gutendex_response.dart';

/// [CatalogRepository] backed by the Gutendex REST API.
///
/// Wraps each remote call, converting [DioException]s into typed [Failure]s and
/// any other error into an [UnknownFailure].
class CatalogRepositoryImpl implements CatalogRepository {
  const CatalogRepositoryImpl(this._remote);

  final GutendexRemoteDataSource _remote;

  @override
  Future<Result<GutendexResponse>> getBooks({
    String? search,
    String? topic,
    List<String>? languages,
    int? page,
    CancelToken? cancelToken,
  }) {
    return _guard(
      () => _remote.fetchBooks(
        search: search,
        topic: topic,
        languages: languages,
        page: page,
        cancelToken: cancelToken,
      ),
    );
  }

  @override
  Future<Result<GutendexResponse>> getPopularBooks({int? page}) {
    return _guard(() => _remote.fetchBooks(page: page));
  }

  @override
  Future<Result<BookSummary>> getBookById(int id) {
    return _guard(() => _remote.fetchBookById(id));
  }

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Success(await action());
    } on DioException catch (e) {
      return ResultFailure(mapDioException(e));
    } on Failure catch (f) {
      return ResultFailure(f);
    } catch (_) {
      return const ResultFailure(UnknownFailure());
    }
  }
}
