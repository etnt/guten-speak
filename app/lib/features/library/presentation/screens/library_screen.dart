import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/failure.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../narration/presentation/providers/synth_cache_providers.dart';
import '../../domain/entities/library_book.dart';
import '../providers/library_providers.dart';

/// Lists downloaded books; tap to open the book's details page, delete to
/// remove (which also clears any narrated audio cached for it).
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(libraryBooksProvider);
    final importing = ref.watch(bookImportControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library'),
        actions: [
          IconButton(
            tooltip: 'Import EPUB',
            onPressed: importing ? null : () => _importEpub(context, ref),
            icon: importing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_upload_outlined),
          ),
        ],
      ),
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
                  'Find a book in Discover and tap Download, '
                  'or import an EPUB you own.',
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

  Future<void> _importEpub(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['epub'],
    );
    final path = picked.isEmpty ? null : picked.first.path;
    if (path == null) return;

    try {
      final book = await ref
          .read(bookImportControllerProvider.notifier)
          .importFromFile(path);
      if (book == null) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Imported "${book.title}"')),
      );
      unawaited(router.push('/read/${book.id}'));
    } on Failure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

class _LibraryTile extends ConsumerWidget {
  const _LibraryTile({required this.book});

  final LibraryBook book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEpub = book.path.toLowerCase().endsWith('.epub');
    return ListTile(
      leading: const Icon(Icons.menu_book),
      title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              book.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _FormatBadge(isEpub: isEpub),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Remove from library',
        onPressed: () => _confirmDelete(context, ref),
      ),
      // Imported books (negative ids) have no catalog detail page, so open
      // them straight in the reader; Gutenberg books show their details first.
      onTap: () =>
          context.push(book.id < 0 ? '/read/${book.id}' : '/book/${book.id}'),
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
    final cache = await ref.read(synthCacheProvider.future);
    await cache.invalidateBook(book.id);
    ref.invalidate(libraryBooksProvider);
  }
}

/// A compact pill showing the stored file format for a library book.
class _FormatBadge extends StatelessWidget {
  const _FormatBadge({required this.isEpub});

  final bool isEpub;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isEpub ? 'EPUB' : 'TXT',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
