import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import 'toc_extractor.dart';

/// Raised when an `.epub` archive is malformed or missing required parts.
class EpubParseException implements Exception {
  const EpubParseException(this.message);

  final String message;

  @override
  String toString() => 'EpubParseException: $message';
}

/// The parsed result of an EPUB: book metadata, ordered reading-flow paragraphs
/// and a real (publisher-authored) table of contents.
///
/// The [paragraphs] / [toc] shape matches what the reader and narration expect
/// from the plain-text pipeline, so an [EpubDocument] slots straight into
/// `ReaderContent`.
class EpubDocument {
  const EpubDocument({
    required this.paragraphs,
    required this.toc,
    this.title,
    this.author,
    this.language,
  });

  final String? title;
  final String? author;
  final String? language;
  final List<String> paragraphs;
  final List<TocEntry> toc;
}

/// Parses EPUB 2 and EPUB 3 archives into an [EpubDocument].
///
/// This is a pure, side-effect-free function of the archive bytes so it can be
/// unit-tested offline and run off the UI isolate. Images and styling are
/// dropped; only reading-flow text and the navigation TOC are extracted.
class EpubParser {
  const EpubParser();

  static const Set<String> _blockTags = <String>{
    'p',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'li',
    'blockquote',
    'pre',
    'figcaption',
    'dd',
    'dt',
  };

  static final RegExp _whitespace = RegExp(r'\s+');

  EpubDocument parse(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (error) {
      throw EpubParseException('Not a valid ZIP/EPUB archive: $error');
    }

    final files = <String, ArchiveFile>{
      for (final file in archive.files)
        if (file.isFile) _normalize(file.name): file,
    };

    final opfPath = _locateOpf(files);
    final opf = XmlDocument.parse(_readString(files, opfPath));
    final opfDir = p.posix.dirname(opfPath);

    final metadata = _readMetadata(opf);
    final manifest = _readManifest(opf, opfDir);
    final spine = _readSpine(opf);

    final paragraphs = <String>[];
    // Absolute content path -> index of its first paragraph.
    final fileStart = <String, int>{};
    // 'absolutePath#elementId' -> paragraph index for TOC anchor resolution.
    final anchorIndex = <String, int>{};

    for (final idref in spine) {
      final item = manifest[idref];
      if (item == null) continue;
      final content = _tryReadString(files, item.href);
      if (content == null) continue;
      final startIndex = paragraphs.length;
      _extractParagraphs(
        html.parse(content),
        item.href,
        paragraphs,
        anchorIndex,
      );
      if (paragraphs.length > startIndex) {
        fileStart[item.href] = startIndex;
      }
    }

    final toc = _buildToc(
      files: files,
      manifest: manifest,
      opf: opf,
      fileStart: fileStart,
      anchorIndex: anchorIndex,
    );

    return EpubDocument(
      title: metadata.title,
      author: metadata.author,
      language: metadata.language,
      paragraphs: paragraphs,
      toc: toc,
    );
  }

  String _locateOpf(Map<String, ArchiveFile> files) {
    const containerPath = 'META-INF/container.xml';
    final container = files[containerPath];
    if (container == null) {
      throw const EpubParseException('Missing META-INF/container.xml');
    }
    final doc = XmlDocument.parse(_decode(container));
    final rootfile = doc.findAllElements('rootfile', namespace: '*').isEmpty
        ? null
        : doc.findAllElements('rootfile', namespace: '*').first;
    final fullPath = rootfile?.getAttribute('full-path');
    if (fullPath == null || fullPath.isEmpty) {
      throw const EpubParseException('container.xml has no rootfile path');
    }
    final normalized = _normalize(fullPath);
    if (!files.containsKey(normalized)) {
      throw EpubParseException('OPF package not found at $normalized');
    }
    return normalized;
  }

  _EpubMetadata _readMetadata(XmlDocument opf) {
    String? first(String name) {
      final elements = opf.findAllElements(name, namespace: '*');
      for (final element in elements) {
        final text = element.innerText.trim();
        if (text.isNotEmpty) return text;
      }
      return null;
    }

    return _EpubMetadata(
      title: first('title'),
      author: first('creator'),
      language: first('language'),
    );
  }

