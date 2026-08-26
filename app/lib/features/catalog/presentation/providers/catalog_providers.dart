import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/dio_client.dart';
import '../../data/datasources/gutendex_remote_data_source.dart';
import '../../data/models/book_summary.dart';
import '../../data/repositories/catalog_repository_impl.dart';
import '../../domain/repositories/catalog_repository.dart';

part 'catalog_providers.g.dart';

/// Remote data source bound to the shared Dio client.
@riverpod
GutendexRemoteDataSource gutendexRemoteDataSource(Ref ref) {
  return GutendexRemoteDataSource(ref.watch(dioProvider));
}

/// Catalog repository used across the Discover, Search and Detail screens.
@riverpod
CatalogRepository catalogRepository(Ref ref) {
  return CatalogRepositoryImpl(ref.watch(gutendexRemoteDataSourceProvider));
}

/// Most popular titles for the Discover carousel.
///
/// Throws the underlying [Failure] on error so the UI can render it via
/// [AsyncValue].
@riverpod
Future<List<BookSummary>> popularBooks(Ref ref) async {
  final repo = ref.watch(catalogRepositoryProvider);
  final result = await repo.getPopularBooks();
  return result.when(
    onSuccess: (response) => response.results,
    onFailure: (failure) => throw failure,
  );
}

/// Books for a given curated subject/topic, keyed by [topic].
@riverpod
Future<List<BookSummary>> booksByTopic(Ref ref, String topic) async {
  final repo = ref.watch(catalogRepositoryProvider);
  final result = await repo.getBooks(topic: topic);
  return result.when(
    onSuccess: (response) => response.results,
    onFailure: (failure) => throw failure,
  );
}

/// A single book's full metadata, keyed by Project Gutenberg [id].
@riverpod
Future<BookSummary> bookDetail(Ref ref, int id) async {
  final repo = ref.watch(catalogRepositoryProvider);
  final result = await repo.getBookById(id);
  return result.when(
    onSuccess: (book) => book,
    onFailure: (failure) => throw failure,
  );
}
