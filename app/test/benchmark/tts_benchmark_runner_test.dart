import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/benchmark/benchmark_corpus.dart';
import 'package:guten_speak/benchmark/benchmark_report.dart';
import 'package:guten_speak/benchmark/tts_benchmark_runner.dart';
import 'package:guten_speak/core/tts/synthesis_profile.dart';
import 'package:guten_speak/core/tts/tts_engine.dart';
import 'package:guten_speak/core/tts/tts_synthesis_request.dart';
import 'package:guten_speak/core/tts/tts_synthesis_result.dart';

/// A deterministic in-memory engine so the runner and report schema are
/// testable on the host without the native model. Audio duration scales with
/// text length; native/pipeline timings are fixed multiples so RTFs are known.
class _FakeEngine implements TtsEngine {
  _FakeEngine({this.failUnitId});

  final String? failUnitId;
  bool _ready = false;
  int initializeCalls = 0;

  @override
  String get engineId => 'fake';

  @override
  bool get isReady => _ready;

  @override
  SynthesisProfile get synthesisProfile => const SynthesisProfile(
    engineId: 'fake',
    engineRevision: '0.0.1',
    onnxRuntimeVersion: '0.0.0',
    modelManifestSha: 'fake-model',
    precision: 'fp32',
    solverSteps: 1,
    temperatureMilli: 700,
    seed: 1234,
    maxFrames: 160,
    sampleRate: 24000,
    voiceContentSha: '',
    textPolicyVersion: 1,
    audioPolicyVersion: 1,
  );

  @override
  Future<void> initialize() async {
    initializeCalls++;
    _ready = true;
  }

  @override
  Future<TtsSynthesisResult> synthesize(TtsSynthesisRequest request) async {
    // requestId may carry a `.warmup` suffix; match on the leading unit id.
    final baseId = request.requestId.split('.').first;
    if (failUnitId != null && baseId == failUnitId) {
      throw const TtsSynthesisException(
        TtsFailureCategory.nativeStreamFailed,
        'injected failure',
      );
    }
    final audioSeconds = request.text.length / 10.0;
    final sampleCount = (audioSeconds * 24000).round();
    final nativeMillis = (audioSeconds * 500).round(); // 0.5x native RTF
    final completeMillis = nativeMillis + 100; // add pipeline overhead
    return TtsSynthesisResult(
      engineId: engineId,
      profileId: synthesisProfile.id,
      sampleCount: sampleCount,
      sampleRate: 24000,
      nativeGenerateMillis: nativeMillis,
      postProcessMillis: 40,
      wavWriteMillis: 20,
      requestToCompleteMillis: completeMillis,
    );
  }

  @override
  Future<void> cancelCurrentSynthesis() async {}

  @override
  Future<void> dispose() async {
    _ready = false;
  }
}

BenchmarkCorpus _loadFixtureCorpus() {
  final file = File('test/fixtures/tts_benchmark_corpus.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  return BenchmarkCorpus.fromJson(json);
}

void main() {
  group('TtsBenchmarkRunner', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('tts_bench_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('fixture corpus parses into typed units', () {
      final corpus = _loadFixtureCorpus();
      expect(corpus.version, 1);
      expect(corpus.units, isNotEmpty);
      expect(
        corpus.units.map((u) => u.category).toSet(),
        containsAll(<String>['short', 'dialogue', 'numbers', 'smart_quotes']),
      );
    });

    test('records one result per corpus unit and times cold load', () async {
      final corpus = _loadFixtureCorpus();
      final engine = _FakeEngine();

      final report = await const TtsBenchmarkRunner().run(
        engine: engine,
        corpus: corpus,
        voiceId: 'reginald-ashworth',
        referenceWavPath: '/voices/reginald.wav',
        outputDir: tempDir.path,
      );

      expect(engine.initializeCalls, 1);
      expect(report.engineId, 'fake');
      expect(report.profileId, engine.synthesisProfile.id);
      expect(report.corpusVersion, 1);
      // Warm-up is separate and excluded from the recorded units.
      expect(report.unitResults.length, corpus.units.length);
      expect(report.aggregate.okUnits, corpus.units.length);
      expect(report.aggregate.failedUnits, 0);
    });

    test('aggregate RTFs match the fake engine model', () async {
      final corpus = _loadFixtureCorpus();
      final report = await const TtsBenchmarkRunner().run(
        engine: _FakeEngine(),
        corpus: corpus,
        voiceId: 'v',
        referenceWavPath: '/v.wav',
        outputDir: tempDir.path,
      );

      // The fake engine synthesizes at a fixed 0.5x native RTF.
      expect(report.aggregate.durationWeightedNativeRtf, closeTo(0.5, 1e-6));
      // Pipeline adds fixed overhead, so it is never faster than native.
      expect(
        report.aggregate.durationWeightedPipelineRtf,
        greaterThanOrEqualTo(report.aggregate.durationWeightedNativeRtf),
      );
      expect(report.aggregate.nativeRtf.median, greaterThan(0));
      expect(report.aggregate.completeMillis.max, greaterThan(0));
    });

    test('captures a failing unit without aborting the run', () async {
      final corpus = _loadFixtureCorpus();
      final failId = corpus.units[2].id;
      final report = await const TtsBenchmarkRunner().run(
        engine: _FakeEngine(failUnitId: failId),
        corpus: corpus,
        voiceId: 'v',
        referenceWavPath: '/v.wav',
        outputDir: tempDir.path,
      );

      expect(report.aggregate.failedUnits, 1);
      expect(report.aggregate.okUnits, corpus.units.length - 1);
      final failed = report.unitResults.firstWhere((r) => !r.ok);
      expect(failed.unitId, failId);
      expect(failed.failure, contains('nativeStreamFailed'));
    });

    test('report serializes to a stable, versioned JSON shape', () async {
      final corpus = _loadFixtureCorpus();
      final report = await const TtsBenchmarkRunner().run(
        engine: _FakeEngine(),
        corpus: corpus,
        voiceId: 'v',
        referenceWavPath: '/v.wav',
        outputDir: tempDir.path,
      );

      final json = report.toJson();
      expect(json['schemaVersion'], BenchmarkReport.schemaVersion);
      expect(json['engineId'], 'fake');
      expect(json['profile'], isA<Map<String, Object?>>());
      expect(json['aggregate'], isA<Map<String, Object?>>());
      expect((json['units']! as List).length, corpus.units.length);
      // Must be round-trippable through dart:convert.
      expect(() => jsonEncode(json), returnsNormally);
    });

    test('empty corpus is rejected', () async {
      await expectLater(
        () => const TtsBenchmarkRunner().run(
          engine: _FakeEngine(),
          corpus: const BenchmarkCorpus(version: 1, units: []),
          voiceId: 'v',
          referenceWavPath: '/v.wav',
          outputDir: tempDir.path,
        ),
        throwsArgumentError,
      );
    });
  });
}
