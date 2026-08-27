import 'dart:async';
import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/tts/tts_service.dart';
import '../../../../core/utils/narration_segmenter.dart';
import '../../data/datasources/narration_progress_data_source.dart';
import '../../data/repositories/synth_cache.dart';
import '../../domain/entities/narration_playback.dart';
import '../../domain/entities/narration_progress.dart';
import '../../domain/services/look_ahead_scheduler.dart';

/// Renders one narration unit to a WAV file in the selected voice. Matches the
/// shape of `NarrationEngine.synthesize` so it can be injected as a tear-off.
typedef SynthesizeToFile =
    Future<SpeakResult> Function({
      required String text,
      required String referenceWavPath,
      required String outputWavPath,
    });

/// The background narration player.
///
/// Bridges the pre-render pipeline (a [LookAheadScheduler] feeding the disk
/// [SynthCache]) to `just_audio`, one narration unit at a time. Playback never
/// runs past the synthesized frontier: if the next unit isn't rendered yet the
/// player enters a **buffering** state and auto-resumes when the scheduler
/// delivers it. Running inside `audio_service` gives lock-screen / notification
/// controls and background playback.
///
/// A rolling window (not a whole-book playlist) is what's on disk at any time,
/// so this drives a *virtual* playlist indexed by unit rather than a fixed
/// `ConcatenatingAudioSource`.
class NarrationAudioHandler extends BaseAudioHandler {
  NarrationAudioHandler({
    required this._cache,
    required this._progress,
    required this._synthesize,
  }) {
    _processingSub = _player.processingStateStream.listen((processing) {
      if (processing == ProcessingState.completed) {
        unawaited(_advance());
      }
    });
  }

  final SynthCache _cache;
  final NarrationProgressDataSource _progress;
  final SynthesizeToFile _synthesize;

  /// How many units to pre-render as a "head start" before playback begins (and
  /// the lead the scheduler then keeps ahead of the play head). On-device
  /// synthesis is slower than real time, so a cushion keeps playback smooth
  /// without pre-rendering the whole book. Chosen by the user per session via
  /// [load]'s `prepLead`.
  int _prepLead = 8;

  final AudioPlayer _player = AudioPlayer();
  final StreamController<NarrationPlaybackState> _stateController =
      StreamController<NarrationPlaybackState>.broadcast();

  LookAheadScheduler? _scheduler;
  StreamSubscription<SynthEvent>? _schedulerSub;
  StreamSubscription<ProcessingState>? _processingSub;

  List<NarrationUnit> _units = const <NarrationUnit>[];
  int? _bookId;
  String _bookTitle = '';
  String? _voiceId;
  String _voiceName = '';
  String? _voiceWav;
  int _index = 0;
  bool _playIntent = false;

  // Head-start preparation state.
  bool _preparing = false;
  int _prepStartIndex = 0;
  int _prepTarget = 0;
  Duration _resumeAt = Duration.zero;
  final Set<int> _preparedAhead = <int>{};

  int _genMsSum = 0;
  int _genCount = 0;

  NarrationPlaybackState _state = const NarrationPlaybackState();

  /// The latest playback snapshot (for seeding new stream listeners).
  NarrationPlaybackState get state => _state;

  /// Playback snapshots for the player screen + mini-player.
  Stream<NarrationPlaybackState> get stateStream => _stateController.stream;

