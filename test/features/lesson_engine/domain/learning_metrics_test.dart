// Unit tests for the T057 Learning Metrics
// (T057_ADAPTIVE_LEARNING_SYSTEM).
//
// Scope:
// - TaskAttemptMetric.fromOutcome extracts verdict /
//   accuracy / retryCount from ToolResult.metadata when
//   present, and falls back to a status-based verdict when
//   absent.
// - TaskAttemptHistory aggregates (consecutiveCorrects /
//   consecutiveWrongs / errorRate / averageElapsedMs) match
//   the expected values across a representative attempt
//   sequence.
// - append is non-mutating and produces an immutable list.

import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/features/lesson_engine/domain/learning_metrics.dart';
import 'package:ukulele_app/features/lesson_engine/domain/lesson_task_type.dart';
import 'package:ukulele_app/features/lesson_engine/domain/lesson_tool.dart';
import 'package:ukulele_app/features/lesson_engine/domain/task_tool_binding.dart';

void main() {
  group('TaskAttemptMetric.fromOutcome', () {
    test('reads verdict=correct from metadata', () {
      final TaskOutcome outcome = _outcome(
        status: ToolResultStatus.completed,
        metadata: const <String, Object>{
          'verdict': 'correct',
          'accuracy': 0.9,
          'retryCount': 1,
        },
        elapsedMs: 3000,
      );
      final TaskAttemptMetric m = TaskAttemptMetric.fromOutcome(
        outcome: outcome,
        taskType: LessonTaskType.rhythm,
      );
      expect(m.verdict, AttemptVerdict.correct);
      expect(m.accuracy, 0.9);
      expect(m.retryCount, 1);
      expect(m.elapsedMs, 3000);
      expect(m.taskId, 'day1_tuner');
    });

    test('reads verdict=wrong from metadata', () {
      final TaskOutcome outcome = _outcome(
        status: ToolResultStatus.completed,
        metadata: const <String, Object>{'verdict': 'wrong'},
      );
      final TaskAttemptMetric m = TaskAttemptMetric.fromOutcome(
        outcome: outcome,
        taskType: LessonTaskType.chord,
      );
      expect(m.verdict, AttemptVerdict.wrong);
    });

    test('reads verdict=partial from metadata', () {
      final TaskOutcome outcome = _outcome(
        status: ToolResultStatus.completed,
        metadata: const <String, Object>{'verdict': 'partial'},
      );
      final TaskAttemptMetric m = TaskAttemptMetric.fromOutcome(
        outcome: outcome,
        taskType: LessonTaskType.note,
      );
      expect(m.verdict, AttemptVerdict.partial);
    });

    test('falls back to wrong when status=failed and no verdict', () {
      final TaskOutcome outcome = _outcome(
        status: ToolResultStatus.failed,
        metadata: const <String, Object>{},
      );
      final TaskAttemptMetric m = TaskAttemptMetric.fromOutcome(
        outcome: outcome,
        taskType: LessonTaskType.rhythm,
      );
      expect(m.verdict, AttemptVerdict.wrong);
    });

    test('falls back to unknown when status=completed and no verdict',
        () {
      final TaskOutcome outcome = _outcome(
        status: ToolResultStatus.completed,
        metadata: const <String, Object>{},
      );
      final TaskAttemptMetric m = TaskAttemptMetric.fromOutcome(
        outcome: outcome,
        taskType: LessonTaskType.rhythm,
      );
      expect(m.verdict, AttemptVerdict.unknown);
    });

    test('falls back to unknown when status=skipped', () {
      final TaskOutcome outcome = _outcome(
        status: ToolResultStatus.skipped,
        metadata: const <String, Object>{},
      );
      final TaskAttemptMetric m = TaskAttemptMetric.fromOutcome(
        outcome: outcome,
        taskType: LessonTaskType.rhythm,
      );
      expect(m.verdict, AttemptVerdict.unknown);
    });

    test('clamps accuracy outside [0, 1]', () {
      final TaskOutcome hi = _outcome(
        status: ToolResultStatus.completed,
        metadata: const <String, Object>{'accuracy': 1.5},
      );
      expect(
        TaskAttemptMetric.fromOutcome(
          outcome: hi,
          taskType: LessonTaskType.rhythm,
        ).accuracy,
        1.0,
      );
      final TaskOutcome lo = _outcome(
        status: ToolResultStatus.completed,
        metadata: const <String, Object>{'accuracy': -0.2},
      );
      expect(
        TaskAttemptMetric.fromOutcome(
          outcome: lo,
          taskType: LessonTaskType.rhythm,
        ).accuracy,
        0.0,
      );
    });

    test('clamps negative retryCount to 0', () {
      final TaskOutcome outcome = _outcome(
        status: ToolResultStatus.completed,
        metadata: const <String, Object>{'retryCount': -3},
      );
      final TaskAttemptMetric m = TaskAttemptMetric.fromOutcome(
        outcome: outcome,
        taskType: LessonTaskType.rhythm,
      );
      expect(m.retryCount, 0);
    });

    test('asserts elapsedMs >= 0 and retryCount >= 0', () {
      expect(
        () => TaskAttemptMetric(
          taskId: 'day1_tuner',
          taskType: LessonTaskType.rhythm,
          verdict: AttemptVerdict.correct,
          elapsedMs: -1,
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => TaskAttemptMetric(
          taskId: 'day1_tuner',
          taskType: LessonTaskType.rhythm,
          verdict: AttemptVerdict.correct,
          elapsedMs: 100,
          retryCount: -1,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('TaskAttemptHistory aggregates', () {
    test('initial history is empty', () {
      const TaskAttemptHistory h = TaskAttemptHistory.initial;
      expect(h.attempts, isEmpty);
      expect(h.last, isNull);
      expect(h.consecutiveCorrects, 0);
      expect(h.consecutiveWrongs, 0);
      expect(h.errorRate, 0.0);
      expect(h.averageElapsedMs, 0);
    });

    test('consecutiveCorrects counts only the trailing run of corrects',
        () {
      final TaskAttemptHistory h = _seed(
        <AttemptVerdict>[
          AttemptVerdict.correct,
          AttemptVerdict.wrong,
          AttemptVerdict.correct,
          AttemptVerdict.correct,
          AttemptVerdict.correct,
        ],
      );
      expect(h.consecutiveCorrects, 3);
      expect(h.consecutiveWrongs, 0);
    });

    test('consecutiveWrongs counts only the trailing run of wrongs', () {
      final TaskAttemptHistory h = _seed(
        <AttemptVerdict>[
          AttemptVerdict.correct,
          AttemptVerdict.wrong,
          AttemptVerdict.wrong,
          AttemptVerdict.correct,
        ],
      );
      // Trailing run of wrongs: 0 (last attempt is correct).
      expect(h.consecutiveWrongs, 0);
      // Trailing run of corrects: 1 (last attempt is correct).
      expect(h.consecutiveCorrects, 1);
    });

    test('pure trailing run of wrongs has consecutiveWrongs = length', () {
      final TaskAttemptHistory h = _seed(
        <AttemptVerdict>[
          AttemptVerdict.wrong,
          AttemptVerdict.wrong,
        ],
      );
      expect(h.consecutiveWrongs, 2);
      expect(h.consecutiveCorrects, 0);
    });

    test('errorRate = wrong / total', () {
      final TaskAttemptHistory h = _seed(
        <AttemptVerdict>[
          AttemptVerdict.correct,
          AttemptVerdict.wrong,
          AttemptVerdict.wrong,
          AttemptVerdict.partial,
        ],
      );
      expect(h.errorRate, closeTo(0.5, 1e-9));
    });

    test('averageElapsedMs is the rounded-down mean', () {
      final TaskAttemptHistory h = _seed(
        <AttemptVerdict>[
          AttemptVerdict.correct,
          AttemptVerdict.wrong,
          AttemptVerdict.correct,
        ],
        elapsedOverride: const <int>[100, 200, 400],
      );
      expect(h.averageElapsedMs, (100 + 200 + 400) ~/ 3);
    });

    test('append is non-mutating and produces an immutable list', () {
      const TaskAttemptHistory h0 = TaskAttemptHistory.initial;
      final TaskAttemptMetric m = TaskAttemptMetric(
        taskId: 'day1_tuner',
        taskType: LessonTaskType.rhythm,
        verdict: AttemptVerdict.correct,
        elapsedMs: 1000,
      );
      final TaskAttemptHistory h1 = h0.append(m);
      expect(h0.attempts, isEmpty);
      expect(h1.attempts, hasLength(1));
      expect(h1.attempts.single, m);
    });
  });
}

TaskOutcome _outcome({
  required ToolResultStatus status,
  Map<String, Object> metadata = const <String, Object>{},
  int elapsedMs = 1000,
}) {
  return TaskOutcome(
    binding: const TaskToolBinding(
      taskId: 'day1_tuner',
      tool: LessonTool.tuner,
      parameters: TunerParams(),
    ),
    result: ToolResult(status: status, metadata: metadata),
    completedAt: DateTime.utc(2026, 6, 25, 10),
    elapsedMs: elapsedMs,
  );
}

TaskAttemptHistory _seed(
  List<AttemptVerdict> verdicts, {
  List<int>? elapsedOverride,
}) {
  TaskAttemptHistory h = TaskAttemptHistory.initial;
  for (int i = 0; i < verdicts.length; i++) {
    final int elapsed =
        (elapsedOverride != null && i < elapsedOverride.length)
            ? elapsedOverride[i]
            : 1000;
    h = h.append(TaskAttemptMetric(
      taskId: 'day1_tuner',
      taskType: LessonTaskType.rhythm,
      verdict: verdicts[i],
      elapsedMs: elapsed,
    ));
  }
  return h;
}