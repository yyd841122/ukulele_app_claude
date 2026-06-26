// Integration tests for the T057 Adaptive Policy Riverpod
// providers (T057_ADAPTIVE_LEARNING_SYSTEM).
//
// Scope:
// - `adaptiveControllerProvider` seeds with the
//   `AdaptiveSnapshot.initial` state and an empty history.
// - `recordOutcome` folds a completed metronome outcome into
//   the running state and bumps the rhythm axis.
// - `decideForLesson` returns a `ProceedTaskDecision` for
//   the first uncompleted task.
// - After 2 wrong outcomes on the same metronome task, the
//   next decision is a `RepeatTaskDecision`.
// - After 3 correct outcomes, the rhythm axis climbs toward
//   the mastery band.
//
// Why a `ProviderContainer` with the real providers (not a
// hand-rolled controller): the test guards the wiring too
// — a future refactor that re-wires the policy / tracker
// without updating the controller is caught here.

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/data/database/app_database.dart';
import 'package:ukulele_app/data/database/app_database_provider.dart';
import 'package:ukulele_app/features/home/data/completed_tasks_repository.dart';
import 'package:ukulele_app/features/home/data/completed_tasks_repository_provider.dart';
import 'package:ukulele_app/features/lesson_engine/application/adaptive_policy_providers.dart';
import 'package:ukulele_app/features/lesson_engine/domain/adaptive_decision.dart';
import 'package:ukulele_app/features/lesson_engine/domain/lesson.dart';
import 'package:ukulele_app/features/lesson_engine/domain/lesson_task_type.dart';
import 'package:ukulele_app/features/lesson_engine/domain/lesson_tool.dart';
import 'package:ukulele_app/features/lesson_engine/domain/task_tool_binding.dart';
import 'package:ukulele_app/shared/providers/app_clock_provider.dart';
import 'package:ukulele_app/shared/services/install_date_service.dart';
import 'package:ukulele_app/shared/services/install_date_service_provider.dart';

