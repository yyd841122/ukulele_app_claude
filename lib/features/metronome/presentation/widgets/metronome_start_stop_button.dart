// Start / stop big button.
//
// T010 scope:
// - A single, prominent button. Label flips between "开始" and
//   "停止" depending on the running state.
// - Icon also flips so the affordance is unambiguous.

import 'package:flutter/material.dart';

class MetronomeStartStopButton extends StatelessWidget {
  const MetronomeStartStopButton({
    super.key,
    required this.isRunning,
    required this.onPressed,
  });

  final bool isRunning;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: const ValueKey<String>('metronome-start-stop'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      onPressed: onPressed,
      icon: Icon(isRunning ? Icons.stop : Icons.play_arrow),
      label: Text(isRunning ? '停止' : '开始'),
    );
  }
}
