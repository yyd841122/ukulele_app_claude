// Status of a single practice task in the 7-day plan.
//
// T007 scope:
// - Per PRD §9, completion is tracked per-task; missing tasks do NOT penalise
//   the user nor shift the plan forward.
// - This is an in-memory state only; persistence is intentionally out of
//   scope for T007 (installDate + completed tasks are session-level only).
//   Real persistence comes in T013 (Drift) or later.

enum PracticeTaskStatus {
  /// Not yet marked as complete.
  todo,

  /// User has checked off this task.
  done,
}
