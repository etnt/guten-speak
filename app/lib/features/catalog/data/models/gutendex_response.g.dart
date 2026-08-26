// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gutendex_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GutendexResponse _$GutendexResponseFromJson(Map<String, dynamic> json) =>
    _GutendexResponse(
      count: (json['count'] as num?)?.toInt() ?? 0,
      next: json['next'] as String?,
      previous: json['previous'] as String?,
      results:
          (json['results'] as List<dynamic>?)
              ?.map((e) => BookSummary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <BookSummary>[],
    );

Map<String, dynamic> _$GutendexResponseToJson(_GutendexResponse instance) =>
    <String, dynamic>{
      'count': instance.count,
      'next': instance.next,
      'previous': instance.previous,
      'results': instance.results,
    };
