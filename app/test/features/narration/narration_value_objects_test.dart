import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/features/narration/domain/entities/narration_playback.dart';
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

  group('NarrationPlaybackState', () {
    test('the default is idle and not active', () {
      const state = NarrationPlaybackState();
      expect(state.status, NarrationStatus.idle);
      expect(state.isActive, isFalse);
      expect(state.isPlaying, isFalse);
      expect(state.isBuffering, isFalse);
    });

    test('isActive requires a book and a non-idle status', () {
      const idleWithBook = NarrationPlaybackState(bookId: 1);
      expect(idleWithBook.isActive, isFalse);

      const paused = NarrationPlaybackState(
        bookId: 1,
        status: NarrationStatus.paused,
      );
      expect(paused.isActive, isTrue);

      const playingNoBook = NarrationPlaybackState(
        status: NarrationStatus.playing,
      );
      expect(playingNoBook.isActive, isFalse);
    });

    test('isPlaying is only true while playing', () {
      const playing = NarrationPlaybackState(
        bookId: 1,
        status: NarrationStatus.playing,
      );
      const paused = NarrationPlaybackState(
        bookId: 1,
        status: NarrationStatus.paused,
      );
      expect(playing.isPlaying, isTrue);
      expect(paused.isPlaying, isFalse);
    });

    test('isBuffering covers loading and buffering', () {
      const loading = NarrationPlaybackState(status: NarrationStatus.loading);
      const buffering = NarrationPlaybackState(
        status: NarrationStatus.buffering,
      );
      const playing = NarrationPlaybackState(status: NarrationStatus.playing);
      expect(loading.isBuffering, isTrue);
      expect(buffering.isBuffering, isTrue);
      expect(playing.isBuffering, isFalse);
    });

    test('progress is the fraction of units reached', () {
      const empty = NarrationPlaybackState();
      expect(empty.progress, 0);

      const midway = NarrationPlaybackState(unitIndex: 4, unitCount: 10);
      expect(midway.progress, closeTo(0.5, 1e-9));

      const last = NarrationPlaybackState(unitIndex: 9, unitCount: 10);
      expect(last.progress, closeTo(1.0, 1e-9));
    });

    test('copyWith overrides only the given fields', () {
      const state = NarrationPlaybackState(
        bookId: 1,
        bookTitle: 'Moby-Dick',
        voiceId: 'v1',
        unitIndex: 2,
        unitCount: 20,
        speed: 1.0,
      );
      final next = state.copyWith(
        status: NarrationStatus.playing,
        unitIndex: 3,
        speed: 1.5,
      );
      expect(next.status, NarrationStatus.playing);
      expect(next.unitIndex, 3);
      expect(next.speed, 1.5);
      // Untouched fields are preserved.
      expect(next.bookId, 1);
      expect(next.bookTitle, 'Moby-Dick');
      expect(next.voiceId, 'v1');
      expect(next.unitCount, 20);
    });

    test('copyWith clears the error unless one is supplied', () {
      const failed = NarrationPlaybackState(
        status: NarrationStatus.error,
        error: 'boom',
      );
      expect(failed.copyWith(error: 'again').error, 'again');
      // Errors are transient: a plain copy clears them.
      expect(failed.copyWith(status: NarrationStatus.playing).error, isNull);
    });
  });
}
