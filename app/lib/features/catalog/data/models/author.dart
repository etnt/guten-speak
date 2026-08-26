import 'package:freezed_annotation/freezed_annotation.dart';

part 'author.freezed.dart';
part 'author.g.dart';

/// A book author (or contributor) as returned by the Gutendex API.
@freezed
abstract class Author with _$Author {
  const Author._();

  const factory Author({
    required String name,
    @JsonKey(name: 'birth_year') int? birthYear,
    @JsonKey(name: 'death_year') int? deathYear,
  }) = _Author;

  factory Author.fromJson(Map<String, dynamic> json) => _$AuthorFromJson(json);

  /// A human-readable life-span, e.g. "1775–1817", or an empty string when
  /// no dates are known.
  String get lifeSpan {
    if (birthYear == null && deathYear == null) return '';
    return '${birthYear ?? '?'}–${deathYear ?? '?'}';
  }
}
