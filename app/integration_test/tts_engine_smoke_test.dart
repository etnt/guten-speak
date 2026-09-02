import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/benchmark/benchmark_corpus.dart';
import 'package:guten_speak/benchmark/tts_benchmark_runner.dart';
import 'package:guten_speak/core/tts/model_manager.dart';
import 'package:guten_speak/core/tts/sherpa_tts_engine.dart';
import 'package:guten_speak/features/voices/data/datasources/voice_library_data_source.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// On-device smoke/benchmark test for the sherpa baseline engine and the
/// benchmark harness. It is NOT a host `flutter test`: it provisions the model
/// and synthesizes real audio, so run it on a device with either
/// `flutter test integration_test/tts_engine_smoke_test.dart -d <device>` (debug,
/// diagnostic only) or `flutter drive --driver=test_driver/integration_test.dart
/// --target=integration_test/tts_engine_smoke_test.dart --profile -d <device>`
/// (profile, authoritative). See tools/run_android_tts_benchmark.sh.
///
/// It replays the small (~100-word) engine-independent corpus bundled at
/// assets/benchmark/tts_benchmark_corpus_small.json so the sherpa baseline and
/// every Raven candidate are measured on identical real-book-text inputs.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('sherpa baseline synthesizes the smoke corpus and writes a report',
      () async {
    final library = VoiceLibrary();
    // Real on-device synthesis (plus cold model/engine init) easily exceeds the
    // default 30s package:test timeout, so disable it for this device run.
    await library.load();
    final voice = library.voices.first;

    final paths = await ModelManager().ensureModel(
      onStatus: (m) => debugMarker('MODEL $m'),
    );

    final engine = SherpaTtsEngine(paths: paths);
    addTearDown(engine.dispose);

    final corpusJson = await rootBundle.loadString(
      'assets/benchmark/tts_benchmark_corpus_small.json',
    );
    final corpus = BenchmarkCorpus.fromJson(
      jsonDecode(corpusJson) as Map<String, Object?>,
    );
    debugMarker('CORPUS ${corpus.units.length} units');

    final outDir = await getTemporaryDirectory();
    final report = await const TtsBenchmarkRunner().run(
      engine: engine,
      corpus: corpus,
      voiceId: voice.id,
      referenceWavPath: voice.wavPath,
      outputDir: outDir.path,
      onProgress: (done, total) => debugMarker('UNIT $done/$total'),
    );

    expect(report.aggregate.okUnits, corpus.units.length);
    expect(report.aggregate.failedUnits, 0);
    expect(report.aggregate.totalAudioSeconds, greaterThan(0));

    final docs = await getApplicationDocumentsDirectory();
    final reportDir = Directory('${docs.path}/benchmark');
    await reportDir.create(recursive: true);
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final file = File('${reportDir.path}/sherpa-smoke-$stamp.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(report.toJson()),
    );
    debugMarker('REPORT ${file.path}');
    // Also stream the report to the host log: `flutter test`/`flutter drive`
    // uninstall the app (wiping app storage) once the run finishes, so the
    // on-device file is gone before it can be pulled, and profile builds are
    // not debuggable so `run-as` cannot read it either. `flutter drive` reads
    // the log via logcat, which truncates a single print at ~1 KB, so the JSON
    // is base64-encoded and emitted in small chunks the harness reassembles.
    final reportB64 = base64Encode(utf8.encode(jsonEncode(report.toJson())));
    const chunkSize = 720;
    debugMarker('REPORT_B64_BEGIN ${reportB64.length}');
    for (var i = 0; i < reportB64.length; i += chunkSize) {
      final end =
          i + chunkSize < reportB64.length ? i + chunkSize : reportB64.length;
      debugMarker('REPORT_B64 ${reportB64.substring(i, end)}');
    }
    debugMarker('REPORT_B64_END');
  }, timeout: Timeout.none);
}

/// Emits a stable, greppable marker to logcat for the harness script to parse.
void debugMarker(String message) {
  // ignore: avoid_print
  print('GS_BENCH $message');
}
