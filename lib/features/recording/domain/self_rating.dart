// Self-rating options for the recording practice flow.
//
// T012 scope: a tiny enum that lets the user label a recorded take as
// one of three buckets. We deliberately keep this as a plain enum
// (not a class with payload, not a freezed model) because the MVP
// does not need anything more than a three-way switch and a label.
//
// Strings are produced via [label] instead of relying on
// `enum.name` so the user-facing copy stays in 中文 and can be
// tweaked without renaming identifiers.

/// Self-assessment choice after listening back to a take.
///
/// Kept in domain layer (rather than directly in the controller)
/// because the page renders it and any future persistence layer
/// (T013) will read/write it.
enum SelfRating {
  /// "Not bad" — the take is good enough to keep.
  good,

  /// "Meh" — usable, but the user can hear rough spots.
  okay,

  /// "Try again" — the take needs another attempt.
  retry;

  /// Chinese label rendered in the UI.
  String get label {
    switch (this) {
      case SelfRating.good:
        return '还不错';
      case SelfRating.okay:
        return '一般';
      case SelfRating.retry:
        return '需要重练';
    }
  }

  /// Short Chinese label for compact rows (e.g. status chips).
  String get shortLabel {
    switch (this) {
      case SelfRating.good:
        return '好';
      case SelfRating.okay:
        return '一般';
      case SelfRating.retry:
        return '重练';
    }
  }
}
