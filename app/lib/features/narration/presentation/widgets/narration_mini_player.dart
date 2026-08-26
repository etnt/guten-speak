import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/narration_playback.dart';
import '../providers/narration_player_providers.dart';

/// A compact now-playing bar shown above the bottom navigation whenever a book
/// is loaded in the narration player. Tapping it opens the full player; the
/// play/pause button toggles playback in place.
class NarrationMiniPlayer extends ConsumerWidget {
  const NarrationMiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(narrationPlaybackProvider).valueOrNull;
    if (playback == null || !playback.isActive) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: () => context.go('/listen/${playback.bookId}'),
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(Icons.record_voice_over, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playback.bookTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      _subtitle(playback),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: playback.isPreparing || playback.isBuffering
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(playback.isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: () => unawaited(_toggle(ref, playback)),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle(NarrationPlaybackState playback) {
    if (playback.status == NarrationStatus.error) {
      return 'Playback error';
    }
    if (playback.isPreparing) {
      return 'Preparing narration… ${(playback.prepFraction * 100).round()}%';
    }
    if (playback.isAwaitingHeadStart) {
      return 'Tap to prepare the next stretch';
    }
    final voice = playback.voiceName.isEmpty ? 'Narrating' : playback.voiceName;
    return '$voice · Unit ${playback.unitIndex + 1} of ${playback.unitCount}';
  }

  Future<void> _toggle(WidgetRef ref, NarrationPlaybackState playback) async {
    final handler = await ref.read(narrationAudioHandlerProvider.future);
    if (playback.isPlaying) {
      await handler.pause();
    } else {
      await handler.play();
    }
  }
}
