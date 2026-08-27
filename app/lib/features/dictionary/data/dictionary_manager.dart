import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Raised when a dictionary download is aborted via the
/// [DictionaryManager.ensureDictionary] cancellation callback, so callers can
/// tell it apart from a real failure.
class DictionaryDownloadCancelled implements Exception {
  const DictionaryDownloadCancelled();

  @override
  String toString() => 'Dictionary download cancelled';
}

/// Downloads and stores the optional WordNet dictionary database on first use.
///
/// The database (~15 MB) is fetched once with resume support and kept at
/// `<appSupport>/dictionary/wordnet.sqlite`, after which look-ups work offline.
/// Build/host the asset with `tools/build_wordnet_db.py` (see that script).
class DictionaryManager {
  static const String _fileName = 'wordnet.sqlite';

  /// Candidate download locations, tried in order until one succeeds. Mirrors
  /// the TTS model's own-repo release pattern; upload `wordnet.sqlite` to this
  /// release tag to enable the feature.
  static const List<String> _urls = <String>[
    'https://github.com/etnt/guten-speak/releases/download/dictionary/wordnet.sqlite',
  ];

  /// Absolute path where the database is (or will be) stored.
  Future<String> databasePath() async {
    final support = await getApplicationSupportDirectory();
    return '${support.path}/dictionary/$_fileName';
  }

  /// Whether the dictionary is already installed on disk.
  Future<bool> isInstalled() async => File(await databasePath()).existsSync();

  /// Size of the installed database in bytes, or 0 when not installed.
  Future<int> installedBytes() async {
    final file = File(await databasePath());
    return file.existsSync() ? file.lengthSync() : 0;
  }

  /// Deletes the installed database, if present.
  Future<void> delete() async {
    final file = File(await databasePath());
    if (file.existsSync()) await file.delete();
    final part = File('${file.path}.part');
    if (part.existsSync()) await part.delete();
  }

  /// Ensures the dictionary is present, downloading it if missing, and returns
  /// its path.
  ///
  /// [onProgress] receives a 0..1 fraction (or null when the size is unknown).
  /// [isCancelled], when supplied, is polled between chunks; returning true
  /// aborts with a [DictionaryDownloadCancelled] (the partial download is kept
  /// so a later call resumes it).
  Future<String> ensureDictionary({
    void Function(double? fraction)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final path = await databasePath();
    final file = File(path);
    if (file.existsSync()) return path;

    await file.parent.create(recursive: true);
    await _downloadWithFallback(
      _urls,
      file,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
    return path;
  }

  Future<void> _downloadWithFallback(
    List<String> urls,
    File target, {
    void Function(double? fraction)? onProgress,
    bool Function()? isCancelled,
  }) async {
    Object? lastError;
    for (final url in urls) {
      try {
        await _download(url, target, onProgress: onProgress, isCancelled: isCancelled);
        return;
      } on DictionaryDownloadCancelled {
        rethrow;
      } catch (e) {
        lastError = e;
        onProgress?.call(null);
      }
    }
    throw Exception('All download sources failed. Last error: $lastError');
  }

  /// Streams [url] into `<target>.part`, resuming from any bytes already there
  /// via a `Range` request, then renames it to [target] once complete.
  Future<void> _download(
    String url,
    File target, {
    void Function(double? fraction)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final partFile = File('${target.path}.part');
    var existing = partFile.existsSync() ? partFile.lengthSync() : 0;

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      if (existing > 0) {
        request.headers['Range'] = 'bytes=$existing-';
      }
      final response = await client.send(request);

      final resuming = response.statusCode == 206;
      if (!resuming) {
        existing = 0;
        if (partFile.existsSync()) {
          await partFile.delete();
        }
      }
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception('Download failed: HTTP ${response.statusCode} for $url');
      }

      final contentLength = response.contentLength;
      final total = contentLength != null ? contentLength + existing : null;
      var received = existing;
      final sink = partFile.openWrite(
        mode: resuming ? FileMode.append : FileMode.write,
      );
      try {
        await for (final chunk in response.stream) {
          if (isCancelled?.call() ?? false) {
            throw const DictionaryDownloadCancelled();
          }
          sink.add(chunk);
          received += chunk.length;
          if (total != null && total > 0) {
            onProgress?.call(received / total);
          } else {
            onProgress?.call(null);
          }
        }
      } finally {
        await sink.close();
      }
    } finally {
      client.close();
    }

    await partFile.rename(target.path);
  }
}