  /// Loads a book+voice and (optionally) starts playing, resuming from the
  /// saved position when the voice matches. Re-narrating in a different voice is
  /// just another [load] with the new voice.
  Future<void> load({
    required int bookId,
    required String bookTitle,
    required String voiceId,
    required String voiceName,
    required String voiceWavPath,
    required List<NarrationUnit> units,
    int prepLead = 8,
    double speed = 1.0,
    bool autoplay = true,
    int? startUnit,
  }) async {
    if (_bookId == bookId && _voiceId == voiceId && _scheduler != null) {
      // Same session already loaded — just seek/(re)start playback.
      if (startUnit != null) await seekToUnit(startUnit);
      _playIntent = autoplay;
      if (autoplay) await play();
      return;
    }

    await _schedulerSub?.cancel();
    await _scheduler?.dispose();
    await _player.stop();

    _bookId = bookId;
    _bookTitle = bookTitle;
    _voiceId = voiceId;
    _voiceName = voiceName;
    _voiceWav = voiceWavPath;
    _units = units;
    _playIntent = autoplay;
    _index = 0;

    _emit(status: NarrationStatus.loading, resetError: true, speed: speed);

    if (units.isEmpty) {
      _emit(status: NarrationStatus.error, error: 'Nothing to narrate.');
      return;
    }

    var startAt = Duration.zero;
    final saved = await _progress.get(bookId);
    if (saved != null && saved.voiceId == voiceId) {
      _index = saved.unitIndex.clamp(0, units.length - 1);
      startAt = Duration(milliseconds: saved.positionMs);
    }
    if (startUnit != null) {
      _index = startUnit.clamp(0, units.length - 1);
      startAt = Duration.zero;
    }

    _prepLead = prepLead < 1 ? 1 : prepLead;

    final scheduler = LookAheadScheduler(
      bookId: bookId,
      voiceId: voiceId,
      units: units,
      cache: _cache,
      synthesize: _synthUnit,
      lookAhead: _prepLead - 1,
    );
    _scheduler = scheduler;
    _schedulerSub = scheduler.events.listen(_onSchedulerEvent);

    mediaItem.add(
      MediaItem(id: 'book-$bookId', title: bookTitle, artist: voiceName),
    );

    // Pre-render a bounded head start before playback so it runs without the
    // per-unit stalls that on-device synthesis (slower than real time) would
    // otherwise cause. Only a small lead is buffered, not the whole book; the
    // scheduler then keeps topping it up as the play head advances.
    _enterPreparing(resumeAt: startAt, resetStats: true);
    unawaited(scheduler.start());
  }

  /// Enters (or re-enters, when playback later catches up to the render
  /// frontier) the head-start phase: rebuild a bounded lead of rendered units
  /// before (re)starting playback, showing the preparing progress + ETA.
  void _enterPreparing({required Duration resumeAt, bool resetStats = false}) {
    _resumeAt = resumeAt;
    _prepStartIndex = _index;
    _preparedAhead.clear();
    if (resetStats) {
      _genMsSum = 0;
      _genCount = 0;
    }
    _prepTarget = math.min(_prepLead, _units.length - _index);
    _preparing = true;
    final scheduler = _scheduler;
    if (scheduler != null) {
      for (var i = _index; i < _index + _prepTarget; i++) {
        if (scheduler.isReady(i)) _preparedAhead.add(i);
      }
    }
    _emitPreparing();
    scheduler?.seekTo(_index);
    if (_preparedAhead.length >= _prepTarget) {
      unawaited(_beginPlayback());
    } else if (scheduler != null) {
      // `seekTo` is intentionally a no-op when the head is unchanged; `start`
      // still re-pumps so cached clips not yet represented in its ready set are
      // discovered and reported to this preparation pass.
      unawaited(scheduler.start());
    }
  }

  /// Emits the current head-start preparation snapshot (progress + rough ETA).
  void _emitPreparing() {
    final remaining = _prepTarget - _preparedAhead.length;
    int? eta;
    if (_genCount > 0 && remaining > 0) {
      final avgMs = _genMsSum / _genCount;
      eta = (avgMs * remaining / 1000).round();
    }
    _emit(
      status: NarrationStatus.preparing,
      unitIndex: _prepStartIndex,
      currentText: _units[_prepStartIndex].text,
      preparedCount: _preparedAhead.length,
      prepTarget: _prepTarget,
      etaSeconds: eta,
    );
  }

  /// Ends the head-start phase and begins playback from the resume point.
  Future<void> _beginPlayback() async {
    if (!_preparing) return;
    _preparing = false;
    final at = _resumeAt;
    _resumeAt = Duration.zero;
    await _playCurrent(at: at, rebuildLeadIfMissing: false);
  }

