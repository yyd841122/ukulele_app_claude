// Difficulty tier for a ukulele chord.
//
// T008 scope:
// - Plain Dart enum, no codegen. The labels are kept short so they can
//   be rendered as a Chip on the chord card without wrapping.
// - We intentionally keep the enum *coarse* (3 levels). It is only used
//   by the UI to give beginners a rough sense of progression; the
//   detailed practice advice lives in [Chord.tips].

/// How hard a chord is for a beginner to fret cleanly.
enum ChordDifficulty {
  /// One finger, no barree, comfortable for absolute beginners.
  /// Example: C.
  beginner,

  /// Two or three fingers, no barree, some stretch required.
  /// Example: Am.
  easy,

  /// Requires a barree or a wide stretch, harder for small hands.
  /// Example: F.
  intermediate,
}

/// Human-readable Chinese label for the difficulty tier.
///
/// T008 keeps the lookup colocated with the enum so the UI does not
/// have to import a separate labels file.
extension ChordDifficultyLabel on ChordDifficulty {
  String get label {
    switch (this) {
      case ChordDifficulty.beginner:
        return '入门';
      case ChordDifficulty.easy:
        return '简单';
      case ChordDifficulty.intermediate:
        return '进阶';
    }
  }
}
