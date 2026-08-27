import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/core/network/failure.dart';
import 'package:guten_speak/core/utils/toc_extractor.dart';
import 'package:guten_speak/features/library/data/book_content_loader.dart';
import 'package:path/path.dart' as p;

import '../../support/epub_fixture.dart';

void main() {
  late Directory bookDir;
  const loader = BookContentLoader();

  setUp(() async {
    bookDir = await Directory.systemTemp.createTemp('book_content_loader_test');
  });

  tearDown(() async {
    if (await bookDir.exists()) {
      await bookDir.delete(recursive: true);
    }
  });

  File file(String name) => File(p.join(bookDir.path, name));

  test('parses book.epub and caches the result to content.json', () async {
    await file(BookContentLoader.epubFileName).writeAsBytes(sampleEpub());

    final content = await loader.load(bookDir);

    expect(content.paragraphs, <String>[
      'Chapter One',
      'First paragraph.',
      'Chapter Two',
      'Second paragraph.',
    ]);
    expect(content.toc, <TocEntry>[
      const TocEntry(title: 'Chapter One', paragraphIndex: 0),
      const TocEntry(title: 'Chapter Two', paragraphIndex: 2),
    ]);

    final cache = file(BookContentLoader.contentCacheName);
    expect(await cache.exists(), isTrue);
    final decoded = jsonDecode(await cache.readAsString()) as Map<String, dynamic>;
    expect(decoded['version'], 1);
  });

  test('reads content.json cache instead of re-parsing', () async {
    await file(BookContentLoader.contentCacheName).writeAsString(
      jsonEncode(<String, dynamic>{
        'version': 1,
        'paragraphs': <String>['Cached paragraph.'],
        'toc': <Map<String, dynamic>>[
          <String, dynamic>{'title': 'Cached', 'paragraphIndex': 0},
        ],
      }),
    );
    // An epub is also present; the cache must win.
    await file(BookContentLoader.epubFileName).writeAsBytes(sampleEpub());

    final content = await loader.load(bookDir);

    expect(content.paragraphs, <String>['Cached paragraph.']);
    expect(content.toc, <TocEntry>[
      const TocEntry(title: 'Cached', paragraphIndex: 0),
    ]);
  });

  test('re-parses when the cache is corrupt', () async {
    await file(BookContentLoader.contentCacheName).writeAsString('{ not json');
    await file(BookContentLoader.epubFileName).writeAsBytes(sampleEpub());

    final content = await loader.load(bookDir);

    expect(content.paragraphs.first, 'Chapter One');
  });

  test('falls back to text.txt when no epub exists', () async {
    await file(BookContentLoader.textFileName).writeAsString(
      'CHAPTER I\n\nOnce upon a time.\n\nThe end.',
    );

    final content = await loader.load(bookDir);

    expect(content.paragraphs, contains('Once upon a time.'));
    expect(content.toc, isNotEmpty);
  });

  test('throws CacheFailure when the book directory is empty', () async {
    expect(
      () => loader.load(bookDir),
      throwsA(isA<CacheFailure>()),
    );
  });
}
