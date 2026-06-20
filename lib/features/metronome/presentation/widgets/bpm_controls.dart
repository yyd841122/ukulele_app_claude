// BPM +/- buttons and preset shortcuts.
//
// T010 scope:
// - The "fine" +/- buttons step by 1 BPM.
// - The preset row exposes 60 / 80 / 100 / 120 — every preset is a
//   no-op when it equals the current BPM (button still visible but
//   inert so the layout doesn't shift).
// - The widget is dumb: it just calls callbacks. The page wires
//   them to the controller.

import 'package:flutter/material.dart';

import 'package:ukulele_app/features/metronome/application/metronome_controller.dart';

class BpmControls extends StatelessWidget {
  const BpmControls({
    super.key,
    required this.state,
    required this.onDecrease,
    required this.onIncrease,
    required this.onPickPreset,
  });

  final MetronomeState state;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final ValueChanged<int> onPickPreset;

  /// Preset BPM values exposed in the UI.
  static const List<int> presets = <int>[60, 80, 100, 120];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Fine adjust row.
        Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey<String>('metronome-bpm-decrease'),
                onPressed: onDecrease,
                icon: const Icon(Icons.remove),
                label: const Text('BPM -'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey<String>('metronome-bpm-increase'),
                onPressed: onIncrease,
                icon: const Icon(Icons.add),
                label: const Text('BPM +'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Preset chips.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: <Widget>[
            for (final int preset in presets)
              ChoiceChip(
                key: ValueKey<String>('metronome-bpm-preset-$preset'),
                label: Text('$preset'),
                selected: state.bpm == preset,
                onSelected: (_) => onPickPreset(preset),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '（范围 ${state.settings.minBpm} - ${state.settings.maxBpm}）',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
