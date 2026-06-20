// Visual representation of the current beat of the metronome.
//
// T010 scope:
// - Renders "第 N / M 拍" with the current beat number enlarged and
//   tinted with the accent colour.
// - Beat 1 is the downbeat ("重拍"); other beats are offbeats
//   ("轻拍").
// - Pure widget — reads no provider state. The page passes the
//   [MetronomeState] in. This keeps the widget trivial to unit
//   test and reusable in future debug screens.

import 'package:flutter/material.dart';

import 'package:ukulele_app/features/metronome/application/metronome_controller.dart';
import 'package:ukulele_app/features/metronome/domain/metronome_settings.dart';

class MetronomeDisplay extends StatelessWidget {
  const MetronomeDisplay({super.key, required this.state});

  final MetronomeState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDownbeat = state.currentAccent == BeatAccent.downbeat;
    final Color beatColor = isDownbeat
        ? theme.colorScheme.primary
        : theme.colorScheme.tertiary;
    final String accentLabel =
        isDownbeat ? '重拍' : '轻拍';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // BPM hero label.
          Text(
            '${state.bpm} BPM',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          // Big beat indicator.
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: beatColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: beatColor, width: 4),
            ),
            child: Center(
              child: Text(
                '${state.currentBeat}',
                style: theme.textTheme.displayLarge?.copyWith(
                  color: beatColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // "第 N / M 拍"
          Text(
            '第 ${state.currentBeat} / ${state.beatsPerBar} 拍',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          // Accent label.
          Text(
            accentLabel,
            style: theme.textTheme.titleSmall?.copyWith(
              color: beatColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}