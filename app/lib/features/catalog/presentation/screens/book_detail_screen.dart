import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/state_views.dart';
import '../../data/models/book_summary.dart';
import '../providers/catalog_providers.dart';
import '../widgets/book_cover.dart';

/// Book details: cover, metadata, subjects and available formats. Download and
/// reading actions are wired in Phase 3.
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
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: book.hasReadableText
                    ? () => _notImplemented(context, 'Reading')
                    : null,
                icon: const Icon(Icons.menu_book),
                label: const Text('Read now'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: book.hasReadableText
                    ? () => _notImplemented(context, 'Download')
                    : null,
                icon: const Icon(Icons.download),
                label: const Text('Download'),
              ),
            ),
          ],
        ),
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

  void _notImplemented(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature will be available in a later update.')),
    );
  }
}
