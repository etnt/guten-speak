import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/state_views.dart';
import '../../../library/domain/entities/download_state.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../data/models/book_summary.dart';
import '../providers/catalog_providers.dart';
import '../widgets/book_cover.dart';

/// Book details: cover, metadata, subjects and available formats, plus download
/// and reading actions.
class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({required this.bookId, super.key});

  final int bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookAsync = ref.watch(bookDetailProvider(bookId));

    return Scaffold(
      appBar: AppBar(title: const Text('Book details')),
      body: bookAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(bookDetailProvider(bookId)),
        ),
        data: (book) => _BookDetailContent(book: book),
      ),
    );
  }
}

class _BookDetailContent extends StatelessWidget {
  const _BookDetailContent({required this.book});

  final BookSummary book;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookCover(imageUrl: book.coverImageUrl),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(book.title, style: textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(book.authorNames, style: textTheme.bodyLarge),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.download_outlined, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${book.downloadCount} downloads',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  if (book.languages.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Language: ${book.languages.join(', ').toUpperCase()}',
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _ActionButtons(book: book),
        if (!book.hasReadableText) ...[
          const SizedBox(height: 8),
          Text(
            'No plain-text edition is available for this title.',
            style: textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        if (book.subjects.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Subjects', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final subject in book.subjects) Chip(label: Text(subject)),
            ],
          ),
        ],
      ],
    );
  }
}

/// Read / download actions that react to the per-book download state.
class _ActionButtons extends ConsumerWidget {
  const _ActionButtons({required this.book});

  final BookSummary book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final download = ref.watch(bookDownloadControllerProvider(book.id));
    final libraryBook = ref.watch(libraryBookProvider(book.id)).valueOrNull;
    final isDownloaded = libraryBook != null;
    final isEpub =
        libraryBook != null &&
        libraryBook.path.toLowerCase().endsWith('.epub');
    final controller = ref.read(
      bookDownloadControllerProvider(book.id).notifier,
    );

    if (download.isDownloading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: download.progress >= 0 ? download.progress : null,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: controller.cancel,
            icon: const Icon(Icons.close),
            label: const Text('Cancel download'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: book.hasReadableText
                    ? () => _read(context, ref, isDownloaded: isDownloaded)
                    : null,
                icon: const Icon(Icons.menu_book),
                label: const Text('Read now'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: !book.hasReadableText || isDownloaded
                    ? null
                    : () => unawaited(controller.start(book)),
                icon: Icon(isDownloaded ? Icons.check : Icons.download),
                label: Text(isDownloaded ? 'Downloaded' : 'Download'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: book.hasReadableText
              ? () => unawaited(context.push('/listen/${book.id}'))
              : null,
          icon: const Icon(Icons.headphones),
          label: const Text('Listen'),
        ),
        if (libraryBook != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                isEpub ? Icons.menu_book_outlined : Icons.description_outlined,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                isEpub ? 'Downloaded as EPUB' : 'Downloaded as plain text',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
        if (download.status == DownloadStatus.failed &&
            download.failure != null) ...[
          const SizedBox(height: 8),
          Text(
            download.failure!.message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _read(
    BuildContext context,
    WidgetRef ref, {
    required bool isDownloaded,
  }) async {
    if (isDownloaded) {
      unawaited(context.push('/read/${book.id}'));
      return;
    }
    final result = await ref
        .read(bookDownloadControllerProvider(book.id).notifier)
        .start(book);
    if (result != null && context.mounted) {
      unawaited(context.push('/read/${book.id}'));
    }
  }
}