  /// Skips the remaining head-start buffering and begins playback now. If the
  /// current unit isn't rendered yet, playback shows a brief buffering state
  /// and auto-resumes when it lands.
  Future<void> startPlaybackNow() {
    _playIntent = true;
    return _beginPlayback();
  }

  /// Playback reached the end of the prepared head start and the next unit
  /// isn't rendered yet. Stop the player at once (so no unrendered garbage is
  /// heard) and surface the head-start selector again so the user can choose
  /// how much to prepare for the next stretch before continuing.
  Future<void> _awaitHeadStart() async {
    _playIntent = false;
    _preparing = false;
    await _player.stop();
    _emit(
      status: NarrationStatus.awaitingHeadStart,
      unitIndex: _index,
      currentText: _units[_index].text,
    );
    await _saveProgress();
  }

  /// Prepares the next head-start batch from the current position using the
  /// (possibly changed) [prepLead], then resumes playback once it's ready.
  Future<void> continueNarration(int prepLead) async {
    if (_units.isEmpty) return;
    _prepLead = prepLead < 1 ? 1 : prepLead;
    _scheduler?.setLookAhead(_prepLead - 1);
    _playIntent = true;
    _enterPreparing(resumeAt: Duration.zero, resetStats: true);
  }

  Future<void> _synthUnit(NarrationUnit unit, String outputPath) async {
    final wav = _voiceWav;
    if (wav == null) throw StateError('No voice loaded for narration.');
    final result = await _synthesize(
      text: unit.text,
      referenceWavPath: wav,
      outputWavPath: outputPath,
    );
    _genMsSum += result.generateMillis;
    _genCount++;
  }

  void _onSchedulerEvent(SynthEvent event) {
    debugPrint(
      'GS_NARR event kind=${event.kind} unit=${event.unitIndex} '
      'idx=$_index status=${_state.status} preparing=$_preparing',
    );
    if (event.kind == SynthEventKind.failed) {
      if (_preparing || event.unitIndex == _index) {
        _preparing = false;
        _emit(
          status: NarrationStatus.error,
          error: 'Failed to render narration audio.',
        );
      }
      return;
    }

    if (_preparing) {
      final idx = event.unitIndex;
      if (idx >= _prepStartIndex && idx < _prepStartIndex + _prepTarget) {
        _preparedAhead.add(idx);
        if (_preparedAhead.length >= _prepTarget) {
          unawaited(_beginPlayback());
        } else {
          _emitPreparing();
        }
      }
      return;
    }

    if (event.unitIndex == _index &&
        _state.status == NarrationStatus.buffering) {
      unawaited(_playCurrent());
      return;
    }

    // A look-ahead unit landed; refresh how far ahead is prepared.
    if (_state.status == NarrationStatus.playing ||
        _state.status == NarrationStatus.paused) {
      _emit();
    }
  }

  /// Loads the current unit's clip and plays it (or buffers if it isn't
  /// rendered yet). [at] seeks within the clip (used to restore a resume point).
  Future<void> _playCurrent({
    Duration at = Duration.zero,
    bool rebuildLeadIfMissing = true,
  }) async {
    final bookId = _bookId;
    final voiceId = _voiceId;
    if (bookId == null || voiceId == null || _units.isEmpty) return;
    if (_index >= _units.length) {
      await _complete();
      return;
    }

    final unit = _units[_index];
    final path = await _cache.cachedPath(bookId, voiceId, unit);
    debugPrint(
      'GS_NARR _playCurrent idx=$_index path=${path != null} '
      'rebuild=$rebuildLeadIfMissing playIntent=$_playIntent '
      'ready=${_scheduler?.isReady(_index)}',
    );
    if (path == null) {
      if (rebuildLeadIfMissing) {
        // Playback caught up to the render frontier. Stop immediately (so no
        // unrendered noise is heard) and let the user choose the next head
        // start before continuing.
        await _awaitHeadStart();
      } else {
        _scheduler?.seekTo(_index);
        _emit(
          status: NarrationStatus.buffering,
          unitIndex: _index,
          currentText: unit.text,
        );
      }
      return;
    }

    await _player.setFilePath(path);
    await _player.setSpeed(_state.speed);
    if (at > Duration.zero) {
      await _player.seek(at);
    }
    if (_playIntent) {
      // Emit `playing` *before* starting playback: `AudioPlayer.play()` returns
      // a future that only completes when the clip finishes, so awaiting it here
      // would delay the state update until the audio had already ended (leaving
      // the UI stuck on the prior buffering state while sound is heard).
      // Completion is handled by the processing-state listener, which advances.
      _emit(
        status: NarrationStatus.playing,
        unitIndex: _index,
        currentText: unit.text,
      );
      unawaited(_player.play());
    } else {
      _emit(
        status: NarrationStatus.paused,
        unitIndex: _index,
        currentText: unit.text,
      );
    }
  }

