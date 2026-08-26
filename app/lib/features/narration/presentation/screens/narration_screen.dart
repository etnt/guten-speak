import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/tts/tts_service.dart';
import '../../../../core/utils/narration_segmenter.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../reader/presentation/providers/reader_providers.dart';
import '../../../voices/domain/entities/voice.dart';
import '../../../voices/presentation/providers/voice_providers.dart';
import '../../domain/entities/narration_prep_progress.dart';
import '../providers/tts_providers.dart';

/// The opt-in narration entry point (Phase C).
///
/// Gates the one-time ~470 MB model download behind explicit consent, then runs
/// an end-to-end smoke test: segment the book, clone the selected voice, and
/// synthesize + play the first narration unit. The full background player is a
/// later phase.
class NarrationScreen extends ConsumerStatefulWidget {
  const NarrationScreen({required this.bookId, super.key});

  final int bookId;

  @override
  ConsumerState<NarrationScreen> createState() => _NarrationScreenState();
}

class _NarrationScreenState extends ConsumerState<NarrationScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _synthesizing = false;
  SpeakResult? _lastResult;
  String? _synthError;

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contentAsync = ref.watch(readerContentProvider(widget.bookId));

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
            bookTitle: content.book.title,
            firstUnit: units.first.text,
            player: _player,
            synthesizing: _synthesizing,
            lastResult: _lastResult,
            synthError: _synthError,
            onSynthesize: (voice) => _synthesizeFirstUnit(units.first, voice),
          );
        },
      ),
    );
  }

  Future<void> _synthesizeFirstUnit(NarrationUnit unit, Voice voice) async {
    setState(() {
      _synthesizing = true;
      _synthError = null;
    });
    try {
      final tempDir = await getTemporaryDirectory();
      final outPath =
          '${tempDir.path}/narration_smoke_${DateTime.now().millisecondsSinceEpoch}.wav';
      final result = await ref
          .read(narrationEngineProvider.notifier)
          .synthesize(
            text: unit.text,
            referenceWavPath: voice.wavPath,
            outputWavPath: outPath,
          );
      await _player.setFilePath(outPath);
      unawaited(_player.play());
      if (mounted) {
        setState(() => _lastResult = result);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _synthError = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _synthesizing = false);
      }
    }
  }
}

/// The prepared/preparing UI once the book's text is loaded.
class _NarrationBody extends ConsumerWidget {
  const _NarrationBody({
    required this.bookTitle,
    required this.firstUnit,
    required this.player,
    required this.synthesizing,
    required this.lastResult,
    required this.synthError,
    required this.onSynthesize,
  });

  final String bookTitle;
  final String firstUnit;
  final AudioPlayer player;
  final bool synthesizing;
  final SpeakResult? lastResult;
  final String? synthError;
  final ValueChanged<Voice> onSynthesize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prep = ref.watch(narrationEngineProvider);
    final voicesAsync = ref.watch(voicesControllerProvider);
    final selected = ref.watch(selectedVoiceProvider);

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

        // Model gate / synthesis.
        if (!prep.isReady)
          _PrepareCard(prep: prep)
        else
          _SmokeTestCard(
            firstUnit: firstUnit,
            player: player,
            synthesizing: synthesizing,
            lastResult: lastResult,
            synthError: synthError,
            onSynthesize: () {
              final voices = voicesAsync.valueOrNull ?? const <Voice>[];
              if (voices.isEmpty) return;
              onSynthesize(selected ?? voices.first);
            },
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

/// The end-to-end smoke test: synthesize + play the first narration unit.
class _SmokeTestCard extends StatelessWidget {
  const _SmokeTestCard({
    required this.firstUnit,
    required this.player,
    required this.synthesizing,
    required this.lastResult,
    required this.synthError,
    required this.onSynthesize,
  });

  final String firstUnit;
  final AudioPlayer player;
  final bool synthesizing;
  final SpeakResult? lastResult;
  final String? synthError;
  final VoidCallback onSynthesize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Preview narration', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              firstUnit,
              style: theme.textTheme.bodyMedium,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: synthesizing ? null : onSynthesize,
              icon: synthesizing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(
                synthesizing ? 'Synthesizing…' : 'Synthesize & play first line',
              ),
            ),
            if (lastResult != null) ...[
              const SizedBox(height: 12),
              Text(
                'Generated ${lastResult!.audioSeconds.toStringAsFixed(1)}s of '
                'audio in ${lastResult!.generateMillis} ms '
                '(RTF ${lastResult!.realTimeFactor.toStringAsFixed(2)}×).',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (synthError != null) ...[
              const SizedBox(height: 12),
              Text(
                synthError!,
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
}
