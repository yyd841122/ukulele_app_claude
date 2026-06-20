// Riverpod controller for the home / "today's practice" page.
//
// T013.3_FIX_PENDING_RESULT_AND_INSTALL_DATE_BOUNDARY scope:
// - `toggleTaskCompleted` now returns [ToggleTaskResult] (not
//   `bool`). The UI can route SnackBars by intent:
//     * `success` — write committed; no UI message.
//     * `ignored` — click was legitimately dropped (unknown id,
//        in-flight for this id, provider unmounted, or the local
//        day rolled over mid-write); no UI message.
//     * `failure` — Repository write threw; UI shows a retry
//        SnackBar.
// - `TodayPracticeState.pendingTaskIds` exposes the in-flight
//   set to the widget tree. The Checkbox on each task card
//   reads `isPending` and renders as disabled when its id is in
//   the set, so the user cannot fire a second click while the
//   first is still in flight.
// - `completedAt` is sourced from
//   `ref.read(clockProvider)().toUtc()`. No direct `DateTime.now()`
//   calls remain — tests can pin the stamp by overriding the
//   clock.
// - `state.installDate` is always local-midnight. The
//   `InstallDateService` returns a UTC instant; we project to
//   local time first, then strip to local-midnight, so the
//   `calculatePracticeDayIndex` call sees consistent local dates
//   on both sides.
// - Cross-day safety: after the await, if the local day rolled
//   over (the clock advanced past midnight while the write was
//   in flight), we DO NOT merge yesterday's result into today's
//   state. Result is `ignored`.
// - Lifecycle: no `catch (Object)` swallow. After every await
//   we check `ref.mounted`; if the Provider was disposed mid-
//   write we leave the state alone and return `ignored`.
//
// T013.3 baseline scope (still in effect):
// - Converted from a synchronous `Notifier<TodayPracticeState>`
//   to `AsyncNotifier<TodayPracticeState>`. The state is built
//   by awaiting two persistence reads:
//     1. The persisted install date (Drift /
//        `InstallDateService`).
//     2. The completed-task set for today (Drift /
//        `CompletedTasksRepository`).
// - The provider stays hand-written (no `@riverpod` codegen) per
//   the project convention.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/core/constants/practice_plan_constants.dart';
import 'package:ukulele_app/core/utils/practice_day_calculator.dart';
import 'package:ukulele_app/features/home/data/completed_tasks_repository.dart';
import 'package:ukulele_app/features/home/data/completed_tasks_repository_provider.dart';
import 'package:ukulele_app/features/home/domain/built_in_practice_plan.dart';
import 'package:ukulele_app/features/home/domain/practice_task.dart';
import 'package:ukulele_app/features/home/domain/practice_task_status.dart';
import 'package:ukulele_app/shared/repositories/user_settings_repository_provider.dart';
import 'package:ukulele_app/shared/services/drift_install_date_service.dart';
import 'package:ukulele_app/shared/services/install_date_service.dart';

/// Provider for the [InstallDateService] used by the home controller.
///
/// T013.3 default is the Drift-backed implementation, wired to the
/// shared `userSettingsRepositoryProvider` (which itself wires the
/// `appDatabaseProvider`). Tests can override this with
/// [InMemoryInstallDateService] (or any other implementation) to
/// pin install date / isolate from the DB.
final Provider<InstallDateService> installDateServiceProvider =
    Provider<InstallDateService>((Ref ref) {
  return DriftInstallDateService(
    repository: ref.watch(userSettingsRepositoryProvider),
  );
});

/// Clock function for the controller. Defaults to [DateTime.now].
///
/// Overriding this provider is the recommended way for tests to
/// pin "today" to a specific instant without monkey-patching
/// globals.
final Provider<DateTime Function()> clockProvider =
    Provider<DateTime Function()>((Ref ref) => DateTime.now);

/// Outcome of a single call to [TodayPracticeController.toggleTaskCompleted].
///
/// The enum is the single source of truth for "what should the UI
/// do next" — it replaces the previous `bool` return, which could
/// not distinguish a successful toggle from a legitimately dropped
/// click.
enum ToggleTaskResult {
  /// The Repository write committed and the in-memory state now
  /// reflects the new completion flag.
  success,

  /// The click was dropped on purpose. Reasons include:
  /// - The controller was still loading / in an error state.
  /// - The taskId is not part of today's plan.
  /// - Another write for the same taskId was already in flight.
  /// - The Provider was disposed between the start of the
  ///   call and its completion.
  /// - The local day rolled over while the write was in flight
  ///   (we will not merge yesterday's toggle into today's state).
  ///
  /// `ignored` is NOT a failure. The UI MUST NOT show a
  /// "保存失败" SnackBar in response to this outcome.
  ignored,

