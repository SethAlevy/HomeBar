// ============================================================================
// stripPolishDiacritics
// ----------------------------------------------------------------------------
// Polish uses several accented letters (ą, ć, ę, ł, ń, ó, ś, ź, ż) that don't
// exist on a standard keyboard layout, so users often type the plain-ASCII
// letter instead (e.g. "pomaranczowy" instead of "pomarańczowy"). This
// function converts a string to an "ASCII-only" version by replacing every
// accented Polish letter with its unaccented equivalent, so two spellings of
// the same word can be compared as if the accents didn't matter.
//
// It does NOT lowercase the text - callers that want a case-insensitive
// comparison should call `.toLowerCase()` themselves, the same way they
// would for any other string comparison.
// ============================================================================

// One entry per accented letter, both lowercase and uppercase, mapped to the
// plain Latin letter a Polish keyboard-less user would type instead.
const Map<String, String> _polishDiacriticsToAscii = {
  'ą': 'a', 'ć': 'c', 'ę': 'e', 'ł': 'l', 'ń': 'n',
  'ó': 'o', 'ś': 's', 'ź': 'z', 'ż': 'z',
  'Ą': 'A', 'Ć': 'C', 'Ę': 'E', 'Ł': 'L', 'Ń': 'N',
  'Ó': 'O', 'Ś': 'S', 'Ź': 'Z', 'Ż': 'Z',
};

String stripPolishDiacritics(String input) {
  final buffer = StringBuffer();
  // Iterating `.runes` instead of indexing by `int` is what keeps this safe
  // for any Unicode input, not just the Polish letters we're translating.
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_polishDiacriticsToAscii[char] ?? char);
  }
  return buffer.toString();
}
