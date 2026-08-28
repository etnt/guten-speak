import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/narration_segmenter.dart';
import '../../../../core/utils/toc_extractor.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../dictionary/presentation/widgets/dictionary_lookup_sheet.dart';
import '../../../library/domain/entities/bookmark.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../../narration/domain/entities/narration_playback.dart';
import '../../../narration/presentation/providers/narration_player_providers.dart';
import '../../../narration/presentation/providers/narration_settings_providers.dart';
import '../../../narration/presentation/providers/tts_providers.dart';
import '../../../voices/domain/entities/voice.dart';
import '../../../voices/presentation/providers/voice_providers.dart';
import '../../domain/entities/reader_content.dart';
import '../providers/reader_providers.dart';
import '../providers/reader_settings_provider.dart';

/// Returns at most the first 15 Unicode code points of [title], adding an
/// ellipsis only when text was removed.
String compactReaderTitle(String title) {
  const limit = 15;
  final characters = title.runes;
  if (characters.length <= limit) return title;
  return '${String.fromCharCodes(characters.take(limit))}…';
}

/// Background/foreground colours for a reading theme.
typedef _ReaderPalette = ({Color background, Color foreground});

_ReaderPalette _paletteFor(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.light:
      return (
        background: AppColors.lightBackground,
        foreground: AppColors.lightOnSurface,
      );
    case AppThemeMode.sepia:
      return (
        background: AppColors.sepiaBackground,
        foreground: AppColors.sepiaOnSurface,
      );
    case AppThemeMode.dark:
      return (
        background: AppColors.darkBackground,
        foreground: AppColors.darkOnSurface,
      );
    case AppThemeMode.oled:
      return (
        background: AppColors.oledBackground,
        foreground: AppColors.oledOnSurface,
      );
  }
}