  Future<void> _advance() async {
    if (_units.isEmpty) return;
    if (_index + 1 >= _units.length) {
      await _complete();
      return;
    }
    _index++;
    _scheduler?.seekTo(_index);
    await _saveProgress();
    // If the next unit isn't rendered yet, buffer and auto-resume when it
    // lands (never hard-stop mid-narration and force a manual tap to continue).
    await _playCurrent(rebuildLeadIfMissing: false);
  }

  Future<void> _complete() async {
    _playIntent = false;
    _emit(status: NarrationStatus.completed);
    await _saveProgress();
  }

  @override
  Future<void> play() async {
    _playIntent = true;
    if (_preparing) {
      await _beginPlayback();
      return;
    }
    if (_state.status == NarrationStatus.awaitingHeadStart) {
      await continueNarration(_prepLead);
      return;
    }
    if (_state.status == NarrationStatus.buffering) {
      _broadcast();
      return;
    }
    if (_state.status == NarrationStatus.completed) {
      _index = 0;
      _scheduler?.seekTo(_index);
      await _playCurrent();
      return;
    }
    _emit(status: NarrationStatus.playing);
    unawaited(_player.play());
  }

  @override
  Future<void> pause() async {
    _playIntent = false;
    await _player.pause();
    _emit(status: NarrationStatus.paused);
    await _saveProgress();
  }

