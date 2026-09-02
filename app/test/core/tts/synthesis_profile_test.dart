import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/core/tts/synthesis_profile.dart';

SynthesisProfile _sherpaBaseline({String voiceSha = 'voice-a'}) =>
    SynthesisProfile(
      engineId: 'sherpa_onnx',
      engineRevision: '1.13.6',
      onnxRuntimeVersion: '1.27.1',
      modelManifestSha: 'model-manifest-sha',
      precision: 'fp32',
      solverSteps: 28,
      temperatureMilli: 200,
      seed: 1234,
      maxFrames: 160,
      sampleRate: 24000,
      voiceContentSha: voiceSha,
      textPolicyVersion: 1,
      audioPolicyVersion: 1,
    );

void main() {
  group('SynthesisProfile.id', () {
    test('is a 64-char lowercase hex SHA-256', () {
      final id = _sherpaBaseline().id;
      expect(id.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(id), isTrue);
    });

    test('is stable across constructions of the same config', () {
      expect(_sherpaBaseline().id, _sherpaBaseline().id);
    });

    test('is stable regardless of source map insertion order', () {
      // toCanonicalMap sorts keys, so the id must not depend on field order.
      final map = _sherpaBaseline().toCanonicalMap();
      final keys = map.keys.toList();
      final sorted = [...keys]..sort();
      expect(keys, sorted);
    });

    test('changes when any output-affecting field changes', () {
      final base = _sherpaBaseline().id;
      expect(
        const SynthesisProfile(
          engineId: 'sherpa_onnx',
          engineRevision: '1.13.6',
          onnxRuntimeVersion: '1.27.1',
          modelManifestSha: 'model-manifest-sha',
          precision: 'fp32',
          solverSteps: 27, // changed
          temperatureMilli: 200,
          seed: 1234,
          maxFrames: 160,
          sampleRate: 24000,
          voiceContentSha: 'voice-a',
          textPolicyVersion: 1,
          audioPolicyVersion: 1,
        ).id,
        isNot(base),
      );
    });

    test('temperature is distinguished at milli precision', () {
      final a = _sherpaBaseline();
      final b = SynthesisProfile(
        engineId: a.engineId,
        engineRevision: a.engineRevision,
        onnxRuntimeVersion: a.onnxRuntimeVersion,
        modelManifestSha: a.modelManifestSha,
        precision: a.precision,
        solverSteps: a.solverSteps,
        temperatureMilli: 201, // 0.201 vs 0.200
        seed: a.seed,
        maxFrames: a.maxFrames,
        sampleRate: a.sampleRate,
        voiceContentSha: a.voiceContentSha,
        textPolicyVersion: a.textPolicyVersion,
        audioPolicyVersion: a.audioPolicyVersion,
      );
      expect(a.id, isNot(b.id));
    });

    test('a different voice yields a different id', () {
      expect(
        _sherpaBaseline().id,
        isNot(_sherpaBaseline(voiceSha: 'voice-b').id),
      );
    });

    test('withVoiceContentSha only rescopes the voice', () {
      final base = _sherpaBaseline();
      final rescoped = base.withVoiceContentSha('voice-b');
      expect(rescoped.id, _sherpaBaseline(voiceSha: 'voice-b').id);
      expect(rescoped.id, isNot(base.id));
    });

    test('canonical map carries every hashed field', () {
      final map = _sherpaBaseline().toCanonicalMap();
      expect(map.keys, containsAll(<String>[
        'audioPolicyVersion',
        'commaSoftening',
        'engineId',
        'engineRevision',
        'maxFrames',
        'modelManifestSha',
        'onnxRuntimeVersion',
        'precision',
        'sampleRate',
        'schemaVersion',
        'seed',
        'solverSteps',
        'temperatureMilli',
        'textPolicyVersion',
        'voiceContentSha',
      ]));
      // commaSoftening is null for sherpa but still present (explicit).
      expect(map.containsKey('commaSoftening'), isTrue);
      expect(map['commaSoftening'], isNull);
    });
  });
}
