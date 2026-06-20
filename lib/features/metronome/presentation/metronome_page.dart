// Metronome page (T010).
//
// Scope:
// - Visual-only metronome. No audio backend, no microphone, no
//   network, no persistence — see the task brief §边界限制.
// - The page reads [metronomeControllerProvider] and forwards
//   button taps to the controller.
// - The "声音" switch is wired into the controller's
//   `soundEnabled` flag but the UI clearly tells the user the
//   audio backend is not yet shipped, matching the brief's
//   "如果本任务不实现真实声音，请明确文案" requirement.
// - The widget tree is split into small components
//   (MetronomeDisplay / BpmControls / BeatsPerBarSelector /
//   MetronomeStartStopButton) so this file stays short and each
//   piece is independently testable.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/features/metronome/application/metronome_controller.dart';
import 'package:ukulele_app/features/metronome/presentation/widgets/beats_per_bar_selector.dart';
import 'package:ukulele_app/features/metronome/presentation/widgets/bpm_controls.dart';
import 'package:ukulele_app/features/metronome/presentation/widgets/metronome_display.dart';
import 'package:ukulele_app/features/metronome/presentation/widgets/metronome_start_stop_button.dart';

class MetronomePage extends ConsumerWidget {
  const MetronomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final MetronomeState state =
        ref.watch(metronomeControllerProvider);
    final MetronomeController controller =
        ref.read(metronomeControllerProvider.notifier);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('节拍器'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            // Disclaimer banner — required by the brief.
            _AudioDisclaimer(theme: theme),
            const SizedBox(height: 16),
            // Big beat indicator.
            MetronomeDisplay(state: state),
            const SizedBox(height: 16),
            // Start / stop.
            MetronomeStartStopButton(
              isRunning: state.isRunning,
              onPressed: controller.toggleRunning,
            ),
            const SizedBox(height: 24),
            // Section: BPM.
            _SectionTitle(theme: theme, text: '速度 (BPM)'),
            const SizedBox(height: 8),
            BpmControls(
              state: state,
              onDecrease: controller.decreaseBpm,
              onIncrease: controller.increaseBpm,
              onPickPreset: controller.setBpm,
            ),
            const SizedBox(height: 24),
            // Section: beats per bar.
            _SectionTitle(theme: theme, text: '每小节拍数'),
            const SizedBox(height: 8),
            Center(
              child: BeatsPerBarSelector(
                beatsPerBar: state.beatsPerBar,
                onChanged: controller.setBeatsPerBar,
              ),
            ),
            const SizedBox(height: 24),
            // Section: sound toggle.
            _SectionTitle(theme: theme, text: '声音'),
            const SizedBox(height: 4),
            SwitchListTile.adaptive(
              key: const ValueKey<String>('metronome-sound-toggle'),
              contentPadding: EdgeInsets.zero,
              title: const Text('开启声音'),
              subtitle: Text(
                state.settings.soundEnabled
                    ? '已开启（当前仍为可视化节拍，声音将在后续任务接入）'
                    : '当前版本为可视化节拍，声音将在后续任务接入。',
              ),
              value: state.settings.soundEnabled,
              onChanged: (_) => controller.toggleSoundEnabled(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Yellow-ish banner explaining that the MVP ships a visual
/// metronome only. Required by the brief.
class _AudioDisclaimer extends StatelessWidget {
  const _AudioDisclaimer({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.info_outline,
            size: 20,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '当前版本为可视化节拍器，没有真实声音播放；'
              '声音功能将在后续任务接入。本节拍器适合跟随视觉节拍练习按弦与拨弦节奏。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section header used between the major blocks.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.theme, required this.text});

  final ThemeData theme;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}