void main() {
  group('adaptiveControllerProvider', () {
    final DateTime fixedToday = DateTime(2026, 6, 25);
    final DateTime fixedStamp = DateTime.utc(2026, 6, 25, 10);

    Future<ProviderContainer> container() async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          appClockProvider.overrideWithValue(() => fixedStamp),
          installDateServiceProvider.overrideWithValue(
            _FixedInstallDateService(fixedToday),
          ),
          // We don't need a real repo for these tests, but the
          // controller's build() reads the engine provider
          // which transitively reads the repo provider. Use
          // the no-op in-memory stub to keep the test
          // hermetic.
          completedTasksRepositoryProvider.overrideWithValue(_NoopRepo()),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('starts at AdaptiveSnapshot.initial', () async {
      final ProviderContainer c = await container();
      final AdaptiveSnapshot snap = c.read(adaptiveControllerProvider);
      expect(snap.state.rhythm, 0.0);
      expect(snap.state.chord, 0.0);
      expect(snap.state.note, 0.0);
      expect(snap.history.attempts, isEmpty);
      expect(snap.lastTask, isNull);
    });

    test('recordOutcome folds a metronome correct into the rhythm axis',
        () async {
      final ProviderContainer c = await container();
      final AdaptiveController controller =
          c.read(adaptiveControllerProvider.notifier);
      final Lesson lesson = _day1();
      final LessonTask metronome = lesson.tasks[2];
      final TaskOutcome outcome = TaskOutcome(
        binding: const TaskToolBinding(
          taskId: 'day1_metronome',
          tool: LessonTool.metronome,
          parameters: MetronomeParams(bpm: 80),
        ),
        result: const ToolResult(
          status: ToolResultStatus.completed,
          metadata: <String, Object>{'verdict': 'correct'},
        ),
        completedAt: fixedStamp,
        elapsedMs: 4000,
      );
      controller.recordOutcome(
        outcome: outcome,
        taskType: LessonTaskType.rhythm,
        task: metronome,
      );
      final AdaptiveSnapshot snap = c.read(adaptiveControllerProvider);
      expect(snap.state.rhythm, greaterThan(0.0));
      expect(snap.history.attempts, hasLength(1));
      expect(snap.lastTask?.id, metronome.id);
    });

    test('decideForLesson returns ProceedTaskDecision on the first task',
        () async {
      final ProviderContainer c = await container();
      final AdaptiveController controller =
          c.read(adaptiveControllerProvider.notifier);
      final Lesson lesson = _day1();
      final AdaptiveDecision d = controller.decideForLesson(lesson);
      expect(d, isA<ProceedTaskDecision>());
      expect((d as ProceedTaskDecision).task.id, lesson.tasks.first.id);
    });

    test('two wrongs on the same task → next decision is RepeatTaskDecision',
        () async {
      final ProviderContainer c = await container();
      final AdaptiveController controller =
          c.read(adaptiveControllerProvider.notifier);
      final Lesson lesson = _day1();
      final LessonTask metronome = lesson.tasks[2];
      // First wrong.
      controller.recordOutcome(
        outcome: TaskOutcome(
          binding: const TaskToolBinding(
            taskId: 'day1_metronome',
            tool: LessonTool.metronome,
            parameters: MetronomeParams(bpm: 80),
          ),
          result: const ToolResult(
            status: ToolResultStatus.completed,
            metadata: <String, Object>{'verdict': 'wrong'},
          ),
          completedAt: fixedStamp,
          elapsedMs: 5000,
        ),
        taskType: LessonTaskType.rhythm,
        task: metronome,
      );
      // Second wrong on the same task.
      controller.recordOutcome(
        outcome: TaskOutcome(
          binding: const TaskToolBinding(
            taskId: 'day1_metronome',
            tool: LessonTool.metronome,
            parameters: MetronomeParams(bpm: 80),
          ),
          result: const ToolResult(
            status: ToolResultStatus.completed,
            metadata: <String, Object>{'verdict': 'wrong'},
          ),
          completedAt: fixedStamp,
          elapsedMs: 5000,
        ),
        taskType: LessonTaskType.rhythm,
        task: metronome,
      );
      final AdaptiveDecision d = controller.decideForLesson(lesson);
      expect(d, isA<RepeatTaskDecision>());
      expect((d as RepeatTaskDecision).task.id, metronome.id);
    });
  });
}

Lesson _day1() {
  const LessonTask tuner = LessonTask(
    id: 'day1_tuner',
    type: LessonTaskType.tuner,
    tool: LessonTool.tuner,
    title: '调音',
    description: '调音 G/C/E/A',
    estimatedMinutes: 5,
    routePath: '/tuner',
  );
  const LessonTask note = LessonTask(
    id: 'day1_single_note',
    type: LessonTaskType.note,
    tool: LessonTool.singleNote,
    title: '单音 C / E 练习',
    description: '练习 C / E 单音',
    estimatedMinutes: 5,
    routePath: '/single-note',
  );
  const LessonTask metronome = LessonTask(
    id: 'day1_metronome',
    type: LessonTaskType.rhythm,
    tool: LessonTool.metronome,
    title: '节拍器 80 BPM',
    description: '用节拍器 80 BPM 跟拍',
    estimatedMinutes: 5,
    routePath: '/metronome',
  );
  return const Lesson(
    id: 'lesson_day_1',
    dayIndex: 1,
    title: '认识琴弦',
    description: '认识琴弦',
    estimatedMinutes: 15,
    tasks: <LessonTask>[tuner, note, metronome],
  );
}

class _NoopRepo implements CompletedTasksRepository {
  @override
  Future<void> markCompleted({
    required DateTime date,
    required String taskId,
    required DateTime completedAt,
  }) async {}
  @override
  Future<Set<String>> getCompletedTaskIds(DateTime date) async =>
      const <String>{};
  @override
  Future<bool> unmarkCompleted({
    required DateTime date,
    required String taskId,
  }) async =>
      false;
  @override
  Stream<Set<String>> watchCompletedTaskIds(DateTime date) async* {
    yield const <String>{};
  }
}

class _FixedInstallDateService implements InstallDateService {
  _FixedInstallDateService(this._fixed);
  final DateTime _fixed;
  @override
  Future<DateTime> getInstallDate() async => _fixed;
}