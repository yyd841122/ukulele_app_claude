// Single practice task card.
//
// T013.3_FIX_PENDING_RESULT_AND_INSTALL_DATE_BOUNDARY changes:
// - The card now takes an `isPending` flag. When `true`, the
//   Checkbox is rendered as disabled (its `onChanged` is set to
//   `null`) so a user cannot fire a second click while the
//   underlying persistence write is still in flight.
// - `onToggleCompleted` is still a `ValueChanged<bool?>` for
//   callers that don't care about the pending state.
//
// T007 scope (unchanged):
// - Renders title, description, estimated minutes, completion
//   state and a tappable surface that calls back to the parent.
// - The card does NOT navigate on its own; the parent owns the
//   [onTap] -> `context.push(routePath)` glue so the controller
//   can stay free of BuildContext.

import 'package:flutter/material.dart';

import 'package:ukulele_app/features/home/domain/practice_task.dart';
import 'package:ukulele_app/features/home/domain/practice_task_icon.dart';
import 'package:ukulele_app/features/home/domain/practice_task_status.dart';

class TodayPracticeTaskCard extends StatelessWidget {
  const TodayPracticeTaskCard({
    super.key,
    required this.task,
    required this.onTap,
    required this.onToggleCompleted,
    this.isPending = false,
  });

  final PracticeTask task;
  final VoidCallback onTap;
  final ValueChanged<bool?> onToggleCompleted;

  /// When `true` the Checkbox is rendered as disabled and the
  /// card suppresses tap-to-toggle. Defaults to `false` for
  /// callers that don't track pending writes (e.g. preview).
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDone = task.status == PracticeTaskStatus.done;

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                _iconFor(task.iconName),
                color: isDone
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      task.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        color: isDone
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '预计 ${task.estimatedMinutes} 分钟',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Checkbox(
                value: isDone,
                // Setting onChanged to null renders the Checkbox
                // as disabled. That is exactly the UX we want
                // while a toggle write is in flight.
                onChanged: isPending ? null : onToggleCompleted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(PracticeTaskIcon name) {
    switch (name) {
      case PracticeTaskIcon.tuner:
        return Icons.tune;
      case PracticeTaskIcon.singleNote:
        return Icons.music_note;
      case PracticeTaskIcon.chord:
        return Icons.library_music;
      case PracticeTaskIcon.metronome:
        return Icons.timer;
      case PracticeTaskIcon.recording:
        return Icons.mic;
      case PracticeTaskIcon.selfAssessment:
        return Icons.fact_check_outlined;
    }
  }
}
