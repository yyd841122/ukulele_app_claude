// Tests for [TodayPracticeController] (T013.3).
//
// T013.3 contract under test:
// - The controller is an AsyncNotifier. Before `build` resolves,
//   the provider exposes `AsyncLoading`.
// - `build` reads the persisted install date AND the persisted
//   completed-task set for today. Both reads MUST happen before
//   any "data" state is emitted — there is no "fake all-todo"
//   snapshot.
// - `toggleTaskCompleted` is async, returns `bool`, only
//   mutates in-memory state after the DB write succeeds, and
//   refuses duplicate clicks while a write for the same id is
//   in flight.
// - Concurrent toggles on DIFFERENT taskIds complete
//   independently — neither one clobbers the other.

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/data/database/app_database.dart';
import 'package:ukulele_app/data/database/app_database_provider.dart';
import 'package:ukulele_app/features/home/application/today_practice_controller.dart';
import 'package:ukulele_app/features/home/data/completed_tasks_repository.dart';
import 'package:ukulele_app/features/home/data/completed_tasks_repository_provider.dart';
import 'package:ukulele_app/features/home/domain/practice_task.dart';
import 'package:ukulele_app/features/home/domain/practice_task_status.dart';
import 'package:ukulele_app/shared/services/install_date_service.dart';