  @override
  Future<void> stop() async {
    _playIntent = false;
    await _saveProgress();
    await _player.stop();
    _emit(status: NarrationStatus.idle);
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_index + 1 >= _units.length) return;
    _index++;
    _scheduler?.seekTo(_index);
    await _saveProgress();
    await _playCurrent();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position > const Duration(seconds: 3) || _index == 0) {
      await _player.seek(Duration.zero);
      return;
    }
    _index--;
    _scheduler?.seekTo(_index);
    await _saveProgress();
    await _playCurrent();
  }

  /// Jumps to an arbitrary unit from the Listen scrubber. If the target clip
  /// isn't rendered yet, playback stops to let the user pick a new head start
  /// before continuing (the Listen page's explicit prepare model).
  Future<void> seekToUnit(int index) async {
    if (_units.isEmpty) return;
    _index = index.clamp(0, _units.length - 1);
    _scheduler?.seekTo(_index);
    await _saveProgress();
    await _playCurrent();
  }

  /// Jumps to [index] for the reader's "read from here" gesture. Stops the
  /// current clip first (so no stale tail keeps playing), then rebuilds the
  /// selected head start around the target before playback. This avoids
  /// starting from one isolated clip and immediately stalling inside the next
  /// paragraph while synthesis catches up.
  Future<void> readFrom(int index) async {
    if (_units.isEmpty) return;
    await _player.stop();
    _preparing = false;
    _index = index.clamp(0, _units.length - 1);
    debugPrint('GS_NARR readFrom idx=$_index');
    _playIntent = true;
    await _saveProgress();
    _enterPreparing(resumeAt: Duration.zero, resetStats: true);
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    _emit(speed: speed);
  }

  /// Highest unit index that, with the current unit, forms a contiguous run of
  /// clips still on disk — how far ahead playback can run without buffering.
  /// Reads the scheduler's live ready set (pruned as the rolling window slides)
  /// so the "prepared" band never claims an already-evicted unit is ready.
  /// Returns `_index - 1` (nothing ready) when the current unit itself isn't
  /// rendered yet, so the band never covers an unready unit.
  int _renderedFrontier() {
    final scheduler = _scheduler;
    if (scheduler == null || !scheduler.isReady(_index)) return _index - 1;
    var i = _index;
    while (scheduler.isReady(i + 1)) {
      i++;
    }
    return i;
  }

  /// Highest unit index the scheduler intends to have ready ahead of the play
  /// head (the look-ahead window edge) — how far the "going to prepare" band
  /// reaches beyond what is already rendered.
  int _plannedFrontier() {
    final scheduler = _scheduler;
    if (scheduler == null || _units.isEmpty) return _index;
    final planned = _index + scheduler.lookAhead;
    final last = _units.length - 1;
    return planned > last ? last : planned;
  }

  Future<void> _saveProgress() async {
    final bookId = _bookId;
    final voiceId = _voiceId;
    if (bookId == null || voiceId == null) return;
    await _progress.save(
      NarrationProgress(
        bookId: bookId,
        voiceId: voiceId,
        unitIndex: _index,
        positionMs: _player.position.inMilliseconds,
        updatedAt: DateTime.now(),
      ),
    );
  }

  void _emit({
    NarrationStatus? status,
    int? unitIndex,
    String? currentText,
    double? speed,
    String? error,
    bool resetError = false,
    int? preparedCount,
    int? prepTarget,
    int? etaSeconds,
  }) {
    _state = _state.copyWith(
      status: status,
      bookId: _bookId,
      bookTitle: _bookTitle,
      voiceId: _voiceId,
      voiceName: _voiceName,
      unitIndex: unitIndex,
      unitCount: _units.length,
      currentText: currentText,
      speed: speed,
      error: resetError ? null : (error ?? _state.error),
      preparedCount: preparedCount,
      prepTarget: prepTarget,
      etaSeconds: etaSeconds,
      renderedThrough: _renderedFrontier(),
      plannedThrough: _plannedFrontier(),
    );
    debugPrint(
      'GS_NARR emit status=${_state.status} idx=${_state.unitIndex} '
      'rendered=${_state.renderedThrough} planned=${_state.plannedThrough}',
    );
    _broadcast();
  }

  void _broadcast() {
    _stateController.add(_state);
    playbackState.add(
      playbackState.value.copyWith(
        controls: <MediaControl>[
          MediaControl.skipToPrevious,
          if (_state.isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const <MediaAction>{MediaAction.seek},
        androidCompactActionIndices: const <int>[0, 1, 2],
        processingState: _mapProcessing(_state.status),
        playing: _state.isPlaying,
        updatePosition: _player.position,
        speed: _state.speed,
        queueIndex: _state.unitIndex,
      ),
    );
  }

  AudioProcessingState _mapProcessing(NarrationStatus status) {
    switch (status) {
      case NarrationStatus.idle:
        return AudioProcessingState.idle;
      case NarrationStatus.loading:
        return AudioProcessingState.loading;
      case NarrationStatus.preparing:
        return AudioProcessingState.loading;
      case NarrationStatus.buffering:
        return AudioProcessingState.buffering;
      case NarrationStatus.playing:
      case NarrationStatus.paused:
      case NarrationStatus.awaitingHeadStart:
        return AudioProcessingState.ready;
      case NarrationStatus.completed:
        return AudioProcessingState.completed;
      case NarrationStatus.error:
        return AudioProcessingState.error;
    }
  }

  /// Tears down the player, scheduler, and streams. Called when the owning
  /// provider is disposed (app shutdown).
  Future<void> shutdown() async {
    await _schedulerSub?.cancel();
    await _processingSub?.cancel();
    await _scheduler?.dispose();
    await _player.dispose();
    await _stateController.close();
  }
}
