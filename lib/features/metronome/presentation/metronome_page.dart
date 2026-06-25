// Metronome page (T010 + T052 audible sound).
//
// Scope:
// - Visual-only metronome with an optional audible click driven by
//   the [metronomeAudioSourceProvider]. No microphone, no network,
//   no persistence — see the task brief §边界限制.
// - The page reads [metronomeControllerProvider] and forwards
//   button taps to the controller.
// - The "声音" switch is wired into the controller's `soundEnabled`
//   flag and the actual click is produced by
//   [MetronomeAudioSource.playClick] called from inside
//   `MetronomeController._advance()`. The page itself never touches
//   the audio engine — the controller is the single integration
//   point.
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
    final MetronomeState state = ref.watch(metronomeControllerProvider);
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
                    ? '已开启声音（每拍播放一次点击，强拍音高更高）'
                    : '已关闭声音（仅可视化节拍）',
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
