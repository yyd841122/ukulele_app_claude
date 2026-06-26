// Unit tests for the T057 Adaptive Decision value layer
// (T057_ADAPTIVE_LEARNING_SYSTEM).
//
// Scope:
// - The three sealed subtypes are value-equal across the
//   fields the consumer reads.
// - Subtypes inherit the `reason` field from the sealed
//   base without re-declaring it.

import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/features/lesson_engine/domain/adaptive_decision.dart';
import 'package:ukulele_app/features/lesson_engine/domain/lesson.dart';
import 'package:ukulele_app/features/lesson_engine/domain/lesson_task_type.dart';
import 'package:ukulele_app/features/lesson_engine/domain/lesson_tool.dart';
import 'package:ukulele_app/features/lesson_engine/domain/task_tool_binding.dart';

void main() {
  const LessonTask sampleTask = LessonTask(
    id: 'day1_metronome',
    type: LessonTaskType.rhythm,
    tool: LessonTool.metronome,
    title: '节拍器 80 BPM',
    description: '跟拍 80 BPM',
    estimatedMinutes: 5,
    routePath: '/metronome',
  );
  const Lesson sampleLesson = Lesson(
    id: 'lesson_day_1',
    dayIndex: 1,
    title: '认识琴弦',
    description: '认识琴弦',
    estimatedMinutes: 15,
    tasks: <LessonTask>[sampleTask],
  );

  group('AdaptiveDecision subclasses', () {
    test('ProceedTaskDecision equality', () {
      const AdaptiveDecision a = ProceedTaskDecision(
        task: sampleTask,
        parameters: MetronomeParams(bpm: 80),
        difficulty: 0.5,
        reason: 'continue',
      );
      const AdaptiveDecision b = ProceedTaskDecision(
        task: sampleTask,
        parameters: MetronomeParams(bpm: 80),
        difficulty: 0.5,
        reason: 'continue',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('RepeatTaskDecision equality', () {
      const AdaptiveDecision a = RepeatTaskDecision(
        task: sampleTask,
        parameters: MetronomeParams(bpm: 70),
        difficulty: 0.3,
        recentWrongs: 2,
        reason: 'down',
      );
      const AdaptiveDecision b = RepeatTaskDecision(
        task: sampleTask,
        parameters: MetronomeParams(bpm: 70),
        difficulty: 0.3,
        recentWrongs: 2,
        reason: 'down',
      );
      expect(a, equals(b));
    });

    test('RepeatTaskDecision asserts recentWrongs >= 0', () {
      expect(
        () => RepeatTaskDecision(
          task: sampleTask,
          parameters: MetronomeParams(bpm: 70),
          difficulty: 0.3,
          recentWrongs: -1,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('InjectSkillDecision equality', () {
      const AdaptiveDecision a = InjectSkillDecision(
        task: sampleTask,
        parameters: MetronomeParams(bpm: 90),
        difficulty: 0.4,
        weakAxis: SkillAxis.rhythm,
        weakScore: 0.2,
        reason: 'weak',
      );
      const AdaptiveDecision b = InjectSkillDecision(
        task: sampleTask,
        parameters: MetronomeParams(bpm: 90),
        difficulty: 0.4,
        weakAxis: SkillAxis.rhythm,
        weakScore: 0.2,
        reason: 'weak',
      );
      expect(a, equals(b));
    });

    test('InjectSkillDecision asserts weakScore in [0, 1]', () {
      expect(
        () => InjectSkillDecision(
          task: sampleTask,
          parameters: MetronomeParams(bpm: 90),
          difficulty: 0.4,
          weakAxis: SkillAxis.rhythm,
          weakScore: 1.5,
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => InjectSkillDecision(
          task: sampleTask,
          parameters: MetronomeParams(bpm: 90),
          difficulty: 0.4,
          weakAxis: SkillAxis.rhythm,
          weakScore: -0.1,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('sealed family is exhaustive (compile-time check)', () {
      // Pattern-matching every subtype forces the consumer to
      // handle all branches. If a new subtype is added, this
      // switch will fail to compile until it is updated.
      const AdaptiveDecision d = ProceedTaskDecision(
        task: sampleTask,
        parameters: MetronomeParams(bpm: 80),
        difficulty: 0.5,
      );
      final String tag = switch (d) {
        ProceedTaskDecision() => 'proceed',
        RepeatTaskDecision() => 'repeat',
        InjectSkillDecision() => 'inject',
      };
      expect(tag, 'proceed');
      // The lesson is referenced so the unused-field analyzer
      // does not flag it (the test file mirrors the
      // surrounding test conventions).
      expect(sampleLesson.tasks, hasLength(1));
    });
  });
}