/// A single reading unit in the engine-independent TTS benchmark corpus.
///
/// The corpus is deliberately engine- and profile-agnostic (see plan §10/§11):
/// the same units are replayed against the sherpa baseline and every Raven
/// candidate so results are directly comparable.
class BenchmarkUnit {
  const BenchmarkUnit({
    required this.id,
    required this.category,
    required this.text,
  });

  factory BenchmarkUnit.fromJson(Map<String, Object?> json) => BenchmarkUnit(
    id: json['id']! as String,
    category: json['category']! as String,
    text: json['text']! as String,
  );

  /// Stable identifier so a unit's results line up across engines and runs.
  final String id;

  /// Coarse bucket for reporting (for example `short`, `median`, `near_limit`,
  /// `dialogue`, `numbers`, `smart_quotes`).
  final String category;

  /// The reading unit text, before any engine-specific normalization.
  final String text;

  int get charCount => text.length;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'category': category,
    'text': text,
  };
}

/// The versioned benchmark corpus.
class BenchmarkCorpus {
  const BenchmarkCorpus({required this.version, required this.units});

  factory BenchmarkCorpus.fromJson(Map<String, Object?> json) {
    final rawUnits = (json['units']! as List<Object?>)
        .map((e) => BenchmarkUnit.fromJson(e! as Map<String, Object?>))
        .toList(growable: false);
    return BenchmarkCorpus(version: json['version']! as int, units: rawUnits);
  }

  /// Bumped whenever the corpus contents change, so a result set records which
  /// corpus it was measured against.
  final int version;

  final List<BenchmarkUnit> units;

  int get length => units.length;
}
