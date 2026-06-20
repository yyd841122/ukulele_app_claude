// Beats-per-bar selector.
//
// T010 scope:
// - Renders the allowed beats-per-bar values (2 / 3 / 4 / 6) as a
//   [SegmentedButton].
// - The widget is dumb: it just calls back when the user picks a
//   new value.

import 'package:flutter/material.dart';

import 'package:ukulele_app/features/metronome/domain/metronome_settings.dart';

class BeatsPerBarSelector extends StatelessWidget {
  const BeatsPerBarSelector({
    super.key,
    required this.beatsPerBar,
    required this.onChanged,
  });

  final int beatsPerBar;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      key: const ValueKey<String>('metronome-beats-per-bar-selector'),
      segments: <ButtonSegment<int>>[
        for (final int beats in MetronomeSettings.allowedBeatsPerBar)
          ButtonSegment<int>(
            value: beats,
            label: Text('$beats'),
          ),
      ],
      selected: <int>{beatsPerBar},
      showSelectedIcon: false,
      onSelectionChanged: (Set<int> selection) {
        if (selection.isEmpty) {
          return;
        }
        onChanged(selection.first);
      },
    );
  }
}
