import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/core/tts/raven_model_manager.dart';
import 'package:guten_speak/core/tts/raven_tts_engine.dart';
import 'package:guten_speak/core/tts/tts_synthesis_request.dart';
import 'package:guten_speak/core/tts/wav_io.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// On-device end-to-end test for the REAL in-app Raven download path.
///
/// Unlike `raven_engine_smoke_test.dart` (which assumes the bundle was pushed
/// via `tools/push_raven_model.sh`), this drives [RavenModelManager.ensureModel]
/// so it actually downloads `raven-int8-2026-01.tar.bz2` from the guten-speak
/// release, extracts it, then loads the engine and synthesizes a clip — exactly
/// what the app does the first time a user opts into narration with Raven (the
/// default engine). Run on a device with network:
///
///   flutter test integration_test/raven_download_smoke_test.dart -d <device>
///
/// The voice is not part of the archive; it ships as a Flutter asset, so this
/// test materializes it into the voices dir the way `VoiceLibrary` does.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test(
    'downloads the Raven model from the release and synthesizes on-device',
    () async {
      final manager = RavenModelManager();

      // Start from a clean slate so we exercise the real download, not a leftover.
      await manager.deleteFromDisk();
      expect(await manager.isInstalled(), isFalse);

      final dl = Stopwatch()..start();
      var lastLoggedPct = -1;
      final paths = await manager.ensureModel(
        onStatus: (m) => _mark('STATUS $m'),
        onProgress: (fraction) {
          if (fraction == null) return;
          final pct = (fraction * 100).floor();
          if (pct >= lastLoggedPct + 10) {
            lastLoggedPct = pct;
            _mark('DL $pct%');
          }
        },
      );
      dl.stop();
      _mark('DOWNLOAD_EXTRACT_MS ${dl.elapsedMilliseconds}');

      // The manager reports installed and the sentinel files are on disk.
      expect(await manager.isInstalled(), isTrue);
      for (final path in <String>[
        p.join(paths.modelsDir, 'flow_lm_main_int8.onnx'),
        p.join(paths.modelsDir, 'flow_lm_flow_int8.onnx'),
        p.join(paths.modelsDir, 'mimi_decoder_delta_int8.onnx'),
        p.join(paths.modelsDir, 'mimi_encoder.onnx'),
        p.join(paths.modelsDir, 'text_conditioner.onnx'),
        p.join(paths.modelsDir, 'bos_before_voice.npy'),
        paths.tokenizerPath,
      ]) {
        expect(File(path).existsSync(), isTrue, reason: 'missing $path');
      }
      _mark('ON_DISK_BYTES ${await manager.onDiskBytes()}');

      // Materialize the built-in voice like VoiceLibrary does (assets are not in
      // the model archive).
      await Directory(paths.voicesDir).create(recursive: true);
      final voicePath = p.join(paths.voicesDir, 'reginald-ashworth.wav');
      final voiceData = await rootBundle.load(
        'assets/voices/reginald-ashworth.wav',
      );
      await File(voicePath).writeAsBytes(
        voiceData.buffer.asUint8List(
          voiceData.offsetInBytes,
          voiceData.lengthInBytes,
        ),
        flush: true,
      );

      final engine = RavenTtsEngine(
        paths: paths,
        modelManifestSha: RavenModelManager.modelManifestSha,
      );
      addTearDown(engine.dispose);

      await engine.initialize();
      expect(engine.isReady, isTrue);

      final outDir = await getTemporaryDirectory();
      final outPath = p.join(outDir.path, 'raven-download-smoke.wav');
      final result = await engine.synthesize(
        TtsSynthesisRequest(
          requestId: 'raven-download-smoke',
          text: 'The north wind blew cold across the frozen lake.',
          voiceId: 'reginald-ashworth',
          referenceWavPath: voicePath,
          outputWavPath: outPath,
        ),
      );

      expect(result.sampleRate, 24000);
      expect(result.sampleCount, greaterThan(0));
      expect(result.audioSeconds, greaterThan(0.5));

      final wav = readWavAsFloat32(outPath);
      expect(wav.sampleRate, 24000);
      var peak = 0.0;
      for (final s in wav.samples) {
        final a = s.abs();
        if (a > peak) peak = a;
      }
      _mark('PEAK ${peak.toStringAsFixed(4)}');
      expect(peak, greaterThan(0.01), reason: 'output is essentially silent');
    },
    timeout: Timeout.none,
  );
}

/// Emits a greppable marker to logcat.
void _mark(String message) {
  debugPrint('GS_RAVEN $message');
}
