import 'dart:async';
import 'dart:math' as math;

import '../../../../core/utils/narration_segmenter.dart';
import '../repositories/narration_audio_cache.dart';

/// Renders one narration unit's audio to [outputPath]. Injected so the scheduler
/// stays free of the native TTS engine and is unit-testable with a fake.
typedef SynthesizeUnit =
    Future<void> Function(NarrationUnit unit, String outputPath);

/// What happened to a unit the scheduler was working on.
enum SynthEventKind { ready, failed }

/// A scheduler notification: a unit became ready to play, or failed to render.
class SynthEvent {
  const SynthEvent(this.kind, this.unitIndex, [this.error]);

  final SynthEventKind kind;
  final int unitIndex;
  final Object? error;

  bool get isReady => kind == SynthEventKind.ready;
}

/// Keeps a rolling window of narration units rendered *ahead* of the play head.
///
/// Synthesis is slower than playback (RTF ≈ 1.12× on a flagship), so narration
/// is pre-rendered rather than streamed. The scheduler runs a **single serial
/// job at a time** (the native engine is RAM-bound and lives on one worker
/// isolate), always targeting the first not-yet-ready unit in
/// `[playHead, playHead + lookAhead]`.
///
/// Because every iteration re-evaluates relative to the current play head,
/// **seeks replan automatically**: [seekTo] just moves the head and re-pumps,
/// and the next job picks the now-nearest missing unit. A synth already in
/// flight when a seek arrives is allowed to finish (the native call is not
/// interruptible) — its clip is still cached — after which the loop re-targets.
///
/// The scheduler is bound to a fixed `(bookId, voiceId)`; a voice change is a
/// replan handled one level up by disposing this scheduler and creating a new
/// one (see the narration providers), which also invalidates the stale voice's
/// cached clips.
class LookAheadScheduler {
  LookAheadScheduler({
    required this.bookId,
    required this.voiceId,
    required this.units,
    required this.cache,
    required this.synthesize,
    this.lookAhead = 3,
    this.behind = 1,
  });

  final int bookId;
  final String voiceId;
  final List<NarrationUnit> units;
  final NarrationAudioCache cache;
  final SynthesizeUnit synthesize;

  /// How many units ahead of the play head to keep rendered. Mutable so the
  /// user can change the head-start size between stretches (see [setLookAhead]).
  int lookAhead;

  /// How many already-played units behind the head to keep before eviction.
  final int behind;

  final Set<int> _ready = <int>{};
  final StreamController<SynthEvent> _events =
      StreamController<SynthEvent>.broadcast();

  int _playHead = 0;
  bool _pumping = false;
  bool _disposed = false;

  /// Fires as units become ready (or fail). The player listens to auto-resume
  /// out of a buffering state when the next unit lands.
  Stream<SynthEvent> get events => _events.stream;

  int get playHead => _playHead;

  int get unitCount => units.length;

  /// Whether unit [index] has been rendered and is safe to play now.
  bool isReady(int index) => _ready.contains(index);

  /// Begins (or resumes) rendering ahead of the current play head.
  Future<void> start() => _pump();

  /// Changes how many units to keep rendered ahead of the play head and
  /// re-pumps so a larger window starts filling immediately.
  void setLookAhead(int value) {
    if (_disposed) return;
    lookAhead = value < 0 ? 0 : value;
    unawaited(_pump());
  }

  /// Moves the play head (a seek) and re-plans rendering around the new
  /// position. Cheap and safe to call repeatedly.
  void seekTo(int index) {
    if (_disposed) return;
    final clamped = index.clamp(0, math.max(0, units.length - 1)).toInt();
    if (clamped == _playHead) return;
    _playHead = clamped;
    unawaited(_pump());
  }

  Future<void> _pump() async {
    if (_pumping || _disposed || units.isEmpty) return;
    _pumping = true;
    try {
      while (!_disposed) {
        await _evict();
        final target = await _nextTarget();
        if (target == null || _disposed) break;
        try {
          final outputPath = await cache.reservePath(bookId, voiceId, target);
          await synthesize(units[target], outputPath);
          if (_disposed) break;
          await cache.record(bookId, voiceId, units[target]);
          _markReady(target);
        } catch (error) {
          _emit(SynthEvent(SynthEventKind.failed, target, error));
          // Stop pumping on failure to avoid a tight failing loop; a later
          // seek (or an explicit restart) re-pumps.
          break;
        }
      }
    } finally {
      _pumping = false;
    }
  }

  /// The first not-yet-ready unit within the look-ahead window, priming the
  /// ready set from any clips already on disk (cross-session reuse).
  Future<int?> _nextTarget() async {
    final hi = math.min(units.length - 1, _playHead + lookAhead);
    for (var i = _playHead; i <= hi; i++) {
      if (_ready.contains(i)) continue;
      final cached = await cache.cachedPath(bookId, voiceId, units[i]);
      if (cached != null) {
        _markReady(i);
        continue;
      }
      return i;
    }
    return null;
  }

  Future<void> _evict() async {
    final lo = math.max(0, _playHead - behind);
    final hi = math.min(units.length - 1, _playHead + lookAhead);
    _ready.removeWhere((i) => i < lo || i > hi);
    await cache.evictOutsideWindow(bookId, voiceId, lo: lo, hi: hi);
  }

  void _markReady(int index) {
    if (_ready.add(index)) {
      _emit(SynthEvent(SynthEventKind.ready, index));
    }
  }

  void _emit(SynthEvent event) {
    if (!_events.isClosed) {
      _events.add(event);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _events.close();
  }
}
