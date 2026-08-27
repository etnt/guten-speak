import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Builds an in-memory `.epub` (a ZIP) from a map of path -> UTF-8 contents.
///
/// A `mimetype` entry is added first for realism; the parser does not rely on
/// it. Callers supply `META-INF/container.xml`, the OPF, and content documents.
Uint8List buildEpub(Map<String, String> entries) {
  final archive = Archive();
  final mimetype = utf8.encode('application/epub+zip');
  archive.addFile(ArchiveFile('mimetype', mimetype.length, mimetype));
  entries.forEach((path, content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  });
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

/// A minimal, valid EPUB 3 (nav) fixture with two short chapters.
Uint8List sampleEpub() => buildEpub(const <String, String>{
  'META-INF/container.xml': _container,
  'OEBPS/content.opf': _opf,
  'OEBPS/nav.xhtml': _nav,
  'OEBPS/chap1.xhtml': _chap1,
  'OEBPS/chap2.xhtml': _chap2,
});

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

const _opf = '''
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0"
    unique-identifier="bookid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>Sample Book</dc:title>
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

const _nav = '''
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

const _chap1 = '''
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
  <body>
    <h1 id="start">Chapter One</h1>
    <p>First paragraph.</p>
  </body>
</html>
''';

const _chap2 = '''
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
  <body>
    <h1>Chapter Two</h1>
    <p>Second paragraph.</p>
  </body>
</html>
''';
