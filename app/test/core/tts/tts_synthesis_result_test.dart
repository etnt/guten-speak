import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/core/tts/tts_synthesis_result.dart';

void main() {
  group('TtsSynthesisResult metrics', () {
    TtsSynthesisResult make({
      int sampleCount = 24000, // 1.0s at 24kHz
      int sampleRate = 24000,
      int nativeGenerateMillis = 2000,
      int requestToCompleteMillis = 2500,
    }) => TtsSynthesisResult(
      engineId: 'sherpa_onnx',
      profileId: 'p',
      sampleCount: sampleCount,
      sampleRate: sampleRate,
      nativeGenerateMillis: nativeGenerateMillis,
      postProcessMillis: 100,
      wavWriteMillis: 50,
      requestToCompleteMillis: requestToCompleteMillis,
    );

    test('audioSeconds is sampleCount / sampleRate', () {
      expect(make(sampleCount: 12000).audioSeconds, 0.5);
    });

    test('nativeRealTimeFactor uses native generate time', () {
      // 2.0s generate / 1.0s audio = 2.0x (slower than real time).
      expect(make().nativeRealTimeFactor, 2.0);
    });

    test('pipelineRealTimeFactor uses complete-file time', () {
      // 2.5s pipeline / 1.0s audio = 2.5x.
      expect(make().pipelineRealTimeFactor, 2.5);
    });

    test('pipeline RTF is never better than native RTF', () {
      final r = make();
      expect(r.pipelineRealTimeFactor, greaterThanOrEqualTo(r.nativeRealTimeFactor));
    });

    test('zero audio yields zero RTFs instead of dividing by zero', () {
      final r = make(sampleCount: 0);
      expect(r.audioSeconds, 0.0);
      expect(r.nativeRealTimeFactor, 0.0);
      expect(r.pipelineRealTimeFactor, 0.0);
    });

    test('toJson exposes both RTFs and the nullable first-chunk time', () {
      final json = make().toJson();
      expect(json['nativeRealTimeFactor'], 2.0);
      expect(json['pipelineRealTimeFactor'], 2.5);
      expect(json.containsKey('requestToFirstChunkMillis'), isTrue);
      expect(json['requestToFirstChunkMillis'], isNull);
    });
  });
}
