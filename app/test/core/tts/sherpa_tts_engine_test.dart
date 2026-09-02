import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/core/tts/model_manager.dart';
import 'package:guten_speak/core/tts/sherpa_tts_engine.dart';
import 'package:guten_speak/core/tts/tts_engine.dart';
import 'package:guten_speak/core/tts/tts_service.dart';
import 'package:guten_speak/core/tts/tts_synthesis_request.dart';
import 'package:mocktail/mocktail.dart';

class _MockTtsService extends Mock implements TtsService {}

const _paths = PocketModelPaths(
  lmFlow: 'lm_flow',
  lmMain: 'lm_main',
  encoder: 'encoder',
  decoder: 'decoder',
  textConditioner: 'text_conditioner',
  vocabJson: 'vocab.json',
  tokenScoresJson: 'token_scores.json',
);

TtsSynthesisRequest _request() => const TtsSynthesisRequest(
  requestId: 'req-1',
  text: 'Hello there.',
  voiceId: 'reginald-ashworth',
  referenceWavPath: '/voices/reginald.wav',
  outputWavPath: '/out/unit-0.wav',
);

void main() {
  late _MockTtsService service;
  late SherpaTtsEngine engine;

  setUp(() {
    service = _MockTtsService();
    engine = SherpaTtsEngine(paths: _paths, service: service);
  });

  test('exposes a stable sherpa baseline synthesis profile', () {
    expect(engine.engineId, 'sherpa_onnx');
    final profile = engine.synthesisProfile;
    expect(profile.engineId, 'sherpa_onnx');
    expect(profile.precision, 'fp32');
    expect(profile.solverSteps, 28);
    expect(profile.temperatureMilli, 200);
    expect(profile.seed, 1234);
    expect(profile.sampleRate, 24000);
    // The id must be deterministic for the same configuration.
    expect(profile.id, engine.synthesisProfile.id);
  });

  test('initialize loads the model into the underlying service', () async {
    when(() => service.init(_paths)).thenAnswer((_) async {});

    await engine.initialize();

    verify(() => service.init(_paths)).called(1);
  });

  test('isReady reflects the underlying service', () {
    when(() => service.isReady).thenReturn(false);
    expect(engine.isReady, isFalse);

    when(() => service.isReady).thenReturn(true);
    expect(engine.isReady, isTrue);
  });

  test('synthesize maps per-stage timings onto the common result', () async {
    when(() => service.isReady).thenReturn(true);
    when(
      () => service.speak(
        text: any(named: 'text'),
        referenceWavPath: any(named: 'referenceWavPath'),
        outputWavPath: any(named: 'outputWavPath'),
        numSteps: any(named: 'numSteps'),
        temperature: any(named: 'temperature'),
        seed: any(named: 'seed'),
      ),
    ).thenAnswer(
      (_) async => const SpeakResult(
        sampleRate: 24000,
        sampleCount: 48000,
        nativeGenerateMillis: 1800,
        postProcessMillis: 40,
        wavWriteMillis: 12,
        completeMillis: 1900,
      ),
    );

    final result = await engine.synthesize(_request());

    expect(result.engineId, 'sherpa_onnx');
    expect(result.profileId, engine.synthesisProfile.id);
    expect(result.sampleRate, 24000);
    expect(result.sampleCount, 48000);
    expect(result.nativeGenerateMillis, 1800);
    expect(result.postProcessMillis, 40);
    expect(result.wavWriteMillis, 12);
    // Sherpa is non-incremental, so there is no first-chunk timing.
    expect(result.requestToFirstChunkMillis, isNull);
    // Request-to-complete is measured at the engine boundary.
    expect(result.requestToCompleteMillis, greaterThanOrEqualTo(0));
    expect(result.audioSeconds, closeTo(2.0, 1e-9));
  });

  test('synthesize before initialize fails with nativeInitFailed', () async {
    when(() => service.isReady).thenReturn(false);

    await expectLater(
      () => engine.synthesize(_request()),
      throwsA(
        isA<TtsSynthesisException>().having(
          (e) => e.category,
          'category',
          TtsFailureCategory.nativeInitFailed,
        ),
      ),
    );
  });

  test('classifies a runaway utterance as outputTooLong', () async {
    when(() => service.isReady).thenReturn(true);
    when(
      () => service.speak(
        text: any(named: 'text'),
        referenceWavPath: any(named: 'referenceWavPath'),
        outputWavPath: any(named: 'outputWavPath'),
        numSteps: any(named: 'numSteps'),
        temperature: any(named: 'temperature'),
        seed: any(named: 'seed'),
      ),
    ).thenThrow(
      Exception('PocketTTS produced implausibly long audio for a retry phrase.'),
    );

    await expectLater(
      () => engine.synthesize(_request()),
      throwsA(
        isA<TtsSynthesisException>().having(
          (e) => e.category,
          'category',
          TtsFailureCategory.outputTooLong,
        ),
      ),
    );
  });

  test('classifies other native failures as nativeStreamFailed', () async {
    when(() => service.isReady).thenReturn(true);
    when(
      () => service.speak(
        text: any(named: 'text'),
        referenceWavPath: any(named: 'referenceWavPath'),
        outputWavPath: any(named: 'outputWavPath'),
        numSteps: any(named: 'numSteps'),
        temperature: any(named: 'temperature'),
        seed: any(named: 'seed'),
      ),
    ).thenThrow(Exception('TTS speak failed: native crash'));

    await expectLater(
      () => engine.synthesize(_request()),
      throwsA(
        isA<TtsSynthesisException>().having(
          (e) => e.category,
          'category',
          TtsFailureCategory.nativeStreamFailed,
        ),
      ),
    );
  });

  test('dispose tears down the underlying service', () async {
    when(() => service.dispose()).thenAnswer((_) async {});

    await engine.dispose();

    verify(() => service.dispose()).called(1);
  });

  test('cancelCurrentSynthesis is a safe no-op for the baseline engine',
      () async {
    await engine.cancelCurrentSynthesis();
  });
}
