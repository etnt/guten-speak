import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Displays a book cover thumbnail with graceful placeholder and error
/// fallbacks. Falls back to a themed book icon when no cover URL is available.
class BookCover extends StatelessWidget {
  const BookCover({
    required this.imageUrl,
    this.width = 120,
    this.height = 180,
    this.borderRadius = 8,
    super.key,
  });

  final String? imageUrl;
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final placeholderColor = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest;

    Widget fallback() => Container(
      width: width,
      height: height,
      color: placeholderColor,
      child: Icon(
        Icons.menu_book_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: width * 0.4,
      ),
    );

    return ClipRRect(
      borderRadius: radius,
      child: imageUrl == null
          ? fallback()
          : CachedNetworkImage(
              imageUrl: imageUrl!,
              width: width,
              height: height,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: width,
                height: height,
                color: placeholderColor,
              ),
              errorWidget: (context, url, error) => fallback(),
            ),
    );
  }
}
