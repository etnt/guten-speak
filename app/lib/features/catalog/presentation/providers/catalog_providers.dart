import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/app_database.dart';
import '../../data/datasources/gutendex_remote_data_source.dart';
import '../../data/datasources/local_catalog_data_source.dart';
import '../../data/models/book_summary.dart';
import '../../data/repositories/catalog_repository_impl.dart';
import '../../data/services/catalog_import_service.dart';
import '../../domain/entities/catalog_import_progress.dart';
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

/// Offline catalog (SQLite FTS index) used for search and book detail.
@Riverpod(keepAlive: true)
Future<LocalCatalogDataSource> localCatalogDataSource(Ref ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return LocalCatalogDataSource(db);
}

/// Service that downloads and indexes Project Gutenberg's catalog locally.
@Riverpod(keepAlive: true)
Future<CatalogImportService> catalogImportService(Ref ref) async {
  final local = await ref.watch(localCatalogDataSourceProvider.future);
  return CatalogImportService(local);
}

/// Drives the one-time import of the catalog into the local index and exposes
/// its progress. [ensure] is idempotent — a no-op once the catalog is ready or
/// while an import is already running.
@Riverpod(keepAlive: true)
class CatalogImport extends _$CatalogImport {
  @override
  CatalogImportProgress build() => const CatalogImportProgress.idle();

  /// Imports the catalog if it hasn't been indexed yet.
  Future<void> ensure() async {
    if (state.isReady || state.phase.isBusy) return;
    try {
      final service = await ref.read(catalogImportServiceProvider.future);
      if (!await service.isEmpty()) {
        state = CatalogImportProgress.ready(await service.count());
        return;
      }
      await service.import(
        onProgress: (progress) => state = progress,
        allowStaged: true,
      );
      state = CatalogImportProgress.ready(await service.count());
    } catch (error) {
      state = CatalogImportProgress.error(error.toString());
    }
  }

  /// Forces a fresh re-download and re-index of the catalog.
  Future<void> refresh() async {
    if (state.phase.isBusy) return;
    try {
      final service = await ref.read(catalogImportServiceProvider.future);
      await service.import(onProgress: (progress) => state = progress);
      state = CatalogImportProgress.ready(await service.count());
    } catch (error) {
      state = CatalogImportProgress.error(error.toString());
    }
  }
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
///
/// Resolved from the local catalog first (offline, reliable), falling back to
/// the remote Gutendex API only if the id isn't in the local index.
@riverpod
Future<BookSummary> bookDetail(Ref ref, int id) async {
  final local = await ref.watch(localCatalogDataSourceProvider.future);
  final localBook = await local.bookById(id);
  if (localBook != null) return localBook;

  final repo = ref.watch(catalogRepositoryProvider);
  final result = await repo.getBookById(id);
  return result.when(
    onSuccess: (book) => book,
    onFailure: (failure) => throw failure,
  );
}
