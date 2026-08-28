import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/library_book.dart';
import '../providers/library_providers.dart';

/// Opens the start page's quick picker for recently read books.
Future<void> showRecentlyReadSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => const RecentlyReadSheet(),
  );
}

class RecentlyReadSheet extends ConsumerWidget {
  const RecentlyReadSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(recentlyReadBooksProvider);
    return FractionallySizedBox(
      heightFactor: 0.65,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              'Recently read',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: booksAsync.when(
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(recentlyReadBooksProvider),
              ),
              data: (books) => books.isEmpty
                  ? const EmptyView(
                      icon: Icons.history_outlined,
                      message:
                          'No recently read books yet.\nOpen a book and start '
                          'reading to see it here.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: books.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) => _RecentBookTile(
                        book: books[index],
                        onTap: () => _openReader(context, books[index].id),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _openReader(BuildContext context, int bookId) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    unawaited(router.push('/read/$bookId'));
  }
}

class _RecentBookTile extends StatelessWidget {
  const _RecentBookTile({required this.book, required this.onTap});

  final LibraryBook book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.menu_book_outlined),
      title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
