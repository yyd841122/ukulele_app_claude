// Practice tags attached to a [PracticeRecord].
//
// T013.2 scope:
// - Mirrors DATA_MODEL_DRAFT.md §2.3. Each tag is serialised to its
//   enum-case `name` and persisted as a JSON array string under
//   `practice_records.practice_tags_json`.
// - The list may be empty for sessions that only carry a single
//   primary type with no extra tags.
// - The Repository layer is the SOLE boundary that converts between
//   `List<PracticeTag>` ↔ `String` (via `jsonEncode` / `jsonDecode`).
//   Domain code never touches raw JSON.

/// Tag attached to a [PracticeRecord] to describe adjunct activities
/// (e.g. "the user also tuned before this session").
enum PracticeTag {
  /// 调音器 (tuner).
  tuner,

  /// 单音练习 (single-note).
  singleNote,

  /// 和弦练习 (chord).
  chord,

  /// 节拍器 (metronome).
  metronome,

  /// 录音 (recording).
  recording,

  /// 手动自评 (manual self-assessment).
  selfAssessment,
}