  Map<String, _ManifestItem> _readManifest(XmlDocument opf, String opfDir) {
    final items = <String, _ManifestItem>{};
    for (final element in opf.findAllElements('item', namespace: '*')) {
      final id = element.getAttribute('id');
      final href = element.getAttribute('href');
      if (id == null || href == null) continue;
      items[id] = _ManifestItem(
        id: id,
        href: _resolve(opfDir, href),
        mediaType: element.getAttribute('media-type') ?? '',
        properties: element.getAttribute('properties') ?? '',
      );
    }
    return items;
  }

  List<String> _readSpine(XmlDocument opf) {
    final spine = <String>[];
    for (final element in opf.findAllElements('itemref', namespace: '*')) {
      final idref = element.getAttribute('idref');
      if (idref != null) spine.add(idref);
    }
    return spine;
  }

  void _extractParagraphs(
    dom.Document document,
    String filePath,
    List<String> paragraphs,
    Map<String, int> anchorIndex,
  ) {
    final body = document.body;
    if (body == null) return;
    _visit(body, filePath, paragraphs, anchorIndex);
  }

  void _visit(
    dom.Element element,
    String filePath,
    List<String> paragraphs,
    Map<String, int> anchorIndex,
  ) {
    final tag = element.localName;
    if (tag == 'script' || tag == 'style' || tag == 'head') return;

    // Recurse whenever the subtree still contains nested block elements. This
    // splits real containers (div/section) into their block children, and also
    // guards against malformed markup — notably Project Gutenberg's self-closing
    // `<pre/>` marker, which the HTML5 parser reinterprets as an *open* <pre>
    // that swallows the whole chapter — from collapsing into one giant
    // paragraph.
    if (element.children.any(_containsBlock)) {
      for (final child in element.children) {
        _visit(child, filePath, paragraphs, anchorIndex);
      }
      return;
    }

    // A leaf block (p/h1/…) or an inline-only container: emit one paragraph.
    _addParagraph(element, filePath, paragraphs, anchorIndex);
  }

  bool _containsBlock(dom.Element element) {
    final tag = element.localName;
    if (tag != null && _blockTags.contains(tag)) return true;
    return element.children.any(_containsBlock);
  }

  void _addParagraph(
    dom.Element element,
    String filePath,
    List<String> paragraphs,
    Map<String, int> anchorIndex,
  ) {
    final text = element.text.replaceAll(_whitespace, ' ').trim();
    if (text.isEmpty) return;
    final index = paragraphs.length;
    paragraphs.add(text);

    // Map the id of this element and any id-bearing ancestors (up to <body>) to
    // this paragraph so TOC fragment anchors can resolve to a position.
    dom.Element? node = element;
    while (node != null && node.localName != 'body') {
      final id = node.id;
      if (id.isNotEmpty) {
        anchorIndex.putIfAbsent('$filePath#$id', () => index);
      }
      node = node.parent;
    }
  }

  List<TocEntry> _buildToc({
    required Map<String, ArchiveFile> files,
    required Map<String, _ManifestItem> manifest,
    required XmlDocument opf,
    required Map<String, int> fileStart,
    required Map<String, int> anchorIndex,
  }) {
    final raw = _readNav(files, manifest, opf);
    final entries = <TocEntry>[];
    var lastIndex = -1;
    for (final entry in raw) {
      final anchorKey = entry.fragment == null
          ? null
          : '${entry.path}#${entry.fragment}';
      final index =
          (anchorKey != null ? anchorIndex[anchorKey] : null) ??
          fileStart[entry.path];
      if (index == null || index == lastIndex) continue;
      entries.add(TocEntry(title: entry.title, paragraphIndex: index));
      lastIndex = index;
    }
    return entries;
  }

