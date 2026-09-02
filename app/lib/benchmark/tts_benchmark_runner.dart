import '../core/tts/tts_engine.dart';
import '../core/tts/tts_synthesis_request.dart';
import '../core/tts/tts_synthesis_result.dart';
import 'benchmark_corpus.dart';
import 'benchmark_report.dart';

/// Replays an engine-independent [BenchmarkCorpus] against one [TtsEngine] and
/// produces a versioned [BenchmarkReport].
///
/// The same runner drives the sherpa baseline and every Raven candidate so the
/// numbers are directly comparable (plan §11). It is engine-agnostic: it only
/// depends on the [TtsEngine] contract, never on a concrete backend.
class TtsBenchmarkRunner {
  const TtsBenchmarkRunner();

  /// Runs [corpus] in [voiceId] (reference WAV [referenceWavPath]), writing one
  /// clip per unit under [outputDir].
  ///
  /// When [initializeEngine] is true the runner also times the cold
  /// [TtsEngine.initialize] call. It always runs one warm-up synthesis (the
  /// first unit) whose timing is reported separately and excluded from the
  /// steady-state unit results.
  Future<BenchmarkReport> run({
    required TtsEngine engine,
    required BenchmarkCorpus corpus,
    required String voiceId,
    required String referenceWavPath,
    required String outputDir,
    void Function(int done, int total)? onProgress,
    bool initializeEngine = true,
  }) async {
    if (corpus.units.isEmpty) {
      throw ArgumentError.value(corpus, 'corpus', 'must not be empty');
    }

    var coldLoadMillis = 0;
    if (initializeEngine && !engine.isReady) {
      final cold = Stopwatch()..start();
      await engine.initialize();
      cold.stop();
      coldLoadMillis = cold.elapsedMilliseconds;
    }

    // Warm-up: the first synthesis pays one-time JIT/allocation/KV costs that
    // would otherwise skew the first steady-state unit.
    final warm = Stopwatch()..start();
    await _synthesizeOne(
      engine: engine,
      unit: corpus.units.first,
      voiceId: voiceId,
      referenceWavPath: referenceWavPath,
      outputDir: outputDir,
      suffix: 'warmup',
    );
    warm.stop();

    final results = <BenchmarkUnitResult>[];
    for (var i = 0; i < corpus.units.length; i++) {
      final unit = corpus.units[i];
      results.add(
        await _recordOne(
          engine: engine,
          unit: unit,
          voiceId: voiceId,
          referenceWavPath: referenceWavPath,
          outputDir: outputDir,
        ),
      );
      onProgress?.call(i + 1, corpus.units.length);
    }

    return BenchmarkReport(
      engineId: engine.engineId,
      profileId: engine.synthesisProfile.id,
      profile: engine.synthesisProfile.toCanonicalMap(),
      corpusVersion: corpus.version,
      generatedAtIso: DateTime.now().toUtc().toIso8601String(),
      coldLoadMillis: coldLoadMillis,
      warmupMillis: warm.elapsedMilliseconds,
      unitResults: results,
    );
  }

  Future<BenchmarkUnitResult> _recordOne({
    required TtsEngine engine,
    required BenchmarkUnit unit,
    required String voiceId,
    required String referenceWavPath,
    required String outputDir,
  }) async {
    try {
      final result = await _synthesizeOne(
        engine: engine,
        unit: unit,
        voiceId: voiceId,
        referenceWavPath: referenceWavPath,
        outputDir: outputDir,
        suffix: null,
      );
      return BenchmarkUnitResult(
        unitId: unit.id,
        category: unit.category,
        charCount: unit.charCount,
        result: result,
      );
    } on TtsSynthesisException catch (e) {
      return BenchmarkUnitResult(
        unitId: unit.id,
        category: unit.category,
        charCount: unit.charCount,
        failure: '${e.category.name}: ${e.message}',
      );
    } catch (e) {
      return BenchmarkUnitResult(
        unitId: unit.id,
        category: unit.category,
        charCount: unit.charCount,
        failure: e.toString(),
      );
    }
  }

  Future<TtsSynthesisResult> _synthesizeOne({
    required TtsEngine engine,
    required BenchmarkUnit unit,
    required String voiceId,
    required String referenceWavPath,
    required String outputDir,
    required String? suffix,
  }) {
    final name = suffix == null ? unit.id : '${unit.id}.$suffix';
    return engine.synthesize(
      TtsSynthesisRequest(
        requestId: name,
        text: unit.text,
        voiceId: voiceId,
        referenceWavPath: referenceWavPath,
        outputWavPath: '$outputDir/$name.wav',
      ),
    );
  }
}
