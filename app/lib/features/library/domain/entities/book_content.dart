import '../../../../core/utils/toc_extractor.dart';

/// A book's reading-flow content: ordered paragraphs and a table of contents.
///
/// Produced either from a parsed EPUB (publisher TOC) or from cleaned plain
/// text (heuristic TOC). The reader wraps this together with the [LibraryBook]
/// record into `ReaderContent`.
class BookContent {
  const BookContent({required this.paragraphs, required this.toc});

  final List<String> paragraphs;
  final List<TocEntry> toc;
}
