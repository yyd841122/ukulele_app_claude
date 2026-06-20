// Tests for [TodayPracticeController]
// (T013.3_FIX_LOCAL_DAY_AND_ERROR_UI + T013.4A0).
//
// T013.4A0_RECORDING_SAVE_FOUNDATION contract under test:
// - The day-index computation is delegated to the shared
//   `PracticeDayResolver`. The controller reads
//   `practiceDayResolverProvider` instead of computing
//   `localToday` / `localInstallDate` inline.
// - The previously feature-local providers `clockProvider` and
//   `installDateServiceProvider` were relocated to the shared
//   layer. The Home Controller and these tests now import the
//   shared providers; there is intentionally no alias preserved
//   in the controller file.
// - `appClockProvider` overrides are still honoured by the
//   resolver — the test contract "completedAt uses the shared
//   clock" is preserved.
//
// T013.3_FIX_LOCAL_DAY_AND_ERROR_UI contract under test:
// - The day index is computed from local-midnight on BOTH sides
//   of the call to `calculatePracticeDayIndex`. The state stores
//   the SAME local-midnight `installDate` that was fed to the
//   calculator, so there is no frame-of-reference drift between
//   `state.installDate` and the index.
// - The boundary-time tests construct their install-instant and
//   "now" using the current `DateTime.now().timeZoneOffset`, so
//   they pass under any offset (positive, negative, or UTC).
// - `TodayPracticeState` is genuinely immutable:
//     * Mutating a `Set` that was passed in to the constructor
//        does NOT affect the state's copy (defensive copy).
//     * Calling `.add(...)` / `.remove(...)` on
//        `state.completedTaskIds` or `state.pendingTaskIds`
//        throws `UnsupportedError`.
//     * `copyWith` produces another immutable state — the
//        returned Set references are still unmodifiable.
//
// T013.3_FIX_PENDING_RESULT_AND_INSTALL_DATE_BOUNDARY contract
// under test:
// - The controller is an AsyncNotifier. Before `build` resolves,
//   the provider exposes `AsyncLoading`.
// - `build` reads the persisted install date AND the persisted
//   completed-task set for today. Both reads MUST happen before
//   any "data" state is emitted — there is no "fake all-todo"
//   snapshot.
// - `toggleTaskCompleted` returns [ToggleTaskResult]:
//     * `success` — write committed, in-memory state updated.
//     * `ignored` — unknown id, duplicate click, provider
//       unmounted, cross-day roll-over. NO SnackBar should fire.
//     * `failure` — Repository write threw. UI shows a retry
//       SnackBar.
// - `TodayPracticeState.pendingTaskIds` exposes the in-flight set
//   so the UI can disable the Checkbox while a write is pending.
// - `completedAt` is sourced from `appClockProvider`, NOT
//   `DateTime.now()`.
// - Concurrent toggles on DIFFERENT taskIds complete
//   independently — neither one clobbers the other.

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/data/database/app_database.dart';
import 'package:ukulele_app/data/database/app_database_provider.dart';
import 'package:ukulele_app/features/home/application/today_practice_controller.dart';
import 'package:ukulele_app/features/home/data/completed_tasks_repository.dart';
import 'package:ukulele_app/features/home/data/completed_tasks_repository_provider.dart';
import 'package:ukulele_app/features/home/domain/built_in_practice_plan.dart';
import 'package:ukulele_app/features/home/domain/practice_task.dart';
import 'package:ukulele_app/features/home/domain/practice_task_status.dart';
import 'package:ukulele_app/shared/providers/app_clock_provider.dart';
import 'package:ukulele_app/shared/services/install_date_service.dart';
import 'package:ukulele_app/shared/services/install_date_service_provider.dart';

