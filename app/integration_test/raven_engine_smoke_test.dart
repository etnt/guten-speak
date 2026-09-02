import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/core/tts/raven_tts_engine.dart';
import 'package:guten_speak/core/tts/tts_synthesis_request.dart';
import 'package:guten_speak/core/tts/tts_synthesis_result.dart';
import 'package:guten_speak/core/tts/wav_io.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// On-device smoke test for the Pocket TTS Raven FFI engine. It is NOT a host
/// `flutter test`: it loads the real int8 models and streams real audio through
/// the native runtime, so it must run on a device. Run it in PROFILE mode via
/// `flutter drive` — a debug build inflates the measured RTF ~40x (Dart JIT +
/// isolate stream-poll overhead), and plain `flutter test --profile` is
/// rejected on this toolchain, so its numbers are diagnostic only:
///
///   1. `flutter install --debug -d <device>` (debug APK so run-as works)
///   2. `bash tools/push_raven_model.sh <device>` (stages the int8 bundle+voice)
///   3. flutter drive --driver=test_driver/integration_test.dart \
///        --target=integration_test/raven_engine_smoke_test.dart \
///        --profile -d `<device>`
///
/// It exercises the full path the app will use: `RavenTtsEngine.initialize()`
/// (ptt_create + model load), then two `synthesize()` calls (stream read loop,
/// terminal-error check, trim/fade, atomic WAV write). Synth #1 is cold (pays
/// the one-time voice-embedding encode); synth #2 reuses the `.cache/<voice>.emb`
/// and reports steady-state RTF. It validates the clip is non-empty, plausible,
/// and a readable RIFF/WAVE file.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test(
    'raven int8 4-step engine synthesizes a short phrase on-device',
    () async {
      final support = await getApplicationSupportDirectory();
      final modelsDir = p.join(support.path, 'models', 'raven-int8-2026-01');
      final voicesDir = p.join(support.path, 'voices');
      final tokenizerPath = p.join(modelsDir, 'tokenizer.model');
      final voicePath = p.join(voicesDir, 'reginald-ashworth.wav');

      // Fail early with an actionable message if the bundle wasn't pushed.
      for (final path in <String>[
        p.join(modelsDir, 'flow_lm_main_int8.onnx'),
        p.join(modelsDir, 'flow_lm_flow_int8.onnx'),
        p.join(modelsDir, 'mimi_decoder_delta_int8.onnx'),
        p.join(modelsDir, 'mimi_encoder.onnx'),
        p.join(modelsDir, 'text_conditioner.onnx'),
        p.join(modelsDir, 'bos_before_voice.npy'),
        tokenizerPath,
        voicePath,
      ]) {
        if (!File(path).existsSync()) {
          fail(
            'Missing Raven asset: $path\n'
            'Run: bash tools/push_raven_model.sh <device> before this test.',
          );
        }
      }

      final engine = RavenTtsEngine(
        paths: RavenModelPaths(
          modelsDir: modelsDir,
          voicesDir: voicesDir,
          tokenizerPath: tokenizerPath,
        ),
        modelManifestSha: 'raven-int8-4step-2026-01',
      );
      addTearDown(engine.dispose);

      final cold = Stopwatch()..start();
      await engine.initialize();
      cold.stop();
      _mark('COLD_INIT_MS ${cold.elapsedMilliseconds}');
      expect(engine.isReady, isTrue);

      final outDir = await getTemporaryDirectory();

      // Synthesize the same phrase twice in one session. Synth #1 is cold: it
      // pays the one-time voice-embedding encode (mimi_encoder + AR conditioning
      // pass) and writes the `.cache/<voice>.emb`. Synth #2 loads that cache, so
      // its timings reflect steady-state generation. Comparing the two isolates
      // the one-time voice-conditioning cost from the true per-utterance RTF and
      // tells us whether the ~18x first-run RTF is a cold-cache artifact.
      const phrase = 'The north wind blew cold across the frozen lake.';

      Future<TtsSynthesisResult> synth(int index) async {
        final outPath = p.join(outDir.path, 'raven-smoke-$index.wav');
        final r = await engine.synthesize(
          TtsSynthesisRequest(
            requestId: 'raven-smoke-$index',
            text: phrase,
            voiceId: 'reginald-ashworth',
            referenceWavPath: voicePath,
            outputWavPath: outPath,
          ),
        );
        _mark('RUN$index SAMPLES ${r.sampleCount}');
        _mark('RUN$index AUDIO_S ${r.audioSeconds.toStringAsFixed(3)}');
        _mark('RUN$index FIRST_CHUNK_MS ${r.requestToFirstChunkMillis}');
        _mark('RUN$index NATIVE_MS ${r.nativeGenerateMillis}');
        _mark('RUN$index COMPLETE_MS ${r.requestToCompleteMillis}');
        _mark(
          'RUN$index NATIVE_RTF ${r.nativeRealTimeFactor.toStringAsFixed(3)}',
        );
        _mark(
          'RUN$index PIPELINE_RTF '
          '${r.pipelineRealTimeFactor.toStringAsFixed(3)}',
        );
        return r;
      }

      final result = await synth(1);
      final warm = await synth(2);
      final coldFirst = result.requestToFirstChunkMillis;
      final warmFirst = warm.requestToFirstChunkMillis;
      if (coldFirst != null && warmFirst != null) {
        _mark('WARM_FIRST_CHUNK_DELTA_MS ${coldFirst - warmFirst}');
      }

      // Basic sanity: some audio, of a plausible duration for this short line.
      expect(result.sampleRate, 24000);
      expect(result.sampleCount, greaterThan(0));
      expect(result.audioSeconds, greaterThan(0.5));
      expect(result.audioSeconds, lessThan(12.0));

      // The published WAV must be a readable RIFF/WAVE and not pure silence.
      final wav = readWavAsFloat32(p.join(outDir.path, 'raven-smoke-1.wav'));
      expect(wav.sampleRate, 24000);
      expect(wav.samples.length, result.sampleCount);
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

/// Emits a greppable marker to logcat for the smoke test.
void _mark(String message) {
  // ignore: avoid_print
  debugPrint('GS_RAVEN $message');
}
