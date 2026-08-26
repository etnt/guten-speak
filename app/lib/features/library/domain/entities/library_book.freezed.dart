// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'library_book.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LibraryBook {

 int get id; String get title; String get author; String get path; DateTime get downloadedAt; String? get language; String? get coverUrl;
/// Create a copy of LibraryBook
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibraryBookCopyWith<LibraryBook> get copyWith => _$LibraryBookCopyWithImpl<LibraryBook>(this as LibraryBook, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibraryBook&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.author, author) || other.author == author)&&(identical(other.path, path) || other.path == path)&&(identical(other.downloadedAt, downloadedAt) || other.downloadedAt == downloadedAt)&&(identical(other.language, language) || other.language == language)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl));
}


@override
int get hashCode => Object.hash(runtimeType,id,title,author,path,downloadedAt,language,coverUrl);

@override
String toString() {
  return 'LibraryBook(id: $id, title: $title, author: $author, path: $path, downloadedAt: $downloadedAt, language: $language, coverUrl: $coverUrl)';
}


}

/// @nodoc
abstract mixin class $LibraryBookCopyWith<$Res>  {
  factory $LibraryBookCopyWith(LibraryBook value, $Res Function(LibraryBook) _then) = _$LibraryBookCopyWithImpl;
@useResult
$Res call({
 int id, String title, String author, String path, DateTime downloadedAt, String? language, String? coverUrl
});




}
/// @nodoc
class _$LibraryBookCopyWithImpl<$Res>
    implements $LibraryBookCopyWith<$Res> {
  _$LibraryBookCopyWithImpl(this._self, this._then);

  final LibraryBook _self;
  final $Res Function(LibraryBook) _then;

/// Create a copy of LibraryBook
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? author = null,Object? path = null,Object? downloadedAt = null,Object? language = freezed,Object? coverUrl = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,downloadedAt: null == downloadedAt ? _self.downloadedAt : downloadedAt // ignore: cast_nullable_to_non_nullable
as DateTime,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LibraryBook].
extension LibraryBookPatterns on LibraryBook {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibraryBook value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibraryBook() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibraryBook value)  $default,){
final _that = this;
switch (_that) {
case _LibraryBook():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibraryBook value)?  $default,){
final _that = this;
switch (_that) {
case _LibraryBook() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String title,  String author,  String path,  DateTime downloadedAt,  String? language,  String? coverUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibraryBook() when $default != null:
return $default(_that.id,_that.title,_that.author,_that.path,_that.downloadedAt,_that.language,_that.coverUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String title,  String author,  String path,  DateTime downloadedAt,  String? language,  String? coverUrl)  $default,) {final _that = this;
switch (_that) {
case _LibraryBook():
return $default(_that.id,_that.title,_that.author,_that.path,_that.downloadedAt,_that.language,_that.coverUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String title,  String author,  String path,  DateTime downloadedAt,  String? language,  String? coverUrl)?  $default,) {final _that = this;
switch (_that) {
case _LibraryBook() when $default != null:
return $default(_that.id,_that.title,_that.author,_that.path,_that.downloadedAt,_that.language,_that.coverUrl);case _:
  return null;

}
}

}

/// @nodoc


class _LibraryBook implements LibraryBook {
  const _LibraryBook({required this.id, required this.title, required this.author, required this.path, required this.downloadedAt, this.language, this.coverUrl});
  

@override final  int id;
@override final  String title;
@override final  String author;
@override final  String path;
@override final  DateTime downloadedAt;
@override final  String? language;
@override final  String? coverUrl;

/// Create a copy of LibraryBook
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibraryBookCopyWith<_LibraryBook> get copyWith => __$LibraryBookCopyWithImpl<_LibraryBook>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibraryBook&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.author, author) || other.author == author)&&(identical(other.path, path) || other.path == path)&&(identical(other.downloadedAt, downloadedAt) || other.downloadedAt == downloadedAt)&&(identical(other.language, language) || other.language == language)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl));
}


@override
int get hashCode => Object.hash(runtimeType,id,title,author,path,downloadedAt,language,coverUrl);

@override
String toString() {
  return 'LibraryBook(id: $id, title: $title, author: $author, path: $path, downloadedAt: $downloadedAt, language: $language, coverUrl: $coverUrl)';
}


}

/// @nodoc
abstract mixin class _$LibraryBookCopyWith<$Res> implements $LibraryBookCopyWith<$Res> {
  factory _$LibraryBookCopyWith(_LibraryBook value, $Res Function(_LibraryBook) _then) = __$LibraryBookCopyWithImpl;
@override @useResult
$Res call({
 int id, String title, String author, String path, DateTime downloadedAt, String? language, String? coverUrl
});




}
/// @nodoc
class __$LibraryBookCopyWithImpl<$Res>
    implements _$LibraryBookCopyWith<$Res> {
  __$LibraryBookCopyWithImpl(this._self, this._then);

  final _LibraryBook _self;
  final $Res Function(_LibraryBook) _then;

/// Create a copy of LibraryBook
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? author = null,Object? path = null,Object? downloadedAt = null,Object? language = freezed,Object? coverUrl = freezed,}) {
  return _then(_LibraryBook(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,downloadedAt: null == downloadedAt ? _self.downloadedAt : downloadedAt // ignore: cast_nullable_to_non_nullable
as DateTime,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
