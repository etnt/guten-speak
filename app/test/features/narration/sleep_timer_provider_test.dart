import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/features/library/domain/entities/bookmark.dart';
import 'package:guten_speak/features/library/presentation/providers/library_providers.dart';
import 'package:guten_speak/features/narration/domain/entities/narration_playback.dart';
import 'package:guten_speak/features/narration/presentation/providers/narration_player_providers.dart';
import 'package:guten_speak/features/narration/presentation/providers/narration_settings_providers.dart';
import 'package:guten_speak/features/narration/presentation/providers/sleep_timer_provider.dart';
import 'package:guten_speak/features/narration/presentation/services/narration_audio_handler.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNarrationAudioHandler extends Mock
    implements NarrationAudioHandler {}

class _BookmarkRecorder extends BookmarkController {
  final List<({int bookId, int paragraphIndex, String? note})> added = [];
  bool shouldThrow = false;

  @override
  void build() {}

  @override
  Future<void> add(int bookId, int paragraphIndex, {String? note}) async {
    if (shouldThrow) throw StateError('bookmark write failed');
    added.add((bookId: bookId, paragraphIndex: paragraphIndex, note: note));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SleepTimerController', () {
    test('fires after timeout, pauses narration, and saves a bookmark', () {
      fakeAsync((async) {
        final fixture = _TimerFixture.create();
        fixture.startPlaying(async);

        expect(fixture.container.read(sleepTimerControllerProvider), isTrue);
        async.elapse(const Duration(seconds: 29));
        expect(fixture.handler.pauseCalls, 0);
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        expect(fixture.handler.pauseCalls, 1);
        expect(fixture.bookmarks.added, [
          (bookId: 42, paragraphIndex: 7, note: 'Sleep timer'),
        ]);
        expect(fixture.container.read(sleepTimerControllerProvider), isFalse);
        fixture.dispose();
      });
    });

    test('repeated playing snapshots do not restart the countdown', () {
      fakeAsync((async) {
        final fixture = _TimerFixture.create();
        fixture.startPlaying(async);
        async.elapse(const Duration(seconds: 20));
        fixture.emitPlaying();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();

        expect(fixture.handler.pauseCalls, 1);
        fixture.dispose();
      });
    });

    test('resetTimer postpones the timeout', () {
      fakeAsync((async) {
        final fixture = _TimerFixture.create();
        fixture.startPlaying(async);
        async.elapse(const Duration(seconds: 20));
        fixture.container
            .read(sleepTimerControllerProvider.notifier)
            .resetTimer();
        async.elapse(const Duration(seconds: 20));
        async.flushMicrotasks();

        expect(fixture.handler.pauseCalls, 0);
        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();
        expect(fixture.handler.pauseCalls, 1);
        fixture.dispose();
      });
    });

    test('buffering does not cancel or restart the countdown', () {
      fakeAsync((async) {
        final fixture = _TimerFixture.create();
        fixture.startPlaying(async);
        async.elapse(const Duration(seconds: 20));
        fixture.playback.add(
          const NarrationPlaybackState(
            status: NarrationStatus.buffering,
            bookId: 42,
          ),
        );
        async.flushMicrotasks();
        fixture.playback.add(
          const NarrationPlaybackState(
            status: NarrationStatus.playing,
            bookId: 42,
          ),
        );
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();

        expect(fixture.handler.pauseCalls, 1);
        fixture.dispose();
      });
    });

    test('bookmark write failures are handled by the timer', () {
      fakeAsync((async) {
        final fixture = _TimerFixture.create();
        fixture.bookmarks.shouldThrow = true;
        fixture.startPlaying(async);
        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();

        expect(fixture.handler.pauseCalls, 1);
        expect(fixture.container.read(sleepTimerControllerProvider), isFalse);
        fixture.dispose();
      });
    });

    test('does not add a duplicate sleep timer bookmark', () {
      fakeAsync((async) {
        final fixture = _TimerFixture.create(
          existingBookmarks: [
            Bookmark(
              bookId: 42,
              paragraphIndex: 7,
              createdAt: DateTime(2024),
              note: 'Sleep timer',
            ),
          ],
        );
        fixture.startPlaying(async);
        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();

        expect(fixture.bookmarks.added, isEmpty);
        fixture.dispose();
      });
    });

    test('timeout change restarts the running countdown at new duration', () {
      fakeAsync((async) {
        final fixture = _TimerFixture.create();
        fixture.startPlaying(async);
        async.elapse(const Duration(seconds: 20));
        fixture.container.read(sleepTimerTimeoutProvider.notifier).set(60);
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();
        expect(fixture.handler.pauseCalls, 0);
        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();
        expect(fixture.handler.pauseCalls, 1);
        fixture.dispose();
      });
    });

    test('playback pause cancels the timeout', () {
      fakeAsync((async) {
        final fixture = _TimerFixture.create();
        fixture.startPlaying(async);
        fixture.playback.add(
          const NarrationPlaybackState(status: NarrationStatus.paused),
        );
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();

        expect(fixture.handler.pauseCalls, 0);
        expect(fixture.container.read(sleepTimerControllerProvider), isFalse);
        fixture.dispose();
      });
    });

    test('disabling the timer cancels the timeout', () {
      fakeAsync((async) {
        final fixture = _TimerFixture.create();
        fixture.startPlaying(async);
        fixture.container.read(sleepTimerEnabledProvider.notifier).set(false);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();

        expect(fixture.handler.pauseCalls, 0);
        expect(fixture.container.read(sleepTimerControllerProvider), isFalse);
        fixture.dispose();
      });
    });
  });
}

