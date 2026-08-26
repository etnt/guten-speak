import '../../../../core/utils/toc_extractor.dart';
import '../../../library/domain/entities/library_book.dart';

/// Everything the reader needs to render a downloaded book: its record, the
/// ordered paragraphs, and a best-effort table of contents.
class ReaderContent {
  const ReaderContent({
    required this.book,
    required this.paragraphs,
    required this.toc,
  });

  final LibraryBook book;
  final List<String> paragraphs;
  final List<TocEntry> toc;

  bool get hasToc => toc.isNotEmpty;
}
