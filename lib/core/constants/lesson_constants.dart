// Built-in lesson constants for the beginner learning phase 2.
//
// T043 scope:
// - Pure-Dart constants for the static `C ↔ Am` 4/4 down-strum
//   lesson, the first vertical slice of the beginner teaching
//   layer (T041 / T042 design; this task is assets + widget
//   only).
// - The data shape follows the model pinned in
//   `tasks/T041_BEGINNER_LEARNING_PHASE_2_SCOPE.md` §4.1 and
//   the content in `docs/learning/lesson_c_am_down_4x4.md`:
//   * `Lesson`      — top-level lesson aggregate, indexed by `id`
//   * `LessonStep`  — an ordered practice step inside a lesson
//   * `StrumPattern`— the rhythm pattern (beats + direction + chord
//                     sequence) referenced by a lesson
//   * `StrumDirection` enum — `down` (only used in T043) and `up`
//                     (forward-compat placeholder, **not** used by
//                     T043)
// - Lessons / lesson steps / strum patterns are **not** persisted
//   in the database (T041 §4.2 — same convention as
//   `practice_plan_constants.dart`): they are code-resident
//   constants so a future copy change does not require a schema
//   migration. PracticeRecord is untouched, schemaVersion stays at 1.
// - This file deliberately does **not** import Flutter. It can be
//   pulled into Dart-only unit tests, build scripts, or other
//   tooling without dragging the framework.
//
// What this file does NOT do:
// - No I/O, no Riverpod, no providers, no Flutter widgets.
// - No reference to `MetronomeController` /
//   `RecordingPracticeController` / `PracticeRecordRepository` /
//   any Drift schema.
// - No lesson flow / route / LessonPage glue — that lands in T044.

/// Direction of a strum. T043 only ships `down`; `up` is reserved
/// for future lessons (Day 5 / Day 6 / Day 7) that may add up-strum
/// or `down-up` patterns without an enum churn.
enum StrumDirection { down, up }

/// Static rhythm pattern used by a lesson.
///
/// The pattern is **pure data** — it does not render anything by
/// itself. The accompanying `StrumPatternDiagram` widget
/// (T043) reads these fields to draw the visual; the metronome
/// controller and `MetronomeSetting` remain unaware of rhythm
/// patterns per PRD §6.5 ("节奏型 不做").
class StrumPattern {
  const StrumPattern({
    required this.id,
    required this.name,
    required this.beatsPerMeasure,
    required this.direction,
    required this.chordSequencePerBeat,
  });

  /// Stable lowercase id, e.g. `"down_4x4_c_am"`. Used as the
  /// lookup key — UI never compares by [name].
  final String id;

  /// Human-readable Chinese name, e.g. `"4/4 全下扫（C↔Am）"`.
  final String name;

  /// Beats per measure. Always `4` for the T043 lesson; the field
  /// exists so future lessons (3/4 waltz, 6/8) can extend without
  /// reshaping the data.
  final int beatsPerMeasure;

  /// Strum direction. T043 only ever sets [StrumDirection.down].
  final StrumDirection direction;

  /// Chord symbol per beat, ordered beat 1 → N. Length must equal
  /// [beatsPerMeasure]. T043 ships `["C", "C", "Am", "Am"]` —
  /// chord switches on beat 3 per
  /// `docs/learning/lesson_c_am_down_4x4.md` §4.4.
  final List<String> chordSequencePerBeat;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StrumPattern &&
          other.id == id &&
          other.name == name &&
          other.beatsPerMeasure == beatsPerMeasure &&
          other.direction == direction &&
          _listEquals(other.chordSequencePerBeat, chordSequencePerBeat));

  @override
  int get hashCode => Object.hash(
        id,
        name,
        beatsPerMeasure,
        direction,
        Object.hashAll(chordSequencePerBeat),
      );
}

/// One ordered practice step inside a [Lesson].
///
/// `bpm` is optional because Step 3 (record & review) in the
/// `c_am_down_4x4` lesson does not run on the metronome — it
/// re-uses the existing `/recording` page, which the user is
/// expected to have set to 80 BPM via the metronome controls.
class LessonStep {
  const LessonStep({
    required this.order,
    required this.instruction,
    this.bpm,
  });

