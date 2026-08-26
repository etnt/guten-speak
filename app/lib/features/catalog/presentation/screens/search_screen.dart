import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/state_views.dart';
import '../../data/models/book_summary.dart';
import '../providers/search_providers.dart';
import '../widgets/book_card.dart';

/// Full-text catalog search with debounced input and explicit loading, empty
/// and error states.
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

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search by title or author',
            border: InputBorder.none,
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      ref.read(searchQueryProvider.notifier).clear();
                    },
                  ),
          ),
          onChanged: (value) =>
              ref.read(searchQueryProvider.notifier).update(value),
        ),
      ),
      body: _SearchBody(
        query: query,
        resultsAsync: resultsAsync,
        onTapBook: (id) => context.push('/book/$id'),
        onRetry: () => ref.invalidate(searchResultsProvider),
      ),
    );
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
        message: 'Search Project Gutenberg for a title or author.',
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
