// Unit tests for the T057 Skill Tracker
// (T057_ADAPTIVE_LEARNING_SYSTEM).
//
// Scope:
// - `correct` verdict nudges the axis up by the default
//   delta (with a small bonus when the user landed the
//   attempt in under the fast-correct threshold).
// - `partial` verdict nudges the axis up by the partial
//   delta.
// - `wrong` verdict nudges the axis down; an extra retry
//   penalty applies when retryCount >= 2.
// - `unknown` verdict leaves the axis unchanged.
// - Out-of-range deltas are clamped to [0.0, 1.0].

import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/features/lesson_engine/application/skill_tracker.dart';
import 'package:ukulele_app/features/lesson_engine/domain/learning_metrics.dart';
import 'package:ukulele_app/features/lesson_engine/domain/lesson_task_type.dart';
import 'package:ukulele_app/features/lesson_engine/domain/lesson_tool.dart';
import 'package:ukulele_app/features/lesson_engine/domain/skill_state.dart';
import 'package:ukulele_app/features/lesson_engine/domain/task_tool_binding.dart';

void main() {
  const SkillTracker tracker = SkillTracker();
  const SkillState seed = SkillState(rhythm: 0.50, chord: 0.50, note: 0.50);

  group('SkillTracker.recordOutcome', () {
    test('correct nudge is +0.10; bonus makes it +0.15 for fast attempts',
        () {
      // Slow correct: 0.50 + 0.10 = 0.60
      final TaskAttemptMetric slow = const TaskAttemptMetric(
        taskId: 'day1_metronome',
        taskType: LessonTaskType.rhythm,
        verdict: AttemptVerdict.correct,
        elapsedMs: 60000,
      );
      final SkillUpdate u1 = tracker.recordOutcome(
        state: seed,
        history: TaskAttemptHistory.initial,
        outcome: _stubOutcome(slow),
        metric: slow,
      );
      expect(u1.state.rhythm, closeTo(0.60, 1e-9));
      expect(u1.history.attempts, hasLength(1));

      // Fast correct: 0.50 + 0.10 + 0.05 = 0.65
      final TaskAttemptMetric fast = const TaskAttemptMetric(
        taskId: 'day1_metronome',
        taskType: LessonTaskType.rhythm,
        verdict: AttemptVerdict.correct,
        elapsedMs: 4000,
      );
      final SkillUpdate u2 = tracker.recordOutcome(
        state: seed,
        history: TaskAttemptHistory.initial,
        outcome: _stubOutcome(fast),
        metric: fast,
      );
      expect(u2.state.rhythm, closeTo(0.65, 1e-9));
    });

    test('partial nudge is +0.04', () {
      const TaskAttemptMetric m = TaskAttemptMetric(
        taskId: 'day3_chord_c',
        taskType: LessonTaskType.chord,
        verdict: AttemptVerdict.partial,
        elapsedMs: 9000,
      );
      final SkillUpdate u = tracker.recordOutcome(
        state: seed,
        history: TaskAttemptHistory.initial,
        outcome: _stubOutcome(m),
        metric: m,
      );
      expect(u.state.chord, closeTo(0.54, 1e-9));
    });

    test('wrong nudge is -0.10; retryCount>=2 adds an extra -0.05', () {
      const TaskAttemptMetric m = TaskAttemptMetric(
        taskId: 'day1_single_note',
        taskType: LessonTaskType.note,
        verdict: AttemptVerdict.wrong,
        elapsedMs: 12000,
        retryCount: 3,
      );
      final SkillUpdate u = tracker.recordOutcome(
        state: seed,
        history: TaskAttemptHistory.initial,
        outcome: _stubOutcome(m),
        metric: m,
      );
      expect(u.state.note, closeTo(0.35, 1e-9));
    });

    test('unknown leaves the axis unchanged', () {
      // Tuner has no axis in T057, so this test is really
      // checking that we don't blow up on a task type that
      // has no axis mapping.
      const TaskAttemptMetric m = TaskAttemptMetric(
        taskId: 'day1_tuner',
        taskType: LessonTaskType.tuner,
        verdict: AttemptVerdict.unknown,
        elapsedMs: 1000,
      );
      final SkillUpdate u = tracker.recordOutcome(
        state: seed,
        history: TaskAttemptHistory.initial,
        outcome: _stubOutcome(m),
        metric: m,
      );
      expect(u.state.rhythm, seed.rhythm);
      expect(u.state.chord, seed.chord);
      expect(u.state.note, seed.note);
    });

    test('clamps axis to [0.0, 1.0] (lower bound)', () {
      const TaskAttemptMetric m = TaskAttemptMetric(
        taskId: 'day1_metronome',
        taskType: LessonTaskType.rhythm,
        verdict: AttemptVerdict.wrong,
        elapsedMs: 12000,
        retryCount: 5,
      );
      const SkillState tiny = SkillState(rhythm: 0.05, chord: 0.0, note: 0.0);
      final SkillUpdate u = tracker.recordOutcome(
        state: tiny,
        history: TaskAttemptHistory.initial,
        outcome: _stubOutcome(m),
        metric: m,
      );
      expect(u.state.rhythm, 0.0);
    });

    test('clamps axis to [0.0, 1.0] (upper bound)', () {
      const TaskAttemptMetric m = TaskAttemptMetric(
        taskId: 'day1_metronome',
        taskType: LessonTaskType.rhythm,
        verdict: AttemptVerdict.correct,
        elapsedMs: 1000,
      );
      const SkillState high = SkillState(rhythm: 0.95, chord: 0.5, note: 0.5);
      final SkillUpdate u = tracker.recordOutcome(
        state: high,
        history: TaskAttemptHistory.initial,
        outcome: _stubOutcome(m),
        metric: m,
      );
      // 0.95 + 0.10 + 0.05 (fast) = 1.10 → clamped to 1.0.
      expect(u.state.rhythm, 1.0);
    });
  });
}

TaskOutcome _stubOutcome(TaskAttemptMetric m) {
  return TaskOutcome(
    binding: TaskToolBinding(
      taskId: m.taskId,
      tool: _toolForType(m.taskType),
      parameters: const TunerParams(),
    ),
    result: const ToolResult(status: ToolResultStatus.completed),
    completedAt: DateTime.utc(2026, 6, 25, 10),
    elapsedMs: m.elapsedMs,
  );
}

LessonTool _toolForType(LessonTaskType t) {
  switch (t) {
    case LessonTaskType.rhythm:
      return LessonTool.metronome;
    case LessonTaskType.chord:
      return LessonTool.chordLibrary;
    case LessonTaskType.note:
      return LessonTool.singleNote;
    case LessonTaskType.tuner:
      return LessonTool.tuner;
    case LessonTaskType.record:
      return LessonTool.recording;
    case LessonTaskType.review:
      return LessonTool.records;
    case LessonTaskType.unknown:
      return LessonTool.tuner;
  }
}