import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import 'user_agent_interceptor.dart';

/// Provides a configured [Dio] instance for talking to the Gutendex API.
///
/// The base URL is the Gutendex origin so both `/books` and `/books/{id}`
/// paths resolve correctly. A [UserAgentInterceptor] applies Gutenberg-friendly
/// request identification; feature-specific interceptors are layered on later.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.gutendexBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json'},
    ),
  );
  dio.interceptors.add(const UserAgentInterceptor());
  return dio;
});
