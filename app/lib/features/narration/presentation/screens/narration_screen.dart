import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/narration_segmenter.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../reader/presentation/providers/reader_providers.dart';
import '../../../voices/domain/entities/voice.dart';
import '../../../voices/presentation/providers/voice_providers.dart';
import '../../domain/entities/narration_playback.dart';
import '../../domain/entities/narration_prep_progress.dart';
import '../providers/narration_player_providers.dart';
import '../providers/tts_providers.dart';

/// The narration player screen.
///
/// Gates the one-time ~470 MB voice-model download behind explicit consent,
/// then drives the background player: pick a narrator voice, play/pause, skip
/// units, adjust speed, and follow the current line. Playback continues in the
/// background and is controllable from the media notification.
class NarrationScreen extends ConsumerWidget {
  const NarrationScreen({required this.bookId, super.key});

  final int bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(readerContentProvider(bookId));

    return Scaffold(
      appBar: AppBar(title: const Text('Listen')),
      body: contentAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => const EmptyView(
          icon: Icons.menu_book_outlined,
          message:
              'Download this book first (open it with "Read now"), then come '
              'back to listen.',
        ),
        data: (content) {
          final units = const NarrationSegmenter().segmentParagraphs(
            content.paragraphs,
          );
          if (units.isEmpty) {
            return const EmptyView(
              message: 'There is no readable text to narrate.',
            );
          }
          return _NarrationBody(
            bookId: bookId,
            bookTitle: content.book.title,
            units: units,
          );
        },
      ),
    );
  }
}

/// The player UI once the book's text is segmented into units.
class _NarrationBody extends ConsumerWidget {
  const _NarrationBody({
    required this.bookId,
    required this.bookTitle,
    required this.units,
  });

  final int bookId;
  final String bookTitle;
  final List<NarrationUnit> units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prep = ref.watch(narrationEngineProvider);
    final voicesAsync = ref.watch(voicesControllerProvider);
    final selected = ref.watch(selectedVoiceProvider);
    final voices = voicesAsync.valueOrNull ?? const <Voice>[];
    final activeVoice = selected ?? (voices.isEmpty ? null : voices.first);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(bookTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: 24),

        // Voice picker.
        Text('Narrator voice', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        voicesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => ErrorView(error: error),
          data: (voices) {
            if (voices.isEmpty) {
              return const EmptyView(message: 'No voices available.');
            }
            final effective = selected ?? voices.first;
            return DropdownButtonFormField<String>(
              initialValue: effective.id,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: [
                for (final voice in voices)
                  DropdownMenuItem<String>(
                    value: voice.id,
                    child: Text(voice.name),
                  ),
              ],
              onChanged: (id) {
                final voice = voices.firstWhere((v) => v.id == id);
                ref.read(selectedVoiceProvider.notifier).select(voice);
              },
            );
          },
        ),
        const SizedBox(height: 24),

        // Model gate / player.
        if (!prep.isReady)
          _PrepareCard(prep: prep)
        else
          _PlayerCard(
            bookId: bookId,
            bookTitle: bookTitle,
            units: units,
            voice: activeVoice,
          ),
      ],
    );
  }
}

/// The consent + progress card for the one-time model download.
class _PrepareCard extends ConsumerWidget {
  const _PrepareCard({required this.prep});

  final NarrationPrepProgress prep;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final engine = ref.read(narrationEngineProvider.notifier);

    if (prep.phase == NarrationPrepPhase.error) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Preparation failed', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                prep.error ?? 'Something went wrong.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => unawaited(engine.prepare()),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (prep.phase.isBusy) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_busyLabel(prep), style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: prep.fraction),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: engine.cancel,
                icon: const Icon(Icons.close),
                label: const Text('Cancel'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Enable narration', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'On-device narration needs a one-time download of the voice '
              'model (~470 MB). It is stored on your device and works offline '
              'afterwards. Best done on Wi-Fi with room to spare.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => unawaited(engine.prepare()),
              icon: const Icon(Icons.download),
              label: const Text('Download voice model'),
            ),
          ],
        ),
      ),
    );
  }

  String _busyLabel(NarrationPrepProgress prep) {
    switch (prep.phase) {
      case NarrationPrepPhase.downloading:
        final pct = prep.fraction != null
            ? ' ${(prep.fraction! * 100).round()}%'
            : '';
        return 'Downloading voice model…$pct';
      case NarrationPrepPhase.extracting:
        return 'Unpacking voice model…';
      case NarrationPrepPhase.loading:
        return 'Loading the engine…';
      case NarrationPrepPhase.idle:
      case NarrationPrepPhase.ready:
      case NarrationPrepPhase.error:
        return 'Preparing…';
    }
  }
}

