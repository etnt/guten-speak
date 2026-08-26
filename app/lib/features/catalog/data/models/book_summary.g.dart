// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'book_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BookSummary _$BookSummaryFromJson(Map<String, dynamic> json) => _BookSummary(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String,
  authors:
      (json['authors'] as List<dynamic>?)
          ?.map((e) => Author.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Author>[],
  subjects:
      (json['subjects'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  languages:
      (json['languages'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const <String>[],
  bookshelves:
      (json['bookshelves'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const <String>[],
  copyright: json['copyright'] as bool?,
  mediaType: json['media_type'] as String?,
  downloadCount: (json['download_count'] as num?)?.toInt() ?? 0,
  formats:
      (json['formats'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const <String, String>{},
);

Map<String, dynamic> _$BookSummaryToJson(_BookSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'authors': instance.authors,
      'subjects': instance.subjects,
      'languages': instance.languages,
      'bookshelves': instance.bookshelves,
      'copyright': instance.copyright,
      'media_type': instance.mediaType,
      'download_count': instance.downloadCount,
      'formats': instance.formats,
    };
