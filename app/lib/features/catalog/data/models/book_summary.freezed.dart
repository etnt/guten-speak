// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'book_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BookSummary {

 int get id; String get title; List<Author> get authors; List<String> get subjects; List<String> get languages; List<String> get bookshelves;@JsonKey(name: 'copyright') bool? get copyright;@JsonKey(name: 'media_type') String? get mediaType;@JsonKey(name: 'download_count') int get downloadCount; Map<String, String> get formats;
/// Create a copy of BookSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookSummaryCopyWith<BookSummary> get copyWith => _$BookSummaryCopyWithImpl<BookSummary>(this as BookSummary, _$identity);

  /// Serializes this BookSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&const DeepCollectionEquality().equals(other.authors, authors)&&const DeepCollectionEquality().equals(other.subjects, subjects)&&const DeepCollectionEquality().equals(other.languages, languages)&&const DeepCollectionEquality().equals(other.bookshelves, bookshelves)&&(identical(other.copyright, copyright) || other.copyright == copyright)&&(identical(other.mediaType, mediaType) || other.mediaType == mediaType)&&(identical(other.downloadCount, downloadCount) || other.downloadCount == downloadCount)&&const DeepCollectionEquality().equals(other.formats, formats));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,const DeepCollectionEquality().hash(authors),const DeepCollectionEquality().hash(subjects),const DeepCollectionEquality().hash(languages),const DeepCollectionEquality().hash(bookshelves),copyright,mediaType,downloadCount,const DeepCollectionEquality().hash(formats));

@override
String toString() {
  return 'BookSummary(id: $id, title: $title, authors: $authors, subjects: $subjects, languages: $languages, bookshelves: $bookshelves, copyright: $copyright, mediaType: $mediaType, downloadCount: $downloadCount, formats: $formats)';
}


}

/// @nodoc
abstract mixin class $BookSummaryCopyWith<$Res>  {
  factory $BookSummaryCopyWith(BookSummary value, $Res Function(BookSummary) _then) = _$BookSummaryCopyWithImpl;
@useResult
$Res call({
 int id, String title, List<Author> authors, List<String> subjects, List<String> languages, List<String> bookshelves,@JsonKey(name: 'copyright') bool? copyright,@JsonKey(name: 'media_type') String? mediaType,@JsonKey(name: 'download_count') int downloadCount, Map<String, String> formats
});




}
/// @nodoc
class _$BookSummaryCopyWithImpl<$Res>
    implements $BookSummaryCopyWith<$Res> {
  _$BookSummaryCopyWithImpl(this._self, this._then);

  final BookSummary _self;
  final $Res Function(BookSummary) _then;

/// Create a copy of BookSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? authors = null,Object? subjects = null,Object? languages = null,Object? bookshelves = null,Object? copyright = freezed,Object? mediaType = freezed,Object? downloadCount = null,Object? formats = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,authors: null == authors ? _self.authors : authors // ignore: cast_nullable_to_non_nullable
as List<Author>,subjects: null == subjects ? _self.subjects : subjects // ignore: cast_nullable_to_non_nullable
as List<String>,languages: null == languages ? _self.languages : languages // ignore: cast_nullable_to_non_nullable
as List<String>,bookshelves: null == bookshelves ? _self.bookshelves : bookshelves // ignore: cast_nullable_to_non_nullable
as List<String>,copyright: freezed == copyright ? _self.copyright : copyright // ignore: cast_nullable_to_non_nullable
as bool?,mediaType: freezed == mediaType ? _self.mediaType : mediaType // ignore: cast_nullable_to_non_nullable
as String?,downloadCount: null == downloadCount ? _self.downloadCount : downloadCount // ignore: cast_nullable_to_non_nullable
as int,formats: null == formats ? _self.formats : formats // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}

}


/// Adds pattern-matching-related methods to [BookSummary].
extension BookSummaryPatterns on BookSummary {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookSummary() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookSummary value)  $default,){
final _that = this;
switch (_that) {
case _BookSummary():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookSummary value)?  $default,){
final _that = this;
switch (_that) {
case _BookSummary() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String title,  List<Author> authors,  List<String> subjects,  List<String> languages,  List<String> bookshelves, @JsonKey(name: 'copyright')  bool? copyright, @JsonKey(name: 'media_type')  String? mediaType, @JsonKey(name: 'download_count')  int downloadCount,  Map<String, String> formats)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookSummary() when $default != null:
return $default(_that.id,_that.title,_that.authors,_that.subjects,_that.languages,_that.bookshelves,_that.copyright,_that.mediaType,_that.downloadCount,_that.formats);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String title,  List<Author> authors,  List<String> subjects,  List<String> languages,  List<String> bookshelves, @JsonKey(name: 'copyright')  bool? copyright, @JsonKey(name: 'media_type')  String? mediaType, @JsonKey(name: 'download_count')  int downloadCount,  Map<String, String> formats)  $default,) {final _that = this;
switch (_that) {
case _BookSummary():
return $default(_that.id,_that.title,_that.authors,_that.subjects,_that.languages,_that.bookshelves,_that.copyright,_that.mediaType,_that.downloadCount,_that.formats);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String title,  List<Author> authors,  List<String> subjects,  List<String> languages,  List<String> bookshelves, @JsonKey(name: 'copyright')  bool? copyright, @JsonKey(name: 'media_type')  String? mediaType, @JsonKey(name: 'download_count')  int downloadCount,  Map<String, String> formats)?  $default,) {final _that = this;
switch (_that) {
case _BookSummary() when $default != null:
return $default(_that.id,_that.title,_that.authors,_that.subjects,_that.languages,_that.bookshelves,_that.copyright,_that.mediaType,_that.downloadCount,_that.formats);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BookSummary extends BookSummary {
  const _BookSummary({required this.id, required this.title, final  List<Author> authors = const <Author>[], final  List<String> subjects = const <String>[], final  List<String> languages = const <String>[], final  List<String> bookshelves = const <String>[], @JsonKey(name: 'copyright') this.copyright, @JsonKey(name: 'media_type') this.mediaType, @JsonKey(name: 'download_count') this.downloadCount = 0, final  Map<String, String> formats = const <String, String>{}}): _authors = authors,_subjects = subjects,_languages = languages,_bookshelves = bookshelves,_formats = formats,super._();
  factory _BookSummary.fromJson(Map<String, dynamic> json) => _$BookSummaryFromJson(json);

@override final  int id;
@override final  String title;
 final  List<Author> _authors;
@override@JsonKey() List<Author> get authors {
  if (_authors is EqualUnmodifiableListView) return _authors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_authors);
}

 final  List<String> _subjects;
@override@JsonKey() List<String> get subjects {
  if (_subjects is EqualUnmodifiableListView) return _subjects;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_subjects);
}

 final  List<String> _languages;
@override@JsonKey() List<String> get languages {
  if (_languages is EqualUnmodifiableListView) return _languages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_languages);
}

 final  List<String> _bookshelves;
