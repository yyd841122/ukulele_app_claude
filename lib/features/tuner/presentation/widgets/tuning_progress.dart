// Reusable progress widget for the tuner guide page.
//
// T011 scope:
// - Pure presentation: takes a [confirmedCount] and [totalCount]
//   and renders a numeric progress label plus a [LinearProgressIndicator]
//   so the user can see at a glance how many strings they have
//   marked as confirmed.
// - 0/4 reads as an empty bar; 4/4 reads as a full bar.

import 'package:flutter/material.dart';

/// Linear progress bar + numeric label for the tuner page.
class TuningProgress extends StatelessWidget {
  const TuningProgress({
    super.key,
    required this.confirmedCount,
    required this.totalCount,
  });

  final int confirmedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int safeTotal = totalCount <= 0 ? 1 : totalCount;
    final double fraction =
        (confirmedCount / safeTotal).clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              '调音进度',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '已确认 $confirmedCount / $totalCount',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 8,
            backgroundColor:
                theme.colorScheme.surfaceContainerHighest,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}