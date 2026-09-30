// ============================================================================
// levenshteinDistance
// ----------------------------------------------------------------------------
// Classic edit-distance algorithm: the minimum number of single-character
// insertions, deletions, or substitutions needed to turn `a` into `b`. Used
// to power the tag editor's "did you mean...?" typo suggestion - a small
// distance between a newly typed tag and an existing one usually means a
// typo, not a genuinely new tag.
// ============================================================================
int levenshteinDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  // Only the previous row of the DP table is ever needed to compute the
  // next one, so we keep a single rolling row instead of a full matrix.
  var previousRow = List<int>.generate(b.length + 1, (i) => i);

  for (var i = 0; i < a.length; i++) {
    final currentRow = List<int>.filled(b.length + 1, 0);
    currentRow[0] = i + 1;

    for (var j = 0; j < b.length; j++) {
      final deletionCost = previousRow[j + 1] + 1;
      final insertionCost = currentRow[j] + 1;
      final substitutionCost = previousRow[j] + (a[i] == b[j] ? 0 : 1);
      currentRow[j + 1] = [
        deletionCost,
        insertionCost,
        substitutionCost,
      ].reduce((x, y) => x < y ? x : y);
    }

    previousRow = currentRow;
  }

  return previousRow[b.length];
}