  /// 1-based step number. Lessons MUST list steps in ascending
  /// order with no gaps starting at 1.
  final int order;

  /// Short Chinese instruction shown on the lesson page. Kept
  /// terse — the long-form text lives in
  /// `docs/learning/lesson_c_am_down_4x4.md`.
  final String instruction;

  /// Optional target BPM. When `null` the step is not metronome-
  /// driven (e.g. record / review).
  final int? bpm;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LessonStep &&
          other.order == order &&
          other.bpm == bpm &&
          other.instruction == instruction);

  @override
  int get hashCode => Object.hash(order, bpm, instruction);
}

/// Top-level lesson aggregate — the unit a future `LessonPage`
/// (T044) would render.
///
/// Lessons are keyed by `id` (lowercase, snake_case). The id is the
/// only thing the route layer cares about, so renaming [title] /
/// [description] is safe but renaming `id` is a breaking change.
class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.description,
    required this.linkedTaskIds,
    required this.strumPattern,
    required this.steps,
  });

  /// Stable lowercase id, e.g. `"c_am_down_4x4"`. Used as the
  /// route key in T044.
  final String id;

  /// Short Chinese title for the lesson page header.
  final String title;

  /// One-sentence description (Chinese) shown beneath the title.
  final String description;

  /// 7-day-plan task ids this lesson is layered on top of (T041
  /// §3.1 — overlay, not replacement). T043 lesson only touches
  /// `day4_chord_switch`.
  final List<String> linkedTaskIds;

  /// The static rhythm pattern this lesson teaches. Drives the
  /// `StrumPatternDiagram` widget and is pinned by tests.
  final StrumPattern strumPattern;

  /// Ordered practice steps. `order` MUST be `1..N` with no gaps.
  final List<LessonStep> steps;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Lesson &&
          other.id == id &&
          other.title == title &&
          other.description == description &&
          _listEquals(other.linkedTaskIds, linkedTaskIds) &&
          other.strumPattern == strumPattern &&
          _listEquals(other.steps, steps));

  @override
  int get hashCode => Object.hash(
        id,
        title,
        description,
        Object.hashAll(linkedTaskIds),
        strumPattern,
        Object.hashAll(steps),
      );
}

/// The built-in lesson list, ordered as displayed.
///
/// T043 ships exactly one entry — the `C ↔ Am` 4/4 down-strum
/// lesson. Future lessons (Day 3 single-chord, Day 5 F/G,
/// Day 6 C-Am-F-G loop) will append entries here per T041 §4.1
/// without modifying existing ones.
const List<Lesson> kBuiltInLessons = <Lesson>[
  Lesson(
    id: 'c_am_down_4x4',
    title: 'C ↔ Am 4/4 下扫入门',
    description: '本节目标：在节拍器 80 BPM 下，每拍下扫 1 次，'
        'C 与 Am 每 2 拍切换 1 次，连续循环 8 小节。',
    linkedTaskIds: <String>['day4_chord_switch'],
    strumPattern: StrumPattern(
      id: 'down_4x4_c_am',
      name: '4/4 全下扫（C↔Am）',
      beatsPerMeasure: 4,
      direction: StrumDirection.down,
      chordSequencePerBeat: <String>['C', 'C', 'Am', 'Am'],
    ),
    steps: <LessonStep>[
      LessonStep(
        order: 1,
        bpm: 60,
        instruction: '在节拍器 60 BPM 下慢速按拍，每拍下扫 1 次，'
            '每 2 拍换 1 次和弦；连续 4 小节不抢拍不拖拍。',
      ),
      LessonStep(
        order: 2,
        bpm: 80,
        instruction: '把节拍器调到 80 BPM，连续 8 小节（32 拍）'
            '完成 C → Am → C → Am 循环。',
      ),
      LessonStep(
        order: 3,
        instruction: '在 80 BPM 下录 1 段 30-60 秒练习，回放并完成自评。',
      ),
    ],
  ),
];

// ---- internal helpers ----

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
