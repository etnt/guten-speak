import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'archive_download.dart';
import 'raven_tts_engine.dart';

export 'archive_download.dart' show ModelDownloadCancelled;

/// Downloads and unpacks the Pocket TTS Raven (int8) model on first use, then
/// hands back the [RavenModelPaths] needed to construct a [RavenTtsEngine].
///
/// Mirrors the sherpa `ModelManager` (resume-capable download + isolate
/// bz2 extraction), but the archive is served **exclusively** from the
/// `guten-speak` release area so a vanished upstream can never break installs.
///
/// The reference voice `.wav` clips are **not** part of this archive: they ship
/// as bundled app assets and are materialized to `<appSupport>/voices/` by
/// `VoiceLibrary`, which is also the writable [RavenModelPaths.voicesDir] the
/// engine caches its `.cache/<voice>.emb` embeddings into.
class RavenModelManager {
  static const String _modelName = 'raven-int8-2026-01';

  /// SHA/identity of the installed Raven model manifest, used as the engine's
  /// cache identity ([RavenTtsEngine.modelManifestSha]). Bump this whenever the
  /// hosted archive changes so stale cached audio is not reused.
  static const String modelManifestSha = 'raven-int8-4step-2026-01';

  /// SHA-256 of the hosted `.tar.bz2` archive, verified before extraction so a
  /// corrupt or tampered download can never be installed. Bump this together
  /// with [modelManifestSha] whenever the hosted archive is re-packaged.
  static const String _archiveSha256 =
      'd42c1e050a4f08a7131df6470fff6e31ce38026dcdac29e0e507a3ce9270aa78';

  /// Single download location: the guten-speak release area only. There is
  /// deliberately no third-party fallback — if the upstream Raven repo
  /// disappears, installs must still work from our own mirror.
  static const List<String> _archiveUrls = <String>[
    'https://github.com/etnt/guten-speak/releases/download/tts-models/$_modelName.tar.bz2',
  ];

  /// Sentinel files that indicate a complete extraction.
  static const String _mainGraph = 'flow_lm_main_int8.onnx';
  static const String _tokenizer = 'tokenizer.model';

  /// Whether the model is already installed on disk (no download needed).
  Future<bool> isInstalled() async {
    final modelDir = (await _modelDir()).path;
    return File('$modelDir/$_mainGraph').existsSync() &&
        File('$modelDir/$_tokenizer').existsSync();
  }

  /// Returns the resolved model paths (whether or not the model is installed).
  Future<RavenModelPaths> paths() async => _pathsFor(
    (await _modelDir()).path,
    (await _voicesDir()).path,
  );

  /// Total bytes the Raven model occupies on disk (the extracted payload plus
  /// any leftover partial download archive). Zero when nothing is installed.
  ///
  /// Voice clips are intentionally excluded — they are accounted for by the
  /// voices storage section, not the model.
  Future<int> onDiskBytes() async {
    final dir = await _modelDir();
    if (!dir.existsSync()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    // Include any leftover partial archive sitting in the models root.
    final part = File('${(await _modelsRoot()).path}/$_modelName.tar.bz2.part');
    if (part.existsSync()) {
      total += await part.length();
    }
    return total;
  }

  /// Deletes the installed Raven model (and any partial download) from disk. The
  /// next narration opt-in re-downloads it. Safe to call when nothing is
  /// installed. Voice clips are left untouched.
  Future<void> deleteFromDisk() async {
    final dir = await _modelDir();
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
    final staging = await _stagingDir();
    if (staging.existsSync()) {
      await staging.delete(recursive: true);
    }
    final part = File('${(await _modelsRoot()).path}/$_modelName.tar.bz2.part');
    if (part.existsSync()) {
      await part.delete();
    }
  }

  /// Returns the model paths, downloading + extracting the archive if missing.
  ///
  /// [onStatus] receives human-readable progress messages. [onProgress]
  /// receives a 0..1 download fraction (or null when the size is unknown).
  /// [isCancelled], when supplied, is polled between chunks; returning true
  /// aborts the download with a [ModelDownloadCancelled] exception (the partial
  /// download is kept on disk so a later call resumes it).
  Future<RavenModelPaths> ensureModel({
    void Function(String message)? onStatus,
    void Function(double? fraction)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final modelsRoot = await _modelsRoot();
    final modelDir = Directory('${modelsRoot.path}/$_modelName');
    final voicesDir = await _voicesDir();

    final paths = _pathsFor(modelDir.path, voicesDir.path);

    if (File('${modelDir.path}/$_mainGraph').existsSync() &&
        File('${modelDir.path}/$_tokenizer').existsSync()) {
      onStatus?.call('Model already installed.');
      return paths;
    }

    await modelsRoot.create(recursive: true);

    // Extract into a sibling staging directory and promote it with a single
    // atomic rename, so a half-extracted payload can never look "installed".
    final stagingDir = await _stagingDir();
    if (stagingDir.existsSync()) {
      await stagingDir.delete(recursive: true);
    }

    final archiveFile = File('${modelsRoot.path}/$_modelName.tar.bz2');
    try {
      await stagingDir.create(recursive: true);

      onStatus?.call('Downloading voice model (this happens only once)…');
      await downloadArchiveWithFallback(
        _archiveUrls,
        archiveFile,
        onStatus: onStatus,
        onProgress: onProgress,
        isCancelled: isCancelled,
      );

      onStatus?.call('Extracting voice model…');
      onProgress?.call(null);
      // Verifies the pinned SHA-256 and rejects path-traversal entries before
      // writing anything; deletes the archive on a SHA mismatch.
      await extractTarBz2(
        archiveFile,
        stagingDir,
        expectedSha256: _archiveSha256,
      );

      // Clean up the archive to save space.
      if (archiveFile.existsSync()) {
        await archiveFile.delete();
      }

      // The archive holds a top-level `$_modelName/` directory; the extracted
      // payload therefore lives at `<staging>/$_modelName/`.
      final stagedModel = Directory('${stagingDir.path}/$_modelName');
      if (!File('${stagedModel.path}/$_mainGraph').existsSync() ||
          !File('${stagedModel.path}/$_tokenizer').existsSync()) {
        throw Exception(
          'Extraction finished but expected files are missing under '
          '${stagedModel.path}',
        );
      }

      // Atomic promote: replace any partial/old install with the staged one.
      if (modelDir.existsSync()) {
        await modelDir.delete(recursive: true);
      }
      await stagedModel.rename(modelDir.path);
    } finally {
      if (stagingDir.existsSync()) {
        await stagingDir.delete(recursive: true);
      }
    }

    onStatus?.call('Voice model ready.');
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

  /// Temporary directory used to stage an extraction before it is atomically
  /// promoted to [_modelDir]. Lives under the models root so the promote is a
  /// same-filesystem rename.
  Future<Directory> _stagingDir() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/models/.staging-$_modelName');
  }

  Future<Directory> _voicesDir() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}/voices');
  }

  RavenModelPaths _pathsFor(String modelDir, String voicesDir) =>
      RavenModelPaths(
        modelsDir: modelDir,
        voicesDir: voicesDir,
        tokenizerPath: '$modelDir/$_tokenizer',
      );
}
