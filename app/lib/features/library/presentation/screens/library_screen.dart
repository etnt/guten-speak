import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/library_book.dart';
import '../providers/library_providers.dart';

/// Lists downloaded books; tap to read, delete to remove.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(libraryBooksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Library')),
      body: booksAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(libraryBooksProvider),
        ),
        data: (books) {
          if (books.isEmpty) {
            return const EmptyView(
              icon: Icons.menu_book_outlined,
              message:
                  'No downloaded books yet.\n'
                  'Find a book in Discover and tap Download.',
            );
          }
          return ListView.separated(
            itemCount: books.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => _LibraryTile(book: books[index]),
          );
        },
      ),
    );
  }
}

class _LibraryTile extends ConsumerWidget {
  const _LibraryTile({required this.book});

  final LibraryBook book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.menu_book),
      title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Remove from library',
        onPressed: () => _confirmDelete(context, ref),
      ),
      onTap: () => context.push('/read/${book.id}'),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove book?'),
        content: Text('Delete "${book.title}" and its downloaded text?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final repo = await ref.read(libraryRepositoryProvider.future);
    await repo.deleteBook(book.id);
    ref.invalidate(libraryBooksProvider);
  }
}
