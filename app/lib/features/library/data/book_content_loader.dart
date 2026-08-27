import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/network/failure.dart';
import '../../../core/utils/epub_parser.dart';
import '../../../core/utils/text_cleaner_service.dart';
import '../../../core/utils/toc_extractor.dart';
import '../domain/entities/book_content.dart';

/// Loads a downloaded book's [BookContent] from its on-disk directory,
/// preferring structured EPUB content over plain text.
///
/// Resolution order for `<bookDir>/`:
/// 1. `content.json` — a cached parse result (fast path); re-parsed if missing
///    or corrupt.
/// 2. `book.epub` — parsed with [EpubParser], then cached to `content.json`.
/// 3. `text.txt` — cleaned plain text split into paragraphs with a heuristic
///    TOC (the legacy Gutenberg fallback).
class BookContentLoader {
  const BookContentLoader({
    this.parser = const EpubParser(),
    this.cleaner = const TextCleanerService(),
    this.tocExtractor = const TocExtractor(),
  });

  final EpubParser parser;
  final TextCleanerService cleaner;
  final TocExtractor tocExtractor;

  static const String epubFileName = 'book.epub';
  static const String textFileName = 'text.txt';
  static const String contentCacheName = 'content.json';
  static const int _cacheVersion = 1;

  Future<BookContent> load(Directory bookDir) async {
    final cacheFile = File(p.join(bookDir.path, contentCacheName));
    if (await cacheFile.exists()) {
      final cached = await _tryReadCache(cacheFile);
      if (cached != null) return cached;
    }

    final epubFile = File(p.join(bookDir.path, epubFileName));
    if (await epubFile.exists()) {
      final bytes = await epubFile.readAsBytes();
      final doc = parser.parse(bytes);
      final content = BookContent(paragraphs: doc.paragraphs, toc: doc.toc);
      await _tryWriteCache(cacheFile, content);
      return content;
    }

    final textFile = File(p.join(bookDir.path, textFileName));
    if (await textFile.exists()) {
      final text = await textFile.readAsString();
      final paragraphs = cleaner.paragraphs(text);
      return BookContent(
        paragraphs: paragraphs,
        toc: tocExtractor.extract(paragraphs),
      );
    }

    throw const CacheFailure('The downloaded book is missing.');
  }

  /// Writes [content] to `<bookDir>/content.json` (best-effort). Used to warm
  /// the cache right after an EPUB is imported or downloaded.
  Future<void> writeCache(Directory bookDir, BookContent content) =>
      _tryWriteCache(File(p.join(bookDir.path, contentCacheName)), content);

  Future<BookContent?> _tryReadCache(File cacheFile) async {
    try {
      final decoded = jsonDecode(await cacheFile.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['version'] != _cacheVersion) return null;

      final paragraphs = (decoded['paragraphs'] as List<dynamic>)
          .map((dynamic e) => e as String)
          .toList();
      final toc = (decoded['toc'] as List<dynamic>)
          .map((dynamic e) => e as Map<String, dynamic>)
          .map(
            (m) => TocEntry(
              title: m['title'] as String,
              paragraphIndex: m['paragraphIndex'] as int,
            ),
          )
          .toList();
      return BookContent(paragraphs: paragraphs, toc: toc);
    } catch (_) {
      // A corrupt or outdated cache is not fatal: fall through to re-parse.
      return null;
    }
  }

  Future<void> _tryWriteCache(File cacheFile, BookContent content) async {
    try {
      final json = jsonEncode(<String, dynamic>{
        'version': _cacheVersion,
        'paragraphs': content.paragraphs,
        'toc': <Map<String, dynamic>>[
          for (final entry in content.toc)
            <String, dynamic>{
              'title': entry.title,
              'paragraphIndex': entry.paragraphIndex,
            },
        ],
      });
      final tmp = File('${cacheFile.path}.tmp');
      await tmp.writeAsString(json, flush: true);
      await tmp.rename(cacheFile.path);
    } catch (_) {
      // Caching is best-effort; a write failure just means we re-parse later.
    }
  }
}
