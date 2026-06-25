// Chord Practice page — the "switch the currently displayed chord"
// surface that T053 ships.
//
// T053 scope:
// - Displays the *currently selected* chord in large type at the top,
//   followed by the same chord diagram the library's detail page uses
//   (re-used via [ChordDiagram], no duplication).
// - Renders a 7-button switcher grid (C / Am / F / G / G7 / Dm / Em).
//   The currently selected button is visually highlighted; tapping
//   another button calls [ChordPracticeController.selectChord] and
//   the big display updates.
// - State is held in [chordPracticeControllerProvider]; the page is
//   `ConsumerWidget` and `watch`es it. No local widget state for
//   selection — the source of truth is the controller, so a future
//   "deep link to a chord" feature just sets the controller's id.
// - No audio, no recording, no persistence. T053 is a UI-only
//   minimum-viable loop; the practice page is the second of the
//   three Demo A deliverables (after the audible metronome).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/features/chord_library/application/chord_library_controller.dart';
import 'package:ukulele_app/features/chord_library/domain/chord.dart';
import 'package:ukulele_app/features/chord_library/domain/chord_difficulty.dart';
import 'package:ukulele_app/features/chord_library/presentation/widgets/chord_diagram.dart';
import 'package:ukulele_app/features/chord_practice/application/chord_practice_controller.dart';

class ChordPracticePage extends ConsumerWidget {
  const ChordPracticePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Chord> chords = ref.watch(chordLibraryProvider);
    final Chord? current = ref.watch(currentChordProvider);
    final String currentId = ref.watch(chordPracticeControllerProvider);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('和弦练习'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(
              '当前和弦',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            if (current == null) ...<Widget>[
              // Defensive empty state. Should not occur at runtime
              // because the controller defaults to the first shipped
              // chord, but the fallback keeps the page from crashing
              // if the library is ever drained.
              Text(
                '暂无可练习的和弦。',
                style: theme.textTheme.bodyMedium,
              ),
            ] else ...<Widget>[
              Center(
                child: Text(
                  current.name,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  current.displayName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: ChordDiagram(
                  fingering: current.primaryVoicing,
                  width: 240,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '难度：${current.difficulty.label}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              '切换和弦（${chords.length}）',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '点击下方按钮可立即切换当前练习的和弦，便于逐个对照指法。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _ChordSwitcher(
              chords: chords,
              currentId: currentId,
              onSelect: (String id) => ref
                  .read(chordPracticeControllerProvider.notifier)
                  .selectChord(id),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2-row × 4-column grid of chord switch buttons.
///
/// T053 keeps the grid fixed (7 buttons, last cell empty) so the
/// button geometry does not reflow when the selected chord changes.
/// The currently selected button uses a filled tonal background;
/// the rest use a low-emphasis outlined style.
class _ChordSwitcher extends StatelessWidget {
  const _ChordSwitcher({
    required this.chords,
    required this.currentId,
    required this.onSelect,
  });

  final List<Chord> chords;
  final String currentId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    // 4 columns × ceil(7 / 4) = 2 rows. We pad the last row with an
    // invisible spacer so the buttons stay aligned to the left edge.
    const int columns = 4;
    final int rowCount = (chords.length + columns - 1) ~/ columns;
    final List<Chord?> padded = <Chord?>[
      ...chords,
      ...List<Chord?>.filled(rowCount * columns - chords.length, null),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int r = 0; r < rowCount; r++)
          Padding(
            padding: EdgeInsets.only(bottom: r == rowCount - 1 ? 0 : 12),
            child: Row(
              children: <Widget>[
                for (int c = 0; c < columns; c++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: c == columns - 1 ? 0 : 12,
                      ),
                      child: padded[r * columns + c] == null
                          ? const SizedBox(height: 56)
                          : _ChordSwitchButton(
                              chord: padded[r * columns + c]!,
                              selected:
                                  padded[r * columns + c]!.id == currentId,
                              onTap: () => onSelect(
                                padded[r * columns + c]!.id,
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A single chord-switch button.
///
/// Uses [FilledButton.tonal] when selected (so the user can see the
/// current state at a glance) and [OutlinedButton] otherwise.
class _ChordSwitchButton extends StatelessWidget {
  const _ChordSwitchButton({
    required this.chord,
    required this.selected,
    required this.onTap,
  });

  final Chord chord;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Widget child = SizedBox(
      height: 56,
      child: selected
          ? FilledButton.tonal(
              onPressed: onTap,
              child: Text(
                chord.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : OutlinedButton(
              onPressed: onTap,
              child: Text(
                chord.name,
                style: const TextStyle(fontSize: 18),
              ),
            ),
    );
    return child;
  }
}