  /// The Repository write threw. The in-memory state is
  /// unchanged. The UI MAY show a "保存失败，请重试" SnackBar.
  failure,
}

/// Immutable state for the home page.
@immutable
class TodayPracticeState {
  const TodayPracticeState({
    required this.today,
    required this.installDate,
    required this.dayIndex,
    required this.plan,
    required this.completedTaskIds,
    this.pendingTaskIds = const <String>{},
  });

  /// The "today" used to compute [dayIndex] (already normalised
  /// to local-midnight by the controller).
  final DateTime today;

  /// The install date used to compute [dayIndex]. Always
  /// normalised to local-midnight by the controller — the
  /// underlying [InstallDateService] returns a UTC instant, the
  /// controller projects to local and strips the time-of-day.
  final DateTime installDate;

  /// 1-based day in the 7-day cycle. Always in 1..7.
  final int dayIndex;

  /// The plan for [dayIndex]. Each [PracticeTask] in the list
  /// reflects the current completion state.
  final BuiltInPracticePlan plan;

  /// Set of task ids that are currently marked done.
  final Set<String> completedTaskIds;

  /// Set of task ids whose toggle write is currently in flight.
  ///
  /// The widget tree disables the Checkbox for any task whose id
  /// is in this set, so a user cannot fire a second click while
  /// the first is still saving.
  final Set<String> pendingTaskIds;

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

  /// Returns `true` iff a toggle write for the given id is
  /// currently in flight. The UI uses this to disable the
  /// Checkbox.
  bool isTaskPending(String taskId) => pendingTaskIds.contains(taskId);

