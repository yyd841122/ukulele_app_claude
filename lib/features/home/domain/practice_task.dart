// A single practice task inside a day's plan.
//
// T007 scope:
// - Immutable, no freezed, no JSON — these are built-in constants read by
//   the UI; the only mutable part is the [status] field, which lives on
//   the controller's state copy.
// - [routePath] must match a path in `lib/app/router.dart`. T007 only
//   navigates; the destination pages are still T006 placeholders.

import 'package:flutter/foundation.dart';

import 'package:ukulele_app/features/home/domain/practice_task_icon.dart';
import 'package:ukulele_app/features/home/domain/practice_task_status.dart';

@immutable
class PracticeTask {
  const PracticeTask({
    required this.id,
    required this.title,
    required this.description,
    required this.estimatedMinutes,
    required this.routePath,
    required this.iconName,
    required this.status,
  });

  /// Stable identifier, e.g. `"day1_tuner"`. Used by the controller to
  /// toggle completion state.
  final String id;

  /// Short title shown on the task card.
  final String title;

  /// One-sentence description of what the user should do.
  final String description;

  /// Estimated time in minutes (>= 1). Used to compute the day's total
  /// estimated time on the header.
  final int estimatedMinutes;

  /// go_router path. T007 only calls `context.push(routePath)`; the
  /// destination pages are T006 placeholders.
  final String routePath;

  /// Icon hint for the UI.
  final PracticeTaskIcon iconName;

  /// Current status. T007 only flips this between [PracticeTaskStatus.todo]
  /// and [PracticeTaskStatus.done] — see `TodayPracticeController`.
  final PracticeTaskStatus status;

  /// Returns a copy of this task with [status] replaced.
  PracticeTask copyWith({PracticeTaskStatus? status}) {
    return PracticeTask(
      id: id,
      title: title,
      description: description,
      estimatedMinutes: estimatedMinutes,
      routePath: routePath,
      iconName: iconName,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PracticeTask &&
          other.id == id &&
          other.title == title &&
          other.description == description &&
          other.estimatedMinutes == estimatedMinutes &&
          other.routePath == routePath &&
          other.iconName == iconName &&
          other.status == status);

  @override
  int get hashCode => Object.hash(
        id,
        title,
        description,
        estimatedMinutes,
        routePath,
        iconName,
        status,
      );
}
