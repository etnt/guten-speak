import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/state_views.dart';
import '../../data/models/book_summary.dart';
import '../../domain/entities/catalog_import_progress.dart';
import '../providers/catalog_providers.dart';
import '../providers/search_providers.dart';
import '../widgets/book_card.dart';

/// Full-text catalog search over the local (offline) Project Gutenberg index,
/// with explicit loading, empty and error states. On first open it triggers a
/// one-time import of the catalog and shows its progress.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(searchQueryProvider));
    unawaited(ref.read(catalogImportProvider.notifier).ensure());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final resultsAsync = ref.watch(searchResultsProvider);
    final import = ref.watch(catalogImportProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search by title or author',
            border: InputBorder.none,
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    ref.read(searchQueryProvider.notifier).clear();
                  },
                );
              },
            ),
          ),
          onSubmitted: (value) =>
              ref.read(searchQueryProvider.notifier).update(value.trim()),
        ),
      ),
      body: import.isReady
          ? _SearchBody(
              query: query,
              resultsAsync: resultsAsync,
              onTapBook: (id) => context.push('/book/$id'),
              onRetry: () => ref.invalidate(searchResultsProvider),
            )
          : _CatalogPreparing(
              progress: import,
              onRetry: () => ref.read(catalogImportProvider.notifier).refresh(),
            ),
    );
  }
}

/// Shown on first use while the offline catalog is downloaded and indexed.
class _CatalogPreparing extends StatelessWidget {
  const _CatalogPreparing({required this.progress, required this.onRetry});

  final CatalogImportProgress progress;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (progress.phase == CatalogPhase.error) {
      return ErrorView(
        error: progress.error ?? 'Failed to prepare the catalog.',
        onRetry: onRetry,
      );
    }

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.cloud_download_outlined,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Preparing offline catalog',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _label(progress),
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(value: progress.fraction),
        ],
      ),
    );
  }

  String _label(CatalogImportProgress progress) {
    switch (progress.phase) {
      case CatalogPhase.downloading:
        final pct = ((progress.fraction ?? 0) * 100).round();
        return 'Downloading Project Gutenberg catalog… $pct%';
      case CatalogPhase.parsing:
        return 'Reading catalog…';
      case CatalogPhase.saving:
        final pct = ((progress.fraction ?? 0) * 100).round();
        return 'Building search index… $pct%';
      case CatalogPhase.idle:
      case CatalogPhase.ready:
      case CatalogPhase.error:
        return 'This happens once and then works offline.';
    }
  }
}

class _SearchBody extends StatelessWidget {
  const _SearchBody({
    required this.query,
    required this.resultsAsync,
    required this.onTapBook,
    required this.onRetry,
  });

  final String query;
  final AsyncValue<List<BookSummary>> resultsAsync;
  final ValueChanged<int> onTapBook;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (query.trim().isEmpty) {
      return const EmptyView(
        icon: Icons.search,
        message:
            'Type a title or author, then press search to look it up in '
            'the offline Project Gutenberg catalog.',
      );
    }

    return resultsAsync.when(
      loading: () => const LoadingView(),
      error: (error, _) => ErrorView(error: error, onRetry: onRetry),
      data: (books) {
        if (books.isEmpty) {
          return EmptyView(message: 'No results for "$query".');
        }
        return ListView.builder(
          itemCount: books.length,
          itemBuilder: (context, index) {
            final book = books[index];
            return BookListTile(book: book, onTap: () => onTapBook(book.id));
          },
        );
      },
    );
  }
}