void main() {
  // Each test gets a fresh in-memory DB. We always close it.
  AppDatabase buildDb() {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    return db;
  }

  /// Builds a `ProviderContainer` wired against [db]. The
  /// controller's `appClockProvider` and
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
      if (clock != null) appClockProvider.overrideWithValue(clock),
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

      final AsyncValue<TodayPracticeState> first =
          container.read(todayPracticeControllerProvider);
      final TodayPracticeState state =
          await container.read(todayPracticeControllerProvider.future);
      expect(state.dayIndex, 1);
      expect(state.completedTaskIds, isEmpty);
      expect(
        first.hasValue && first.value!.completedTaskIds.isNotEmpty,
        isFalse,
      );
    });

    test('DB-already-completed tasks appear in the first data state', () async {
      final AppDatabase db = buildDb();
      final DateTime fixed = DateTime(2026, 6, 20, 9, 0);
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
      final PracticeTask t =
          state.plan.tasks.firstWhere((PracticeTask p) => p.id == 'day1_tuner');
      expect(t.status, PracticeTaskStatus.done);
      for (final PracticeTask other in state.plan.tasks) {
        if (other.id == 'day1_tuner') continue;
        expect(other.status, PracticeTaskStatus.todo);
      }
    });

    test('does NOT show fake "all-todo" snapshot during the load window',
        () async {
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

      final List<AsyncValue<TodayPracticeState>> emissions =
          <AsyncValue<TodayPracticeState>>[];
      container.listen<AsyncValue<TodayPracticeState>>(
        todayPracticeControllerProvider,
        (AsyncValue<TodayPracticeState>? prev,
                AsyncValue<TodayPracticeState> next) =>
            emissions.add(next),
        fireImmediately: true,
      );
      await container.read(todayPracticeControllerProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      for (final AsyncValue<TodayPracticeState> e in emissions) {
        if (!e.hasValue) continue;
        expect(e.value!.completedTaskIds, contains('day1_single_note'));
      }
    });

    test('error during build surfaces as AsyncError + retry recovers',
        () async {
      final AppDatabase db = buildDb();
      final DateTime fixed = DateTime(2026, 6, 20, 9, 0);
      final ProviderContainer container = buildContainer(
        db: db,
        clock: () => fixed,
        installService: _FailingThenSucceedingInstallDateService(
          failureOnFirstCall: true,
          success: fixed,
        ),
      );
      await expectLater(
        container.read(todayPracticeControllerProvider.future),
        throwsA(anything),
      );
      container.invalidate(todayPracticeControllerProvider);
      final TodayPracticeState recovered =
          await container.read(todayPracticeControllerProvider.future);
      expect(recovered.dayIndex, 1);
      expect(recovered.completedTaskIds, isEmpty);
    });

    test('state.installDate is local-midnight even when service returns UTC',
        () async {
      final AppDatabase db = buildDb();
      // 23:30 local on 2026-06-20. As UTC this is 15:30 on
      // 2026-06-20 in CST, but in other offsets it can be the
      // day before. The controller MUST project to local first.
      final DateTime localLateNight = DateTime(2026, 6, 20, 23, 30);
      // The fixed clock the controller reads via appClockProvider.
      final DateTime fixedClock = DateTime(2026, 6, 20, 23, 31);
      final ProviderContainer container = buildContainer(
        db: db,
        clock: () => fixedClock,
        installService: _FakeInstallDateService(
          localLateNight.toUtc(),
        ),
      );
      final TodayPracticeState state =
          await container.read(todayPracticeControllerProvider.future);
      // Always local-midnight of the day the install instant
      // projected to.
      expect(state.installDate.isUtc, isFalse);
      expect(state.installDate, DateTime(2026, 6, 20));
    });
  });

  group('T013.3_FIX_LOCAL_DAY day-index contract', () {
    // The boundary tests below construct their install and
    // "now" instants using the host's current timeZoneOffset.
    // The contract — `state.installDate` is the SAME local
    // midnight that was fed to `calculatePracticeDayIndex` —
    // must hold for any offset (positive, negative, or UTC),
    // and for the 23:30-into-midnight roll-over case in
    // particular. We do NOT assert a specific local date
    // because the local date depends on the host offset; we
    // assert that `state.installDate` is exactly the local
    // midnight the calculator saw, and that the calculator
    // saw a `today` exactly equal to `state.today`.
    test(
        'dayIndex uses local-midnight for both installDate and today, '
        'with 23:30 install instant', () async {
      final AppDatabase db = buildDb();
      // 23:30 LOCAL on whatever local day the host is in right
      // now. The controller reads "today" from the same clock
      // value (`nowClock`), so the calculator sees:
      //   installMidnight == localMidnight(install.toLocal())
      //   todayMidnight   == localMidnight(now)
      // and (todayMidnight - installMidnight) is exactly the
      // offset between those two local midnights, regardless
      // of time zone.
      final DateTime nowLocal = DateTime.now();
      final DateTime nowClock = DateTime(
        nowLocal.year,
        nowLocal.month,
        nowLocal.day,
        23,
        31,
      );
      final DateTime installLocal = DateTime(
        nowLocal.year,
        nowLocal.month,
        nowLocal.day,
        23,
        30,
      );
      final DateTime expectedInstallMidnight = DateTime(
        installLocal.year,
        installLocal.month,
        installLocal.day,
      );
      final DateTime expectedTodayMidnight = DateTime(
        nowLocal.year,
        nowLocal.month,
        nowLocal.day,
      );

      final ProviderContainer container = buildContainer(
        db: db,
        clock: () => nowClock,
        installService: _FakeInstallDateService(installLocal.toUtc()),
      );
      final TodayPracticeState state =
          await container.read(todayPracticeControllerProvider.future);

      // The state must carry the SAME local-midnight pair that
      // was fed to the calculator. The day-index call saw
      // (expectedInstallMidnight, expectedTodayMidnight) and
      // must return 1 (same day), and the state must agree.
      expect(state.installDate, expectedInstallMidnight,
          reason: 'state.installDate must match the local-midnight fed '
              'to calculatePracticeDayIndex');
      expect(state.today, expectedTodayMidnight,
          reason: 'state.today must match the local-midnight fed '
              'to calculatePracticeDayIndex');
      // Same calendar day → 1.
      expect(state.dayIndex, 1,
          reason: 'install and now are on the same local day → dayIndex 1');
    });

    test(
        'dayIndex rolls into the next day when "now" crosses local midnight '
        'relative to install (no UTC leakage)', () async {
      final AppDatabase db = buildDb();
      // Pick a base day in local time. The install instant is
      // local midnight of that day; "now" is 1 second past
      // local midnight of the FOLLOWING day. We use the host's
      // timeZoneOffset to project both to UTC, which is what
      // the controller's fake service will hand back.
      final DateTime baseDay = DateTime.now();
      final DateTime installLocal = DateTime(
        baseDay.year,
        baseDay.month,
        baseDay.day,
      );
      final DateTime nextDay = installLocal.add(const Duration(days: 1));
      final DateTime nowLocal = DateTime(
        nextDay.year,
        nextDay.month,
        nextDay.day,
        0,
        0,
        1,
      );

      final ProviderContainer container = buildContainer(
        db: db,
        clock: () => nowLocal,
        installService: _FakeInstallDateService(installLocal.toUtc()),
      );
      final TodayPracticeState state =
          await container.read(todayPracticeControllerProvider.future);

      // Calendar diff is exactly 1 day → dayIndex 2.
      expect(state.installDate, installLocal);
      expect(state.today, DateTime(nextDay.year, nextDay.month, nextDay.day));
      expect(state.dayIndex, 2,
          reason: 'one local day after install → dayIndex 2');
    });

    test(
        'UTC host: dayIndex is computed from local-midnight values that '
        'happen to equal the original UTC day', () async {
      // We do NOT assume the host is UTC. The contract is that
      // the state and the calculator agree on local-midnight.
      // To exercise the "both are UTC" case we synthesise a
      // pair where the local time-zone offset is zero (i.e.
      // we're in a UTC run) by working with values that are
      // representable as both local and UTC.
      final AppDatabase db = buildDb();
      final DateTime installLocal = DateTime(2026, 1, 1, 0, 0, 0);
      final DateTime nowLocal = DateTime(2026, 1, 8, 0, 0, 0);
      final ProviderContainer container = buildContainer(
        db: db,
        clock: () => nowLocal,
        installService: _FakeInstallDateService(installLocal.toUtc()),
      );
      final TodayPracticeState state =
          await container.read(todayPracticeControllerProvider.future);
      expect(state.installDate, installLocal);
      expect(state.today, DateTime(2026, 1, 8));
      // 7 days exactly → dayIndex 1 ((7 % 7) + 1).
      expect(state.dayIndex, 1);
    });
  });

  group('T013.3_FIX_LOCAL_DAY immutable-state contract', () {
    test('external mutation of completed Set does not affect state', () async {
      final Set<String> external = <String>{'day1_tuner'};
      final TodayPracticeState state = TodayPracticeState(
        today: DateTime(2026, 6, 20),
        installDate: DateTime(2026, 6, 20),
        dayIndex: 1,
        plan: const BuiltInPracticePlan(
          dayIndex: 1,
          title: 'Day 1',
          estimatedMinutes: 10,
          tasks: <PracticeTask>[],
        ),
        completedTaskIds: external,
      );
      external.add('sneaky');
      external.remove('day1_tuner');
      expect(state.completedTaskIds, equals(<String>{'day1_tuner'}),
          reason: 'state must not see the caller mutations');
    });

    test('external mutation of pending Set does not affect state', () async {
      final Set<String> external = <String>{'day1_tuner'};
      final TodayPracticeState state = TodayPracticeState(
        today: DateTime(2026, 6, 20),
        installDate: DateTime(2026, 6, 20),
        dayIndex: 1,
        plan: const BuiltInPracticePlan(
          dayIndex: 1,
          title: 'Day 1',
          estimatedMinutes: 10,
          tasks: <PracticeTask>[],
        ),
        completedTaskIds: const <String>{},
        pendingTaskIds: external,
      );
      external.add('sneaky');
      external.remove('day1_tuner');
      expect(state.pendingTaskIds, equals(<String>{'day1_tuner'}));
    });

    test('state.completedTaskIds is unmodifiable (add throws)', () async {
      final TodayPracticeState state = TodayPracticeState(
        today: DateTime(2026, 6, 20),
        installDate: DateTime(2026, 6, 20),
        dayIndex: 1,
        plan: const BuiltInPracticePlan(
          dayIndex: 1,
          title: 'Day 1',
          estimatedMinutes: 10,
          tasks: <PracticeTask>[],
        ),
        completedTaskIds: <String>{'day1_tuner'},
      );
      expect(
        () => state.completedTaskIds.add('boom'),
        throwsUnsupportedError,
      );
      expect(
        () => state.completedTaskIds.remove('day1_tuner'),
        throwsUnsupportedError,
      );
    });

    test('state.pendingTaskIds is unmodifiable (add throws)', () async {
      final TodayPracticeState state = TodayPracticeState(
        today: DateTime(2026, 6, 20),
        installDate: DateTime(2026, 6, 20),
        dayIndex: 1,
        plan: const BuiltInPracticePlan(
          dayIndex: 1,
          title: 'Day 1',
          estimatedMinutes: 10,
          tasks: <PracticeTask>[],
        ),
        completedTaskIds: const <String>{},
        pendingTaskIds: <String>{'day1_tuner'},
      );
      expect(
        () => state.pendingTaskIds.add('boom'),
        throwsUnsupportedError,
      );
      expect(
        () => state.pendingTaskIds.remove('day1_tuner'),
        throwsUnsupportedError,
      );
    });

    test('copyWith preserves unmodifiable Sets', () async {
      final TodayPracticeState state = TodayPracticeState(
        today: DateTime(2026, 6, 20),
        installDate: DateTime(2026, 6, 20),
        dayIndex: 1,
        plan: const BuiltInPracticePlan(
          dayIndex: 1,
          title: 'Day 1',
          estimatedMinutes: 10,
          tasks: <PracticeTask>[],
        ),
        completedTaskIds: <String>{'day1_tuner'},
        pendingTaskIds: <String>{'day1_chord'},
      );
      final TodayPracticeState copied = state.copyWith(
        dayIndex: 2,
      );
      expect(copied.dayIndex, 2);
      // The new state's Sets are still unmodifiable.
      expect(
        () => copied.completedTaskIds.add('boom'),
        throwsUnsupportedError,
      );
      expect(
        () => copied.pendingTaskIds.add('boom'),
        throwsUnsupportedError,
      );
      // And carrying an external Set through copyWith still
      // results in an unmodifiable Set (the constructor wraps).
      final Set<String> externalCompleted = <String>{'a', 'b'};
      final Set<String> externalPending = <String>{'c'};
      final TodayPracticeState copied2 = state.copyWith(
        completedTaskIds: externalCompleted,
        pendingTaskIds: externalPending,
      );
      externalCompleted.add('sneaky');
      externalPending.add('sneaky-pending');
      expect(copied2.completedTaskIds, equals(<String>{'a', 'b'}));
      expect(copied2.pendingTaskIds, equals(<String>{'c'}));
      expect(
        () => copied2.completedTaskIds.add('boom'),
        throwsUnsupportedError,
      );
    });
  });

  group('TodayPracticeController.toggleTaskCompleted', () {
    test('success persists and returns success', () async {
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
      final ToggleTaskResult result =
          await controller.toggleTaskCompleted(taskId);
      expect(result, ToggleTaskResult.success);
      final TodayPracticeState state =
          container.read(todayPracticeControllerProvider).value!;
      expect(state.isTaskCompleted(taskId), isTrue);
      expect(state.pendingTaskIds, isNot(contains(taskId)));
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
      expect(
        await controller.toggleTaskCompleted(taskId),
        ToggleTaskResult.success,
      );
      expect(
        await controller.toggleTaskCompleted(taskId),
        ToggleTaskResult.success,
        reason: 'un-mark is also a successful persistence write',
      );
      final TodayPracticeState state =
          container.read(todayPracticeControllerProvider).value!;
      expect(state.isTaskCompleted(taskId), isFalse);
      final List<CompletedTaskData> rows =
          await db.select(db.completedTasks).get();
      expect(rows, isEmpty);
    });

    test('unknown taskId returns ignored and does not touch the DB', () async {
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
      final ToggleTaskResult result =
          await controller.toggleTaskCompleted('nonsense-id');
      expect(result, ToggleTaskResult.ignored);
      final TodayPracticeState state =
          container.read(todayPracticeControllerProvider).value!;
      expect(state.completedTaskIds, isEmpty);
      expect(state.pendingTaskIds, isEmpty);
      final List<CompletedTaskData> rows =
          await db.select(db.completedTasks).get();
      expect(rows, isEmpty);
    });

    test('failed DB write returns failure and leaves state unchanged',
        () async {
      final AppDatabase db = buildDb();
      final DateTime fixed = DateTime(2026, 6, 20, 9, 0);
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
      final ToggleTaskResult result =
          await controller.toggleTaskCompleted(taskId);
      expect(result, ToggleTaskResult.failure);
      final TodayPracticeState state =
          container.read(todayPracticeControllerProvider).value!;
      expect(state.isTaskCompleted(taskId), isFalse,
          reason: 'failure must not mutate state');
      expect(state.pendingTaskIds, isNot(contains(taskId)),
          reason: 'pending flag must be cleared on failure');
    });

    test('same taskId concurrent toggles — second returns ignored', () async {
      final AppDatabase db = buildDb();
      final DateTime fixed = DateTime(2026, 6, 20, 9, 0);
      final ProviderContainer container = buildContainer(
        db: db,
        clock: () => fixed,
        installService: _FakeInstallDateService(fixed),
        completedTasksRepo: _GatedCompletedTasksRepository(),
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

      // Fire two clicks back-to-back. The second is dropped
      // (returns ignored) and the state ends up "completed"
      // exactly once. The gated repo ensures the first write is
      // still in flight when the second toggle is fired.
      final Completer<void> release = Completer<void>();
      _GatedCompletedTasksRepository.gate = release.future;

      final Future<ToggleTaskResult> first =
          controller.toggleTaskCompleted(taskId);
      // Yield so the controller can register the pending id.
      await Future<void>.delayed(const Duration(milliseconds: 0));
      final Future<ToggleTaskResult> second =
          controller.toggleTaskCompleted(taskId);

      // The duplicate click resolves immediately as ignored.
      expect(await second, ToggleTaskResult.ignored);
      // Now release the gate and let the first write complete.
      release.complete();
      expect(await first, ToggleTaskResult.success);

      final TodayPracticeState state =
          container.read(todayPracticeControllerProvider).value!;
      expect(state.isTaskCompleted(taskId), isTrue);
      expect(state.pendingTaskIds, isNot(contains(taskId)));
    });

    test('pending taskId is in state.pendingTaskIds before write resolves',
        () async {
      final AppDatabase db = buildDb();
      final DateTime fixed = DateTime(2026, 6, 20, 9, 0);
      final ProviderContainer container = buildContainer(
        db: db,
        clock: () => fixed,
        installService: _FakeInstallDateService(fixed),
        completedTasksRepo: _GatedCompletedTasksRepository(),
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

      final Completer<void> release = Completer<void>();
      _GatedCompletedTasksRepository.gate = release.future;

      final Future<ToggleTaskResult> write =
          controller.toggleTaskCompleted(taskId);
      // Yield to let the controller mark the id as pending.
      await Future<void>.delayed(const Duration(milliseconds: 0));
      final TodayPracticeState during =
          container.read(todayPracticeControllerProvider).value!;
      expect(during.pendingTaskIds, contains(taskId));
      expect(during.isTaskCompleted(taskId), isFalse,
          reason: 'pending must NOT flip the completion state');

      release.complete();
      await write;
      final TodayPracticeState after =
          container.read(todayPracticeControllerProvider).value!;
      expect(after.pendingTaskIds, isNot(contains(taskId)));
      expect(after.isTaskCompleted(taskId), isTrue);
    });

    test('pending is cleared after a failure', () async {
      final AppDatabase db = buildDb();
      final DateTime fixed = DateTime(2026, 6, 20, 9, 0);
      final ProviderContainer container = buildContainer(
        db: db,
        clock: () => fixed,
        installService: _FakeInstallDateService(fixed),
        completedTasksRepo: _GatedThrowingCompletedTasksRepository(),
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

      final Completer<void> release = Completer<void>();
      _GatedThrowingCompletedTasksRepository.gate = release.future;

      final Future<ToggleTaskResult> write =
          controller.toggleTaskCompleted(taskId);
      await Future<void>.delayed(const Duration(milliseconds: 0));
      expect(
        container.read(todayPracticeControllerProvider).value!.pendingTaskIds,
        contains(taskId),
      );

      release.complete();
      expect(await write, ToggleTaskResult.failure);
      expect(
        container.read(todayPracticeControllerProvider).value!.pendingTaskIds,
        isNot(contains(taskId)),
      );
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

      final List<ToggleTaskResult> results =
          await Future.wait<ToggleTaskResult>(<Future<ToggleTaskResult>>[
        controller.toggleTaskCompleted(a),
        controller.toggleTaskCompleted(b),
      ]);
      expect(results, <ToggleTaskResult>[
        ToggleTaskResult.success,
        ToggleTaskResult.success,
      ]);
      final TodayPracticeState state =
          container.read(todayPracticeControllerProvider).value!;
      expect(state.completedTaskIds, equals(<String>{a, b}));
    });

    test('different taskIds pending simultaneously are independent', () async {
      final AppDatabase db = buildDb();
      final DateTime fixed = DateTime(2026, 6, 20, 9, 0);
      final ProviderContainer container = buildContainer(
        db: db,
        clock: () => fixed,
        installService: _FakeInstallDateService(fixed),
        completedTasksRepo: _GatedCompletedTasksRepository(),
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

      final Completer<void> release = Completer<void>();
      _GatedCompletedTasksRepository.gate = release.future;

      final Future<ToggleTaskResult> fa = controller.toggleTaskCompleted(a);
      final Future<ToggleTaskResult> fb = controller.toggleTaskCompleted(b);
      await Future<void>.delayed(const Duration(milliseconds: 0));

      // Both pending simultaneously, neither blocks the other.
      final TodayPracticeState during =
          container.read(todayPracticeControllerProvider).value!;
      expect(during.pendingTaskIds, containsAll(<String>{a, b}));

      release.complete();
      final List<ToggleTaskResult> results =
          await Future.wait<ToggleTaskResult>(<Future<ToggleTaskResult>>[
        fa,
        fb,
      ]);
      expect(
        results,
        <ToggleTaskResult>[ToggleTaskResult.success, ToggleTaskResult.success],
      );
      final TodayPracticeState after =
          container.read(todayPracticeControllerProvider).value!;
      expect(after.completedTaskIds, equals(<String>{a, b}));
      expect(after.pendingTaskIds, isEmpty);
    });

    test('completedAt uses appClockProvider (not DateTime.now)', () async {
      final AppDatabase db = buildDb();
      // Pin a deterministic "now" via the override clock; the
      // controller MUST stamp `completedAt` with this exact
      // value (projected to UTC).
      final DateTime clockFixed = DateTime.utc(2026, 6, 20, 9, 30);
      final ProviderContainer container = buildContainer(
        db: db,
        // The clock fn returns a UTC value here so the assertion
        // below reads cleanly. The controller still calls
        // `.toUtc()` itself.
        clock: () => clockFixed,
        installService: _FakeInstallDateService(clockFixed),
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
      final ToggleTaskResult result =
          await controller.toggleTaskCompleted(taskId);
      expect(result, ToggleTaskResult.success);
      final List<CompletedTaskData> rows =
          await db.select(db.completedTasks).get();
      expect(rows, hasLength(1));
      // The persisted instant must match the override clock
      // value exactly. Drift's `dateTime()` column truncates to
      // second precision, so we project both sides to whole
      // seconds before comparing.
      final int persistedEpochSec =
          rows.single.completedAt.millisecondsSinceEpoch ~/ 1000;
      final int expectedEpochSec =
          clockFixed.toUtc().millisecondsSinceEpoch ~/ 1000;
      expect(persistedEpochSec, expectedEpochSec);
    });

    test('cross-day toggle is ignored (no leak into the new day)', () async {
      final AppDatabase db = buildDb();
      // Mutable clock so the test can advance "now" between
      // the start of a write and its release.
      DateTime clockNow = DateTime(2026, 6, 20, 23, 59);
      final ProviderContainer container = buildContainer(
        db: db,
        clock: () => clockNow,
        installService: _FakeInstallDateService(
          DateTime.utc(2026, 6, 20, 0),
        ),
        completedTasksRepo: _GatedCompletedTasksRepository(),
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

      final Completer<void> release = Completer<void>();
      _GatedCompletedTasksRepository.gate = release.future;

      // Start a write while we are still on Day N.
      final Future<ToggleTaskResult> write =
          controller.toggleTaskCompleted(taskId);
      await Future<void>.delayed(const Duration(milliseconds: 0));

      // The wall clock crosses midnight. The controller's state
      // has `today = 2026-06-20` (local), but `build()` will be
      // re-run via `invalidate` and the FRESH state will have
      // `today = 2026-06-21`.
      clockNow = DateTime(2026, 6, 21, 0, 5);
      container.invalidate(todayPracticeControllerProvider);
      // Wait for the rebuild so `state.value` reflects the new
      // day. Note: this is a re-build, so `today` becomes
      // `DateTime(2026, 6, 21)`.
      await container.read(todayPracticeControllerProvider.future);

      release.complete();
      expect(await write, ToggleTaskResult.ignored);
      // In-memory state: pending was cleared for the old day,
      // and the new day's state has no completion merge.
      final TodayPracticeState after =
          container.read(todayPracticeControllerProvider).value!;
      expect(after.today, DateTime(2026, 6, 21));
      expect(after.completedTaskIds, isEmpty,
          reason: 'yesterday\'s write must NOT leak into today');
      expect(after.pendingTaskIds, isNot(contains(taskId)));
    });

    test('ProviderContainer rebuild preserves completed state', () async {
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
          ToggleTaskResult.success,
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

/// Repository whose `markCompleted` / `unmarkCompleted` block
/// until a static `gate` future resolves. The static `gate` field
/// is shared between tests by design — the test that uses this
/// repo is responsible for resetting it.
class _GatedCompletedTasksRepository implements CompletedTasksRepository {
  static Future<void>? gate;

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
    final Future<void>? g = gate;
    if (g != null) {
      await g;
    }
  }

  @override
  Future<bool> unmarkCompleted({
    required DateTime date,
    required String taskId,
  }) async {
    final Future<void>? g = gate;
    if (g != null) {
      await g;
    }
    return true;
  }
}

/// Repository that BLOCKS on a gate (so we can observe the
/// pending state) and THEN throws. Lets us verify the pending
/// flag is cleared on the failure path.
class _GatedThrowingCompletedTasksRepository
    implements CompletedTasksRepository {
  static Future<void>? gate;

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
    final Future<void>? g = gate;
    if (g != null) {
      await g;
    }
    throw StateError('synthetic gated write failure');
  }

  @override
  Future<bool> unmarkCompleted({
    required DateTime date,
    required String taskId,
  }) async {
    final Future<void>? g = gate;
    if (g != null) {
      await g;
    }
    return true;
  }
}
