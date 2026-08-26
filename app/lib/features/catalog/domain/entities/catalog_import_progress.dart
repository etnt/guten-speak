/// The phase of the local catalog import pipeline.
enum CatalogPhase {
  /// Not started yet.
  idle,

  /// Downloading `pg_catalog.csv`.
  downloading,

  /// Parsing the CSV in a background isolate.
  parsing,

  /// Writing rows into the local FTS index.
  saving,

  /// Catalog is indexed and ready to search.
  ready,

  /// Import failed.
  error;

  /// Whether the import is actively running (download/parse/save).
  bool get isBusy =>
      this == CatalogPhase.downloading ||
      this == CatalogPhase.parsing ||
      this == CatalogPhase.saving;
}

/// Progress of the one-time (and periodic refresh) import of Project
/// Gutenberg's catalog into the local search index.
class CatalogImportProgress {
  const CatalogImportProgress({
    required this.phase,
    this.fraction,
    this.count = 0,
    this.error,
  });

  const CatalogImportProgress.idle() : this(phase: CatalogPhase.idle);

  const CatalogImportProgress.parsing() : this(phase: CatalogPhase.parsing);

  const CatalogImportProgress.downloading(double fraction)
    : this(phase: CatalogPhase.downloading, fraction: fraction);

  const CatalogImportProgress.saving(double fraction)
    : this(phase: CatalogPhase.saving, fraction: fraction);

  const CatalogImportProgress.ready(int count)
    : this(phase: CatalogPhase.ready, count: count);

  const CatalogImportProgress.error(String message)
    : this(phase: CatalogPhase.error, error: message);

  final CatalogPhase phase;

  /// Completion fraction (0..1) for the download and save phases; null when the
  /// total is unknown or the phase has no measurable progress.
  final double? fraction;

  /// Number of indexed books once [phase] is [CatalogPhase.ready].
  final int count;

  /// Error message when [phase] is [CatalogPhase.error].
  final String? error;

  bool get isReady => phase == CatalogPhase.ready;
}
