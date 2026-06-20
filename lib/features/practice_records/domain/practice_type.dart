// Primary practice type of a [PracticeRecord].
//
// T013.2 scope:
// - Mirrors DATA_MODEL_DRAFT.md §2.2. Five cases; `tuner` and
//   `selfAssessment` deliberately do NOT appear here — they are
//   PracticeTag entries (see `practice_tag.dart`) because they are
//   adjuncts to a session, not the primary activity.
// - Stored as the enum-case `name` string so future re-orderings do
//   not shift historical data.

/// Primary practice type of a [PracticeRecord].
enum PracticeType {
  /// 单音练习 (single-note practice).
  singleNote,

  /// 和弦练习 (chord practice).
  chord,

  /// 节拍器练习 (metronome practice).
  metronome,

  /// 录音练习 (recording practice).
  recording,

  /// 混合类型 (mixed — e.g. tuning + single-note + recording).
  mixed,
}
