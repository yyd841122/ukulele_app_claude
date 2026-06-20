// Riverpod controller for the home / "today's practice" page.
//
// T013.3 scope:
// - Converted from a synchronous `Notifier<TodayPracticeState>`
//   to `AsyncNotifier<TodayPracticeState>`. The state is built by
//   awaiting two persistence reads:
//     1. The persisted install date (Drift /
//        `InstallDateService`).
//     2. The completed-task set for today (Drift /
//        `CompletedTasksRepository`).
//   This means the UI must handle the `AsyncValue` envelope
//   instead of seeing a "fake empty" snapshot during the load
//   window.
// - `toggleTaskCompleted` is now `Future<bool>`. It awaits the
//   persistence write BEFORE updating the in-memory state, so:
//     * On success it returns `true` and the UI sees the new
//       completion state.
//     * On failure it returns `false` and leaves the state
//       unchanged.
//   Concurrent clicks on the same `taskId` while a write is in
//   flight are dropped (return `false`) — see `_pendingTaskIds`.
//   Concurrent clicks on DIFFERENT taskIds proceed independently.
// - The provider stays hand-written (no `@riverpod` codegen) per
//   the project convention.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/core/constants/practice_plan_constants.dart';
import 'package:ukulele_app/core/utils/practice_day_calculator.dart';
import 'package:ukulele_app/data/database/app_database_provider.dart';
import 'package:ukulele_app/features/home/data/completed_tasks_repository.dart';
import 'package:ukulele_app/features/home/data/completed_tasks_repository_provider.dart';
import 'package:ukulele_app/features/home/domain/built_in_practice_plan.dart';
import 'package:ukulele_app/features/home/domain/practice_task.dart';
import 'package:ukulele_app/features/home/domain/practice_task_status.dart';
import 'package:ukulele_app/shared/services/drift_install_date_service.dart';
import 'package:ukulele_app/shared/services/install_date_service.dart';

/// Provider for the [InstallDateService] used by the home controller.
///
/// T013.3 default is the Drift-backed implementation, wired to the
/// shared [appDatabaseProvider]. Tests can override this with
/// [InMemoryInstallDateService] (or any other implementation) to
/// pin install date / isolate from the DB.
final Provider<InstallDateService> installDateServiceProvider =
    Provider<InstallDateService>((Ref ref) {
  return DriftInstallDateService(
    database: ref.watch(appDatabaseProvider),
  );
});

/// Clock function for the controller. Defaults to [DateTime.now].
///
/// Overriding this provider is the recommended way for tests to
/// pin "today" to a specific instant without monkey-patching
/// globals.
final Provider<DateTime Function()> clockProvider =
    Provider<DateTime Function()>((Ref ref) => DateTime.now);

/// Immutable state for the home page.
@immutable
class TodayPracticeState {
  const TodayPracticeState({
    required this.today,
    required this.installDate,
    required this.dayIndex,
    required this.plan,
    required this.completedTaskIds,
  });

  /// The "today" used to compute [dayIndex] (already normalised
  /// to local-midnight by the calculator).
  final DateTime today;

  /// The install date used to compute [dayIndex] (already
  /// normalised to local-midnight by the calculator).
  final DateTime installDate;

  /// 1-based day in the 7-day cycle. Always in 1..7.
  final int dayIndex;

  /// The plan for [dayIndex]. Each [PracticeTask] in the list
  /// reflects the current completion state.
  final BuiltInPracticePlan plan;

  /// Set of task ids that are currently marked done.
  final Set<String> completedTaskIds;

  /// Number of tasks marked done.
  int get completedTaskCount => completedTaskIds.length;

  /// Total number of tasks for the day.
  int get totalTaskCount => plan.tasks.length;

  /// Total estimated minutes, derived from the current task list
  /// to guarantee consistency with what the UI renders.
  int get totalEstimatedMinutes => plan.tasks.fold<int>(
        0,
        (int sum, PracticeTask task) => sum + task.estimatedMinutes,
      );

  /// Returns `true` iff the task with the given id is marked
  /// done.
  bool isTaskCompleted(String taskId) => completedTaskIds.contains(taskId);

  TodayPracticeState copyWith({
    DateTime? today,
    DateTime? installDate,
    int? dayIndex,
    BuiltInPracticePlan? plan,
    Set<String>? completedTaskIds,
  }) {
    return TodayPracticeState(
      today: today ?? this.today,
      installDate: installDate ?? this.installDate,
      dayIndex: dayIndex ?? this.dayIndex,
      plan: plan ?? this.plan,
      completedTaskIds: completedTaskIds ?? this.completedTaskIds,
    );
  }
}

/// Riverpod notifier that produces [TodayPracticeState].
///
/// The state is loaded asynchronously from the install-date
/// service and the completed-tasks repository. While the load is
/// in flight the provider exposes an `AsyncLoading`. The UI
/// MUST handle the `AsyncValue` envelope.
class TodayPracticeController extends AsyncNotifier<TodayPracticeState> {
  // Tracks task ids whose toggle write is currently in flight.
  //
  // Set, not bool, because the spec requires different taskIds to
  // be processed independently: task A's pending write MUST NOT
  // block task B's pending write. A single `bool _busy` would
  // over-block.
  final Set<String> _pendingTaskIds = <String>{};

