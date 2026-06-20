// Compact chord summary card used on the library list page.
//
// T008 scope:
// - Renders the chord name, difficulty chip, a one-line description
//   and a small diagram preview.
// - Tapping the card calls [onTap] so the parent (the list page) owns
//   the navigation logic — the card stays free of `BuildContext` and
//   of `go_router`.

import 'package:flutter/material.dart';

import 'package:ukulele_app/features/chord_library/domain/chord.dart';
import 'package:ukulele_app/features/chord_library/domain/chord_difficulty.dart';
import 'package:ukulele_app/features/chord_library/presentation/widgets/chord_diagram.dart';

class ChordCard extends StatelessWidget {
  const ChordCard({
    super.key,
    required this.chord,
    required this.onTap,
  });

  final Chord chord;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 88,
                height: 96,
                child: ChordDiagram(
                  fingering: chord.primaryVoicing,
                  width: 88,
                  showLabels: false,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            chord.displayName,
                            style: theme.textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _DifficultyChip(difficulty: chord.difficulty),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      chord.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({required this.difficulty});

  final ChordDifficulty difficulty;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        difficulty.label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
