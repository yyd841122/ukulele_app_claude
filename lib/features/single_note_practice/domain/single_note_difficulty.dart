// Difficulty tier for a single-note practice item.
//
// T009 scope:
// - Plain Dart enum, no codegen. Mirrors the chord library's
//   [ChordDifficulty] shape so the UI can render a similar chip
//   without forking the styling logic.
// - The tier is a *coarse* signal: it is derived from how many
//   fingers the note needs (open / 1-finger) and whether the fret
//   is at the dusty end of the neck. The detailed practice advice
//   lives in [SingleNote.tips].

/// How easy it is for a beginner to play this single note cleanly.
enum SingleNoteDifficulty {
  /// Open string, no fretting required.
  /// Examples in the built-in data: C (3rd string open), E (2nd
  /// string open), G (4th string open), A (1st string open).
  openString,

  /// One finger on a 1st-fret position. Comfortable for absolute
  /// beginners, but the very first time a beginner presses a string
  /// it can still buzz.
  /// Example in the built-in data: F (2nd string, fret 1).
  firstFret,

  /// One finger past the 1st fret. Common for extending the
  /// vocabulary after the first week of practice.
  /// Example in the built-in data: D (3rd string, fret 2).
  higherFret,
}

/// Human-readable Chinese label for the difficulty tier.
///
/// T009 keeps the lookup colocated with the enum so the UI does not
/// have to import a separate labels file.
extension SingleNoteDifficultyLabel on SingleNoteDifficulty {
  String get label {
    switch (this) {
      case SingleNoteDifficulty.openString:
        return '空弦';
      case SingleNoteDifficulty.firstFret:
        return '一品';
      case SingleNoteDifficulty.higherFret:
        return '高把位';
    }
  }
}
