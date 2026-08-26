import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/features/narration/domain/entities/narration_prep_progress.dart';
import 'package:guten_speak/features/voices/domain/entities/voice.dart';

void main() {
  group('NarrationPrepProgress', () {
    test('idle is not busy and not ready', () {
      const progress = NarrationPrepProgress.idle();
      expect(progress.phase, NarrationPrepPhase.idle);
      expect(progress.phase.isBusy, isFalse);
      expect(progress.isReady, isFalse);
    });

    test('downloading carries a fraction and is busy', () {
      const progress = NarrationPrepProgress.downloading(0.42);
      expect(progress.phase, NarrationPrepPhase.downloading);
      expect(progress.fraction, 0.42);
      expect(progress.phase.isBusy, isTrue);
      expect(progress.isReady, isFalse);
    });

    test('extracting and loading are busy', () {
      expect(const NarrationPrepProgress.extracting().phase.isBusy, isTrue);
      expect(const NarrationPrepProgress.loading().phase.isBusy, isTrue);
    });

    test('ready is ready and not busy', () {
      const progress = NarrationPrepProgress.ready();
      expect(progress.isReady, isTrue);
      expect(progress.phase.isBusy, isFalse);
    });

    test('error carries the message and is not busy', () {
      const progress = NarrationPrepProgress.error('boom');
      expect(progress.phase, NarrationPrepPhase.error);
      expect(progress.error, 'boom');
      expect(progress.phase.isBusy, isFalse);
      expect(progress.isReady, isFalse);
    });
  });

  group('Voice', () {
    test('defaults to a user voice', () {
      const voice = Voice(id: 'a', name: 'Alice', wavPath: '/tmp/a.wav');
      expect(voice.builtIn, isFalse);
    });

    test('equality is by value', () {
      const a = Voice(id: 'a', name: 'Alice', wavPath: '/tmp/a.wav');
      const b = Voice(id: 'a', name: 'Alice', wavPath: '/tmp/a.wav');
      const c = Voice(id: 'a', name: 'Alice', wavPath: '/tmp/other.wav');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });
}
