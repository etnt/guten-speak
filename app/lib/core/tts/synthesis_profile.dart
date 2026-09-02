import 'dart:convert';

import 'package:crypto/crypto.dart';

/// A canonical, versioned description of every input that can change the bytes
/// of a synthesized narration clip.
///
/// The [id] is the SHA-256 of a deterministic canonical serialization of all
/// fields. It is the cache identity: two configurations that could produce
/// different audio must hash differently, and two byte-identical configurations
/// must hash the same across runs, isolates, and devices.
///
/// Floating-point settings (temperature) are stored as scaled integers and all
/// keys are emitted in a fixed sorted order, so the hash never depends on
/// locale-sensitive float formatting or map iteration order.
class SynthesisProfile {
  const SynthesisProfile({
    required this.engineId,
    required this.engineRevision,
    required this.onnxRuntimeVersion,
    required this.modelManifestSha,
    required this.precision,
    required this.solverSteps,
    required this.temperatureMilli,
    required this.seed,
    required this.maxFrames,
    required this.sampleRate,
    required this.voiceContentSha,
    this.commaSoftening,
    this.textPolicyVersion = 0,
    this.audioPolicyVersion = 0,
    this.schemaVersion = kSynthesisProfileSchemaVersion,
  });

  /// Schema version of the canonical form itself. Bump when fields are added,
  /// removed, or reinterpreted.
  static const int kSynthesisProfileSchemaVersion = 1;

  /// Stable engine identifier, e.g. `sherpa_onnx` or `pocket_tts_raven`.
  final String engineId;

  /// Engine/native build revision, e.g. the pub version or native commit.
  final String engineRevision;

  /// ONNX Runtime version the engine links against.
  final String onnxRuntimeVersion;

  /// SHA-256 of the installed model manifest this profile was produced with.
  final String modelManifestSha;

  /// Weight precision, e.g. `fp32` or `int8`.
  final String precision;

  /// Flow-matching ODE solver step count.
  final int solverSteps;

  /// Sampling temperature scaled by 1000 (0.20 -> 200) so it hashes as an int.
  final int temperatureMilli;

  /// Random seed fixing the generated noise.
  final int seed;

  /// EOS/max-frame bound applied per internal sentence.
  final int maxFrames;

  /// Output sample rate in Hz.
  final int sampleRate;

  /// SHA-256 of the reference voice content this profile is scoped to.
  final String voiceContentSha;

  /// Raven comma-softening setting; `null` for engines without it.
  final bool? commaSoftening;

  /// Version of the shared text normalization/retry policy (see
  /// `tts_text_processing.dart`).
  final int textPolicyVersion;

  /// Version of the audio trim/fade/WAV-encoding policy.
  final int audioPolicyVersion;

  /// Canonical-form schema version.
  final int schemaVersion;

  /// The fixed-key, sorted, deterministic map hashed to produce [id].
  ///
  /// Also surfaced verbatim in benchmark output and logs as the human-readable
  /// profile.
  Map<String, Object?> toCanonicalMap() {
    final map = <String, Object?>{
      'audioPolicyVersion': audioPolicyVersion,
      'commaSoftening': commaSoftening,
      'engineId': engineId,
      'engineRevision': engineRevision,
      'maxFrames': maxFrames,
      'modelManifestSha': modelManifestSha,
      'onnxRuntimeVersion': onnxRuntimeVersion,
      'precision': precision,
      'sampleRate': sampleRate,
      'schemaVersion': schemaVersion,
      'seed': seed,
      'solverSteps': solverSteps,
      'temperatureMilli': temperatureMilli,
      'textPolicyVersion': textPolicyVersion,
      'voiceContentSha': voiceContentSha,
    };
    // Guard against a future edit that adds an out-of-order key.
    final sortedKeys = map.keys.toList()..sort();
    return <String, Object?>{for (final key in sortedKeys) key: map[key]};
  }

  /// Canonical JSON string that is hashed into [id].
  String toCanonicalJson() => jsonEncode(toCanonicalMap());

  /// 64-character lowercase hex SHA-256 of the canonical form.
  String get id => sha256.convert(utf8.encode(toCanonicalJson())).toString();

  /// A copy scoped to a different reference voice.
  SynthesisProfile withVoiceContentSha(String sha) => SynthesisProfile(
    engineId: engineId,
    engineRevision: engineRevision,
    onnxRuntimeVersion: onnxRuntimeVersion,
    modelManifestSha: modelManifestSha,
    precision: precision,
    solverSteps: solverSteps,
    temperatureMilli: temperatureMilli,
    seed: seed,
    maxFrames: maxFrames,
    sampleRate: sampleRate,
    voiceContentSha: sha,
    commaSoftening: commaSoftening,
    textPolicyVersion: textPolicyVersion,
    audioPolicyVersion: audioPolicyVersion,
    schemaVersion: schemaVersion,
  );

  @override
  String toString() => 'SynthesisProfile(${toCanonicalJson()})';
}
