import 'failure.dart';

/// A discriminated union representing either a successful value of type [T]
/// or a [Failure]. Used as the return type of repository methods so callers
/// handle errors explicitly instead of relying on thrown exceptions.
sealed class Result<T> {
  const Result();

  /// Whether this result holds a success value.
  bool get isSuccess => this is Success<T>;

  /// Whether this result holds a failure.
  bool get isFailure => this is ResultFailure<T>;

  /// Folds the result into a single value by handling both branches.
  R when<R>({
    required R Function(T value) onSuccess,
    required R Function(Failure failure) onFailure,
  }) {
    final self = this;
    return switch (self) {
      Success<T>(:final value) => onSuccess(value),
      ResultFailure<T>(:final failure) => onFailure(failure),
    };
  }
}

/// A successful [Result] wrapping [value].
class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;
}

/// A failed [Result] wrapping a [Failure].
class ResultFailure<T> extends Result<T> {
  const ResultFailure(this.failure);

  final Failure failure;
}
