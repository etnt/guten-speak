/// Engine-independent text preparation shared by every TTS engine.
///
/// This is the single home for the quote normalization and runaway-retry
/// splitting that used to live inside the sherpa worker. Both behaviors affect
/// the produced audio, so they are versioned by [kTtsTextPolicyVersion]: any
/// change here must bump that constant so audio cached under the old policy is
/// keyed separately and never reused across a behavior change.
library;

/// Version of the text normalization + retry-splitting policy.
///
/// Bump on any behavioral change to [normalizeTtsText], [splitTtsRetryPhrases],
/// or [plausibleAudioSeconds].
const int kTtsTextPolicyVersion = 1;

/// Removes visual quote punctuation that PocketTTS-family models tend to trip
/// over.
///
/// Quote glyphs are visual punctuation, not speech. The model can miss its stop
/// token on a trailing smart quote (for example `.”`), producing a grinding
/// noise tail. Straight/curly double quotes are dropped entirely and curly
/// single quotes are folded to a plain apostrophe.
String normalizeTtsText(String text) {
  return text
      .replaceAll('"', '')
      .replaceAll('\u201C', '')
      .replaceAll('\u201D', '')
      .replaceAll('\u201E', '')
      .replaceAll('\u201F', '')
      .replaceAll('\u2018', "'")
      .replaceAll('\u2019', "'");
}

/// Plausible upper bound, in seconds, for the audio a [phrase] should produce.
///
/// Used to reject a runaway generation (a missed stop token that appends a long
/// grinding tail) before it is ever cached.
double plausibleAudioSeconds(String phrase) => phrase.length / 10.0 + 4.0;

/// Splits a rejected utterance into shorter retry phrases, preferring clause
/// punctuation and then whitespace so the fallback keeps natural prosody.
List<String> splitTtsRetryPhrases(String text, {int maxChars = 80}) {
  final phrases = <String>[];
  var remaining = text.trim();
  while (remaining.length > maxChars) {
    var cut = -1;
    for (var i = maxChars; i >= maxChars ~/ 2; i--) {
      if (',;:'.contains(remaining[i])) {
        cut = i + 1;
        break;
      }
    }
    if (cut < 0) {
      cut = remaining.lastIndexOf(' ', maxChars);
    }
    if (cut <= 0) cut = maxChars;
    phrases.add(remaining.substring(0, cut).trim());
    remaining = remaining.substring(cut).trim();
  }
  if (remaining.isNotEmpty) phrases.add(remaining);
  return phrases;
}
