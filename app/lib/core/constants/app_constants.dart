class AppConstants {
  static const String appName = 'Guten-Speak';
  static const String gutendexBaseUrl = 'https://gutendex.com';
  static const String booksPath = '/books';
  static const String userAgent =
      'GutenSpeak/1.0 (https://github.com/etnt/guten-speak)';

  // Navigation Keys & Routes
  static const String routeDiscover = '/discover';
  static const String routeLibrary = '/library';
  static const String routeSettings = '/settings';
  static const String routeSearch = '/search';
  static const String routeBookDetail = '/book/:id';
  static const String routeReader = '/read/:id';

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
