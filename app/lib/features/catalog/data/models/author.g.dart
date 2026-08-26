// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'author.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Author _$AuthorFromJson(Map<String, dynamic> json) => _Author(
  name: json['name'] as String,
  birthYear: (json['birth_year'] as num?)?.toInt(),
  deathYear: (json['death_year'] as num?)?.toInt(),
);

Map<String, dynamic> _$AuthorToJson(_Author instance) => <String, dynamic>{
  'name': instance.name,
  'birth_year': instance.birthYear,
  'death_year': instance.deathYear,
};
