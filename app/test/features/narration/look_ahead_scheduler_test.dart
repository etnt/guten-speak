import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/core/utils/narration_segmenter.dart';
import 'package:guten_speak/features/narration/domain/repositories/narration_audio_cache.dart';
import 'package:guten_speak/features/narration/domain/services/look_ahead_scheduler.dart';

/// In-memory [NarrationAudioCache] whose `rendered` set doubles as the
/// "on-disk" cache: pre-seed it to simulate clips left by a previous session.
class _FakeCache implements NarrationAudioCache {
  _FakeCache({Set<int>? preRendered}) : rendered = <int>{...?preRendered};

  final Set<int> rendered;
  final List<int> recorded = <int>[];
  final List<({int lo, int hi})> evictions = <({int lo, int hi})>[];

  @override
  Future<String?> cachedPath(
    int bookId,
    String voiceId,
    NarrationUnit unit,
  ) async => rendered.contains(unit.index) ? 'unit_${unit.index}.wav' : null;

  @override
  Future<String> reservePath(int bookId, String voiceId, int unitIndex) async =>
      'unit_$unitIndex.wav';

  @override
  Future<void> record(int bookId, String voiceId, NarrationUnit unit) async {
    rendered.add(unit.index);
    recorded.add(unit.index);
  }

  @override
  Future<void> evictOutsideWindow(
    int bookId,
    String voiceId, {
    required int lo,
    required int hi,
  }) async {
    evictions.add((lo: lo, hi: hi));
    rendered.removeWhere((i) => i < lo || i > hi);
  }
}

List<NarrationUnit> _makeUnits(int count) => List<NarrationUnit>.generate(
  count,
  (i) => NarrationUnit(index: i, paragraphIndex: i, text: 'unit $i'),
);

void main() {
  group('LookAheadScheduler', () {
    test('renders the look-ahead window ahead of the head, in order', () async {
      final cache = _FakeCache();
      final synthCalls = <int>[];
      final scheduler = LookAheadScheduler(
        bookId: 1,
        voiceId: 'v',
        units: _makeUnits(10),
        cache: cache,
        synthesize: (unit, path) async => synthCalls.add(unit.index),
      );
      addTearDown(scheduler.dispose);

      await scheduler.start();

      // lookAhead defaults to 3 → window [0, 3].
      expect(synthCalls, <int>[0, 1, 2, 3]);
      expect(scheduler.isReady(0), isTrue);
      expect(scheduler.isReady(3), isTrue);
      expect(scheduler.isReady(4), isFalse);
    });

    test('reuses clips already on disk without re-synthesizing', () async {
      final cache = _FakeCache(preRendered: <int>{0, 1, 2, 3});
      final synthCalls = <int>[];
      final scheduler = LookAheadScheduler(
        bookId: 1,
        voiceId: 'v',
        units: _makeUnits(10),
        cache: cache,
        synthesize: (unit, path) async => synthCalls.add(unit.index),
      );
      addTearDown(scheduler.dispose);

      await scheduler.start();

      expect(synthCalls, isEmpty);
      expect(scheduler.isReady(0), isTrue);
      expect(scheduler.isReady(3), isTrue);
    });

    test('seekTo replans rendering around the new head', () async {
      final cache = _FakeCache();
      final synthCalls = <int>[];
      final scheduler = LookAheadScheduler(
        bookId: 1,
        voiceId: 'v',
        units: _makeUnits(10),
        cache: cache,
        synthesize: (unit, path) async => synthCalls.add(unit.index),
      );
      addTearDown(scheduler.dispose);

      await scheduler.start();
      synthCalls.clear();

      scheduler.seekTo(5);
      await pumpEventQueue();

      // New window [5, 8]; units behind the head are evicted.
      expect(synthCalls, <int>[5, 6, 7, 8]);
      expect(scheduler.playHead, 5);
      expect(scheduler.isReady(5), isTrue);
      expect(scheduler.isReady(0), isFalse);
    });

    test('emits ready events as units land', () async {
      final cache = _FakeCache();
      final scheduler = LookAheadScheduler(
        bookId: 1,
        voiceId: 'v',
        units: _makeUnits(10),
        cache: cache,
        synthesize: (unit, path) async {},
      );
      addTearDown(scheduler.dispose);

      final ready = <int>[];
      scheduler.events
          .where((e) => e.isReady)
          .listen((e) => ready.add(e.unitIndex));

      await scheduler.start();
      await pumpEventQueue();

      expect(ready, <int>[0, 1, 2, 3]);
    });

    test('a synth failure emits a failed event and stops the pump', () async {
      final cache = _FakeCache();
      final synthCalls = <int>[];
      final scheduler = LookAheadScheduler(
        bookId: 1,
        voiceId: 'v',
        units: _makeUnits(10),
        cache: cache,
        synthesize: (unit, path) async {
          synthCalls.add(unit.index);
          if (unit.index == 2) throw StateError('boom');
        },
      );
      addTearDown(scheduler.dispose);

      final failed = <int>[];
      scheduler.events
          .where((e) => e.kind == SynthEventKind.failed)
          .listen((e) => failed.add(e.unitIndex));

      await scheduler.start();
      await pumpEventQueue();

      expect(synthCalls, <int>[0, 1, 2]);
      expect(failed, <int>[2]);
      expect(scheduler.isReady(1), isTrue);
      expect(scheduler.isReady(2), isFalse);
    });

    test('evicts ready units outside the rolling window on seek', () async {
      final cache = _FakeCache();
      final scheduler = LookAheadScheduler(
        bookId: 1,
        voiceId: 'v',
        units: _makeUnits(20),
        cache: cache,
        synthesize: (unit, path) async {},
      );
      addTearDown(scheduler.dispose);

      await scheduler.start();
      scheduler.seekTo(10);
      await pumpEventQueue();

      // behind defaults to 1, lookAhead 3 → window [9, 13].
      expect(cache.rendered, containsAll(<int>[10, 11, 12, 13]));
      expect(cache.rendered, isNot(contains(0)));
      expect(cache.evictions.last, (lo: 9, hi: 13));
    });
  });
}
