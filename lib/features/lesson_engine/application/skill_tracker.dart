// Lesson Engine — Skill Tracker (T057_ADAPTIVE_LEARNING_SYSTEM).
//
// What this class is:
// - The T057 accumulator. Given a fresh [TaskOutcome] +
//   the source [LessonTaskType], it produces:
//     1. A NEW [SkillState] with the relevant axis nudged
//        based on the attempt's verdict.
//     2. A NEW [TaskAttemptMetric] describing the attempt.
//     3. A NEW [TaskAttemptHistory] with the metric appended.
// - The tracker is a pure function: it has no Riverpod / no I/O
//   / no time. State persistence is the job of the
//   [SkillTrackerController] (see `adaptive_policy_providers.dart`).
//
// Why a dedicated class (vs. inlining into the policy):
// - The T057 policy file is already long. Splitting "given an
//   outcome, compute the new state" into a separate class
//   keeps the policy readable as a decision tree.
// - The tracker's signature is small enough that a future
//   "what-if I rerun this attempt" test can drive it
//   directly without going through the policy.
//
// Update rules (T057 v1 — kept simple, easy to retune):
// - [AttemptVerdict.correct]  → axis += 0.10 (capped at 1.0)
//   AND a small extra (+0.05) when the user landed it in
//   under 10 seconds (fast-correct mastery signal).
// - [AttemptVerdict.partial]  → axis += 0.04
//   (weaker evidence than a clean correct).
// - [AttemptVerdict.wrong]    → axis -= 0.10 (floored at 0.0).
//   If the user also burned 2+ retries we take an extra 0.05
//   off (capped at the 0.0 floor).
// - [AttemptVerdict.unknown]  → no change. The policy still
//   emits a metric for the history (so the user can see the
//   attempt happened) but the skill axes are untouched.
//
// The deltas are deliberately small. T057 is the first
// adaptive pass; T058+ can widen the per-axis learning rate
// once we have a real AI scorer feeding `accuracy` into the
// `metadata` channel.

import 'package:flutter/foundation.dart';

import 'package:ukulele_app/features/lesson_engine/domain/learning_metrics.dart';
import 'package:ukulele_app/features/lesson_engine/domain/lesson_task_type.dart';
import 'package:ukulele_app/features/lesson_engine/domain/skill_state.dart';
import 'package:ukulele_app/features/lesson_engine/domain/task_tool_binding.dart';

/// Pure accumulator: `SkillState + TaskOutcome -> (SkillState,
/// TaskAttemptMetric, TaskAttemptHistory)`.
///
/// The tracker is `const`-constructible (it has no fields)
/// so the policy can hold a single canonical instance and
/// share it across the app via a Riverpod provider.
class SkillTracker {
  const SkillTracker();

  /// Default per-correct delta. T057 v1 keeps this small; see
  /// the file-level comment for why.
  static const double _correctDelta = 0.10;

  /// Bonus added to a correct attempt that landed in under
  /// [fastCorrectThresholdMs]. A "fast correct" is the
  /// strongest mastery signal the policy has in T057.
  static const double _fastCorrectBonus = 0.05;

  /// Threshold below which a correct attempt is treated as
  /// a "fast" correct.
  static const int fastCorrectThresholdMs = 10000;

  /// Per-partial delta. Smaller than the correct delta
  /// because partial evidence is weaker.
  static const double _partialDelta = 0.04;

  /// Per-wrong delta. Same magnitude as a correct (so the
  /// axis can recover at the same rate it decays) but
  /// applied in the negative direction.
  static const double _wrongDelta = 0.10;

  /// Extra penalty for a wrong attempt that burned 2+
  /// retries. Capped by the 0.0 floor on the axis.
  static const double _retryPenalty = 0.05;

  /// Per-wrong deltas. Public so tests can assert the
  /// exact numbers without re-deriving them.
  static const double correctDelta = _correctDelta;
  static const double partialDelta = _partialDelta;
  static const double wrongDelta = _wrongDelta;

