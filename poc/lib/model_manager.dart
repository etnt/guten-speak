import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Resolved absolute paths to the files that make up the PocketTTS model.
class PocketModelPaths {
  const PocketModelPaths({
    required this.lmFlow,
    required this.lmMain,
    required this.encoder,
    required this.decoder,
    required this.textConditioner,
    required this.vocabJson,
    required this.tokenScoresJson,
  });

  final String lmFlow;
  final String lmMain;
  final String encoder;
  final String decoder;
  final String textConditioner;
  final String vocabJson;
  final String tokenScoresJson;
}

/// Downloads and unpacks the sherpa-onnx PocketTTS (int8) model on first use,
/// then hands back the paths needed to construct an `OfflineTts`.
class ModelManager {
  static const String _modelName = 'sherpa-onnx-pocket-tts-2026-01-26';

  /// Candidate download locations, tried in order until one succeeds.
  ///
  /// The first entry is our own mirror (resilient to the upstream release being
  /// removed). While the `etnt/guten-speak` repo is private its release assets
  /// require authentication, so unauthenticated fetches fail and we
  /// transparently fall back to the upstream `k2-fsa/sherpa-onnx` release. Once
  /// the repo is made public the mirror will start working on its own.
  static const List<String> _archiveUrls = [
    'https://github.com/etnt/guten-speak/releases/download/tts-models/$_modelName.tar.bz2',
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/$_modelName.tar.bz2',
  ];

  /// Returns the model paths, downloading + extracting the archive if missing.
  ///
  /// [onStatus] receives human-readable progress messages. [onProgress]
  /// receives a 0..1 download fraction (or null when the size is unknown).
  Future<PocketModelPaths> ensureModel({
    void Function(String message)? onStatus,
    void Function(double? fraction)? onProgress,
  }) async {
    final support = await getApplicationSupportDirectory();
    final modelsRoot = Directory('${support.path}/models');
    final modelDir = Directory('${modelsRoot.path}/$_modelName');

    final paths = _pathsFor(modelDir.path);

    if (File(paths.encoder).existsSync() && File(paths.lmMain).existsSync()) {
      onStatus?.call('Model already installed.');
      return paths;
    }

    await modelsRoot.create(recursive: true);

    final archiveFile = File('${modelsRoot.path}/$_modelName.tar.bz2');
    onStatus?.call('Downloading model (~ this happens only once)…');
    await _downloadWithFallback(
      _archiveUrls,
      archiveFile,
      onStatus: onStatus,
      onProgress: onProgress,
    );

    onStatus?.call('Extracting model…');
    onProgress?.call(null);
    await _extractTarBz2(archiveFile, modelsRoot);

    // Clean up the archive to save space.
    if (archiveFile.existsSync()) {
      await archiveFile.delete();
    }

    if (!File(paths.encoder).existsSync()) {
      throw Exception(
        'Extraction finished but expected file is missing: ${paths.encoder}',
      );
    }

    onStatus?.call('Model ready.');
    return paths;
  }

  /// Decompresses a `.tar.bz2` archive and extracts it into [destDir].
  ///
  /// The actual work runs in a short-lived isolate via [Isolate.run] because
  /// bz2 decompression of the ~470 MB payload is CPU-bound and synchronous;
  /// running it on the UI isolate froze the app and triggered Android's ANR
  /// ("application doesn't respond") dialog.
  Future<void> _extractTarBz2(File archiveFile, Directory destDir) async {
    final archivePath = archiveFile.path;
    final destPath = destDir.path;
    await Isolate.run(() => _extractTarBz2Sync(archivePath, destPath));
  }

  PocketModelPaths _pathsFor(String dir) => PocketModelPaths(
    lmFlow: '$dir/lm_flow.onnx',
    lmMain: '$dir/lm_main.onnx',
    encoder: '$dir/encoder.onnx',
    decoder: '$dir/decoder.onnx',
    textConditioner: '$dir/text_conditioner.onnx',
    vocabJson: '$dir/vocab.json',
    tokenScoresJson: '$dir/token_scores.json',
  );

  /// Tries each URL in [urls] in order, returning after the first successful
  /// download. If every source fails, rethrows the last error so the caller can
  /// surface it.
  Future<void> _downloadWithFallback(
    List<String> urls,
    File target, {
    void Function(String message)? onStatus,
    void Function(double? fraction)? onProgress,
  }) async {
    Object? lastError;
    for (var i = 0; i < urls.length; i++) {
      try {
        await _download(urls[i], target, onProgress: onProgress);
        return;
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

  Future<void> _download(
    String url,
    File target, {
    void Function(double? fraction)? onProgress,
  }) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception(
          'Download failed: HTTP ${response.statusCode} for $url',
        );
      }

      final total = response.contentLength;
      var received = 0;
      final sink = target.openWrite();
      try {
        await for (final chunk in response.stream) {
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
  }
}

/// Decompresses [archivePath] (`.tar.bz2`) and extracts it into [destPath].
///
/// Runs inside an isolate (see [ModelManager._extractTarBz2]). To keep peak
/// **disk** usage low on nearly-full devices, the bz2 is decompressed into
/// memory and the compressed archive is deleted before any files are written,
/// so the disk only ever holds the final extracted payload (never the archive
/// and an intermediate `.tar` at the same time). The uncompressed bytes live in
/// RAM briefly, which modern phones handle comfortably.
///
/// `extractFileToDisk` is deliberately avoided: it relies on the platform temp
/// directory (Android's `code_cache`) and was observed to fail there with a
/// missing-temp-file error.
void _extractTarBz2Sync(String archivePath, String destPath) {
  final archiveFile = File(archivePath);

  // bz2 -> tar bytes in memory.
  final compressed = archiveFile.readAsBytesSync();
  final tarBytes = BZip2Decoder().decodeBytes(compressed);

  // Free the compressed archive from disk before writing the payload.
  if (archiveFile.existsSync()) {
    archiveFile.deleteSync();
  }

  final archive = TarDecoder().decodeBytes(tarBytes);
  for (final entry in archive) {
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
