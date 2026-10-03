import 'dart:async';

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
  Completer<void> _ready = Completer<void>();

  /// Completes once the catalog index is ready to query, or fails with the
  /// import error. Lets other providers wait for the import without touching
  /// notifier state.
  Future<void> get ready => _ready.future;

  @override
  CatalogImportProgress build() {
    _ready = Completer<void>();
    return const CatalogImportProgress.idle();
  }

  /// Imports the catalog if it hasn't been indexed yet.
  Future<void> ensure() async {
    if (state.isReady) {
      _completeReady();
      return;
    }
    if (state.phase.isBusy) return;
    try {
      final service = await ref.read(catalogImportServiceProvider.future);
      if (!await service.isEmpty()) {
        state = CatalogImportProgress.ready(await service.count());
        _completeReady();
        return;
      }
      await service.import(
        onProgress: (progress) => state = progress,
        allowStaged: true,
      );
      state = CatalogImportProgress.ready(await service.count());
      _completeReady();
    } catch (error) {
      state = CatalogImportProgress.error(error.toString());
      _completeError(error);
    }
  }

  /// Forces a fresh re-download and re-index of the catalog.
  Future<void> refresh() async {
    if (state.phase.isBusy) return;
    try {
      final service = await ref.read(catalogImportServiceProvider.future);
      await service.import(onProgress: (progress) => state = progress);
      state = CatalogImportProgress.ready(await service.count());
      _completeReady();
    } catch (error) {
      state = CatalogImportProgress.error(error.toString());
    }
  }

  void _completeReady() {
    if (!_ready.isCompleted) _ready.complete();
  }

  void _completeError(Object error) {
    if (!_ready.isCompleted) _ready.completeError(error);
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
///
/// Gutendex's `topic` filter times out server-side (the equivalent
/// `sort=popular` endpoint responds in ~0.2 s), so these shelves are served
/// from the local catalog instead. On a fresh install the one-time catalog
/// import is kicked off here; the provider completes once the index is ready.
@riverpod
Future<List<BookSummary>> booksByTopic(Ref ref, String topic) async {
  // Capture the notifier before the async gaps: after the provider is
  // disposed (user navigates away mid-import) `ref` may no longer be used.
  final import = ref.read(catalogImportProvider.notifier);
  unawaited(import.ensure());
  // Listen right away: if the import fails before the await below (e.g. the
  // local database is unavailable), the completer's error must not surface as
  // an unhandled error; the failure reaches us through the await instead.
  import.ready.ignore();
  final local = await ref.watch(localCatalogDataSourceProvider.future);
  // Fresh installs import the catalog first; this completes once the index
  // is ready, or fails the shelf with the import error.
  await import.ready;
  return local.bySubject(topic);
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