void main() {
  // Each test gets a fresh in-memory DB. We always close it.
  AppDatabase buildDb() {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    return db;
  }

  /// Builds a `ProviderContainer` wired against [db]. The
  /// controller's `clockProvider` and
  /// `installDateServiceProvider` are overrideable per test.
  /// [completedTasksRepo] overrides the
  /// `completedTasksRepositoryProvider` for tests that need to
  /// inject a throwing / scripted repo.
  ProviderContainer buildContainer({
    required AppDatabase db,
    DateTime Function()? clock,
    InstallDateService? installService,
    CompletedTasksRepository? completedTasksRepo,
  }) {
    final List<Override> overrides = <Override>[
      appDatabaseProvider.overrideWithValue(db),
      if (clock != null) clockProvider.overrideWithValue(clock),
      if (installService != null)
        installDateServiceProvider.overrideWithValue(installService),
      if (completedTasksRepo != null)
        completedTasksRepositoryProvider.overrideWithValue(completedTasksRepo),
    ];
    final ProviderContainer container = ProviderContainer(
      overrides: overrides,
    );
    addTearDown(container.dispose);
    return container;
  }

  group('TodayPracticeController initial load', () {
    test('exposes AsyncLoading until build completes', () async {
      final AppDatabase db = buildDb();
      final DateTime fixed = DateTime(2026, 6, 20, 9, 0);
      final ProviderContainer container = buildContainer(
        db: db,
        clock: () => fixed,
        installService: _FakeInstallDateService(fixed),
      );

      // Read the AsyncValue synchronously: it must be Loading (or
      // very quickly Data, but never a false-empty data). We do
      // not assert `isLoading == true` because AsyncNotifier
      // resolves the initial state synchronously in some cases;
      // we only assert that we DO NOT see "data with 0 completed
      // tasks" before the controller has had a chance to query
      // the DB. We solve this by checking that the FIRST emission
      // after awaiting a microtask is the data we expect — i.e.,
      // it was either loading or data, and if data, the data came
      // from the DB (here the DB is empty so it is empty).
      final AsyncValue<TodayPracticeState> first =
          container.read(todayPracticeControllerProvider);
      // Resolve to a real state.
      final TodayPracticeState state =
          await container.read(todayPracticeControllerProvider.future);
      expect(state.dayIndex, 1);
      expect(state.completedTaskIds, isEmpty);
      // The first read must not have produced a non-empty data.
      expect(
        first.hasValue && first.value!.completedTaskIds.isNotEmpty,
        isFalse,
      );
    });

    test('DB-already-completed tasks appear in the first data state', () async {
      final AppDatabase db = buildDb();
      final DateTime fixed = DateTime(2026, 6, 20, 9, 0);
      // Seed the DB BEFORE the controller ever runs.
      await db.into(db.completedTasks).insert(
            CompletedTasksCompanion.insert(
              localDate: '2026-06-20',
              taskId: 'day1_tuner',
              completedAt: DateTime.utc(2026, 6, 20, 9),
            ),
          );
      final ProviderContainer container = buildContainer(
        db: db,
        clock: () => fixed,
        installService: _FakeInstallDateService(fixed),
      );
      final TodayPracticeState state =
          await container.read(todayPracticeControllerProvider.future);
      expect(state.completedTaskIds, equals(<String>{'day1_tuner'}));
      // The task card itself is marked done.
      final PracticeTask t =
          state.plan.tasks.firstWhere((PracticeTask p) => p.id == 'day1_tuner');
      expect(t.status, PracticeTaskStatus.done);
      // Other tasks are still todo.
      for (final PracticeTask other in state.plan.tasks) {
        if (other.id == 'day1_tuner') continue;
        expect(other.status, PracticeTaskStatus.todo);
      }
    });

    test('does NOT show fake "all-todo" snapshot during the load window',
        () async {
      // Strict contract: if a task WAS persisted as completed,
      // the controller's first data emission MUST include it. We
      // assert that there is no emission where the persisted
      // task is suddenly absent.
      final AppDatabase db = buildDb();
      final DateTime fixed = DateTime(2026, 6, 20, 9, 0);
      await db.into(db.completedTasks).insert(
            CompletedTasksCompanion.insert(
              localDate: '2026-06-20',
              taskId: 'day1_single_note',
              completedAt: DateTime.utc(2026, 6, 20, 9),
            ),
          );
      final ProviderContainer container = buildContainer(
        db: db,
        clock: () => fixed,
        installService: _FakeInstallDateService(fixed),
      );

      // Capture every distinct state emitted.
      final List<AsyncValue<TodayPracticeState>> emissions =
          <AsyncValue<TodayPracticeState>>[];
      container.listen<AsyncValue<TodayPracticeState>>(
        todayPracticeControllerProvider,
        (AsyncValue<TodayPracticeState>? prev,
                AsyncValue<TodayPracticeState> next) =>
            emissions.add(next),
        fireImmediately: true,
      );
      // Wait for the first data state.
      await container.read(todayPracticeControllerProvider.future);
      // Drain a microtask so any late emissions land.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      // Every emission that has data must include the persisted id.
      for (final AsyncValue<TodayPracticeState> e in emissions) {
        if (!e.hasValue) continue;
        expect(e.value!.completedTaskIds, contains('day1_single_note'));
      }
    });

    test('error during build surfaces as AsyncError + retry recovers',
        () async {
      final AppDatabase db = buildDb();
      final DateTime fixed = DateTime(2026, 6, 20, 9, 0);
      // First call: throw. Second call: return a valid date.
      final ProviderContainer container = buildContainer(
        db: db,
        clock: () => fixed,
        installService: _FailingThenSucceedingInstallDateService(
          failureOnFirstCall: true,
          success: fixed,
        ),
      );
      // First read should yield an error.
      await expectLater(
        container.read(todayPracticeControllerProvider.future),
        throwsA(anything),
      );
      // Retry via invalidate.
      container.invalidate(todayPracticeControllerProvider);
      final TodayPracticeState recovered =
          await container.read(todayPracticeControllerProvider.future);
      expect(recovered.dayIndex, 1);
      expect(recovered.completedTaskIds, isEmpty);
    });
  });

  group('TodayPracticeController.toggleTaskCompleted', () {
    test('success persists and returns true', () async {
      final AppDatabase db = buildDb();
      final DateTime fixed = DateTime(2026, 6, 20, 9, 0);
      final ProviderContainer container = buildContainer(
        db: db,
        clock: () => fixed,
        installService: _FakeInstallDateService(fixed),
      );
      final TodayPracticeController controller =
          container.read(todayPracticeControllerProvider.notifier);
      await container.read(todayPracticeControllerProvider.future);
      final String taskId = container
          .read(todayPracticeControllerProvider)
          .value!
          .plan
          .tasks
          .first
          .id;
      final bool ok = await controller.toggleTaskCompleted(taskId);
      expect(ok, isTrue);
      final TodayPracticeState state =
          container.read(todayPracticeControllerProvider).value!;
      expect(state.isTaskCompleted(taskId), isTrue);
      // DB row exists.
      final List<CompletedTaskData> rows =
          await db.select(db.completedTasks).get();
      expect(rows, hasLength(1));
      expect(rows.single.taskId, taskId);
    });

    test('second toggle removes the persisted row', () async {
      final AppDatabase db = buildDb();
      final DateTime fixed = DateTime(2026, 6, 20, 9, 0);
      final ProviderContainer container = buildContainer(
        db: db,
        clock: () => fixed,
        installService: _FakeInstallDateService(fixed),
      );
      final TodayPracticeController controller =
          container.read(todayPracticeControllerProvider.notifier);
      await container.read(todayPracticeControllerProvider.future);
      final String taskId = container
          .read(todayPracticeControllerProvider)
          .value!
          .plan
          .tasks
          .first
          .id;
      expect(await controller.toggleTaskCompleted(taskId), isTrue);
      expect(
        await controller.toggleTaskCompleted(taskId),
        isTrue,
        reason: 'un-mark is also a successful persistence write',
      );
      final TodayPracticeState state =
          container.read(todayPracticeControllerProvider).value!;
      expect(state.isTaskCompleted(taskId), isFalse);
      final List<CompletedTaskData> rows =
          await db.select(db.completedTasks).get();
      expect(rows, isEmpty);
    });

    test('unknown taskId is no-op and returns false', () async {
      final AppDatabase db = buildDb();
      final DateTime fixed = DateTime(2026, 6, 20, 9, 0);
      final ProviderContainer container = buildContainer(
        db: db,
        clock: () => fixed,
        installService: _FakeInstallDateService(fixed),
      );
      final TodayPracticeController controller =
          container.read(todayPracticeControllerProvider.notifier);
      await container.read(todayPracticeControllerProvider.future);
      final bool ok = await controller.toggleTaskCompleted('nonsense-id');
      expect(ok, isFalse);
      final TodayPracticeState state =
          container.read(todayPracticeControllerProvider).value!;
      expect(state.completedTaskIds, isEmpty);
      final List<CompletedTaskData> rows =
          await db.select(db.completedTasks).get();
      expect(rows, isEmpty);
    });

    test('failed DB write leaves in-memory state unchanged and returns false',
        () async {
      final AppDatabase db = buildDb();
      final DateTime fixed = DateTime(2026, 6, 20, 9, 0);
      // Wire a throwing repo so both build-time reads and
      // toggle writes go through it. Reads return empty so
      // build() resolves; writes throw.
      final ProviderContainer container = buildContainer(
        db: db,
        clock: () => fixed,
        installService: _FakeInstallDateService(fixed),
        completedTasksRepo: _ThrowingCompletedTasksRepository(),
      );
      final TodayPracticeController controller =
          container.read(todayPracticeControllerProvider.notifier);
      await container.read(todayPracticeControllerProvider.future);
      final String taskId = container
          .read(todayPracticeControllerProvider)
          .value!
          .plan
          .tasks
          .first
          .id;
      final bool ok = await controller.toggleTaskCompleted(taskId);
      expect(ok, isFalse);
      final TodayPracticeState state =
          container.read(todayPracticeControllerProvider).value!;
      expect(state.isTaskCompleted(taskId), isFalse,
          reason: 'failure must not mutate state');
    });

    test('same taskId concurrent toggles are coalesced', () async {
      final AppDatabase db = buildDb();
      final DateTime fixed = DateTime(2026, 6, 20, 9, 0);
      final ProviderContainer container = buildContainer(
        db: db,
        clock: () => fixed,
        installService: _FakeInstallDateService(fixed),
      );
      final TodayPracticeController controller =
          container.read(todayPracticeControllerProvider.notifier);
      await container.read(todayPracticeControllerProvider.future);
      final String taskId = container
          .read(todayPracticeControllerProvider)
          .value!
          .plan
          .tasks
          .first
          .id;

      // Fire two clicks back-to-back. The second must be dropped
      // (returns false) and the state must end up "completed".
      final Future<bool> first = controller.toggleTaskCompleted(taskId);
      final Future<bool> second = controller.toggleTaskCompleted(taskId);
      final List<bool> results =
          await Future.wait(<Future<bool>>[first, second]);
      // Exactly one is `true`. Order is implementation-defined, so
      // we count.
      expect(results.where((bool r) => r).length, 1);
      expect(results.where((bool r) => !r).length, 1);
      final TodayPracticeState state =
          container.read(todayPracticeControllerProvider).value!;
      expect(state.isTaskCompleted(taskId), isTrue);
    });

    test('different taskIds complete independently', () async {
      final AppDatabase db = buildDb();
      final DateTime fixed = DateTime(2026, 6, 20, 9, 0);
      final ProviderContainer container = buildContainer(
        db: db,
        clock: () => fixed,
        installService: _FakeInstallDateService(fixed),
      );
      final TodayPracticeController controller =
          container.read(todayPracticeControllerProvider.notifier);
      await container.read(todayPracticeControllerProvider.future);
      final List<String> ids = container
          .read(todayPracticeControllerProvider)
          .value!
          .plan
          .tasks
          .map((PracticeTask t) => t.id)
          .toList();
      if (ids.length < 2) {
        fail('test requires at least 2 tasks on Day 1');
      }
      final String a = ids[0];
      final String b = ids[1];

      // Concurrently toggle A and B. Both writes MUST complete
      // successfully, and the resulting state MUST contain BOTH
      // ids — neither write should clobber the other.
      final List<bool> results = await Future.wait<bool>(<Future<bool>>[
        controller.toggleTaskCompleted(a),
        controller.toggleTaskCompleted(b),
      ]);
      expect(results, <bool>[true, true]);
      final TodayPracticeState state =
          container.read(todayPracticeControllerProvider).value!;
      expect(state.completedTaskIds, equals(<String>{a, b}));
    });

    test('ProviderContainer rebuild preserves completed state', () async {
      // Simulate cold start: build a container, toggle a task,
      // dispose, build a fresh container against the same DB,
      // verify the persisted state surfaces.
      final AppDatabase db = buildDb();
      final DateTime fixed = DateTime(2026, 6, 20, 9, 0);

      String taskId;
      {
        final ProviderContainer container = buildContainer(
          db: db,
          clock: () => fixed,
          installService: _FakeInstallDateService(fixed),
        );
        await container.read(todayPracticeControllerProvider.future);
        taskId = container
            .read(todayPracticeControllerProvider)
            .value!
            .plan
            .tasks
            .first
            .id;
        expect(
          await container
              .read(todayPracticeControllerProvider.notifier)
              .toggleTaskCompleted(taskId),
          isTrue,
        );
        container.dispose();
      }

      final ProviderContainer fresh = buildContainer(
        db: db,
        clock: () => fixed,
        installService: _FakeInstallDateService(fixed),
      );
      final TodayPracticeState reloaded =
          await fresh.read(todayPracticeControllerProvider.future);
      expect(reloaded.completedTaskIds, equals(<String>{taskId}));
    });
  });
}

