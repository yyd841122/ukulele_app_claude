// Lesson Engine — Adaptive Policy Riverpod providers
// (T057_ADAPTIVE_LEARNING_SYSTEM).
//
// What this file is:
// - The T057 wiring layer. It exposes three Riverpod
//   providers that presentation code consumes:
//     * `adaptivePolicyProvider` — the stateless
//       [AdaptivePolicy] singleton.
//     * `skillTrackerProvider` — the stateless
//       [SkillTracker] singleton.
//     * `adaptiveControllerProvider` — the stateful
//       controller that owns the user's [SkillState] +
//       [TaskAttemptHistory] in memory and answers "what
//       should the user do next?" given today's lesson.
//
// Why a dedicated controller instead of a Notifier inside
// the engine:
// - The T055 [LessonEngine] returns a fresh `Lesson` per
//   build (no caching). T057 needs the controller to hold
//   cross-call state (the running skill model + history),
//   so it cannot live inside the same `AsyncNotifier`.
// - Splitting the controller out keeps the engine
//   untouched (T055 invariant) and lets presentation code
//   observe adaptive decisions through a single provider.
//
// In-memory scope:
// - T057 keeps the state in memory only. The provider is
//   intentionally NOT wired to any Drift table; a future
//   `practice_metrics` migration can persist it without
//   touching the controller's surface.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/features/lesson_engine/application/adaptive_policy.dart';
import 'package:ukulele_app/features/lesson_engine/application/skill_tracker.dart';
import 'package:ukulele_app/features/lesson_engine/application/lesson_engine_providers.dart';
import 'package:ukulele_app/features/lesson_engine/domain/adaptive_decision.dart';
import 'package:ukulele_app/features/lesson_engine/domain/learning_metrics.dart';
import 'package:ukulele_app/features/lesson_engine/domain/lesson.dart';
import 'package:ukulele_app/features/lesson_engine/domain/lesson_task_type.dart';
import 'package:ukulele_app/features/lesson_engine/domain/skill_state.dart';
import 'package:ukulele_app/features/lesson_engine/domain/task_tool_binding.dart';

/// Provider for the stateless [AdaptivePolicy].
final Provider<AdaptivePolicy> adaptivePolicyProvider = Provider<AdaptivePolicy>(
  (Ref ref) => const AdaptivePolicy(),
);

/// Provider for the stateless [SkillTracker].
final Provider<SkillTracker> skillTrackerProvider = Provider<SkillTracker>(
  (Ref ref) => const SkillTracker(),
);

/// The stateful controller that owns the user's skill model
/// + attempt history.
///
/// T057 contract:
/// - `state` starts at `AdaptiveSnapshot.initial` and is
///   mutated only via [recordOutcome]. Direct mutations are
///   intentionally NOT exposed — every state transition
///   flows through the tracker so the policy + tracker stay
///   in lockstep.
/// - `decideForLesson(lesson)` is a pure projection: it does
///   NOT mutate state. The caller (a presenter) is
///   expected to surface the decision, run the tool, and
///   then call [recordOutcome] to fold the result back in.
class AdaptiveController extends Notifier<AdaptiveSnapshot> {
  AdaptiveController();

  late final AdaptivePolicy _policy;
  late final SkillTracker _tracker;

  @override
  AdaptiveSnapshot build() {
    _policy = ref.read(adaptivePolicyProvider);
    _tracker = ref.read(skillTrackerProvider);
    ref.watch(lessonEngineControllerProvider);
    return AdaptiveSnapshot.initial;
  }