  /// Applies [outcome] (with the [taskType] the binding
  /// originated from) to [state] and returns the new state,
  /// the recorded metric, and the new history.
  ///
  /// T057 contract:
  /// - The returned [SkillState] is a NEW instance. The
  ///   input is not mutated.
  /// - The returned [TaskAttemptMetric] is the same metric
  ///   that ends up appended to the new history (callers do
  ///   not have to build it separately).
  /// - The returned history is the input history with the
  ///   metric appended (immutable copy).
  /// - The function NEVER throws. Unknown verdicts (i.e. a
  ///   future enum value the tracker has not been taught)
  ///   are treated as neutral.
  SkillUpdate recordOutcome({
    required SkillState state,
    required TaskAttemptHistory history,
    required TaskOutcome outcome,
    required TaskAttemptMetric metric,
  }) {
    final double newAxis = _nextAxisValue(
      currentAxis: _axisFor(state, metric.taskType),
      metric: metric,
    );
    final SkillState next = _applyAxis(state, metric.taskType, newAxis);
    final TaskAttemptHistory nextHistory = history.append(metric);
    return SkillUpdate(
      state: next,
      history: nextHistory,
      metric: metric,
    );
  }

  /// Helper: returns the updated [SkillState] for a given
  /// axis after applying [metric]. Public so the policy can
  /// ask "what would the tracker do" without constructing a
  /// full outcome (mostly useful in unit tests).
  @visibleForTesting
  double axisAfterForTesting({
    required double currentAxis,
    required TaskAttemptMetric metric,
  }) {
    return _nextAxisValue(currentAxis: currentAxis, metric: metric);
  }

  // --- Internal helpers ---

  double _axisFor(SkillState state, LessonTaskType type) {
    switch (type) {
      case LessonTaskType.rhythm:
        return state.rhythm;
      case LessonTaskType.chord:
        return state.chord;
      case LessonTaskType.note:
        return state.note;
      case LessonTaskType.tuner:
      case LessonTaskType.record:
      case LessonTaskType.review:
      case LessonTaskType.unknown:
        // Tuner / record / review do not have a skill axis in
        // T057. The tracker returns the overall score as a
        // neutral stand-in so the next state stays
        // numerically well-defined; the policy never
        // branches on the tuner axis in T057.
        return state.overall;
    }
  }

  SkillState _applyAxis(
    SkillState state,
    LessonTaskType type,
    double newAxis,
  ) {
    switch (type) {
      case LessonTaskType.rhythm:
        return state.withAxis(rhythm: newAxis);
      case LessonTaskType.chord:
        return state.withAxis(chord: newAxis);
      case LessonTaskType.note:
        return state.withAxis(note: newAxis);
      case LessonTaskType.tuner:
      case LessonTaskType.record:
      case LessonTaskType.review:
      case LessonTaskType.unknown:
        return state;
    }
  }

  double _nextAxisValue({
    required double currentAxis,
    required TaskAttemptMetric metric,
  }) {
    double delta = 0.0;
    switch (metric.verdict) {
      case AttemptVerdict.correct:
        delta = _correctDelta;
        if (metric.elapsedMs < fastCorrectThresholdMs) {
          delta += _fastCorrectBonus;
        }
        break;
      case AttemptVerdict.partial:
        delta = _partialDelta;
        break;
      case AttemptVerdict.wrong:
        delta = -_wrongDelta;
        if (metric.retryCount >= 2) delta -= _retryPenalty;
        break;
      case AttemptVerdict.unknown:
        delta = 0.0;
        break;
    }
    double next = currentAxis + delta;
    if (next.isNaN) return currentAxis;
    if (next < 0.0) return 0.0;
    if (next > 1.0) return 1.0;
    return next;
  }
}

/// The triple returned by [SkillTracker.recordOutcome].
///
/// T057 contract: a plain value holder so the policy can
/// "pull" all three outputs from one call without having to
/// re-thread the metric through the rest of its body.
@immutable
class SkillUpdate {
  const SkillUpdate({
    required this.state,
    required this.history,
    required this.metric,
  });

  /// The new skill state (input state with one axis nudged).
  final SkillState state;

  /// The new attempt history (input history with the metric
  /// appended).
  final TaskAttemptHistory history;

  /// The metric that was just applied. Echoed back so the
  /// caller can route it to telemetry without rebuilding
  /// the record.
  final TaskAttemptMetric metric;
}
