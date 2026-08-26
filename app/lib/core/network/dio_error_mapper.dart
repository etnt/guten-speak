import 'package:dio/dio.dart';

import 'failure.dart';

/// Maps a [DioException] onto the app's typed [Failure] model so the rest of
/// the codebase never has to reason about Dio-specific error types.
Failure mapDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const TimeoutFailure();
    case DioExceptionType.connectionError:
      return const NetworkFailure();
    case DioExceptionType.cancel:
      return const CancelledFailure();
    case DioExceptionType.badCertificate:
      return const NetworkFailure(
        'The server certificate could not be verified.',
      );
    case DioExceptionType.badResponse:
      final statusCode = e.response?.statusCode;
      return ServerFailure(
        'Server responded with status ${statusCode ?? 'unknown'}.',
        statusCode: statusCode,
      );
    case DioExceptionType.unknown:
      return UnknownFailure(
        e.message ?? 'An unexpected network error occurred.',
      );
  }
}
