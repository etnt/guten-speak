import 'package:freezed_annotation/freezed_annotation.dart';

import 'author.dart';

part 'book_summary.freezed.dart';
part 'book_summary.g.dart';

/// A single book entry from the Gutendex catalog.
///
/// The [formats] map keys are MIME types (e.g. `text/plain; charset=utf-8`)
/// and values are direct download URLs. Convenience getters expose the formats
/// the app cares about.
@freezed
abstract class BookSummary with _$BookSummary {
  const BookSummary._();

  const factory BookSummary({
    required int id,
    required String title,
    @Default(<Author>[]) List<Author> authors,
    @Default(<String>[]) List<String> subjects,
    @Default(<String>[]) List<String> languages,
    @Default(<String>[]) List<String> bookshelves,
    @JsonKey(name: 'copyright') bool? copyright,
    @JsonKey(name: 'media_type') String? mediaType,
    @JsonKey(name: 'download_count') @Default(0) int downloadCount,
    @Default(<String, String>{}) Map<String, String> formats,
  }) = _BookSummary;

  factory BookSummary.fromJson(Map<String, dynamic> json) =>
      _$BookSummaryFromJson(json);

  /// Comma-separated author names, e.g. "Austen, Jane".
  String get authorNames => authors.isEmpty
      ? 'Unknown author'
      : authors.map((a) => a.name).join(', ');

  /// URL of the cover thumbnail, if the catalog provides one.
  String? get coverImageUrl =>
      _firstMatching((mime) => mime.startsWith('image/'));

  /// UTF-8 plain-text download URL (preferred), falling back to any non-zipped
  /// plain-text format. Returns `null` when no readable text format exists.
  String? get plainTextUrl {
    final utf8 = _firstMatching(
      (mime) => mime.startsWith('text/plain') && mime.contains('utf-8'),
    );
    if (utf8 != null) return utf8;
    return _firstMatching(
      (mime) => mime.startsWith('text/plain') && !mime.contains('zip'),
    );
  }

  /// EPUB download URL, if available.
  String? get epubUrl =>
      _firstMatching((mime) => mime.startsWith('application/epub'));

  /// HTML reading URL, if available.
  String? get htmlUrl => _firstMatching(
    (mime) => mime.startsWith('text/html') && !mime.contains('zip'),
  );

  /// Whether the book can be read as plain text within the app.
  bool get hasReadableText => plainTextUrl != null;

  String? _firstMatching(bool Function(String mime) test) {
    for (final entry in formats.entries) {
      if (test(entry.key)) return entry.value;
    }
    return null;
  }
}
