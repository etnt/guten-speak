class AppConstants {
  static const String appName = 'Guten-Speak';

  /// App version shown in the UI. Injected at release-build time from the
  /// latest git tag (e.g. `v1.0.0`) via `--dart-define=APP_VERSION=...`;
  /// defaults to `dev` for debug/local builds.
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: 'dev',
  );

  static const String gutendexBaseUrl = 'https://gutendex.com';
  static const String booksPath = '/books';
  static const String userAgent =
      'GutenSpeak/1.0 (https://github.com/etnt/guten-speak)';

  /// Project Gutenberg's full catalog dump. Downloaded once and indexed locally
  /// so search/detail work offline and don't depend on the flaky Gutendex API.
  static const String catalogCsvUrl =
      'https://www.gutenberg.org/cache/epub/feeds/pg_catalog.csv';

  /// Direct plain-text (UTF-8) download URL for a book, derived from its id.
  /// Project Gutenberg auto-generates this for every `Text` entry.
  static String plainTextUrl(int id) =>
      'https://www.gutenberg.org/ebooks/$id.txt.utf-8';

  /// EPUB (with images) download URL for a book, derived from its id.
  /// Preferred over plain text because it carries a publisher-authored table of
  /// contents; falls back to [plainTextUrl] when no EPUB edition exists.
  static String epubUrl(int id) =>
      'https://www.gutenberg.org/ebooks/$id.epub3.images';

  /// Medium cover-thumbnail URL for a book, derived from its id.
  static String coverImageUrl(int id) =>
      'https://www.gutenberg.org/cache/epub/$id/pg$id.cover.medium.jpg';

  // Navigation Keys & Routes
  static const String routeDiscover = '/discover';
  static const String routeLibrary = '/library';
  static const String routeSettings = '/settings';
  static const String routeSearch = '/search';
  static const String routeBookDetail = '/book/:id';
  static const String routeReader = '/read/:id';
  static const String routeListen = '/listen/:id';
  static const String routeVoices = '/voices';

  /// Curated subjects surfaced on the Discover screen.
  static const List<String> curatedSubjects = <String>[
    'Fiction',
    'Adventure',
    'History',
    'Science Fiction',
    'Philosophy',
    'Poetry',
    'Fantasy',
    'Drama',
  ];
}