class _TimerFixture {
  _TimerFixture._({
    required this.container,
    required this.playback,
    required this.handler,
    required this.bookmarks,
    required this.stopListening,
  });

  final ProviderContainer container;
  final StreamController<NarrationPlaybackState> playback;
  final _TestNarrationAudioHandler handler;
  final _BookmarkRecorder bookmarks;
  final ProviderSubscription<bool> stopListening;

  static _TimerFixture create({List<Bookmark> existingBookmarks = const []}) {
    SharedPreferences.setMockInitialValues({
      'sleep_timer_enabled': true,
      'sleep_timer_timeout_seconds': 30,
    });
    // The fixture owns this stream and closes it in dispose().
    // ignore: close_sinks
    final playback = StreamController<NarrationPlaybackState>.broadcast(
      sync: true,
    );
    final handler = _TestNarrationAudioHandler();
    final bookmarks = _BookmarkRecorder();
    final container = ProviderContainer(
      overrides: [
        narrationPlaybackProvider.overrideWith((ref) => playback.stream),
        narrationAudioHandlerProvider.overrideWith((ref) async => handler),
        bookmarkControllerProvider.overrideWith(() => bookmarks),
        bookmarksProvider(42).overrideWith((ref) async => existingBookmarks),
      ],
    );
    final subscription = container.listen(
      sleepTimerControllerProvider,
      (_, _) {},
    );
    return _TimerFixture._(
      container: container,
      playback: playback,
      handler: handler,
      bookmarks: bookmarks,
      stopListening: subscription,
    );
  }

  void startPlaying(FakeAsync async) {
    playback.add(
      const NarrationPlaybackState(status: NarrationStatus.playing, bookId: 42),
    );
    // Let shared-preference loading and the playback stream deliver their
    // initial values before the fake clock advances.
    async.flushMicrotasks();
  }

  void emitPlaying() {
    playback.add(
      const NarrationPlaybackState(
        status: NarrationStatus.playing,
        bookId: 42,
        unitIndex: 1,
      ),
    );
  }

  void dispose() {
    stopListening.close();
    container.dispose();
    playback.close();
  }
}

class _TestNarrationAudioHandler extends _MockNarrationAudioHandler {
  int pauseCalls = 0;

  @override
  ({int bookId, int paragraphIndex})? currentNarrationPosition() =>
      (bookId: 42, paragraphIndex: 7);

  @override
  Future<void> pause() async {
    pauseCalls++;
  }
}
