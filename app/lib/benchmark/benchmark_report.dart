import 'dart:math' as math;

import '../core/tts/tts_synthesis_result.dart';

/// The per-unit benchmark record: the corpus unit joined with its measured
/// synthesis result (or a failure).
class BenchmarkUnitResult {
  const BenchmarkUnitResult({
    required this.unitId,
    required this.category,
    required this.charCount,
    this.result,
    this.failure,
  });

  final String unitId;
  final String category;
  final int charCount;

  /// The measured result, or null if this unit failed.
  final TtsSynthesisResult? result;

  /// A short failure description, or null on success.
  final String? failure;

  bool get ok => result != null;

  Map<String, Object?> toJson() => <String, Object?>{
    'unitId': unitId,
    'category': category,
    'charCount': charCount,
    'ok': ok,
    if (failure != null) 'failure': failure,
    if (result != null) 'result': result!.toJson(),
  };
}

/// Aggregate statistics across all successful units.
///
/// Latency and RTF distributions are reported as median/p90/p95/max per plan
/// §11.3. Duration-weighted RTF divides total compute time by total audio
/// duration, so long units are not drowned out by many short ones.
class BenchmarkAggregate {
  const BenchmarkAggregate({
    required this.totalUnits,
    required this.okUnits,
    required this.failedUnits,
    required this.totalAudioSeconds,
    required this.nativeRtf,
    required this.pipelineRtf,
    required this.completeMillis,
    required this.durationWeightedNativeRtf,
    required this.durationWeightedPipelineRtf,
  });

  factory BenchmarkAggregate.fromResults(List<BenchmarkUnitResult> results) {
    final ok = results.where((r) => r.ok).toList(growable: false);
    final nativeRtfs = <double>[];
    final pipelineRtfs = <double>[];
    final completes = <double>[];
    var sumNativeMillis = 0.0;
    var sumPipelineMillis = 0.0;
    var sumAudioSeconds = 0.0;
    for (final r in ok) {
      final res = r.result!;
      nativeRtfs.add(res.nativeRealTimeFactor);
      pipelineRtfs.add(res.pipelineRealTimeFactor);
      completes.add(res.requestToCompleteMillis.toDouble());
      sumNativeMillis += res.nativeGenerateMillis;
      sumPipelineMillis += res.requestToCompleteMillis;
      sumAudioSeconds += res.audioSeconds;
    }
    return BenchmarkAggregate(
      totalUnits: results.length,
      okUnits: ok.length,
      failedUnits: results.length - ok.length,
      totalAudioSeconds: sumAudioSeconds,
      nativeRtf: Distribution.fromSamples(nativeRtfs),
      pipelineRtf: Distribution.fromSamples(pipelineRtfs),
      completeMillis: Distribution.fromSamples(completes),
      durationWeightedNativeRtf: sumAudioSeconds > 0
          ? (sumNativeMillis / 1000.0) / sumAudioSeconds
          : 0.0,
      durationWeightedPipelineRtf: sumAudioSeconds > 0
          ? (sumPipelineMillis / 1000.0) / sumAudioSeconds
          : 0.0,
    );
  }

  final int totalUnits;
  final int okUnits;
  final int failedUnits;
  final double totalAudioSeconds;
  final Distribution nativeRtf;
  final Distribution pipelineRtf;
  final Distribution completeMillis;
  final double durationWeightedNativeRtf;
  final double durationWeightedPipelineRtf;

  Map<String, Object?> toJson() => <String, Object?>{
    'totalUnits': totalUnits,
    'okUnits': okUnits,
    'failedUnits': failedUnits,
    'totalAudioSeconds': totalAudioSeconds,
    'nativeRtf': nativeRtf.toJson(),
    'pipelineRtf': pipelineRtf.toJson(),
    'completeMillis': completeMillis.toJson(),
    'durationWeightedNativeRtf': durationWeightedNativeRtf,
    'durationWeightedPipelineRtf': durationWeightedPipelineRtf,
  };
}

/// A median/p90/p95/max summary of one metric over the run.
class Distribution {
  const Distribution({
    required this.count,
    required this.median,
    required this.p90,
    required this.p95,
    required this.max,
  });

  factory Distribution.fromSamples(List<double> samples) {
    if (samples.isEmpty) {
      return const Distribution(
        count: 0,
        median: 0,
        p90: 0,
        p95: 0,
        max: 0,
      );
    }
    final sorted = [...samples]..sort();
    return Distribution(
      count: sorted.length,
      median: _percentile(sorted, 50),
      p90: _percentile(sorted, 90),
      p95: _percentile(sorted, 95),
      max: sorted.last,
    );
  }

  final int count;
  final double median;
  final double p90;
  final double p95;
  final double max;

  /// Nearest-rank percentile on an already-sorted, non-empty list.
  static double _percentile(List<double> sorted, int percentile) {
    final rank = (percentile / 100.0 * sorted.length).ceil();
    final index = math.max(0, math.min(sorted.length - 1, rank - 1));
    return sorted[index];
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'count': count,
    'median': median,
    'p90': p90,
    'p95': p95,
    'max': max,
  };
}

/// A complete, versioned benchmark result set for one engine/profile on one
/// device. Serializes to JSON for the harness to persist and diff.
class BenchmarkReport {
  BenchmarkReport({
    required this.engineId,
    required this.profileId,
    required this.profile,
    required this.corpusVersion,
    required this.generatedAtIso,
    required this.coldLoadMillis,
    required this.warmupMillis,
    required this.unitResults,
  }) : aggregate = BenchmarkAggregate.fromResults(unitResults);

  /// Bumped when the serialized report shape changes.
  static const int schemaVersion = 1;

  final String engineId;
  final String profileId;

  /// The human-readable synthesis profile (canonical map) this run used.
  final Map<String, Object?> profile;

  final int corpusVersion;
  final String generatedAtIso;

  /// Cold model/native load time (engine `initialize()`).
  final int coldLoadMillis;

  /// Time for the first (warm-up) synthesis, excluded from steady-state stats.
  final int warmupMillis;

  final List<BenchmarkUnitResult> unitResults;
  final BenchmarkAggregate aggregate;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'engineId': engineId,
    'profileId': profileId,
    'profile': profile,
    'corpusVersion': corpusVersion,
    'generatedAtIso': generatedAtIso,
    'coldLoadMillis': coldLoadMillis,
    'warmupMillis': warmupMillis,
    'aggregate': aggregate.toJson(),
    'units': unitResults.map((r) => r.toJson()).toList(growable: false),
  };
}
