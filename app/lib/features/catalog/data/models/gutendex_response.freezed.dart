// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gutendex_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GutendexResponse {
  int get count;
  String? get next;
  String? get previous;
  List<BookSummary> get results;

  /// Create a copy of GutendexResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $GutendexResponseCopyWith<GutendexResponse> get copyWith =>
      _$GutendexResponseCopyWithImpl<GutendexResponse>(
          this as GutendexResponse, _$identity);

  /// Serializes this GutendexResponse to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is GutendexResponse &&
            (identical(other.count, count) || other.count == count) &&
            (identical(other.next, next) || other.next == next) &&
            (identical(other.previous, previous) ||
                other.previous == previous) &&
            const DeepCollectionEquality().equals(other.results, results));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, count, next, previous,
      const DeepCollectionEquality().hash(results));

  @override
  String toString() {
    return 'GutendexResponse(count: $count, next: $next, previous: $previous, results: $results)';
  }
}

/// @nodoc
abstract mixin class $GutendexResponseCopyWith<$Res> {
  factory $GutendexResponseCopyWith(
          GutendexResponse value, $Res Function(GutendexResponse) _then) =
      _$GutendexResponseCopyWithImpl;
  @useResult
  $Res call(
      {int count, String? next, String? previous, List<BookSummary> results});
}

/// @nodoc
class _$GutendexResponseCopyWithImpl<$Res>
    implements $GutendexResponseCopyWith<$Res> {
  _$GutendexResponseCopyWithImpl(this._self, this._then);

  final GutendexResponse _self;
  final $Res Function(GutendexResponse) _then;

  /// Create a copy of GutendexResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? count = null,
    Object? next = freezed,
    Object? previous = freezed,
    Object? results = null,
  }) {
    return _then(_self.copyWith(
      count: null == count
          ? _self.count
          : count // ignore: cast_nullable_to_non_nullable
              as int,
      next: freezed == next
          ? _self.next
          : next // ignore: cast_nullable_to_non_nullable
              as String?,
      previous: freezed == previous
          ? _self.previous
          : previous // ignore: cast_nullable_to_non_nullable
              as String?,
      results: null == results
          ? _self.results
          : results // ignore: cast_nullable_to_non_nullable
              as List<BookSummary>,
    ));
  }
}

/// Adds pattern-matching-related methods to [GutendexResponse].
extension GutendexResponsePatterns on GutendexResponse {
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

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_GutendexResponse value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _GutendexResponse() when $default != null:
        return $default(_that);
      case _:
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

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_GutendexResponse value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GutendexResponse():
        return $default(_that);
      case _:
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

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_GutendexResponse value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GutendexResponse() when $default != null:
        return $default(_that);
      case _:
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

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(int count, String? next, String? previous,
            List<BookSummary> results)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _GutendexResponse() when $default != null:
        return $default(_that.count, _that.next, _that.previous, _that.results);
      case _:
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

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(int count, String? next, String? previous,
            List<BookSummary> results)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GutendexResponse():
        return $default(_that.count, _that.next, _that.previous, _that.results);
      case _:
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

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(int count, String? next, String? previous,
            List<BookSummary> results)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _GutendexResponse() when $default != null:
        return $default(_that.count, _that.next, _that.previous, _that.results);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _GutendexResponse extends GutendexResponse {
  const _GutendexResponse(
      {this.count = 0,
      this.next,
      this.previous,
      final List<BookSummary> results = const <BookSummary>[]})
      : _results = results,
        super._();
  factory _GutendexResponse.fromJson(Map<String, dynamic> json) =>
      _$GutendexResponseFromJson(json);

  @override
  @JsonKey()
  final int count;
  @override
  final String? next;
  @override
  final String? previous;
  final List<BookSummary> _results;
  @override
  @JsonKey()
  List<BookSummary> get results {
    if (_results is EqualUnmodifiableListView) return _results;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_results);
  }

  /// Create a copy of GutendexResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$GutendexResponseCopyWith<_GutendexResponse> get copyWith =>
      __$GutendexResponseCopyWithImpl<_GutendexResponse>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$GutendexResponseToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _GutendexResponse &&
            (identical(other.count, count) || other.count == count) &&
            (identical(other.next, next) || other.next == next) &&
            (identical(other.previous, previous) ||
                other.previous == previous) &&
            const DeepCollectionEquality().equals(other._results, _results));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, count, next, previous,
      const DeepCollectionEquality().hash(_results));

  @override
  String toString() {
    return 'GutendexResponse(count: $count, next: $next, previous: $previous, results: $results)';
  }
}

/// @nodoc
abstract mixin class _$GutendexResponseCopyWith<$Res>
    implements $GutendexResponseCopyWith<$Res> {
  factory _$GutendexResponseCopyWith(
          _GutendexResponse value, $Res Function(_GutendexResponse) _then) =
      __$GutendexResponseCopyWithImpl;
  @override
  @useResult
  $Res call(
      {int count, String? next, String? previous, List<BookSummary> results});
}

/// @nodoc
class __$GutendexResponseCopyWithImpl<$Res>
    implements _$GutendexResponseCopyWith<$Res> {
  __$GutendexResponseCopyWithImpl(this._self, this._then);

  final _GutendexResponse _self;
  final $Res Function(_GutendexResponse) _then;

  /// Create a copy of GutendexResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? count = null,
    Object? next = freezed,
    Object? previous = freezed,
    Object? results = null,
  }) {
    return _then(_GutendexResponse(
      count: null == count
          ? _self.count
          : count // ignore: cast_nullable_to_non_nullable
              as int,
      next: freezed == next
          ? _self.next
          : next // ignore: cast_nullable_to_non_nullable
              as String?,
      previous: freezed == previous
          ? _self.previous
          : previous // ignore: cast_nullable_to_non_nullable
              as String?,
      results: null == results
          ? _self._results
          : results // ignore: cast_nullable_to_non_nullable
              as List<BookSummary>,
    ));
  }
}

// dart format on
