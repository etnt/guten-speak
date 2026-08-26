import 'package:freezed_annotation/freezed_annotation.dart';

part 'reading_progress.freezed.dart';

/// The reader's last position within a book, keyed by paragraph index (the
/// shared reader/narration position model).
@freezed
abstract class ReadingProgress with _$ReadingProgress {
  const factory ReadingProgress({
    required int bookId,
    required int paragraphIndex,
    required DateTime updatedAt,
  }) = _ReadingProgress;
}
