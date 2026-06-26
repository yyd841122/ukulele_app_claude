// Lesson Engine — Learning Metrics (T057_ADAPTIVE_LEARNING_SYSTEM).
//
// What this file is:
// - The T057 metric layer: pure value types that capture what
//   happened on a single task attempt, plus a per-session
//   accumulator the policy consumes.
// - T057 does NOT persist these to the database. They live in
//   memory (a Riverpod-owned list) and are exposed to the
//   adaptive policy. T058+ can move them to a `practice_metrics`
//   table once the schema is decided.
//
// Why a separate domain file:
// - The existing `ToolResult` / `TaskOutcome` (T056) already
//   capture terminal status + elapsed time. T057 ADDS a
//   "did the user actually get it right?" dimension which
//   T055/T056 deliberately do NOT model — T055/T056 are
//   pre-P2-AI scope and should not change. Keeping the new
//   types in their own file means the T056 surface stays
//   untouched.
//
// Inputs to the policy:
// - `TaskAttemptMetric` — one row per task completion. T057
//   derives it from a `TaskOutcome` plus the
//   `ToolResult.metadata` side-channel that the policy reads
//   to extract `correct` / `wrong` / `partial` / `accuracy`.
//   The fallback (no metadata) treats the outcome as a single
//   "completed" attempt with neutral evidence (no up, no down).
// - `TaskAttemptHistory` — the accumulating list. The policy
//   pulls aggregates (consecutive corrects, error rate, average
//   elapsed) without iterating raw rows in hot paths.

import 'package:flutter/foundation.dart';

import 'package:ukulele_app/features/lesson_engine/domain/lesson.dart';
import 'package:ukulele_app/features/lesson_engine/domain/lesson_task_type.dart';
import 'package:ukulele_app/features/lesson_engine/domain/task_tool_binding.dart';

/// What the policy infers from a single [TaskOutcome].
///
/// T057 deliberately uses a small enum (NOT a free-form
/// accuracy double) so the policy rules can be written as
/// readable `switch` statements. The conversion from
/// `ToolResult.metadata` → [AttemptVerdict] lives in
/// `learning_metrics.dart`'s `AttemptVerdict.fromMetadata`.
///
/// Why not store raw accuracy directly:
/// - The Demo A tools do not all produce a numeric accuracy
///   (the tuner page has no notion of "right" vs "wrong"). A
///   verdict enum lets the policy reason uniformly about
///   tools that emit accuracy and tools that don't.
enum AttemptVerdict {
  /// The tool reported a "correct" signal. Treated as evidence
  /// the user nailed this attempt.
  correct,

  /// The tool reported a "wrong" signal (error / fail). Treated
  /// as evidence the user missed this attempt.
  wrong,

  /// The tool reported a partial result. Treated as weak
  /// "almost there" evidence; the policy uses this for the
  /// "no escalation yet" middle ground.
  partial,

  /// The tool did not emit enough information to classify the
  /// attempt. Treated as a neutral signal — does not move
  /// skill scores up or down.
  unknown,
}

/// A single recorded attempt the policy can branch on.
///
/// T057 fields:
/// - [taskId] is the source `LessonTask.id` (mirrors T055/T056).
/// - [taskType] is the source [LessonTaskType] so the policy
///   can route the attempt to the right skill axis without
///   re-querying the lesson plan.
/// - [verdict] is what the policy uses to update the skill
///   model (see `SkillTracker.recordOutcome`).
/// - [accuracy] is the optional numeric accuracy in [0.0, 1.0]
///   when the tool emitted one (Demo A today does not; future
///   AI scoring will). The policy uses this as a tie-breaker
///   between two attempts of the same verdict.
/// - [elapsedMs] is the wall-clock from T056's [TaskOutcome].
///   The policy treats very fast + correct as a mastery signal
///   and very slow + wrong as a struggle signal.
/// - [retryCount] is the number of retries the user burned
///   before the tool returned. The policy uses this to
///   escalate "needs more repetition" decisions.
@immutable
class TaskAttemptMetric {
  const TaskAttemptMetric({
    required this.taskId,
    required this.taskType,
    required this.verdict,
    required this.elapsedMs,
    this.accuracy,
    this.retryCount = 0,
  })  : assert(elapsedMs >= 0,
            'TaskAttemptMetric.elapsedMs must be >= 0; got $elapsedMs'),
        assert(retryCount >= 0,
            'TaskAttemptMetric.retryCount must be >= 0; got $retryCount'),
        assert(accuracy == null || (accuracy >= 0.0 && accuracy <= 1.0),
            'TaskAttemptMetric.accuracy must be in 0.0..1.0 or null');

