import 'package:freezed_annotation/freezed_annotation.dart';

part 'bookmark.freezed.dart';

/// A user-saved position within a book, keyed by paragraph index (the shared
/// reader/narration position model). Unlike [ReadingProgress] there can be many
/// per book.
@freezed
abstract class Bookmark with _$Bookmark {
  const factory Bookmark({
    required int bookId,
    required int paragraphIndex,
    required DateTime createdAt,
    int? id,
    String? note,
  }) = _Bookmark;
}
