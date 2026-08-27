import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/state_views.dart';
import '../../data/models/book_summary.dart';
import '../providers/catalog_providers.dart';
import '../widgets/book_card.dart';

/// Discover tab: a carousel of popular titles followed by curated subject
/// shelves sourced from Gutendex.
class CatalogHomeScreen extends ConsumerWidget {
  const CatalogHomeScreen({super.key});

  void _openBook(BuildContext context, int id) {
    context.push('/book/$id');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text.rich(
          TextSpan(
            text: 'guten-speak',
            children: [
              TextSpan(
                text: '  ${AppConstants.appVersion}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: () => context.push(AppConstants.routeSearch),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(popularBooksProvider);
          for (final subject in AppConstants.curatedSubjects) {
            ref.invalidate(booksByTopicProvider(subject));
          }
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            const _SectionHeader(title: 'Popular now'),
            _BookCarousel(
              provider: popularBooksProvider,
              onTapBook: (id) => _openBook(context, id),
            ),
            for (final subject in AppConstants.curatedSubjects) ...[
              _SectionHeader(title: subject),
              _BookCarousel(
                provider: booksByTopicProvider(subject),
                onTapBook: (id) => _openBook(context, id),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

/// Horizontally scrolling shelf backed by an async provider of books.
class _BookCarousel extends ConsumerWidget {
  const _BookCarousel({required this.provider, required this.onTapBook});

  final AutoDisposeFutureProvider<List<BookSummary>> provider;
  final ValueChanged<int> onTapBook;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(provider);
    return SizedBox(
      height: 250,
      child: booksAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) =>
            ErrorView(error: error, onRetry: () => ref.invalidate(provider)),
        data: (books) {
          if (books.isEmpty) {
            return const EmptyView(message: 'No books found.');
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: books.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final book = books[index];
              return BookCard(book: book, onTap: () => onTapBook(book.id));
            },
          );
        },
      ),
    );
  }
}
