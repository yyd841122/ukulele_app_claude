// Reusable info card for a single [SingleNote].
//
// T009 scope:
// - Pure presentation: takes a [SingleNote] and renders the
//   beginner-friendly breakdown (string name, fret, finger, open-
//   string callout, tips). No business logic, no `BuildContext`
//   side effects.
// - Used by the practice page below the diagram.

import 'package:flutter/material.dart';

import 'package:ukulele_app/features/single_note_practice/domain/single_note.dart';

/// Card showing the breakdown of a single ukulele note.
class SingleNoteInfoCard extends StatelessWidget {
  const SingleNoteInfoCard({super.key, required this.note});

  final SingleNote note;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '位置信息',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.music_note,
              label: '所在弦',
              value: '${note.stringName} 弦',
            ),
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.tag,
              label: '第几品',
              value: note.isOpen ? '空弦，不需要按品' : '第 ${note.fret} 品',
            ),
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.back_hand,
              label: '用哪根手指',
              value: note.isOpen
                  ? '空弦，不需要用手指'
                  : '第 ${note.finger} 根手指（${_fingerName(note.finger)}）',
            ),
            if (note.tips.isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                '练习提示',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              for (final String tip in note.tips)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('• '),
                      Expanded(
                        child: Text(
                          tip,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  static String _fingerName(int? finger) {
    switch (finger) {
      case 1:
        return '食指';
      case 2:
        return '中指';
      case 3:
        return '无名指';
      case 4:
        return '小指';
      default:
        return '—';
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
