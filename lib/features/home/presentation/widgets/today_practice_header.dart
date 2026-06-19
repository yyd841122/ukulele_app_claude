// Header for the "Today's Practice" section on the home page.
//
// T007 scope: shows today's local date, day index, theme, estimated total
// and completed task count. No animations.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:ukulele_app/features/home/application/today_practice_controller.dart';

class TodayPracticeHeader extends StatelessWidget {
  const TodayPracticeHeader({super.key, required this.state});

  final TodayPracticeState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateFormat formatter = DateFormat('yyyy年M月d日 EEEE', 'zh_CN');
    final String todayLabel = formatter.format(state.today);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '今日练习',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            todayLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _Pill(
                label: 'Day ${state.dayIndex}',
                background: theme.colorScheme.primary,
                foreground: theme.colorScheme.onPrimary,
              ),
              const SizedBox(width: 8),
              _Pill(
                label: state.plan.title,
                background: theme.colorScheme.secondary,
                foreground: theme.colorScheme.onSecondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '预计总时长：${state.totalEstimatedMinutes} 分钟',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '已完成：${state.completedTaskCount} / ${state.totalTaskCount}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'T007 临时实现：installDate 后续由 T013 本地设置持久化。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer.withValues(
                alpha: 0.7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}
