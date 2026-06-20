// Single practice task card.
//
// T007 scope:
// - Renders title, description, estimated minutes, completion state and
//   a tappable surface that calls back to the parent.
// - The card does NOT navigate on its own; the parent owns the
//   [onTap] -> `context.push(routePath)` glue so the controller can
//   stay free of BuildContext.

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
  });

  final PracticeTask task;
  final VoidCallback onTap;
  final ValueChanged<bool?> onToggleCompleted;

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
                onChanged: onToggleCompleted,
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
