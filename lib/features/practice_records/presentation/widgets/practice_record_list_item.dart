// Single-row widget for the practice records list (T013.4B).
//
// Scope:
// - Renders one [PracticeRecord] as a Material list tile.
// - All display strings are user-readable Chinese; the raw
//   enum-case `.name` is NEVER shown to the user.
// - `audioFilePath` is NEVER rendered.
// - Long content uses [TextOverflow.ellipsis] and a constrained
//   line count so the row never overflows on small screens.
// - The widget is purely presentational: it does NOT touch the
//   repository, the database, the Drift row class, or routing.
//   The parent ([PracticeRecordsPage]) owns `onTap` → navigation.

import 'package:flutter/material.dart';

import 'package:ukulele_app/features/practice_records/domain/practice_record.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_type.dart';
import 'package:ukulele_app/features/practice_records/domain/self_assessment.dart';

/// Single-row widget for the practice records list.
///
/// Pure presentation — parent owns tap-to-navigate and the
/// surrounding ListView. `record.id` is used as the ListView key
/// (the parent owns the [Key] — see [PracticeRecordsPage]).
class PracticeRecordListItem extends StatelessWidget {
  const PracticeRecordListItem({
    super.key,
    required this.record,
    required this.onTap,
  });

  final PracticeRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Header row: date + Day N (left), completion chip (right).
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _formatHeader(record),
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _CompletionChip(isCompleted: record.isCompleted),
              ],
            ),
            const SizedBox(height: 4),
            // Type (Chinese) + duration (mm:ss).
            Text(
              '${_practiceTypeLabel(record.primaryPracticeType)} · '
              '${_formatDuration(record.durationSeconds)}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            // Content — capped at 3 lines + ellipsis so an
            // unusually long practiceContent never overflows.
            Text(
              record.practiceContent,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            // Self-assessment is rendered only when present.
            if (record.selfAssessment != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                '自评：${_selfAssessmentLabel(record.selfAssessment!)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// `2026-06-20 · Day 2` style header.
  String _formatHeader(PracticeRecord r) {
    final String date = _formatDate(r.practiceDate);
    return '$date · Day ${r.dayIndex}';
  }

  String _formatDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  /// `mm:ss` formatter. Zero-pads both fields.
  String _formatDuration(int seconds) {
    final int safe = seconds < 0 ? 0 : seconds;
    final String mm = (safe ~/ 60).toString().padLeft(2, '0');
    final String ss = (safe % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}

/// Small chip showing the completion state.
///
/// Rendered on the right side of the item header so a glance at
/// the list reveals progress.
class _CompletionChip extends StatelessWidget {
  const _CompletionChip({required this.isCompleted});

  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color background =
        isCompleted ? theme.colorScheme.primaryContainer : theme.disabledColor;
    final Color foreground = isCompleted
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isCompleted ? '已完成' : '未完成',
        style: theme.textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}

/// User-readable Chinese label for every [PracticeType].
///
/// The set is exhaustive on purpose: a future enum case will
/// fail to compile against this switch, surfacing the missing
/// label as a static error rather than silently rendering
/// `practiceType.name` to the user.
@visibleForTesting
String practiceTypeLabel(PracticeType type) => _practiceTypeLabel(type);

String _practiceTypeLabel(PracticeType type) {
  switch (type) {
    case PracticeType.singleNote:
      return '单音练习';
    case PracticeType.chord:
      return '和弦练习';
    case PracticeType.metronome:
      return '节拍器练习';
    case PracticeType.recording:
      return '录音练习';
    case PracticeType.mixed:
      return '混合练习';
  }
}

/// User-readable Chinese label for every [SelfAssessment].
///
/// Exhaustive on purpose; same rationale as
/// [practiceTypeLabel].
@visibleForTesting
String selfAssessmentLabel(SelfAssessment value) => _selfAssessmentLabel(value);

String _selfAssessmentLabel(SelfAssessment value) {
  switch (value) {
    case SelfAssessment.good:
      return '好';
    case SelfAssessment.neutral:
      return '一般';
    case SelfAssessment.needsImprovement:
      return '需改进';
  }
}
