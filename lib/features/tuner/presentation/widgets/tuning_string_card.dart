// Reusable card widget for a single tuning string entry.
//
// T011 scope:
// - Pure presentation: takes a [TuningString], a confirmed flag,
//   and an [onToggleConfirmed] callback. Renders the string
//   name, beginner tip, common-mistake warning, and a
//   "我已调好" toggle button.
// - No business logic. The controller decides whether the
//   unknown-string case is a no-op; this widget always renders
//   whatever it's given.

import 'package:flutter/material.dart';

import 'package:ukulele_app/features/tuner/domain/tuning_string.dart';

/// Card showing one ukulele string's tuning instruction.
class TuningStringCard extends StatelessWidget {
  const TuningStringCard({
    super.key,
    required this.tuningString,
    required this.isConfirmed,
    required this.onToggleConfirmed,
  });

  final TuningString tuningString;
  final bool isConfirmed;
  final VoidCallback onToggleConfirmed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      key: ValueKey<String>('tuning-card-${tuningString.stringNumber}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Header: string display name + (弦名) badge.
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tuningString.displayName,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '音名 ${tuningString.stringName}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tuningString.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _TipBlock(
              icon: Icons.tips_and_updates_outlined,
              title: '调音小贴士',
              body: tuningString.beginnerTip,
              tint: theme.colorScheme.tertiaryContainer,
              onTint: theme.colorScheme.onTertiaryContainer,
            ),
            const SizedBox(height: 8),
            _TipBlock(
              icon: Icons.warning_amber_outlined,
              title: '常见错误',
              body: tuningString.commonMistake,
              tint: theme.colorScheme.errorContainer,
              onTint: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                key: ValueKey<String>(
                  'tuning-toggle-${tuningString.stringNumber}',
                ),
                onPressed: onToggleConfirmed,
                icon: Icon(
                  isConfirmed
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                ),
                label: Text(isConfirmed ? '已调好（取消）' : '我已调好'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small labeled block used twice inside the card (tip + warning).
class _TipBlock extends StatelessWidget {
  const _TipBlock({
    required this.icon,
    required this.title,
    required this.body,
    required this.tint,
    required this.onTint,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color tint;
  final Color onTint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: onTint),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    color: onTint,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(color: onTint, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}