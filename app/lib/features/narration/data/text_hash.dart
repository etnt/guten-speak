/// A deterministic 64-bit FNV-1a hash of [text], as a zero-padded hex string.
///
/// Used to key cached narration audio by its source text so a clip can be
/// detected as stale when the underlying book text changes (e.g. on
/// re-download). Dart's built-in `String.hashCode` is **not** stable across
/// runs/isolates, so it cannot be used for a persisted cache key — hence this
/// explicit, portable hash.
String stableTextHash(String text) {
  const int offsetBasis = 0xcbf29ce484222325;
  const int prime = 0x100000001b3;

  var hash = offsetBasis;
  final units = text.codeUnits;
  for (final unit in units) {
    // Fold each UTF-16 code unit as two bytes so multibyte characters still
    // contribute deterministically without a UTF-8 dependency.
    hash = (hash ^ (unit & 0xff)) * prime;
    hash = (hash ^ ((unit >> 8) & 0xff)) * prime;
  }
  // Emit as two unsigned 32-bit halves: a signed 64-bit int with its high bit
  // set is negative, and `toRadixString` would otherwise prepend a '-'.
  final high = (hash >>> 32) & 0xffffffff;
  final low = hash & 0xffffffff;
  return high.toRadixString(16).padLeft(8, '0') +
      low.toRadixString(16).padLeft(8, '0');
}
