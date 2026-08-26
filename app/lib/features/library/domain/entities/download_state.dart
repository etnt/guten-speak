import '../../../../core/network/failure.dart';
import 'library_book.dart';

/// Lifecycle of a single book download, surfaced to the UI for progress and
/// cancellation.
enum DownloadStatus { idle, downloading, completed, failed }

/// Immutable snapshot of a book download.
class DownloadState {
  const DownloadState({
    this.status = DownloadStatus.idle,
    this.progress = 0,
    this.failure,
    this.book,
  });

  final DownloadStatus status;

  /// Fraction complete in `0..1`, or `-1` when the total size is unknown
  /// (indeterminate progress).
  final double progress;

  /// Set when [status] is [DownloadStatus.failed].
  final Failure? failure;

  /// Set when [status] is [DownloadStatus.completed].
  final LibraryBook? book;

  bool get isDownloading => status == DownloadStatus.downloading;
  bool get isCompleted => status == DownloadStatus.completed;

  DownloadState copyWith({
    DownloadStatus? status,
    double? progress,
    Failure? failure,
    LibraryBook? book,
  }) {
    return DownloadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      failure: failure ?? this.failure,
      book: book ?? this.book,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DownloadState &&
      other.status == status &&
      other.progress == progress &&
      other.failure == failure &&
      other.book == book;

  @override
  int get hashCode => Object.hash(status, progress, failure, book);
}
