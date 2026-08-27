import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/dictionary_entry.dart';
import '../providers/dictionary_providers.dart';

/// Shows the dictionary look-up for [word] in a modal bottom sheet. On first
/// use it offers the one-time (~15 MB) WordNet download; afterwards it shows the
/// definitions directly and works offline.
Future<void> showDictionaryLookup(BuildContext context, String word) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _DictionaryLookupSheet(word: word),
  );
}

class _DictionaryLookupSheet extends ConsumerWidget {
  const _DictionaryLookupSheet({required this.word});

  final String word;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installed = ref.watch(dictionaryInstalledProvider);

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(word: word),
              const SizedBox(height: 12),
              Flexible(
                child: installed.when(
                  loading: () => const _Busy(),
                  error: (error, _) =>
                      const _Message('Couldn’t open the dictionary.'),
                  data: (isInstalled) => isInstalled
                      ? _Definitions(word: word)
                      : const _DownloadGate(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.word});

  final String word;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      word,
      style: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// The consent + progress card shown the first time a word is looked up.
class _DownloadGate extends ConsumerWidget {
  const _DownloadGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(dictionaryDownloadControllerProvider);
    final controller = ref.read(dictionaryDownloadControllerProvider.notifier);

    if (state.isDownloading) {
      final pct = state.fraction != null
          ? ' ${(state.fraction! * 100).round()}%'
          : '';
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Downloading dictionary…$pct',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: state.fraction),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: controller.cancel,
            icon: const Icon(Icons.close),
            label: const Text('Cancel'),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Word look-ups use an offline dictionary (WordNet). It’s a one-time '
          '~15 MB download, stored on your device and used without a network '
          'afterwards.',
          style: theme.textTheme.bodyMedium,
        ),
        if (state.error != null) ...[
          const SizedBox(height: 8),
          Text(
            state.error!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: controller.download,
          icon: const Icon(Icons.download),
          label: Text(
            state.error != null ? 'Try again' : 'Download dictionary',
          ),
        ),
      ],
    );
  }
}

class _Definitions extends ConsumerWidget {
  const _Definitions({required this.word});

  final String word;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(wordLookupProvider(word));
    return result.when(
      loading: () => const _Busy(),
      error: (error, _) => const _Message('Couldn’t read the dictionary.'),
      data: (senses) {
        if (senses.isEmpty) {
          return _Message('No definition found for “$word”.');
        }
        return ListView.separated(
          shrinkWrap: true,
          itemCount: senses.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, index) =>
              _SenseTile(index: index + 1, sense: senses[index]),
        );
      },
    );
  }
}

class _SenseTile extends StatelessWidget {
  const _SenseTile({required this.index, required this.sense});

  final int index;
  final DictionarySense sense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('$index. ', style: theme.textTheme.titleMedium),
            Text(
              sense.posLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(sense.definition, style: theme.textTheme.bodyLarge),
        if (sense.examples.isNotEmpty) ...[
          const SizedBox(height: 4),
          for (final example in sense.examples)
            Text(
              '“$example”',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
        if (sense.synonyms.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Synonyms: ${sense.synonyms.join(', ')}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _Busy extends StatelessWidget {
  const _Busy();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