  @override
  Future<TodayPracticeState> build() async {
    final InstallDateService service = ref.read(installDateServiceProvider);
    final CompletedTasksRepository repo =
        ref.read(completedTasksRepositoryProvider);
    final DateTime installDate = await service.getInstallDate();
    final DateTime now = ref.read(clockProvider)();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final Set<String> completedIds = await repo.getCompletedTaskIds(today);

    final int dayIndex = calculatePracticeDayIndex(
      installDate: installDate,
      today: now,
    );

    final BuiltInPracticePlan rawPlan = kBuiltInPracticePlan[dayIndex - 1];
    final List<PracticeTask> tasks = rawPlan.tasks
        .map(
          (PracticeTask t) => t.copyWith(
            status: completedIds.contains(t.id)
                ? PracticeTaskStatus.done
                : PracticeTaskStatus.todo,
          ),
        )
        .toList(growable: false);

    return TodayPracticeState(
      today: today,
      installDate: DateTime(
        installDate.year,
        installDate.month,
        installDate.day,
      ),
      dayIndex: dayIndex,
      plan: BuiltInPracticePlan(
        dayIndex: rawPlan.dayIndex,
        title: rawPlan.title,
        estimatedMinutes: rawPlan.estimatedMinutes,
        tasks: tasks,
      ),
      completedTaskIds: Set<String>.unmodifiable(completedIds),
    );
  }

  /// Toggles the completion state of [taskId] and persists the
  /// change.
  ///
  /// Returns:
  /// - `true` if the persistence write succeeded and the in-memory
  ///   state now reflects the new completion flag.
  /// - `false` if the persistence write failed (state is left
  ///   unchanged) OR if a write for [taskId] is already in flight
  ///   (concurrent click is dropped — UI should briefly disable
  ///   the checkbox).
  ///
  /// Unknown ids are ignored: a typo or a stale id from an older
  /// app version cannot silently inflate the completion count.
  Future<bool> toggleTaskCompleted(String taskId) async {
    final AsyncValue<TodayPracticeState> snapshot = state;
    final TodayPracticeState? snapshotValue = snapshot.value;
    if (snapshotValue == null) {
      // Still loading or in error — refuse the write so the UI
      // does not silently mutate a half-initialised state.
      return false;
    }
    final bool isKnownTask = snapshotValue.plan.tasks.any(
      (PracticeTask t) => t.id == taskId,
    );
    if (!isKnownTask) {
      return false;
    }
    if (_pendingTaskIds.contains(taskId)) {
      // Another write for this id is still pending. Drop the
      // duplicate click; the in-flight write will resolve the
      // UI state on its own.
      return false;
    }
    _pendingTaskIds.add(taskId);

    final bool wasCompleted = snapshotValue.completedTaskIds.contains(taskId);
    final bool nowCompleted = !wasCompleted;
    final CompletedTasksRepository repo =
        ref.read(completedTasksRepositoryProvider);
    try {
      if (nowCompleted) {
        await repo.markCompleted(
          date: snapshotValue.today,
          taskId: taskId,
          completedAt: DateTime.now().toUtc(),
        );
      } else {
        await repo.unmarkCompleted(
          date: snapshotValue.today,
          taskId: taskId,
        );
      }
    } catch (_) {
      // Persistence failed. Do not mutate state.
      _pendingTaskIds.remove(taskId);
      return false;
    }

    // Re-read state.value (NOT the snapshot captured at
    // function entry): another concurrent toggle on a DIFFERENT
    // task may have already updated the in-memory completion set
    // while we were awaiting the DB write. Overwriting
    // `state.value` with a set that only knows about *this* task
    // would clobber that progress.
    final TodayPracticeState? latest;
    try {
      latest = state.value;
    } on Object {
      // The provider was disposed between our await and here.
      // The ref is unmounted and `state` throws
      // `UnmountedRefException`. Nothing safe to write back to.
      _pendingTaskIds.remove(taskId);
      return false;
    }
    if (latest == null) {
      // The AsyncValue is in a loading/error state — refuse the
      // in-memory update.
      _pendingTaskIds.remove(taskId);
      return false;
    }
    final Set<String> next = Set<String>.from(latest.completedTaskIds);
    if (nowCompleted) {
      next.add(taskId);
    } else {
      next.remove(taskId);
    }
    final List<PracticeTask> nextTasks = latest.plan.tasks
        .map(
          (PracticeTask t) => t.copyWith(
            status: next.contains(t.id)
                ? PracticeTaskStatus.done
                : PracticeTaskStatus.todo,
          ),
        )
        .toList(growable: false);
    state = AsyncData<TodayPracticeState>(
      latest.copyWith(
        completedTaskIds: Set<String>.unmodifiable(next),
        plan: BuiltInPracticePlan(
          dayIndex: latest.plan.dayIndex,
          title: latest.plan.title,
          estimatedMinutes: latest.plan.estimatedMinutes,
          tasks: nextTasks,
        ),
      ),
    );
    _pendingTaskIds.remove(taskId);
    return true;
  }

  /// Test-only helper that clears the in-flight write guard. Do
  /// NOT call from production code — it exists only so tests can
  /// reset state between scenarios.
  @visibleForTesting
  void resetPendingForTesting() {
    _pendingTaskIds.clear();
  }
}

/// Provider for the home page controller.
///
/// `AsyncNotifierProvider` exposes an `AsyncValue<TodayPracticeState>`
/// — `AsyncLoading`, `AsyncData`, or `AsyncError` — so the UI
/// MUST `.when(...)` it.
final AsyncNotifierProvider<TodayPracticeController, TodayPracticeState>
    todayPracticeControllerProvider =
    AsyncNotifierProvider<TodayPracticeController, TodayPracticeState>(
  TodayPracticeController.new,
);