/// Lazy, reflowable plain-text reader with reading themes, typography controls,
/// a heuristic table of contents, and paragraph-index resume.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({required this.bookId, super.key});

  final int bookId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  ReaderController? _readerController;
  bool _restored = false;
  int _firstVisible = 0;
  // Mirrors [_firstVisible] for widgets that need to react to scrolling (the
  // bottom-bar bookmark toggle) without rebuilding the whole reader.
  final ValueNotifier<int> _firstVisibleParagraph = ValueNotifier<int>(0);
  Timer? _saveDebounce;

  // Narration sync: units are segmented the same way the player does, so the
  // reader can map the current unit → paragraph (highlight/follow) and a tapped
  // paragraph → its first unit (seek). Cached by the paragraphs list identity so
  // it's computed once per loaded book rather than on every rebuild.
  List<String>? _unitsSource;
  List<NarrationUnit> _units = const <NarrationUnit>[];
  final Map<int, int> _paraToFirstUnit = <int, int>{};
  int? _lastFollowedParagraph;
  bool _narrationCommandRunning = false;

  @override
  void initState() {
    super.initState();
    _itemPositionsListener.itemPositions.addListener(_onScroll);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _itemPositionsListener.itemPositions.removeListener(_onScroll);
    _firstVisibleParagraph.dispose();
    // Best-effort final save of the last known position. Uses the captured
    // controller (kept alive) rather than `ref`, which is invalid in dispose.
    unawaited(_readerController?.saveProgress(widget.bookId, _firstVisible));
    super.dispose();
  }

  void _onScroll() {
    final index = _computeFirstVisibleIndex();
    if (index != _firstVisible) {
      _firstVisible = index;
      _firstVisibleParagraph.value = index;
      _saveDebounce?.cancel();
      _saveDebounce = Timer(const Duration(seconds: 1), () {
        unawaited(
          _readerController?.saveProgress(widget.bookId, _firstVisible),
        );
      });
    }
  }

  int _computeFirstVisibleIndex() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return _firstVisible;
    // The top-most paragraph whose start is visible (leading edge at or below
    // the viewport's top). Fall back to the top-most partly-visible paragraph
    // when a single tall paragraph fills the viewport. Positions are unordered,
    // so we scan them all instead of trusting iteration order.
    int? firstWithVisibleStart;
    int? firstPartlyVisible;
    for (final p in positions) {
      if (p.itemTrailingEdge <= 0) continue; // entirely above the viewport
      if (firstPartlyVisible == null || p.index < firstPartlyVisible) {
        firstPartlyVisible = p.index;
      }
      if (p.itemLeadingEdge >= 0 &&
          (firstWithVisibleStart == null || p.index < firstWithVisibleStart)) {
        firstWithVisibleStart = p.index;
      }
    }
    return firstWithVisibleStart ?? firstPartlyVisible ?? _firstVisible;
  }

  void _jumpToParagraph(int index) {
    if (index < 0 || !_itemScrollController.isAttached) return;
    unawaited(
      _itemScrollController.scrollTo(
        index: index,
        alignment: _topBarAlignment,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ),
    );
  }

  /// Leading-edge alignment (fraction of the viewport) that places a target
  /// paragraph just below the overlaid top bar instead of behind it.
  double get _topBarAlignment {
    final media = MediaQuery.of(context);
    final height = media.size.height;
    if (height <= 0) return 0;
    return (media.padding.top + 64) / height;
  }

  /// Segments [content] into narration units (matching the player) and builds
  /// the paragraph → first-unit lookup, caching by the paragraphs list identity
  /// so it only runs once per loaded book.
  List<NarrationUnit> _unitsFor(ReaderContent content) {
    if (identical(_unitsSource, content.paragraphs)) return _units;
    _unitsSource = content.paragraphs;
    _units = const NarrationSegmenter().segmentParagraphs(content.paragraphs);
    _paraToFirstUnit.clear();
    for (final unit in _units) {
      _paraToFirstUnit.putIfAbsent(unit.paragraphIndex, () => unit.index);
    }
    return _units;
  }

  /// The paragraph the narrator is currently on, or null when playback isn't
  /// active for this book or the unit index is out of range.
  int? _narratedParagraph(NarrationPlaybackState? playback) {
    if (playback == null ||
        playback.bookId != widget.bookId ||
        !playback.isActive) {
      return null;
    }
    final index = playback.unitIndex;
    if (index < 0 || index >= _units.length) return null;
    return _units[index].paragraphIndex;
  }

  /// The paragraph through which narration audio is currently prepared ahead of
  /// the play head (used to shade the "ready" band). Null when not narrating
  /// this book or the rendered frontier is out of range.
  int? _preparedThroughParagraph(NarrationPlaybackState? playback) {
    if (playback == null ||
        playback.bookId != widget.bookId ||
        !playback.isActive) {
      return null;
    }
    final through = playback.renderedThrough;
    if (through < 0 || through >= _units.length) return null;
    final paragraph = _units[through].paragraphIndex;
    final paragraphFullyPrepared =
        through == _units.length - 1 ||
        _units[through + 1].paragraphIndex != paragraph;
    return paragraphFullyPrepared ? paragraph : paragraph - 1;
  }

  /// The paragraph through which narration audio is queued to be prepared (the
  /// scheduler's look-ahead edge, beyond what is rendered). Null when not
  /// narrating this book or the frontier is out of range.
  int? _plannedThroughParagraph(NarrationPlaybackState? playback) {
    if (playback == null ||
        playback.bookId != widget.bookId ||
        !playback.isActive) {
      return null;
    }
    final through = playback.plannedThrough;
    if (through < 0 || through >= _units.length) return null;
    return _units[through].paragraphIndex;
  }

  /// The first narration unit at or after [paragraphIndex] (paragraphs with no
  /// speakable units — e.g. dividers — are skipped forward to the next one).
  int? _firstUnitAtOrAfter(int paragraphIndex, int paragraphCount) {
    for (var p = paragraphIndex; p < paragraphCount; p++) {
      final unit = _paraToFirstUnit[p];
      if (unit != null) return unit;
    }
    return null;
  }

  /// Follows narration while it plays: scrolls the tapped/played paragraph into
  /// view when the narrator moves to a new one.
  void _followNarration(NarrationPlaybackState? playback) {
    if (playback == null || !playback.isPlaying) return;
    final paragraph = _narratedParagraph(playback);
    if (paragraph == null || paragraph == _lastFollowedParagraph) return;
    _lastFollowedParagraph = paragraph;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToParagraph(paragraph);
    });
  }

  /// Handles a paragraph tap: seek the narrator there when it's narrating this
  /// book. When not narrating, tapping does nothing (the reading controls stay
  /// visible at all times).
  Future<void> _onParagraphTap(int index, int paragraphCount) async {
    final playback = ref.read(narrationPlaybackProvider).valueOrNull;
    final narrating =
        playback != null &&
        playback.bookId == widget.bookId &&
        playback.isActive;
    if (!narrating) {
      return;
    }
    // A paragraph may contain several narration units. Seeking an active
    // paragraph to its first unit makes an extra tap during buffering replay
    // speech the user has already heard.
    if (index == _narratedParagraph(playback)) {
      return;
    }
    final unit = _firstUnitAtOrAfter(index, paragraphCount);
    if (unit == null) {
      return;
    }
    final handler = await ref.read(narrationAudioHandlerProvider.future);
    await handler.seekToUnit(unit);
  }

  /// Handles a paragraph double-tap while the narrator is enabled. Tapping the
  /// paragraph being read toggles play/pause; tapping another paragraph reads
  /// from there. Narration must first be enabled from the bottom bar.
  Future<void> _onParagraphReadFromHere(int index, int paragraphCount) async {
    final unit = _firstUnitAtOrAfter(index, paragraphCount);
    if (unit == null) return;

    final playback = ref.read(narrationPlaybackProvider).valueOrNull;
    final loaded =
        playback != null &&
        playback.bookId == widget.bookId &&
        playback.isActive;
    if (loaded) {
      final handler = await ref.read(narrationAudioHandlerProvider.future);
      if (!mounted) return;
      if (index == _narratedParagraph(playback)) {
        // A second double-tap may explicitly start a blue (already rendered)
        // current paragraph before the rest of the configured head start is
        // ready. A red current paragraph remains in preparation.
        if (playback.isPlaying) {
          await handler.pause();
        } else if (playback.status == NarrationStatus.paused ||
            playback.status == NarrationStatus.awaitingHeadStart ||
            playback.status == NarrationStatus.completed) {
          await handler.play();
        } else if (playback.status == NarrationStatus.preparing &&
            playback.renderedThrough >= playback.unitIndex) {
          await handler.startPlaybackNow();
        }
        return;
      }
      await handler.readFrom(unit);
      return;
    }

    _showNarrationMessage('Enable the narrator from the bottom bar first.');
  }

  /// Resolves the persisted narrator, falling back to and selecting the first
  /// bundled voice so narration can be started entirely from the Reader.
  Future<Voice?> _resolveNarrationVoice() async {
    try {
      final voices = await ref.read(voicesControllerProvider.future);
      if (!mounted) return null;
      final selected = ref.read(selectedVoiceProvider);
      if (selected != null) return selected;
      if (voices.isEmpty) {
        _showNarrationMessage('No narrator voices are available.');
        return null;
      }
      final fallback = voices.first;
      ref.read(selectedVoiceProvider.notifier).select(fallback);
      return fallback;
    } catch (error) {
      if (mounted) _showNarrationMessage('Could not load narrator voices.');
      return null;
    }
  }

  /// Loads the engine in place. The large first-time model download retains an
  /// explicit consent gate; an installed model is loaded without another
  /// prompt.
  Future<bool> _ensureNarrationReady() async {
    final prep = ref.read(narrationEngineProvider);
    if (prep.isReady) return true;
    if (prep.phase.isBusy) return false;

    final installed = await ref.read(modelInstalledProvider.future);
    if (!mounted) return false;
    if (!installed) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Enable narration?'),
          content: const Text(
            'On-device narration needs a one-time voice-model download '
            '(~470 MB). It is stored on this device and works offline.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.download),
              label: const Text('Download'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return false;
    }

    final ready = await ref.read(narrationEngineProvider.notifier).prepare();
    if (!mounted || ready) return ready;
    final failed = ref.read(narrationEngineProvider);
    if (failed.error != null) {
      _showNarrationMessage('Could not enable narration: ${failed.error}');
    }
    return false;
  }

  Future<void> _toggleNarrator(ReaderContent content) async {
    if (_narrationCommandRunning) return;
    setState(() => _narrationCommandRunning = true);
    try {
      final playback = ref.read(narrationPlaybackProvider).valueOrNull;
      final currentBook =
          playback != null &&
          playback.bookId == widget.bookId &&
          playback.isActive;
      if (currentBook) {
        final handler = await ref.read(narrationAudioHandlerProvider.future);
        await handler.stop();
        return;
      }

      final voice = await _resolveNarrationVoice();
      if (voice == null || !await _ensureNarrationReady()) return;

      final handler = await ref.read(narrationAudioHandlerProvider.future);
      if (!mounted) return;
      final startUnit =
          _firstUnitAtOrAfter(_firstVisible, content.paragraphs.length) ?? 0;
      await handler.load(
        bookId: widget.bookId,
        bookTitle: content.book.title,
        voiceId: voice.id,
        voiceName: voice.name,
        voiceWavPath: voice.wavPath,
        units: _units,
        prepLead: ref.read(headStartProvider),
        speed: ref.read(narrationSpeedProvider),
        autoplay: false,
        startUnit: startUnit,
      );
    } finally {
      if (mounted) setState(() => _narrationCommandRunning = false);
    }
  }

  Future<void> _selectNarrationVoice(ReaderContent content, Voice voice) async {
    ref.read(selectedVoiceProvider.notifier).select(voice);
    if (_narrationCommandRunning) return;

    final playback = ref.read(narrationPlaybackProvider).valueOrNull;
    final currentBook =
        playback != null &&
        playback.bookId == widget.bookId &&
        playback.isActive;
    if (!currentBook || playback.voiceId == voice.id) return;

    setState(() => _narrationCommandRunning = true);
    try {
      final handler = await ref.read(narrationAudioHandlerProvider.future);
      await handler.load(
        bookId: widget.bookId,
        bookTitle: content.book.title,
        voiceId: voice.id,
        voiceName: voice.name,
        voiceWavPath: voice.wavPath,
        units: _units,
        prepLead: ref.read(headStartProvider),
        speed: playback.speed,
        autoplay: playback.isPlaying,
        startUnit: playback.unitIndex,
      );
    } finally {
      if (mounted) setState(() => _narrationCommandRunning = false);
    }
  }

  void _showNarrationMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Opens the dictionary look-up sheet for a long-pressed word.
  void _onWordLongPress(String word) {
    unawaited(HapticFeedback.selectionClick());
    unawaited(showDictionaryLookup(context, word));
  }

  @override
  Widget build(BuildContext context) {
    _readerController = ref.read(readerControllerProvider.notifier);
    final contentAsync = ref.watch(readerContentProvider(widget.bookId));
    final settings = ref.watch(readerSettingsProvider);
    final palette = _paletteFor(settings.themeMode);
    final playback = ref.watch(narrationPlaybackProvider).valueOrNull;

    return Scaffold(
      backgroundColor: palette.background,
      body: contentAsync.when(
        loading: () => const LoadingView(message: 'Preparing the book…'),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(readerContentProvider(widget.bookId)),
        ),
        data: (content) => _buildReader(content, settings, palette, playback),
      ),
    );
  }

  Widget _buildReader(
    ReaderContent content,
    ReaderSettings settings,
    _ReaderPalette palette,
    NarrationPlaybackState? playback,
  ) {
    _maybeRestore();
    _unitsFor(content);
    _followNarration(playback);
    final narratedParagraph = _narratedParagraph(playback);
    final preparedThroughParagraph = _preparedThroughParagraph(playback);
    final plannedThroughParagraph = _plannedThroughParagraph(playback);

    final headingIndices = <int>{for (final e in content.toc) e.paragraphIndex};
    final bookmarkedIndices = <int>{
      for (final b
          in ref.watch(bookmarksProvider(widget.bookId)).valueOrNull ??
              const <Bookmark>[])
        b.paragraphIndex,
    };
    final baseSize = 18.0 * settings.fontScale;

    return Stack(
      children: [
        ScrollablePositionedList.builder(
          itemScrollController: _itemScrollController,
          itemPositionsListener: _itemPositionsListener,
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.of(context).padding.top + 64,
            20,
            MediaQuery.of(context).padding.bottom + 80,
          ),
          itemCount: content.paragraphs.length,
          itemBuilder: (context, index) {
            final isHeading = headingIndices.contains(index);
            final isNarrated = index == narratedParagraph;
            final currentAudioReady =
                isNarrated &&
                (playback?.status == NarrationStatus.playing ||
                    playback?.status == NarrationStatus.paused);
            final isPrepared =
                narratedParagraph != null &&
                (currentAudioReady ||
                    (preparedThroughParagraph != null &&
                        index >= narratedParagraph &&
                        index <= preparedThroughParagraph));
            final isPlanned =
                !isPrepared &&
                narratedParagraph != null &&
                plannedThroughParagraph != null &&
                index >= narratedParagraph &&
                index <= plannedThroughParagraph;
            final bandColor = isPrepared
                ? Colors.blue
                : (isPlanned ? Colors.redAccent : null);
            return _ReaderParagraph(
              text: content.paragraphs[index],
              style: TextStyle(
                color: palette.foreground,
                fontSize: isHeading ? baseSize * 1.25 : baseSize,
                height: 1.5,
                fontWeight: isHeading ? FontWeight.bold : FontWeight.normal,
              ),
              textScaler: MediaQuery.textScalerOf(context),
              isNarrated: isNarrated,
              speakerActive: playback?.isPlaying ?? false,
              isBookmarked: bookmarkedIndices.contains(index),
              bandColor: bandColor,
              highlightColor: palette.foreground.withValues(alpha: 0.08),
              onTap: () =>
                  unawaited(_onParagraphTap(index, content.paragraphs.length)),
              onDoubleTap: () => unawaited(
                _onParagraphReadFromHere(index, content.paragraphs.length),
              ),
              onWordLongPress: _onWordLongPress,
            );
          },
        ),
        _buildTopBar(content, settings, palette),
        _buildBottomBar(content, palette, playback),
      ],
    );
  }

  void _maybeRestore() {
    if (_restored) return;
    final progressAsync = ref.watch(readingProgressProvider(widget.bookId));
    final progress = progressAsync.valueOrNull;
    if (progressAsync.isLoading) return;
    _restored = true;
    final index = progress?.paragraphIndex ?? 0;
    if (index <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _firstVisible = index;
      _firstVisibleParagraph.value = index;
      if (_itemScrollController.isAttached) {
        _itemScrollController.jumpTo(index: index, alignment: _topBarAlignment);
      }
    });
  }

  Widget _buildTopBar(
    ReaderContent content,
    ReaderSettings settings,
    _ReaderPalette palette,
  ) {
    final notifier = ref.read(readerSettingsProvider.notifier);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: palette.background.withValues(alpha: 0.95),
        elevation: 1,
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: palette.foreground),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: Text(
                  compactReaderTitle(content.book.title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.text_decrease, color: palette.foreground),
                tooltip: 'Smaller text',
                onPressed: notifier.decreaseFont,
              ),
              IconButton(
                icon: Icon(Icons.text_increase, color: palette.foreground),
                tooltip: 'Larger text',
                onPressed: notifier.increaseFont,
              ),
              IconButton(
                icon: Icon(Icons.palette_outlined, color: palette.foreground),
                tooltip: 'Reading theme',
                onPressed: () => _showThemeSheet(settings, palette),
              ),
              IconButton(
                icon: Icon(Icons.list, color: palette.foreground),
                tooltip: 'Contents',
                onPressed: content.hasToc
                    ? () => _showTocSheet(content, palette)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(
    ReaderContent content,
    _ReaderPalette palette,
    NarrationPlaybackState? playback,
  ) {
    final prep = ref.watch(narrationEngineProvider);
    final voicesAsync = ref.watch(voicesControllerProvider);
    final voices = voicesAsync.valueOrNull ?? const <Voice>[];
    final selected = ref.watch(selectedVoiceProvider);
    final bookmarks =
        ref.watch(bookmarksProvider(widget.bookId)).valueOrNull ??
        const <Bookmark>[];
    final currentBook =
        playback != null &&
        playback.bookId == widget.bookId &&
        playback.isActive;
    final playbackVoiceId = currentBook ? playback.voiceId : null;
    Voice? activeVoice;
    for (final voice in voices) {
      if (voice.id == (playbackVoiceId ?? selected?.id)) {
        activeVoice = voice;
        break;
      }
    }
    activeVoice ??= selected ?? (voices.isEmpty ? null : voices.first);

    final modelBusy = prep.phase.isBusy;
    final playbackBusy =
        currentBook &&
        (playback.status == NarrationStatus.loading || playback.isBuffering);
    final preparing = currentBook && playback.isPreparing;
    final showProgress =
        _narrationCommandRunning || modelBusy || playbackBusy || preparing;
    final narratorTooltip = modelBusy
        ? 'Cancel narration setup'
        : currentBook
        ? 'Disable narrator'
        : 'Enable narrator';

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Material(
        color: palette.background.withValues(alpha: 0.95),
        elevation: 1,
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (voicesAsync.isLoading)
                const SizedBox.square(
                  dimension: 48,
                  child: Center(
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                PopupMenuButton<String>(
                  initialValue: activeVoice?.id,
                  tooltip: activeVoice == null
                      ? 'Narrator voice unavailable'
                      : 'Narrator voice: ${activeVoice.name}',
                  enabled: voices.isNotEmpty && !_narrationCommandRunning,
                  color: palette.background,
                  icon: Icon(
                    Icons.record_voice_over_outlined,
                    color: voices.isEmpty
                        ? palette.foreground.withValues(alpha: 0.38)
                        : palette.foreground,
                  ),
                  onSelected: (id) {
                    final voice = voices.firstWhere((voice) => voice.id == id);
                    unawaited(_selectNarrationVoice(content, voice));
                  },
                  itemBuilder: (context) => [
                    for (final voice in voices)
                      PopupMenuItem<String>(
                        value: voice.id,
                        child: Row(
                          children: [
                            if (voice.id == activeVoice?.id) ...[
                              Icon(Icons.check, color: palette.foreground),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Text(
                                voice.name,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: palette.foreground),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              IconButton(
                iconSize: 30,
                style: IconButton.styleFrom(
                  foregroundColor: palette.foreground,
                  backgroundColor: currentBook
                      ? palette.foreground.withValues(alpha: 0.16)
                      : Colors.transparent,
                ),
                tooltip: narratorTooltip,
                onPressed: modelBusy
                    ? ref.read(narrationEngineProvider.notifier).cancel
                    : _narrationCommandRunning
                    ? null
                    : () => unawaited(_toggleNarrator(content)),
                icon: showProgress
                    ? SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.foreground,
                        ),
                      )
                    : Icon(
                        currentBook
                            ? Icons.record_voice_over
                            : Icons.voice_over_off,
                      ),
              ),
              ValueListenableBuilder<int>(
                valueListenable: _firstVisibleParagraph,
                builder: (context, paragraph, _) {
                  final existing = _bookmarkAt(bookmarks, paragraph);
                  final marked = existing != null;
                  return IconButton(
                    icon: Icon(
                      marked ? Icons.bookmark : Icons.bookmark_border,
                      color: palette.foreground,
                    ),
                    tooltip: marked ? 'Remove bookmark' : 'Add bookmark',
                    onPressed: () =>
                        unawaited(_toggleBookmark(paragraph, existing)),
                  );
                },
              ),
              IconButton(
                icon: Icon(Icons.bookmarks_outlined, color: palette.foreground),
                tooltip: 'Bookmarks',
                onPressed: () =>
                    unawaited(_showBookmarksSheet(content, palette)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Returns the bookmark at [paragraphIndex], or `null` when none exists.
  Bookmark? _bookmarkAt(List<Bookmark> bookmarks, int paragraphIndex) {
    for (final bookmark in bookmarks) {
      if (bookmark.paragraphIndex == paragraphIndex) return bookmark;
    }
    return null;
  }

  Future<void> _toggleBookmark(int paragraphIndex, Bookmark? existing) async {
    final controller = ref.read(bookmarkControllerProvider.notifier);
    if (existing != null) {
      await controller.remove(widget.bookId, existing.id!);
      _showBookmarkMessage('Bookmark removed');
    } else {
      await controller.add(widget.bookId, paragraphIndex);
      _showBookmarkMessage('Bookmark added');
    }
  }

  void _showBookmarkMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// A human-readable label for [bookmark]: its note, else the nearest preceding
  /// chapter title plus its paragraph position.
  String _bookmarkLabel(ReaderContent content, Bookmark bookmark) {
    final note = bookmark.note?.trim();
    if (note != null && note.isNotEmpty) return note;
    String? chapter;
    for (final entry in content.toc) {
      if (entry.paragraphIndex <= bookmark.paragraphIndex) {
        chapter = entry.title;
      } else {
        break;
      }
    }
    final position = 'Paragraph ${bookmark.paragraphIndex + 1}';
    return chapter == null ? position : '$chapter · $position';
  }

  Future<void> _showBookmarksSheet(
    ReaderContent content,
    _ReaderPalette palette,
  ) async {
    final selected = await showModalBottomSheet<Bookmark>(
      context: context,
      backgroundColor: palette.background,
      builder: (context) {
        return SafeArea(
          child: Consumer(
            builder: (context, ref, _) {
              final bookmarks =
                  ref.watch(bookmarksProvider(widget.bookId)).valueOrNull ??
                  const <Bookmark>[];
              if (bookmarks.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No bookmarks yet',
                    style: TextStyle(color: palette.foreground),
                  ),
                );
              }
              return ListView(
                shrinkWrap: true,
                children: [
                  for (final bookmark in bookmarks)
                    ListTile(
                      leading: Icon(Icons.bookmark, color: palette.foreground),
                      title: Text(
                        _bookmarkLabel(content, bookmark),
                        style: TextStyle(color: palette.foreground),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: palette.foreground,
                        ),
                        tooltip: 'Delete bookmark',
                        onPressed: () => unawaited(
                          ref
                              .read(bookmarkControllerProvider.notifier)
                              .remove(widget.bookId, bookmark.id!),
                        ),
                      ),
                      onTap: () => Navigator.of(context).pop(bookmark),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
    if (selected != null) {
      _jumpToParagraph(selected.paragraphIndex);
    }
  }

  Future<void> _showTocSheet(
    ReaderContent content,
    _ReaderPalette palette,
  ) async {
    final selected = await showModalBottomSheet<TocEntry>(
      context: context,
      backgroundColor: palette.background,
      builder: (context) {
        return SafeArea(
          child: ListView(
            children: [
              for (final entry in content.toc)
                ListTile(
                  title: Text(
                    entry.title,
                    style: TextStyle(color: palette.foreground),
                  ),
                  onTap: () => Navigator.of(context).pop(entry),
                ),
            ],
          ),
        );
      },
    );
    if (selected != null) {
      _jumpToParagraph(selected.paragraphIndex);
    }
  }

  Future<void> _showThemeSheet(
    ReaderSettings settings,
    _ReaderPalette palette,
  ) async {
    final notifier = ref.read(readerSettingsProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.background,
      builder: (context) {
        return SafeArea(
          child: RadioGroup<AppThemeMode>(
            groupValue: settings.themeMode,
            onChanged: (value) {
              if (value != null) {
                unawaited(notifier.setThemeMode(value));
                Navigator.of(context).pop();
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final mode in AppThemeMode.values)
                  RadioListTile<AppThemeMode>(
                    value: mode,
                    title: Text(
                      _themeLabel(mode),
                      style: TextStyle(color: palette.foreground),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _themeLabel(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.sepia:
        return 'Sepia';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.oled:
        return 'AMOLED';
    }
  }
}

/// A single reader paragraph: tap to seek narration (handled by [onTap]),
/// double-tap to read from here ([onDoubleTap]), and long-press a word to look
/// it up ([onWordLongPress]). The pressed word is resolved by hit-testing the
/// rendered [Text]'s [RenderParagraph] directly, so detection stays accurate at
/// any font size or family.
class _ReaderParagraph extends StatefulWidget {
  const _ReaderParagraph({
    required this.text,
    required this.style,
    required this.textScaler,
    required this.isNarrated,
    required this.speakerActive,
    required this.isBookmarked,
    required this.bandColor,
    required this.highlightColor,
    required this.onTap,
    required this.onDoubleTap,
    required this.onWordLongPress,
  });

  final String text;
  final TextStyle style;
  final TextScaler textScaler;
  final bool isNarrated;
  final bool speakerActive;
  final bool isBookmarked;
  final Color? bandColor;
  final Color highlightColor;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final void Function(String word) onWordLongPress;

  @override
  State<_ReaderParagraph> createState() => _ReaderParagraphState();
}

class _ReaderParagraphState extends State<_ReaderParagraph> {
  final GlobalKey _textKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onLongPressStart: _handleLongPress,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: widget.bandColor ?? Colors.transparent,
                width: 4,
              ),
            ),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: widget.isNarrated
                  ? widget.highlightColor
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.isNarrated)
                  Padding(
                    padding: const EdgeInsets.only(top: 3, right: 6),
                    child: Icon(
                      widget.speakerActive ? Icons.volume_up : Icons.volume_off,
                      size: 16,
                      color: widget.style.color,
                    ),
                  ),
                Expanded(
                  child: Text(
                    widget.text,
                    key: _textKey,
                    style: widget.style,
                    textScaler: widget.textScaler,
                  ),
                ),
                if (widget.isBookmarked)
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 6),
                    child: Icon(
                      Icons.bookmark,
                      size: 16,
                      color: widget.style.color,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleLongPress(LongPressStartDetails details) {
    final renderObject = _textKey.currentContext?.findRenderObject();
    if (renderObject is! RenderParagraph) return;
    final local = renderObject.globalToLocal(details.globalPosition);
    final size = renderObject.size;
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx > size.width ||
        local.dy > size.height) {
      return;
    }
    final position = renderObject.getPositionForOffset(local);
    final range = renderObject.getWordBoundary(position);
    if (range.start < 0 || range.end <= range.start) return;
    final word = _normalizeWord(widget.text.substring(range.start, range.end));
    if (word != null) widget.onWordLongPress(word);
  }
}

/// Extracts a lookup-able word from a raw text selection, keeping internal
/// apostrophes and hyphens but trimming surrounding punctuation. Returns null
/// when there are no letters (e.g. a tapped space or symbol).
String? _normalizeWord(String raw) {
  final match = RegExp(r"[A-Za-z](?:[A-Za-z'\-]*[A-Za-z])?").firstMatch(raw);
  return match?.group(0);
}