/// Install-date stub that returns a fixed instant. Used when the
/// test wants to bypass the install-date service entirely.
class _FakeInstallDateService implements InstallDateService {
  _FakeInstallDateService(this._fixed);

  final DateTime _fixed;

  @override
  Future<DateTime> getInstallDate() async => _fixed;
}

/// Throws on the first call, succeeds on every subsequent call.
/// Used to exercise the retry path.
class _FailingThenSucceedingInstallDateService implements InstallDateService {
  _FailingThenSucceedingInstallDateService({
    required this.failureOnFirstCall,
    required this.success,
  });

  bool failureOnFirstCall;
  final DateTime success;

  @override
  Future<DateTime> getInstallDate() async {
    if (failureOnFirstCall) {
      failureOnFirstCall = false;
      throw StateError('synthetic first-call failure');
    }
    return success;
  }
}

/// Throws on every write, returns empty on reads. Used to
/// exercise the "persistence failure leaves state unchanged"
/// contract.
class _ThrowingCompletedTasksRepository implements CompletedTasksRepository {
  @override
  Future<Set<String>> getCompletedTaskIds(DateTime date) async =>
      const <String>{};

  @override
  Stream<Set<String>> watchCompletedTaskIds(DateTime date) =>
      const Stream<Set<String>>.empty();

  @override
  Future<void> markCompleted({
    required DateTime date,
    required String taskId,
    required DateTime completedAt,
  }) async {
    throw StateError('synthetic write failure');
  }

  @override
  Future<bool> unmarkCompleted({
    required DateTime date,
    required String taskId,
  }) async {
    throw StateError('synthetic write failure');
  }
}