@override@JsonKey() List<String> get bookshelves {
  if (_bookshelves is EqualUnmodifiableListView) return _bookshelves;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_bookshelves);
}

@override@JsonKey(name: 'copyright') final  bool? copyright;
@override@JsonKey(name: 'media_type') final  String? mediaType;
@override@JsonKey(name: 'download_count') final  int downloadCount;
 final  Map<String, String> _formats;
@override@JsonKey() Map<String, String> get formats {
  if (_formats is EqualUnmodifiableMapView) return _formats;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_formats);
}


/// Create a copy of BookSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookSummaryCopyWith<_BookSummary> get copyWith => __$BookSummaryCopyWithImpl<_BookSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BookSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&const DeepCollectionEquality().equals(other._authors, _authors)&&const DeepCollectionEquality().equals(other._subjects, _subjects)&&const DeepCollectionEquality().equals(other._languages, _languages)&&const DeepCollectionEquality().equals(other._bookshelves, _bookshelves)&&(identical(other.copyright, copyright) || other.copyright == copyright)&&(identical(other.mediaType, mediaType) || other.mediaType == mediaType)&&(identical(other.downloadCount, downloadCount) || other.downloadCount == downloadCount)&&const DeepCollectionEquality().equals(other._formats, _formats));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,const DeepCollectionEquality().hash(_authors),const DeepCollectionEquality().hash(_subjects),const DeepCollectionEquality().hash(_languages),const DeepCollectionEquality().hash(_bookshelves),copyright,mediaType,downloadCount,const DeepCollectionEquality().hash(_formats));

@override
String toString() {
  return 'BookSummary(id: $id, title: $title, authors: $authors, subjects: $subjects, languages: $languages, bookshelves: $bookshelves, copyright: $copyright, mediaType: $mediaType, downloadCount: $downloadCount, formats: $formats)';
}


}

/// @nodoc
abstract mixin class _$BookSummaryCopyWith<$Res> implements $BookSummaryCopyWith<$Res> {
  factory _$BookSummaryCopyWith(_BookSummary value, $Res Function(_BookSummary) _then) = __$BookSummaryCopyWithImpl;
@override @useResult
$Res call({
 int id, String title, List<Author> authors, List<String> subjects, List<String> languages, List<String> bookshelves,@JsonKey(name: 'copyright') bool? copyright,@JsonKey(name: 'media_type') String? mediaType,@JsonKey(name: 'download_count') int downloadCount, Map<String, String> formats
});




}
/// @nodoc
class __$BookSummaryCopyWithImpl<$Res>
    implements _$BookSummaryCopyWith<$Res> {
  __$BookSummaryCopyWithImpl(this._self, this._then);

  final _BookSummary _self;
  final $Res Function(_BookSummary) _then;

/// Create a copy of BookSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? authors = null,Object? subjects = null,Object? languages = null,Object? bookshelves = null,Object? copyright = freezed,Object? mediaType = freezed,Object? downloadCount = null,Object? formats = null,}) {
  return _then(_BookSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,authors: null == authors ? _self._authors : authors // ignore: cast_nullable_to_non_nullable
as List<Author>,subjects: null == subjects ? _self._subjects : subjects // ignore: cast_nullable_to_non_nullable
as List<String>,languages: null == languages ? _self._languages : languages // ignore: cast_nullable_to_non_nullable
as List<String>,bookshelves: null == bookshelves ? _self._bookshelves : bookshelves // ignore: cast_nullable_to_non_nullable
as List<String>,copyright: freezed == copyright ? _self.copyright : copyright // ignore: cast_nullable_to_non_nullable
as bool?,mediaType: freezed == mediaType ? _self.mediaType : mediaType // ignore: cast_nullable_to_non_nullable
as String?,downloadCount: null == downloadCount ? _self.downloadCount : downloadCount // ignore: cast_nullable_to_non_nullable
as int,formats: null == formats ? _self._formats : formats // ignore: cast_nullable_to_non_nullable
as Map<String, String>,
  ));
}


}

// dart format on
