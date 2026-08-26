import 'package:freezed_annotation/freezed_annotation.dart';

import 'book_summary.dart';

part 'gutendex_response.freezed.dart';
part 'gutendex_response.g.dart';

/// A paginated page of catalog results from the Gutendex `/books` endpoint.
@freezed
abstract class GutendexResponse with _$GutendexResponse {
  const GutendexResponse._();

  const factory GutendexResponse({
    @Default(0) int count,
    String? next,
    String? previous,
    @Default(<BookSummary>[]) List<BookSummary> results,
  }) = _GutendexResponse;

  factory GutendexResponse.fromJson(Map<String, dynamic> json) =>
      _$GutendexResponseFromJson(json);

  /// Whether another page of results is available.
  bool get hasMore => next != null;
}
