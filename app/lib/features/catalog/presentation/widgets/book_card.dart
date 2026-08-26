import 'package:flutter/material.dart';

import '../../data/models/book_summary.dart';
import 'book_cover.dart';

/// Compact vertical book card used in the Discover carousels.
class BookCard extends StatelessWidget {
  const BookCard({
    required this.book,
    required this.onTap,
    this.width = 130,
    super.key,
  });

  final BookSummary book;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BookCover(
              imageUrl: book.coverImageUrl,
              width: width,
              height: width * 1.5,
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              book.authorNames,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width horizontal book row used in search results and lists.
class BookListTile extends StatelessWidget {
  const BookListTile({required this.book, required this.onTap, super.key});

  final BookSummary book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: BookCover(imageUrl: book.coverImageUrl, width: 48, height: 72),
      title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(book.authorNames, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.download_outlined,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text('${book.downloadCount}', style: textTheme.labelSmall),
            ],
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
