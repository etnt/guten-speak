import 'package:freezed_annotation/freezed_annotation.dart';

part 'library_book.freezed.dart';

/// A book that has been downloaded and stored locally.
///
/// The [path] points at the cleaned plain-text file on disk; metadata is
/// mirrored into SQLite so the library can be listed without touching the
/// filesystem.
@freezed
abstract class LibraryBook with _$LibraryBook {
  const factory LibraryBook({
    required int id,
    required String title,
    required String author,
    required String path,
    required DateTime downloadedAt,
    String? language,
    String? coverUrl,
  }) = _LibraryBook;
}