  /// Folds [outcome] into the skill model + history and
  /// returns the new snapshot.
  ///
  /// T057 contract:
  /// - [outcome] is recorded exactly once per call. Calling
  ///   this twice with the same outcome would double-count
  ///   the attempt — the controller deliberately does NOT
  ///   de-duplicate.
  /// - [taskType] is the [LessonTaskType] of the source task.
  ///   The tracker uses it to pick which skill axis to
  ///   update. Callers MUST pass the correct type — the
  ///   controller does NOT re-derive it from the binding's
  ///   tool alone (a metronome binding drives the rhythm
  ///   axis; the tool enum and the type enum are similar
  ///   but not identical).
  @visibleForTesting
  AdaptiveSnapshot debugRecord({
    required SkillState state,
    required TaskAttemptHistory history,
    required TaskOutcome outcome,
    required LessonTaskType taskType,
  }) {
    final TaskAttemptMetric metric = TaskAttemptMetric.fromOutcome(
      outcome: outcome,
      taskType: taskType,
    );
    final SkillUpdate update = _tracker.recordOutcome(
      state: state,
      history: history,
      outcome: outcome,
      metric: metric,
    );
    return AdaptiveSnapshot(
      state: update.state,
      history: update.history,
    );
  }

  /// Public entry point: records [outcome] (typed by
  /// [taskType]) for the source [task] into the running
  /// snapshot. The [task] is stored in the snapshot as the
  /// `lastTask` so the next `decideForLesson` call can
  /// detect same-task consecutive wrongs without scanning
  /// the full history.
  AdaptiveSnapshot recordOutcome({
    required TaskOutcome outcome,
    required LessonTaskType taskType,
    required LessonTask task,
  }) {
    final AdaptiveSnapshot next = debugRecord(
      state: state.state,
      history: state.history,
      outcome: outcome,
      taskType: taskType,
    );
    final AdaptiveSnapshot withTask = AdaptiveSnapshot(
      state: next.state,
      history: next.history,
      lastTask: task,
    );
    state = withTask;
    return withTask;
  }

  /// Computes the next decision for [lesson] given the
  /// current snapshot. Does NOT mutate state — see the
  /// class-level contract.
  AdaptiveDecision decideForLesson(Lesson lesson) {
    return _policy.decide(
      state: state.state,
      history: state.history,
      lesson: lesson,
      lastTask: state.lastTask,
    );
  }

  /// Records [outcome] AND emits the next decision for
  /// [lesson]. The convenient "tap → record → next" entry
  /// point for presenters.
  AdaptiveDecision recordAndDecideNext({
    required Lesson lesson,
    required TaskOutcome outcome,
    required LessonTaskType taskType,
    required LessonTask task,
  }) {
    recordOutcome(outcome: outcome, taskType: taskType, task: task);
    return decideForLesson(lesson);
  }
}

/// Provider for [AdaptiveController].
final NotifierProvider<AdaptiveController, AdaptiveSnapshot>
    adaptiveControllerProvider =
    NotifierProvider<AdaptiveController, AdaptiveSnapshot>(
  AdaptiveController.new,
);

/// Immutable snapshot of the adaptive state the controller
/// owns.
///
/// T057 contract:
/// - `state` is the user's [SkillState].
/// - `history` is the running [TaskAttemptHistory].
/// - `lastTask` is the task the user just finished (or
///   `null`). The policy uses this to detect same-task
///   repeats without scanning the full history.
/// - `lastTask` is updated by [AdaptiveController.recordOutcome]
///   and is `null` until the first outcome is recorded.
@immutable
class AdaptiveSnapshot {
  const AdaptiveSnapshot({
    required this.state,
    required this.history,
    this.lastTask,
  });

  /// The "no evidence yet" seed.
  static const AdaptiveSnapshot initial = AdaptiveSnapshot(
    state: SkillState.initial,
    history: TaskAttemptHistory.initial,
  );

  /// The user's per-axis skill model.
  final SkillState state;

  /// The running attempt history.
  final TaskAttemptHistory history;

  /// The most recently attempted task, or `null` when no
  /// outcome has been recorded yet.
  final LessonTask? lastTask;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AdaptiveSnapshot &&
          other.state == state &&
          other.history == history &&
          other.lastTask == lastTask);

  @override
  int get hashCode => Object.hash(state, history, lastTask);
}