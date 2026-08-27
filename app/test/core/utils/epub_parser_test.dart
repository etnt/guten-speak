import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:guten_speak/core/utils/epub_parser.dart';
import 'package:guten_speak/core/utils/toc_extractor.dart';

import '../../support/epub_fixture.dart';

const _container = '''
<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0"
    xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf"
        media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
''';

void main() {
  group('EpubParser (EPUB 3 nav)', () {
    late EpubDocument doc;

    setUp(() {
      const opf = '''
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0"
    unique-identifier="bookid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Test Book</dc:title>
    <dc:creator>Jane Author</dc:creator>
    <dc:language>en</dc:language>
  </metadata>
  <manifest>
    <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml"
        properties="nav"/>
    <item id="c1" href="chap1.xhtml" media-type="application/xhtml+xml"/>
    <item id="c2" href="chap2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="c1"/>
    <itemref idref="c2"/>
  </spine>
</package>
''';
      const nav = '''
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml"
    xmlns:epub="http://www.idpf.org/2007/ops">
  <body>
    <nav epub:type="toc">
      <ol>
        <li><a href="chap1.xhtml#start">Chapter One</a></li>
        <li><a href="chap2.xhtml">Chapter Two</a></li>
      </ol>
    </nav>
  </body>
</html>
''';
      const chap1 = '''
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head><style>p { color: red; }</style></head>
  <body>
    <h1 id="start">Chapter One</h1>
    <p>First paragraph of chapter one.</p>
    <p>Second   paragraph
       with newlines.</p>
    <script>console.log('skip me');</script>
    <img src="cover.png" alt="ignored"/>
  </body>
</html>
''';
      const chap2 = '''
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
  <body>
    <h1>Chapter Two</h1>
    <div><div>Wrapped paragraph without p tag.</div></div>
  </body>
</html>
''';

      doc = const EpubParser().parse(
        buildEpub({
          'META-INF/container.xml': _container,
          'OEBPS/content.opf': opf,
          'OEBPS/nav.xhtml': nav,
          'OEBPS/chap1.xhtml': chap1,
          'OEBPS/chap2.xhtml': chap2,
        }),
      );
    });

    test('reads metadata', () {
      expect(doc.title, 'Test Book');
      expect(doc.author, 'Jane Author');
      expect(doc.language, 'en');
    });

    test(
      'extracts paragraphs in spine order, dropping script/style/images',
      () {
        expect(doc.paragraphs, <String>[
          'Chapter One',
          'First paragraph of chapter one.',
          'Second paragraph with newlines.',
          'Chapter Two',
          'Wrapped paragraph without p tag.',
        ]);
      },
    );

    test('maps the nav TOC to paragraph indices', () {
      expect(doc.toc, <TocEntry>[
        const TocEntry(title: 'Chapter One', paragraphIndex: 0),
        const TocEntry(title: 'Chapter Two', paragraphIndex: 3),
      ]);
    });
  });

  group('EpubParser (EPUB 2 ncx)', () {
    test('maps an NCX toc referenced by the spine toc attribute', () {
      const opf = '''
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0"
    unique-identifier="bookid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Old Book</dc:title>
  </metadata>
  <manifest>
    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="c1" href="chap1.xhtml" media-type="application/xhtml+xml"/>
    <item id="c2" href="chap2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="c1"/>
    <itemref idref="c2"/>
  </spine>
</package>
''';
      const ncx = '''
<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <navMap>
    <navPoint id="np1" playOrder="1">
      <navLabel><text>The Beginning</text></navLabel>
      <content src="chap1.xhtml"/>
    </navPoint>
    <navPoint id="np2" playOrder="2">
      <navLabel><text>The Middle</text></navLabel>
      <content src="chap2.xhtml#mid"/>
    </navPoint>
  </navMap>
</ncx>
''';
      const chap1 = '''
<html><body><p>Opening line.</p></body></html>
''';
      const chap2 = '''
<html><body>
  <p>Before the anchor.</p>
  <p id="mid">At the anchor.</p>
</body></html>
''';

      final doc = const EpubParser().parse(
        buildEpub({
          'META-INF/container.xml': _container,
          'OEBPS/content.opf': opf,
          'OEBPS/toc.ncx': ncx,
          'OEBPS/chap1.xhtml': chap1,
          'OEBPS/chap2.xhtml': chap2,
        }),
      );

      expect(doc.title, 'Old Book');
      expect(doc.paragraphs, <String>[
        'Opening line.',
        'Before the anchor.',
        'At the anchor.',
      ]);
      expect(doc.toc, <TocEntry>[
        const TocEntry(title: 'The Beginning', paragraphIndex: 0),
        const TocEntry(title: 'The Middle', paragraphIndex: 2),
      ]);
    });
  });

  group('EpubParser (malformed markup)', () {
    test('a self-closing <pre/> does not swallow the chapter into one '
        'paragraph', () {
      // Project Gutenberg's ebookmaker emits an empty `<pre/>` marker. Parsed
      // under HTML5 rules (not XML), `<pre/>` becomes an *open* <pre> that
      // nests the rest of the chapter inside it. The parser must still split
      // the nested block elements instead of flattening them into one blob.
      const opf = '''
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0"
    unique-identifier="bookid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Pre Book</dc:title>
  </metadata>
  <manifest>
    <item id="c1" href="chap1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="c1"/>
  </spine>
</package>
''';
      const chap1 = '''
<html xmlns="http://www.w3.org/1999/xhtml">
  <body>
    <pre/>
    <h1>The Repairman</h1>
    <p>First body paragraph.</p>
    <p>Second body paragraph.</p>
    <pre/>
  </body>
</html>
''';

      final doc = const EpubParser().parse(
        buildEpub({
          'META-INF/container.xml': _container,
          'OEBPS/content.opf': opf,
          'OEBPS/chap1.xhtml': chap1,
        }),
      );

      expect(doc.paragraphs, <String>[
        'The Repairman',
        'First body paragraph.',
        'Second body paragraph.',
      ]);
    });

    test(
      'a real <pre> block of preformatted text stays a single paragraph',
      () {
        // A genuine <pre> with only inline/text content (e.g. a poem or code
        // block) should remain one paragraph — the fix only recurses when the
        // block actually contains nested block elements.
        const opf = '''
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0"
    unique-identifier="bookid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Poem Book</dc:title>
  </metadata>
  <manifest>
    <item id="c1" href="chap1.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="c1"/>
  </spine>
</package>
''';
        const chap1 = '''
<html xmlns="http://www.w3.org/1999/xhtml">
  <body>
    <h1>A Poem</h1>
    <pre>Line one
Line two
Line three</pre>
  </body>
</html>
''';

        final doc = const EpubParser().parse(
          buildEpub({
            'META-INF/container.xml': _container,
            'OEBPS/content.opf': opf,
            'OEBPS/chap1.xhtml': chap1,
          }),
        );

        expect(doc.paragraphs, <String>[
          'A Poem',
          'Line one Line two Line three',
        ]);
      },
    );
  });

  group('EpubParser (errors)', () {
    test('throws on a non-zip payload', () {
      expect(
        () => const EpubParser().parse(Uint8List.fromList(<int>[1, 2, 3, 4])),
        throwsA(isA<EpubParseException>()),
      );
    });

    test('throws when container.xml is missing', () {
      final bytes = buildEpub({'OEBPS/content.opf': '<package/>'});
      expect(
        () => const EpubParser().parse(bytes),
        throwsA(isA<EpubParseException>()),
      );
    });
  });
}