  /// Source task id.
  final String taskId;

  /// Source semantic type. The tracker uses this to know
  /// which skill axis to update (rhythm / chord / note).
  final LessonTaskType taskType;

  /// The verdict the policy branches on.
  final AttemptVerdict verdict;

  /// Wall-clock from `TaskOutcome.elapsedMs`.
  final int elapsedMs;

  /// Optional numeric accuracy. `null` when the tool did not
  /// emit one.
  final double? accuracy;

  /// Number of retries the user burned. Defaults to 0.
  final int retryCount;

  /// Maps a [ToolResultStatus] + its `metadata` side-channel
  /// into a [TaskAttemptMetric].
  ///
  /// T057 contract:
  /// - `metadata` is consulted FIRST. The well-known keys
  ///   are:
  ///     * `'verdict'` (String): `'correct'` / `'wrong'` /
  ///       `'partial'`. Recognising these by name lets a
  ///       future Demo A surface opt-in to the adaptive
  ///       policy without code changes.
  ///     * `'accuracy'` (num / double): numeric accuracy in
  ///       [0.0, 1.0]. Out-of-range values are clamped.
  ///     * `'retryCount'` (int): number of retries. Negative
  ///       values are clamped to 0.
  /// - If `metadata` does not carry a `verdict`, the
  ///   [TaskOutcome.result.status] is used as a coarse
  ///   fallback:
  ///     * [ToolResultStatus.completed] → [AttemptVerdict.unknown]
  ///       (T057 keeps "completed" as neutral so the policy
  ///       does not move scores up on a tool that never
  ///       reported right / wrong).
  ///     * [ToolResultStatus.skipped]   → [AttemptVerdict.unknown].
  ///     * [ToolResultStatus.failed]    → [AttemptVerdict.wrong]
  ///       (a tool-level failure is the closest thing the
  ///       policy has to a "user got it wrong" signal).
  /// - The source [LessonTaskType] is recovered from the
  ///   [Lesson] the tracker already has in scope; this
  ///   factory does NOT need a lesson reference because the
  ///   tracker passes the type in directly. We keep the
  ///   factory small on purpose.
  factory TaskAttemptMetric.fromOutcome({
    required TaskOutcome outcome,
    required LessonTaskType taskType,
  }) {
    final Map<String, Object> md = outcome.result.metadata;
    final AttemptVerdict verdict = _verdictFromMetadata(md, outcome.result.status);
    final double? accuracy = _accuracyFromMetadata(md);
    final int retryCount = _retryCountFromMetadata(md);
    return TaskAttemptMetric(
      taskId: outcome.binding.taskId,
      taskType: taskType,
      verdict: verdict,
      elapsedMs: outcome.elapsedMs,
      accuracy: accuracy,
      retryCount: retryCount,
    );
  }

  static AttemptVerdict _verdictFromMetadata(
    Map<String, Object> md,
    ToolResultStatus status,
  ) {
    final Object? raw = md['verdict'];
    if (raw is String) {
      switch (raw) {
        case 'correct':
          return AttemptVerdict.correct;
        case 'wrong':
          return AttemptVerdict.wrong;
        case 'partial':
          return AttemptVerdict.partial;
      }
    }
    switch (status) {
      case ToolResultStatus.failed:
        return AttemptVerdict.wrong;
      case ToolResultStatus.completed:
      case ToolResultStatus.skipped:
        return AttemptVerdict.unknown;
    }
  }

  static double? _accuracyFromMetadata(Map<String, Object> md) {
    final Object? raw = md['accuracy'];
    if (raw is num) {
      final double v = raw.toDouble();
      if (v.isNaN) return null;
      if (v < 0.0) return 0.0;
      if (v > 1.0) return 1.0;
      return v;
    }
    return null;
  }

