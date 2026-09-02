import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/core/tts/raven_model_manager.dart';

/// Host tests for the Raven per-voice cache invalidation helpers. These use a
/// real temp directory (no `path_provider`) so the file logic that guards
/// against reusing embeddings across model upgrades is verified directly.
void main() {
  late Directory voicesDir;
  late Directory cacheDir;

  const marker = '.model-manifest';

  setUp(() async {
    voicesDir = await Directory.systemTemp.createTemp('raven_voice_cache_test');
    cacheDir = Directory('${voicesDir.path}/.cache')..createSync();
  });

  tearDown(() async {
    if (voicesDir.existsSync()) await voicesDir.delete(recursive: true);
  });

  void seedArtifacts() {
    File('${cacheDir.path}/123.emb').writeAsStringSync('emb');
    File('${cacheDir.path}/123.kv').writeAsStringSync('kv');
  }

  File markerFile() => File('${cacheDir.path}/$marker');

  group('reconcileRavenVoiceCache', () {
    test('first run adopts the current model without purging', () async {
      seedArtifacts();

      await reconcileRavenVoiceCache(
        voicesDir: voicesDir,
        modelManifestSha: 'model-A',
      );

      expect(File('${cacheDir.path}/123.emb').existsSync(), isTrue);
      expect(File('${cacheDir.path}/123.kv').existsSync(), isTrue);
      expect(markerFile().readAsStringSync(), 'model-A');
    });

    test('same model is a no-op that preserves artifacts', () async {
      seedArtifacts();
      markerFile().writeAsStringSync('model-A');

      await reconcileRavenVoiceCache(
        voicesDir: voicesDir,
        modelManifestSha: 'model-A',
      );

      expect(File('${cacheDir.path}/123.emb').existsSync(), isTrue);
      expect(File('${cacheDir.path}/123.kv').existsSync(), isTrue);
    });

    test(
      'model change purges stale artifacts and updates the marker',
      () async {
        seedArtifacts();
        markerFile().writeAsStringSync('model-A');
        // A foreign file that is not an embedding must survive.
        File('${cacheDir.path}/keep.txt').writeAsStringSync('x');

        await reconcileRavenVoiceCache(
          voicesDir: voicesDir,
          modelManifestSha: 'model-B',
        );

        expect(File('${cacheDir.path}/123.emb').existsSync(), isFalse);
        expect(File('${cacheDir.path}/123.kv').existsSync(), isFalse);
        expect(File('${cacheDir.path}/keep.txt').existsSync(), isTrue);
        expect(markerFile().readAsStringSync(), 'model-B');
      },
    );

    test('creates the cache dir and marker when none exists yet', () async {
      await cacheDir.delete(recursive: true);

      await reconcileRavenVoiceCache(
        voicesDir: voicesDir,
        modelManifestSha: 'model-A',
      );

      expect(cacheDir.existsSync(), isTrue);
      expect(markerFile().readAsStringSync(), 'model-A');
    });
  });

  group('purgeRavenVoiceCache', () {
    test('removes all .emb/.kv and the marker', () async {
      seedArtifacts();
      markerFile().writeAsStringSync('model-A');

      await purgeRavenVoiceCache(voicesDir);

      expect(File('${cacheDir.path}/123.emb').existsSync(), isFalse);
      expect(File('${cacheDir.path}/123.kv').existsSync(), isFalse);
      expect(markerFile().existsSync(), isFalse);
    });

    test('is a no-op when the cache directory is absent', () async {
      await cacheDir.delete(recursive: true);

      await purgeRavenVoiceCache(voicesDir);

      expect(cacheDir.existsSync(), isFalse);
    });
  });
}
