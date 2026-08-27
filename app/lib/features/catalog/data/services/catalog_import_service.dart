import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/catalog_import_progress.dart';
import '../datasources/catalog_csv_parser.dart';
import '../datasources/local_catalog_data_source.dart';

/// Downloads Project Gutenberg's catalog CSV, parses it off the UI isolate and
/// populates the local FTS index. Runs once on first use; [refresh] forces a
/// re-download so the index can be updated.
class CatalogImportService {
  CatalogImportService(this._local);

  final LocalCatalogDataSource _local;

  static const String metaImportedAt = 'imported_at';
  static const String metaLastModified = 'last_modified';
  static const String _csvFileName = 'pg_catalog.csv';

  late final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      // Long, streamed download — no receive timeout.
      receiveTimeout: Duration.zero,
      headers: <String, Object?>{'User-Agent': AppConstants.userAgent},
    ),
  );

  /// Whether the local catalog has no rows yet (needs a first import).
  Future<bool> isEmpty() async => (await _local.count()) == 0;

  /// Number of indexed books.
  Future<int> count() => _local.count();

  /// Downloads, parses and indexes the catalog, reporting progress through
  /// [onProgress]. Replaces any existing index.
  ///
  /// When [allowStaged] is true and a non-empty CSV is already present at the
  /// destination (e.g. sideloaded over USB because the network is too slow),
  /// it is used as-is and the network download is skipped.
  Future<void> import({
    required void Function(CatalogImportProgress progress) onProgress,
    bool allowStaged = false,
  }) async {
    final dir = await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, _csvFileName));

    try {
      String? lastModified;
      // 1. Obtain the CSV: reuse a staged copy when allowed, else download it.
      if (allowStaged && await file.exists() && await file.length() > 0) {
        onProgress(const CatalogImportProgress.downloading(1));
      } else {
        onProgress(const CatalogImportProgress.downloading(0));
        final response = await _dio.download(
          AppConstants.catalogCsvUrl,
          file.path,
          onReceiveProgress: (received, total) {
            onProgress(
              CatalogImportProgress.downloading(
                total > 0 ? received / total : 0,
              ),
            );
          },
        );
        lastModified = response.headers.value('last-modified');
      }

      // 2. Parse it in a background isolate.
      onProgress(const CatalogImportProgress.parsing());
      final rows = await compute(parseCatalogCsvFile, file.path);

      // 3. Index the rows.
      onProgress(const CatalogImportProgress.saving(0));
      await _local.replaceAll(
        rows,
        onProgress: (inserted, total) {
          onProgress(
            CatalogImportProgress.saving(total > 0 ? inserted / total : 0),
          );
        },
      );

      // 4. Record metadata.
      await _local.metaSet(metaImportedAt, DateTime.now().toIso8601String());
      if (lastModified != null) {
        await _local.metaSet(metaLastModified, lastModified);
      }
    } finally {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
