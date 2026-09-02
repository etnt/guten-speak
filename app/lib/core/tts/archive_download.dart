import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Raised when a download is aborted via a cancellation callback, so callers can
/// distinguish it from a real failure.
class ModelDownloadCancelled implements Exception {
  const ModelDownloadCancelled();

  @override
  String toString() => 'Model download cancelled';
}

/// Raised when an extracted archive fails an integrity check: either the
/// downloaded bytes do not match the pinned SHA-256, or an entry's path tries
/// to escape the destination directory (a "zip slip"/path-traversal attempt).
class ArchiveIntegrityException implements Exception {
  const ArchiveIntegrityException(this.message);

  ArchiveIntegrityException.shaMismatch({
    required String expected,
    required String actual,
  }) : message = 'Archive integrity check failed: expected SHA-256 $expected '
            'but got $actual';

  ArchiveIntegrityException.unsafePath(String name)
      : message = 'Refusing to extract unsafe archive path: $name';

  final String message;

  @override
  String toString() => message;
}

/// Returns true when [name] (an archive entry path) is unsafe to extract because
/// it is absolute or would escape the destination via `..` segments.
bool _isUnsafeArchivePath(String name) {
  if (name.isEmpty) return true;
  final normalized = name.replaceAll('\\', '/');
  if (normalized.startsWith('/')) return true; // absolute POSIX path
  if (RegExp(r'^[a-zA-Z]:').hasMatch(normalized)) return true; // drive letter
  for (final segment in normalized.split('/')) {
    if (segment == '..') return true;
  }
  return false;
}

/// Tries each URL in [urls] in order, returning after the first successful
/// download. If every source fails, rethrows the last error so the caller can
/// surface it. A cancellation is not retried — it propagates immediately.
///
/// [onStatus] receives human-readable progress messages. [onProgress] receives
/// a 0..1 download fraction (or null when the size is unknown). [isCancelled],
/// when supplied, is polled between chunks; returning true aborts the download
/// with a [ModelDownloadCancelled] exception (the partial download is kept on
/// disk so a later call resumes it).
Future<void> downloadArchiveWithFallback(
  List<String> urls,
  File target, {
  void Function(String message)? onStatus,
  void Function(double? fraction)? onProgress,
  bool Function()? isCancelled,
}) async {
  Object? lastError;
  for (var i = 0; i < urls.length; i++) {
    try {
      await _download(
        urls[i],
        target,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );
      return;
    } on ModelDownloadCancelled {
      rethrow;
    } catch (e) {
      lastError = e;
      final hasNext = i + 1 < urls.length;
      if (hasNext) {
        onStatus?.call('Source unavailable — trying another source…');
        onProgress?.call(null);
      }
    }
  }
  throw Exception('All download sources failed. Last error: $lastError');
}

/// Streams [url] into `<target>.part`, resuming from any bytes already there via
/// a `Range` request, then renames it to [target] once complete.
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

    // A server that ignores Range replies 200 and resends from the start.
    final resuming = response.statusCode == 206;
    if (!resuming) {
      existing = 0;
      if (partFile.existsSync()) {
        await partFile.delete();
      }
    }
    if (response.statusCode != 200 && response.statusCode != 206) {
      throw Exception(
        'Download failed: HTTP ${response.statusCode} for $url',
      );
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
          throw const ModelDownloadCancelled();
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

/// Decompresses a `.tar.bz2` archive and extracts it into [destDir].
///
/// The actual work runs in a short-lived isolate via [Isolate.run] because bz2
/// decompression of a large payload is CPU-bound and synchronous; running it on
/// the UI isolate froze the app and triggered Android's ANR
/// ("application doesn't respond") dialog.
///
/// When [expectedSha256] is supplied, the compressed archive's SHA-256 is
/// verified before anything is written; a mismatch deletes the archive and
/// throws an [ArchiveIntegrityException]. Every entry path is also checked for
/// path-traversal before it is written.
Future<void> extractTarBz2(
  File archiveFile,
  Directory destDir, {
  String? expectedSha256,
}) async {
  final archivePath = archiveFile.path;
  final destPath = destDir.path;
  await Isolate.run(
    () => _extractTarBz2Sync(archivePath, destPath, expectedSha256),
  );
}

/// Decompresses [archivePath] (`.tar.bz2`) and extracts it into [destPath].
///
/// Runs inside an isolate (see [extractTarBz2]). To keep peak **disk** usage low
/// on nearly-full devices, the bz2 is decompressed into memory and the
/// compressed archive is deleted before any files are written, so the disk only
/// ever holds the final extracted payload (never the archive and an intermediate
/// `.tar` at the same time). The uncompressed bytes live in RAM briefly, which
/// modern phones handle comfortably.
///
/// `extractFileToDisk` is deliberately avoided: it relies on the platform temp
/// directory (Android's `code_cache`) and was observed to fail there with a
/// missing-temp-file error.
void _extractTarBz2Sync(
  String archivePath,
  String destPath, [
  String? expectedSha256,
]) {
  final archiveFile = File(archivePath);

  // bz2 -> tar bytes in memory.
  final compressed = archiveFile.readAsBytesSync();

  // Verify integrity before touching disk, so a corrupt/tampered download can
  // never be extracted. On mismatch, delete the archive so the next attempt
  // re-downloads a fresh copy instead of resuming onto bad bytes.
  if (expectedSha256 != null) {
    final actual = sha256.convert(compressed).toString();
    if (actual != expectedSha256) {
      if (archiveFile.existsSync()) {
        archiveFile.deleteSync();
      }
      throw ArchiveIntegrityException.shaMismatch(
        expected: expectedSha256,
        actual: actual,
      );
    }
  }

  final tarBytes = BZip2Decoder().decodeBytes(compressed);

  // Free the compressed archive from disk before writing the payload.
  if (archiveFile.existsSync()) {
    archiveFile.deleteSync();
  }

  final archive = TarDecoder().decodeBytes(tarBytes);
  for (final entry in archive) {
    if (_isUnsafeArchivePath(entry.name)) {
      throw ArchiveIntegrityException.unsafePath(entry.name);
    }
    final outPath = '$destPath/${entry.name}';
    if (entry.isFile) {
      final out = OutputFileStream(outPath);
      try {
        entry.writeContent(out);
      } finally {
        out.closeSync();
      }
    } else {
      Directory(outPath).createSync(recursive: true);
    }
  }
}