  static int _retryCountFromMetadata(Map<String, Object> md) {
    final Object? raw = md['retryCount'];
    if (raw is int) return raw < 0 ? 0 : raw;
    if (raw is num) {
      final int v = raw.toInt();
      return v < 0 ? 0 : v;
    }
    return 0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskAttemptMetric &&
          other.taskId == taskId &&
          other.taskType == taskType &&
          other.verdict == verdict &&
          other.elapsedMs == elapsedMs &&
          other.accuracy == accuracy &&
          other.retryCount == retryCount);

  @override
  int get hashCode => Object.hash(
        taskId,
        taskType,
        verdict,
        elapsedMs,
        accuracy,
        retryCount,
      );
}

/// An append-only, in-memory history of attempts.
///
/// T057 contract:
/// - The list is non-growable: the tracker always returns a
///   NEW [TaskAttemptHistory] with one extra element rather
///   than mutating the previous one. This keeps the policy
///   pure (it can read `history` and reason about it without
///   worrying about concurrent writes).
/// - The aggregate getters (`errorRate`, `consecutiveCorrects`,
///   `averageElapsedMs`) are computed lazily over the full
///   list. The history is bounded by user behavior (at most a
///   few hundred entries per day) so the O(n) cost is
///   acceptable; if T058 ships larger histories the aggregates
///   can move to incremental fields.
@immutable
class TaskAttemptHistory {
  /// Creates a history from a raw list. The list is copied so
  /// callers can mutate their source without affecting the
  /// history.
  const TaskAttemptHistory(this.attempts);

  /// The "no attempts yet" state. Used as the seed the
  /// tracker starts from.
  static const TaskAttemptHistory initial =
      TaskAttemptHistory(<TaskAttemptMetric>[]);

  /// The raw attempts in chronological order. Non-growable.
  final List<TaskAttemptMetric> attempts;

  /// The most recent attempt, or `null` if the history is
  /// empty. The policy uses this to drive "consecutive
  /// correct" / "consecutive wrong" calculations.
  TaskAttemptMetric? get last => attempts.isEmpty ? null : attempts.last;

  /// Length of the trailing run of `correct` verdicts. Zero
  /// when the last attempt is anything else (or there is no
  /// last attempt).
  int get consecutiveCorrects {
    int n = 0;
    for (int i = attempts.length - 1; i >= 0; i--) {
      if (attempts[i].verdict != AttemptVerdict.correct) break;
      n++;
    }
    return n;
  }

  /// Length of the trailing run of `wrong` verdicts. Zero
  /// when the last attempt is anything else (or there is no
  /// last attempt).
  int get consecutiveWrongs {
    int n = 0;
    for (int i = attempts.length - 1; i >= 0; i--) {
      if (attempts[i].verdict != AttemptVerdict.wrong) break;
      n++;
    }
    return n;
  }

  /// Total wrong attempts divided by total attempts. Returns
  /// 0.0 when the history is empty. The policy uses this as a
  /// "global error rate" signal that complements the
  /// per-axis verdict tracking.
  double get errorRate {
    if (attempts.isEmpty) return 0.0;
    int wrong = 0;
    for (final TaskAttemptMetric a in attempts) {
      if (a.verdict == AttemptVerdict.wrong) wrong++;
    }
    return wrong / attempts.length;
  }

  /// Average wall-clock across all attempts, in ms. Returns
  /// 0 when the history is empty. The policy treats a
  /// sustained drop in average elapsed as a "getting faster"
  /// signal.
  int get averageElapsedMs {
    if (attempts.isEmpty) return 0;
    int total = 0;
    for (final TaskAttemptMetric a in attempts) {
      total += a.elapsedMs;
    }
    return total ~/ attempts.length;
  }

  /// Returns a new history with [metric] appended.
  TaskAttemptHistory append(TaskAttemptMetric metric) {
    return TaskAttemptHistory(
      List<TaskAttemptMetric>.unmodifiable(
        <TaskAttemptMetric>[...attempts, metric],
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TaskAttemptHistory) return false;
    if (other.attempts.length != attempts.length) return false;
    for (int i = 0; i < attempts.length; i++) {
      if (other.attempts[i] != attempts[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(attempts);
}
