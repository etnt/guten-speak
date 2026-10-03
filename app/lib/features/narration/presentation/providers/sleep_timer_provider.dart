import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../library/presentation/providers/library_providers.dart';
import '../../domain/entities/narration_playback.dart';
import 'narration_player_providers.dart';
import 'narration_settings_providers.dart';

part 'sleep_timer_provider.g.dart';

/// Controls the sleep timer: when enabled the timer fires after the configured
/// period without user interaction in the reader, pausing narration and saving
/// a bookmark at the current paragraph.
///
/// State is `true` while the countdown is actively running, `false` otherwise.
@Riverpod(keepAlive: true)
class SleepTimerController extends _$SleepTimerController {
  Timer? _timer;

  @override
  bool build() {
    // Keep the countdown through short buffering/loading gaps between units.
    // Repeated playback snapshots must not restart the inactivity period.
    ref.listen<AsyncValue<NarrationPlaybackState>>(narrationPlaybackProvider, (
      _,
      next,
    ) {
      final playback = next.valueOrNull;
      if (playback == null) return;

      if (_isTerminal(playback.status)) {
        _cancelTimer();
      } else if (_isActive(playback.status) && _timer == null) {
        if (ref.read(sleepTimerEnabledProvider)) _startTimer();
      }
    });

    // Turning the setting off must cancel an already active countdown. Turning
    // it on while narration is playing starts a fresh countdown.
    ref.listen<bool>(sleepTimerEnabledProvider, (_, enabled) {
      if (!enabled) {
        _cancelTimer();
      } else if (_isPlaying) {
        _startTimer();
      }
    });

    // Apply a duration change immediately to the current countdown.
    ref.listen<int>(sleepTimerTimeoutProvider, (_, _) {
      if (ref.read(sleepTimerEnabledProvider) && _isPlaying) _startTimer();
    });

    ref.onDispose(_cancelTimer);

    // Playback may already be active before the controller is first watched.
    final shouldStart = ref.read(sleepTimerEnabledProvider) && _isPlaying;
    if (shouldStart) {
      final seconds = ref.read(sleepTimerTimeoutProvider);
      _timer = Timer(Duration(seconds: seconds), _onTimerFired);
    }
    return shouldStart;
  }

  bool get _isPlaying {
    final status = ref.read(narrationPlaybackProvider).valueOrNull?.status;
    return status != null && _isActive(status);
  }

  bool _isPlaybackActiveFor(int? bookId) {
    final playback = ref.read(narrationPlaybackProvider).valueOrNull;
    return playback != null &&
        playback.bookId == bookId &&
        _isActive(playback.status);
  }

  bool _isSameBook(int? bookId) =>
      ref.read(narrationPlaybackProvider).valueOrNull?.bookId == bookId;

  bool _isActive(NarrationStatus status) =>
      status == NarrationStatus.playing ||
      status == NarrationStatus.buffering ||
      status == NarrationStatus.preparing;

  bool _isTerminal(NarrationStatus status) =>
      status == NarrationStatus.paused ||
      status == NarrationStatus.idle ||
      status == NarrationStatus.completed ||
      status == NarrationStatus.error;

  /// Called after user interactions with the reader or narration controls.
  /// Resets the countdown so the timer only fires after a fresh period of
  /// inactivity.
  void resetTimer() {
    if (!ref.read(sleepTimerEnabledProvider)) return;
    if (!_isPlaying) return;
    _startTimer(); // cancel-then-restart
  }

  void _startTimer() {
    _timer?.cancel();
    final seconds = ref.read(sleepTimerTimeoutProvider);
    _timer = Timer(Duration(seconds: seconds), _onTimerFired);
    state = true;
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
    state = false;
  }

  Future<void> _onTimerFired() async {
    state = false;
    _timer = null;

    try {
      // Capture the session identity before any asynchronous work. A new book
      // must never receive the expired session's bookmark.
      final initialBookId = ref
          .read(narrationPlaybackProvider)
          .valueOrNull
          ?.bookId;
      if (initialBookId == null) return;

      final handler = await ref.read(narrationAudioHandlerProvider.future);
      if (!_isPlaybackActiveFor(initialBookId)) return;

      final position = handler.currentNarrationPosition();
      if (position == null || position.bookId != initialBookId) return;

      // Re-check immediately before pausing in case the handler lookup crossed
      // a pause, completion, or book switch.
      if (!_isPlaybackActiveFor(initialBookId)) return;
      await handler.pause();

      // pause() itself ends active playback. Validate the session identity and
      // position instead, so a mid-await book change cannot be bookmarked.
      final currentPosition = handler.currentNarrationPosition();
      if (!_isSameBook(initialBookId) ||
          currentPosition?.bookId != initialBookId) {
        return;
      }

      final existing = await ref.read(bookmarksProvider(initialBookId).future);
      if (!_isSameBook(initialBookId) ||
          handler.currentNarrationPosition()?.bookId != initialBookId) {
        return;
      }
      final alreadySaved = existing.any(
        (bookmark) =>
            bookmark.paragraphIndex == position.paragraphIndex &&
            bookmark.note == 'Sleep timer',
      );
      if (alreadySaved) return;

      await ref
          .read(bookmarkControllerProvider.notifier)
          .add(initialBookId, position.paragraphIndex, note: 'Sleep timer');
    } catch (_) {
      // Timer work is detached from a caller; handle failures from handler
      // setup, pause, bookmark lookup, and persistence without an async error.
    }
  }
}
