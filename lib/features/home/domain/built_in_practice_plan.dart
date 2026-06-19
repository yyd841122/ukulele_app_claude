// One day inside the built-in 7-day practice plan.
//
// T007 scope:
// - [BuiltInPracticePlan] is constructed in
//   `lib/core/constants/practice_plan_constants.dart`. We do NOT mutate
//   the constants at runtime; the controller keeps a list of *copies* of
//   each [PracticeTask] in its state.
// - [estimatedMinutes] is a hint for the header total; the controller
//   re-derives it as `sum(task.estimatedMinutes)` to make sure the
//   displayed total is always consistent with the tasks shown.

import 'package:flutter/foundation.dart';

import 'package:ukulele_app/features/home/domain/practice_task.dart';

@immutable
class BuiltInPracticePlan {
  const BuiltInPracticePlan({
    required this.dayIndex,
    required this.title,
    required this.estimatedMinutes,
    required this.tasks,
  });

  /// 1-based day number in the 7-day cycle. Always in the range 1-7.
  final int dayIndex;

  /// Short theme name, e.g. "认识琴弦".
  final String title;

  /// Pre-baked total estimate (minutes). The controller re-derives the
  /// displayed total from the per-task estimates.
  final int estimatedMinutes;

  /// Ordered list of practice tasks for this day. UI renders in order.
  final List<PracticeTask> tasks;
}
