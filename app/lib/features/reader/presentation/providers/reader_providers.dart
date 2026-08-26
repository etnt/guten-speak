import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/failure.dart';
import '../../../../core/utils/text_cleaner_service.dart';
import '../../../../core/utils/toc_extractor.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../domain/entities/reader_content.dart';

part 'reader_providers.g.dart';

/// Loads a downloaded book's paragraphs and table of contents for the reader.
///
/// Requires the book to already be in the library; the "Read" action downloads
/// it first. The stored text is already cleaned, so this only splits paragraphs
/// and extracts headings.
@riverpod
Future<ReaderContent> readerContent(Ref ref, int bookId) async {
  final repo = await ref.watch(libraryRepositoryProvider.future);

  final bookResult = await repo.getBook(bookId);
  final book = bookResult.when(
    onSuccess: (value) => value,
    onFailure: (failure) => throw failure,
  );
  if (book == null) {
    throw const CacheFailure('This book has not been downloaded yet.');
  }

  final textResult = await repo.readBookText(book);
  final text = textResult.when(
    onSuccess: (value) => value,
    onFailure: (failure) => throw failure,
  );

  const cleaner = TextCleanerService();
  final paragraphs = cleaner.paragraphs(text);
  const extractor = TocExtractor();
  final toc = extractor.extract(paragraphs);

  return ReaderContent(book: book, paragraphs: paragraphs, toc: toc);
}

/// Imperative reader actions (e.g. persisting scroll position).
@Riverpod(keepAlive: true)
class ReaderController extends _$ReaderController {
  @override
  void build() {}

  /// Persists the reader's position for [bookId] at [paragraphIndex].
  Future<void> saveProgress(int bookId, int paragraphIndex) async {
    final repo = await ref.read(libraryRepositoryProvider.future);
    await repo.saveProgress(bookId, paragraphIndex);
  }
}
