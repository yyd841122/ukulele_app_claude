// Riverpod controller for the home / "today's practice" page.
//
// T007 scope:
// - Hand-written [Notifier] (no `@riverpod` codegen) per the task brief
//   to keep this task self-contained.
// - The controller derives the day's [BuiltInPracticePlan] from the
//   install date (via [InstallDateService]) and the current local date,
//   and keeps a per-task "completed" set in memory.
// - No Drift, no SharedPreferences, no network, no permissions — see
//   task brief §10.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/core/constants/practice_plan_constants.dart';
import 'package:ukulele_app/core/utils/practice_day_calculator.dart';
import 'package:ukulele_app/features/home/domain/built_in_practice_plan.dart';
import 'package:ukulele_app/features/home/domain/practice_task.dart';
import 'package:ukulele_app/features/home/domain/practice_task_status.dart';
import 'package:ukulele_app/shared/services/install_date_service.dart';

/// Provider for the [InstallDateService] used by the home controller.
///
/// T007 ships only an in-memory implementation. T013 is expected to
/// override this with a Drift-backed implementation.
final Provider<InstallDateService> installDateServiceProvider =
    Provider<InstallDateService>((Ref ref) {
  return InMemoryInstallDateService();
});

/// Clock function for the controller. Defaults to [DateTime.now].
///
/// Overriding this provider is the recommended way for tests to pin
/// "today" to a specific instant without monkey-patching globals.
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

  /// The "today" used to compute [dayIndex] (already normalised to
  /// local-midnight by the calculator).
  final DateTime today;

  /// The install date used to compute [dayIndex] (already normalised to
  /// local-midnight by the calculator).
  final DateTime installDate;

  /// 1-based day in the 7-day cycle. Always in 1..7.
  final int dayIndex;

  /// The plan for [dayIndex]. Each [PracticeTask] in the list reflects
  /// the current completion state.
  final BuiltInPracticePlan plan;

  /// Set of task ids that are currently marked done.
  final Set<String> completedTaskIds;

  /// Number of tasks marked done.
  int get completedTaskCount => completedTaskIds.length;

  /// Total number of tasks for the day.
  int get totalTaskCount => plan.tasks.length;

  /// Total estimated minutes, derived from the current task list to
  /// guarantee consistency with what the UI renders.
  int get totalEstimatedMinutes => plan.tasks.fold<int>(
        0,
        (int sum, PracticeTask task) => sum + task.estimatedMinutes,
      );

  /// Returns `true` iff the task with the given id is marked done.
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
class TodayPracticeController extends Notifier<TodayPracticeState> {
  @override
  TodayPracticeState build() {
    return _rebuildState();
  }

  /// Flips the completion state of [taskId] (idempotent toggle).
  ///
  /// Unknown ids are ignored: if [taskId] is not part of the current
  /// plan, the state is left untouched. This is a defensive choice so a
  /// typo in a built-in constant (or a stale id from an older app
  /// version) cannot silently inflate [completedTaskCount] or mutate
  /// the task list.
  void toggleTaskCompleted(String taskId) {
    final bool isKnownTask = state.plan.tasks.any(
      (PracticeTask t) => t.id == taskId,
    );
    if (!isKnownTask) {
      return;
    }

    final Set<String> next = Set<String>.from(state.completedTaskIds);
    if (next.contains(taskId)) {
      next.remove(taskId);
    } else {
      next.add(taskId);
    }

    final List<PracticeTask> nextTasks = state.plan.tasks
        .map(
          (PracticeTask t) => t.copyWith(
            status: next.contains(t.id)
                ? PracticeTaskStatus.done
                : PracticeTaskStatus.todo,
          ),
        )
        .toList(growable: false);

    state = state.copyWith(
      completedTaskIds: next,
      plan: BuiltInPracticePlan(
        dayIndex: state.plan.dayIndex,
        title: state.plan.title,
        estimatedMinutes: state.plan.estimatedMinutes,
        tasks: nextTasks,
      ),
    );
  }

  /// Recomputes the state from the install date + current clock.
  ///
  /// Intended for test resets. Production code does not need to call
  /// this — the state is rebuilt once on [build] and then mutated in
  /// place via [toggleTaskCompleted].
  void resetForTesting() {
    state = _rebuildState();
  }

  TodayPracticeState _rebuildState() {
    final InstallDateService service = ref.read(installDateServiceProvider);
    final DateTime installDate = service.getInstallDate();
    final DateTime today = ref.read(clockProvider)();
    final int dayIndex = calculatePracticeDayIndex(
      installDate: installDate,
      today: today,
    );

    final BuiltInPracticePlan rawPlan = kBuiltInPracticePlan[dayIndex - 1];
    // Re-emit the plan with every task marked todo. Completion is held
    // in [completedTaskIds] only, so a re-build always starts from a
    // clean task list.
    final List<PracticeTask> tasks = rawPlan.tasks
        .map(
          (PracticeTask t) => t.copyWith(status: PracticeTaskStatus.todo),
        )
        .toList(growable: false);

    return TodayPracticeState(
      today: DateTime(today.year, today.month, today.day),
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
      completedTaskIds: const <String>{},
    );
  }
}

/// Provider for the home page controller.
final NotifierProvider<TodayPracticeController, TodayPracticeState>
    todayPracticeControllerProvider =
    NotifierProvider<TodayPracticeController, TodayPracticeState>(
  TodayPracticeController.new,
);
