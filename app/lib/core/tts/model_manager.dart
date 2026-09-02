import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'archive_download.dart';

export 'archive_download.dart' show ModelDownloadCancelled;

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

/// Downloads and unpacks the sherpa-onnx PocketTTS (fp32) model on first use,
/// then hands back the paths needed to construct an `OfflineTts`.
///
/// Ported from the Guten-Speak PoC. The ~470 MB archive is downloaded once (with
/// resume support), decompressed in a short-lived isolate, and the archive is
/// deleted before the payload is written so a nearly-full device never holds
/// both at once.
class ModelManager {
  static const String _modelName = 'sherpa-onnx-pocket-tts-2026-01-26';

  /// Candidate download locations, tried in order until one succeeds.
  ///
  /// The first entry is our own mirror (resilient to the upstream release being
  /// removed). While the `etnt/guten-speak` repo is private its release assets
  /// require authentication, so unauthenticated fetches fail and we
  /// transparently fall back to the upstream `k2-fsa/sherpa-onnx` release. Once
  /// the repo is made public the mirror will start working on its own.
  static const List<String> _archiveUrls = <String>[
    'https://github.com/etnt/guten-speak/releases/download/tts-models/$_modelName.tar.bz2',
    'https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/$_modelName.tar.bz2',
  ];

  /// Whether the model is already installed on disk (no download needed).
  Future<bool> isInstalled() async {
    final paths = _pathsFor((await _modelDir()).path);
    return File(paths.encoder).existsSync() && File(paths.lmMain).existsSync();
  }

  /// Returns the resolved model paths (whether or not the model is installed).
  Future<PocketModelPaths> paths() async => _pathsFor((await _modelDir()).path);

  /// Total bytes the model occupies on disk (the extracted payload plus any
  /// leftover partial download archive). Zero when nothing is installed.
  Future<int> onDiskBytes() async {
    final root = await _modelsRoot();
    if (!root.existsSync()) return 0;
    var total = 0;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  /// Deletes the installed model (and any partial download) from disk. The next
  /// narration opt-in re-downloads it. Safe to call when nothing is installed.
  Future<void> deleteFromDisk() async {
    final root = await _modelsRoot();
    if (root.existsSync()) {
      await root.delete(recursive: true);
    }
  }

  /// Returns the model paths, downloading + extracting the archive if missing.
  ///
  /// [onStatus] receives human-readable progress messages. [onProgress]
  /// receives a 0..1 download fraction (or null when the size is unknown).
  /// [isCancelled], when supplied, is polled between chunks; returning true
  /// aborts the download with a [ModelDownloadCancelled] exception (the partial
  /// download is kept on disk so a later call resumes it).
  Future<PocketModelPaths> ensureModel({
    void Function(String message)? onStatus,
    void Function(double? fraction)? onProgress,
    bool Function()? isCancelled,
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
    onStatus?.call('Downloading model (this happens only once)…');
    await downloadArchiveWithFallback(
      _archiveUrls,
      archiveFile,
      onStatus: onStatus,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );

    onStatus?.call('Extracting model…');
    onProgress?.call(null);
    await extractTarBz2(archiveFile, modelsRoot);

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

  Future<Directory> _modelDir() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/models/$_modelName');
  }

  Future<Directory> _modelsRoot() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/models');
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
}
