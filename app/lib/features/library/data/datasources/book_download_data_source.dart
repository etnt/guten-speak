import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Streams a remote file to disk with progress, cancellation and best-effort
/// resume via HTTP Range requests. Throws [DioException] on network errors and
/// [FileSystemException] on disk errors; the repository maps both to failures.
class BookDownloadDataSource {
  const BookDownloadDataSource(this._dio);

  final Dio _dio;

  /// Downloads [url] into [destination].
  ///
  /// If [destination] already holds a partial download, a `Range` request
  /// resumes from where it left off (when the server returns `206`); otherwise
  /// the file is (re)written from the start. [onProgress] reports
  /// `(received, total)` bytes, with `total == -1` when the size is unknown.
  Future<void> download({
    required String url,
    required File destination,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final partialBytes = await destination.exists()
        ? await destination.length()
        : 0;

    final response = await _dio.get<ResponseBody>(
      url,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: true,
        headers: partialBytes > 0
            ? <String, Object?>{'Range': 'bytes=$partialBytes-'}
            : null,
        validateStatus: (status) => status != null && status < 400,
      ),
    );

    final resumed = response.statusCode == 206;
    final contentLength = _contentLength(response.headers);
    var received = resumed ? partialBytes : 0;
    final total = contentLength == null
        ? -1
        : (resumed ? partialBytes + contentLength : contentLength);

    final sink = destination.openWrite(
      mode: resumed ? FileMode.append : FileMode.writeOnly,
    );
    try {
      await for (final Uint8List chunk in response.data!.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  int? _contentLength(Headers headers) {
    final raw = headers.value(Headers.contentLengthHeader);
    if (raw == null) return null;
    return int.tryParse(raw);
  }
}
