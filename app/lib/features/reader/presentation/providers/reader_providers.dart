import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/failure.dart';
import '../../../library/presentation/providers/library_providers.dart';
import '../../domain/entities/reader_content.dart';

part 'reader_providers.g.dart';

/// Loads a downloaded book's paragraphs and table of contents for the reader.
///
/// Requires the book to already be in the library; the "Read" action downloads
/// it first. Content resolution (EPUB vs. cleaned plain text) is handled by the
/// repository.
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

  final contentResult = await repo.readBookContent(book);
  final content = contentResult.when(
    onSuccess: (value) => value,
    onFailure: (failure) => throw failure,
  );

  return ReaderContent(
    book: book,
    paragraphs: content.paragraphs,
    toc: content.toc,
  );
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
