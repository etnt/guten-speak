import 'package:dio/dio.dart';

import '../constants/app_constants.dart';

/// Attaches a descriptive `User-Agent` header to every outgoing request.
///
/// Project Gutenberg etiquette asks clients to identify themselves; centralising
/// this in an interceptor keeps the header consistent across all data sources.
class UserAgentInterceptor extends Interceptor {
  const UserAgentInterceptor();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['User-Agent'] = AppConstants.userAgent;
    handler.next(options);
  }
}
