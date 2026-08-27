/// Shared, typed failure model returned from all repositories.
///
/// UI layers pattern-match on the concrete subtype to render explicit
/// error states (retryable network issues vs. terminal errors).
sealed class Failure implements Exception {
  const Failure(this.message);

  final String message;

  @override
  String toString() => '$runtimeType($message)';
}

/// No connectivity or the host could not be reached. Retryable.
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection.']);
}

/// The request exceeded its configured timeout. Retryable.
class TimeoutFailure extends Failure {
  const TimeoutFailure([super.message = 'The request timed out.']);
}

/// The server responded with a non-success status code.
class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode});

  final int? statusCode;
}

/// The request was cancelled before completion.
class CancelledFailure extends Failure {
  const CancelledFailure([super.message = 'The request was cancelled.']);
}

/// A local persistence / file-system error (database or disk I/O).
class CacheFailure extends Failure {
  const CacheFailure([super.message = 'A local storage error occurred.']);
}

/// The supplied input was invalid or unsupported (e.g. a malformed or
/// DRM-protected file that cannot be read).
class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'The file could not be read.']);
}

/// Any error that does not map to a more specific failure.
class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'An unexpected error occurred.']);
}