/// The main player controls once the model is ready.
class _PlayerCard extends ConsumerWidget {
  const _PlayerCard({
    required this.bookId,
    required this.bookTitle,
    required this.units,
    required this.voice,
  });

  final int bookId;
  final String bookTitle;
  final List<NarrationUnit> units;
  final Voice? voice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final voice = this.voice;
    final playback =
        ref.watch(narrationPlaybackProvider).valueOrNull ??
        const NarrationPlaybackState();

    final isCurrent =
        voice != null &&
        playback.bookId == bookId &&
        playback.voiceId == voice.id;
    final unitCount = units.length;
    final unitIndex = isCurrent ? playback.unitIndex : 0;
    final currentText = isCurrent && playback.currentText.isNotEmpty
        ? playback.currentText
        : units.first.text;
    final isPlaying = isCurrent && playback.isPlaying;
    final isBuffering = isCurrent && playback.isBuffering;

    if (isCurrent && playback.isPreparing) {
      return _PreparingCard(playback: playback);
    }

    if (isCurrent && playback.isAwaitingHeadStart) {
      return _ContinueCard(units: units, unitIndex: playback.unitIndex);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Unit ${unitIndex + 1} of $unitCount',
                  style: theme.textTheme.labelLarge,
                ),
                const Spacer(),
                _SpeedButton(
                  speed: isCurrent ? playback.speed : 1.0,
                  onChanged: voice == null
                      ? null
                      : (speed) => unawaited(_setSpeed(ref, speed)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: unitCount == 0 ? 0 : (unitIndex + 1) / unitCount,
            ),
            const SizedBox(height: 16),
            Text(
              currentText,
              style: theme.textTheme.bodyLarge,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            if (!isCurrent) ...[
              const _HeadStartSelector(),
              const SizedBox(height: 8),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 36,
                  onPressed: voice == null || !isCurrent
                      ? null
                      : () => unawaited(_skipPrevious(ref)),
                  icon: const Icon(Icons.skip_previous),
                ),
                const SizedBox(width: 12),
                _PlayPauseButton(
                  isPlaying: isPlaying,
                  isBuffering: isBuffering,
                  onPressed: voice == null
                      ? null
                      : () => unawaited(
                          _togglePlay(ref, playback, voice, isCurrent),
                        ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  iconSize: 36,
                  onPressed: voice == null || !isCurrent
                      ? null
                      : () => unawaited(_skipNext(ref)),
                  icon: const Icon(Icons.skip_next),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Narration is generated on your device. A short head start is '
              'prepared before playback so it runs smoothly.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (playback.status == NarrationStatus.error &&
                playback.error != null) ...[
              const SizedBox(height: 12),
              Text(
                playback.error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _togglePlay(
    WidgetRef ref,
    NarrationPlaybackState playback,
    Voice voice,
    bool isCurrent,
  ) async {
    final handler = await ref.read(narrationAudioHandlerProvider.future);
    if (isCurrent && playback.isPlaying) {
      await handler.pause();
    } else if (isCurrent) {
      await handler.play();
    } else {
      await handler.load(
        bookId: bookId,
        bookTitle: bookTitle,
        voiceId: voice.id,
        voiceName: voice.name,
        voiceWavPath: voice.wavPath,
        units: units,
        prepLead: ref.read(headStartChunksProvider),
      );
    }
  }

  Future<void> _skipNext(WidgetRef ref) async {
    final handler = await ref.read(narrationAudioHandlerProvider.future);
    await handler.skipToNext();
  }

  Future<void> _skipPrevious(WidgetRef ref) async {
    final handler = await ref.read(narrationAudioHandlerProvider.future);
    await handler.skipToPrevious();
  }

  Future<void> _setSpeed(WidgetRef ref, double speed) async {
    final handler = await ref.read(narrationAudioHandlerProvider.future);
    await handler.setSpeed(speed);
  }
}

/// Lets the user choose how many "head start" sections to pre-render before
/// playback begins (larger = longer initial wait, smoother listening).
class _HeadStartSelector extends ConsumerWidget {
  const _HeadStartSelector();

  static const int _min = 1;
  static const int _max = 40;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chunks = ref.watch(headStartChunksProvider);
    final controller = ref.read(headStartChunksProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Head start', style: theme.textTheme.labelLarge),
            const Spacer(),
            IconButton(
              onPressed: chunks > _min
                  ? () => controller.state = chunks - 1
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('$chunks', style: theme.textTheme.titleMedium),
            IconButton(
              onPressed: chunks < _max
                  ? () => controller.state = chunks + 1
                  : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        Text(
          'Sections prepared before playback starts. More means a longer wait '
          'now but smoother, longer listening before it needs to catch up.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Shown after the prepared head start has played out: playback is stopped
/// (no noise) and the user can adjust how much to prepare next before
/// continuing.
class _ContinueCard extends ConsumerWidget {
  const _ContinueCard({required this.units, required this.unitIndex});

  final List<NarrationUnit> units;
  final int unitIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Ready to continue', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'The prepared head start has played out (up to unit '
              '${unitIndex + 1} of ${units.length}). Choose how much to '
              'prepare next, then continue.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            const _HeadStartSelector(),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => unawaited(_continue(ref)),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Prepare & continue'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => unawaited(_stop(ref)),
              icon: const Icon(Icons.close),
              label: const Text('Stop'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _continue(WidgetRef ref) async {
    final handler = await ref.read(narrationAudioHandlerProvider.future);
    await handler.continueNarration(ref.read(headStartChunksProvider));
  }

  Future<void> _stop(WidgetRef ref) async {
    final handler = await ref.read(narrationAudioHandlerProvider.future);
    await handler.stop();
  }
}

/// Shows head-start preparation progress before playback begins.
class _PreparingCard extends ConsumerWidget {
  const _PreparingCard({required this.playback});

  final NarrationPlaybackState playback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final eta = playback.etaSeconds;
    final String etaText;
    if (eta == null) {
      etaText = 'estimating…';
    } else if (eta >= 60) {
      etaText = '~${(eta / 60).ceil()} min left';
    } else {
      etaText = '~$eta s left';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Preparing narration', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Your device is rendering a head start so playback runs smoothly '
              'without pauses. This happens once for this stretch of the book — '
              'you can start now, but a very long uninterrupted listen may hit a '
              'brief catch-up pause.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: playback.prepTarget == 0 ? null : playback.prepFraction,
            ),
            const SizedBox(height: 8),
            Text(
              '${playback.preparedCount} of ${playback.prepTarget} sections '
              'ready · $etaText',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => unawaited(_startNow(ref)),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start now'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => unawaited(_cancel(ref)),
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startNow(WidgetRef ref) async {
    final handler = await ref.read(narrationAudioHandlerProvider.future);
    await handler.startPlaybackNow();
  }

  Future<void> _cancel(WidgetRef ref) async {
    final handler = await ref.read(narrationAudioHandlerProvider.future);
    await handler.stop();
  }
}

/// The round play/pause button, showing a spinner while buffering.
class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.isPlaying,
    required this.isBuffering,
    required this.onPressed,
  });

  final bool isPlaying;
  final bool isBuffering;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(20),
      ),
      child: isBuffering
          ? const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(isPlaying ? Icons.pause : Icons.play_arrow, size: 28),
    );
  }
}

/// A playback-speed picker (0.75×–2×).
class _SpeedButton extends StatelessWidget {
  const _SpeedButton({required this.speed, required this.onChanged});

  final double speed;
  final ValueChanged<double>? onChanged;

  static const List<double> _speeds = <double>[0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      enabled: onChanged != null,
      initialValue: speed,
      onSelected: onChanged,
      itemBuilder: (context) => <PopupMenuEntry<double>>[
        for (final option in _speeds)
          PopupMenuItem<double>(value: option, child: Text('$option×')),
      ],
      child: Chip(label: Text('$speed×')),
    );
  }
}