  TodayPracticeState copyWith({
    DateTime? today,
    DateTime? installDate,
    int? dayIndex,
    BuiltInPracticePlan? plan,
    Set<String>? completedTaskIds,
    Set<String>? pendingTaskIds,
  }) {
    return TodayPracticeState(
      today: today ?? this.today,
      installDate: installDate ?? this.installDate,
      dayIndex: dayIndex ?? this.dayIndex,
      plan: plan ?? this.plan,
      completedTaskIds: completedTaskIds ?? this.completedTaskIds,
      pendingTaskIds: pendingTaskIds ?? this.pendingTaskIds,
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
  @override
  Future<TodayPracticeState> build() async {
    final InstallDateService service = ref.read(installDateServiceProvider);
    final CompletedTasksRepository repo =
        ref.read(completedTasksRepositoryProvider);
    final DateTime installInstant = await service.getInstallDate();
    final DateTime now = ref.read(clockProvider)();
    final DateTime today = _localMidnight(now);
    final Set<String> completedIds = await repo.getCompletedTaskIds(today);

    final int dayIndex = calculatePracticeDayIndex(
      installDate: installInstant,
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
      // The service returns a UTC instant. Project to local time
      // BEFORE stripping the time-of-day, otherwise an install at
      // 23:30 local can leak into the previous local day (the
      // calculator would see 15:30 UTC of the day before in
      // CST-equivalent offsets).
      installDate: _localMidnight(installInstant.toLocal()),
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
  /// Returns a [ToggleTaskResult] describing the outcome — see
  /// that type for the exact mapping from cause to result.
  ///
  /// No direct `DateTime.now()` calls: the `completedAt` stamp
  /// is sourced from `ref.read(clockProvider)`. The Provider
  /// lifecycle is guarded with `ref.mounted` after every await.
  Future<ToggleTaskResult> toggleTaskCompleted(String taskId) async {
    final TodayPracticeState? snapshotValue = state.value;
    if (snapshotValue == null) {
      // Still loading or in error — refuse the write so the UI
      // does not silently mutate a half-initialised state.
      return ToggleTaskResult.ignored;
    }
    final bool isKnownTask = snapshotValue.plan.tasks.any(
      (PracticeTask t) => t.id == taskId,
    );
    if (!isKnownTask) {
      return ToggleTaskResult.ignored;
    }
    if (snapshotValue.pendingTaskIds.contains(taskId)) {
      // Another write for this id is still pending. Drop the
      // duplicate click; the in-flight write will resolve the
      // UI state on its own.
      return ToggleTaskResult.ignored;
    }

    // Mark the id pending BEFORE the await so the UI can
    // immediately disable the Checkbox. Reading the LATEST state
    // (not the snapshot) ensures a concurrent toggle on a
    // DIFFERENT id is preserved.
    _publishPendingAdd(taskId);

    final bool wasCompleted = snapshotValue.completedTaskIds.contains(taskId);
    final bool nowCompleted = !wasCompleted;
    final CompletedTasksRepository repo =
        ref.read(completedTasksRepositoryProvider);

    try {
      if (nowCompleted) {
        await repo.markCompleted(
          date: snapshotValue.today,
          taskId: taskId,
          completedAt: ref.read(clockProvider)().toUtc(),
        );
      } else {
        await repo.unmarkCompleted(
          date: snapshotValue.today,
          taskId: taskId,
        );
      }
    } catch (_) {
      // Persistence failed. Clear the pending flag, leave the
      // completion set alone, surface a retry cue.
      if (ref.mounted) {
        _publishPendingRemove(taskId);
      }
      return ToggleTaskResult.failure;
    }

    // Re-read state.value (NOT the snapshot captured at function
    // entry): another concurrent toggle on a DIFFERENT task may
    // have already updated the in-memory completion set while we
    // were awaiting the DB write. Overwriting `state.value` with
    // a set that only knows about *this* task would clobber that
    // progress.
    if (!ref.mounted) {
      // Provider was disposed between our await and here.
      return ToggleTaskResult.ignored;
    }
    final TodayPracticeState? latest = state.value;
    if (latest == null) {
      // The AsyncValue is in a loading/error state — refuse the
      // in-memory update.
      _publishPendingRemove(taskId);
      return ToggleTaskResult.ignored;
    }
    // Cross-day guard: if the local "today" advanced while the
    // write was in flight, do NOT merge yesterday's toggle into
    // today's state. The user is now looking at a different day
    // and the persisted row keyed by yesterday's `localDate` is
    // semantically the right place for this write — we just
    // should not touch today's in-memory view.
    if (latest.today != snapshotValue.today) {
      _publishPendingRemove(taskId);
      return ToggleTaskResult.ignored;
    }

    final Set<String> nextCompleted = Set<String>.from(latest.completedTaskIds);
    if (nowCompleted) {
      nextCompleted.add(taskId);
    } else {
      nextCompleted.remove(taskId);
    }
    final Set<String> nextPending = Set<String>.from(latest.pendingTaskIds)
      ..remove(taskId);
    final List<PracticeTask> nextTasks = latest.plan.tasks
        .map(
          (PracticeTask t) => t.copyWith(
            status: nextCompleted.contains(t.id)
                ? PracticeTaskStatus.done
                : PracticeTaskStatus.todo,
          ),
        )
        .toList(growable: false);
    state = AsyncData<TodayPracticeState>(
      latest.copyWith(
        completedTaskIds: Set<String>.unmodifiable(nextCompleted),
        pendingTaskIds: Set<String>.unmodifiable(nextPending),
        plan: BuiltInPracticePlan(
          dayIndex: latest.plan.dayIndex,
          title: latest.plan.title,
          estimatedMinutes: latest.plan.estimatedMinutes,
          tasks: nextTasks,
        ),
      ),
    );
    return ToggleTaskResult.success;
  }

  /// Test-only helper that clears the in-flight write guard. Do
  /// NOT call from production code — it exists only so tests can
  /// reset state between scenarios.
  @visibleForTesting
  void resetPendingForTesting() {
    if (state.value == null) return;
    state = AsyncData<TodayPracticeState>(
      state.value!.copyWith(pendingTaskIds: const <String>{}),
    );
  }

  // --- Internal helpers ---

  /// Returns the local-midnight representation of [d]. Strips the
  /// time-of-day component to keep `today` consistent with what
  /// the calculator expects.
  static DateTime _localMidnight(DateTime d) {
    return DateTime(d.year, d.month, d.day);
  }

  /// Adds [taskId] to `pendingTaskIds` and publishes the new
  /// state. The current value must be non-null when this is
  /// called.
  void _publishPendingAdd(String taskId) {
    final TodayPracticeState? current = state.value;
    if (current == null) return;
    final Set<String> next = Set<String>.from(current.pendingTaskIds)
      ..add(taskId);
    state = AsyncData<TodayPracticeState>(
      current.copyWith(pendingTaskIds: Set<String>.unmodifiable(next)),
    );
  }

  /// Removes [taskId] from `pendingTaskIds` and publishes the new
  /// state. The current value must be non-null when this is
  /// called.
  void _publishPendingRemove(String taskId) {
    final TodayPracticeState? current = state.value;
    if (current == null) return;
    if (!current.pendingTaskIds.contains(taskId)) return;
    final Set<String> next = Set<String>.from(current.pendingTaskIds)
      ..remove(taskId);
    state = AsyncData<TodayPracticeState>(
      current.copyWith(pendingTaskIds: Set<String>.unmodifiable(next)),
    );
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