  List<_RawTocEntry> _readNav(
    Map<String, ArchiveFile> files,
    Map<String, _ManifestItem> manifest,
    XmlDocument opf,
  ) {
    // EPUB 3: a manifest item with properties="nav" (an XHTML nav document).
    for (final item in manifest.values) {
      if (item.properties.split(_whitespace).contains('nav')) {
        final content = _tryReadString(files, item.href);
        if (content != null) {
          return _parseNavDocument(content, p.posix.dirname(item.href));
        }
      }
    }

    // EPUB 2: an NCX referenced by the spine `toc` attribute or media type.
    String? ncxHref;
    final spine = opf.findAllElements('spine', namespace: '*');
    final tocId = spine.isEmpty ? null : spine.first.getAttribute('toc');
    if (tocId != null && manifest.containsKey(tocId)) {
      ncxHref = manifest[tocId]!.href;
    } else {
      for (final item in manifest.values) {
        if (item.mediaType == 'application/x-dtbncx+xml') {
          ncxHref = item.href;
          break;
        }
      }
    }
    if (ncxHref != null) {
      final content = _tryReadString(files, ncxHref);
      if (content != null) {
        return _parseNcx(content, p.posix.dirname(ncxHref));
      }
    }

    return const <_RawTocEntry>[];
  }

  List<_RawTocEntry> _parseNavDocument(String content, String baseDir) {
    final doc = html.parse(content);
    final navs = doc.querySelectorAll('nav');
    dom.Element? tocNav;
    for (final nav in navs) {
      final isToc = nav.attributes.entries.any(
        (e) => e.value.split(_whitespace).contains('toc'),
      );
      if (isToc) {
        tocNav = nav;
        break;
      }
    }
    tocNav ??= navs.isNotEmpty ? navs.first : doc.body;
    if (tocNav == null) return const <_RawTocEntry>[];

    final entries = <_RawTocEntry>[];
    for (final anchor in tocNav.querySelectorAll('a')) {
      final href = anchor.attributes['href'];
      final title = anchor.text.replaceAll(_whitespace, ' ').trim();
      if (href == null || href.isEmpty || title.isEmpty) continue;
      final entry = _resolveHref(href, baseDir, title);
      if (entry != null) entries.add(entry);
    }
    return entries;
  }

  List<_RawTocEntry> _parseNcx(String content, String baseDir) {
    final doc = XmlDocument.parse(content);
    final entries = <_RawTocEntry>[];
    for (final point in doc.findAllElements('navPoint', namespace: '*')) {
      final labels = point.findAllElements('text', namespace: '*');
      final title = labels.isEmpty
          ? ''
          : labels.first.innerText.replaceAll(_whitespace, ' ').trim();
      final contentEl = point.findAllElements('content', namespace: '*');
      final src = contentEl.isEmpty
          ? null
          : contentEl.first.getAttribute('src');
      if (title.isEmpty || src == null || src.isEmpty) continue;
      final entry = _resolveHref(src, baseDir, title);
      if (entry != null) entries.add(entry);
    }
    return entries;
  }

  _RawTocEntry? _resolveHref(String href, String baseDir, String title) {
    final hashIndex = href.indexOf('#');
    final pathPart = hashIndex >= 0 ? href.substring(0, hashIndex) : href;
    final fragment = hashIndex >= 0 ? href.substring(hashIndex + 1) : null;
    if (pathPart.isEmpty) return null;
    return _RawTocEntry(
      title: title,
      path: _resolve(baseDir, pathPart),
      fragment: fragment == null || fragment.isEmpty ? null : fragment,
    );
  }

  String _resolve(String baseDir, String href) {
    final decoded = Uri.decodeFull(href);
    final joined = baseDir.isEmpty ? decoded : p.posix.join(baseDir, decoded);
    return _normalize(p.posix.normalize(joined));
  }

  String _normalize(String path) => path.replaceAll('\\', '/');

  String _readString(Map<String, ArchiveFile> files, String path) {
    final file = files[path];
    if (file == null) throw EpubParseException('Missing archive entry: $path');
    return _decode(file);
  }

  String? _tryReadString(Map<String, ArchiveFile> files, String path) {
    final file = files[path];
    return file == null ? null : _decode(file);
  }

  String _decode(ArchiveFile file) {
    final content = file.content as List<int>;
    return utf8.decode(content, allowMalformed: true);
  }
}

class _EpubMetadata {
  const _EpubMetadata({this.title, this.author, this.language});

  final String? title;
  final String? author;
  final String? language;
}

class _ManifestItem {
  const _ManifestItem({
    required this.id,
    required this.href,
    required this.mediaType,
    required this.properties,
  });

  final String id;
  final String href;
  final String mediaType;
  final String properties;
}

class _RawTocEntry {
  const _RawTocEntry({
    required this.title,
    required this.path,
    required this.fragment,
  });

  final String title;
  final String path;
  final String? fragment;
}
