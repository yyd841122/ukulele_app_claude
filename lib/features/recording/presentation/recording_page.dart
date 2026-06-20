// Recording practice page (T012 + T013.4A).
//
// Scope:
// - MVP / placeholder-style page that lets the user walk through
//   the "record -> stop -> playback -> self-assess -> re-record ->
//   save-as-PracticeRecord" loop entirely in-memory.
// - NO microphone, NO audio bytes, NO permission prompt, NO file
//   I/O — see the task brief §边界限制. The page text makes this
//   very explicit so a user landing on it is not surprised that
//   "录音" is actually a simulated flow.
// - The widget tree is split into small private components
//   (DisclaimerBanner / StatusCard / ElapsedDisplay / ControlRow
//   / SelfRatingSelector / NoteField / ResetButton / SaveRecordButton)
//   so this file stays short and each piece is independently
//   testable via `find.byKey(...)`.
//
// T013.4A adds the "保存到练习记录" affordance. The button lives in
// its own widget (`SaveRecordButton`) and the page only routes
// taps through to the controller. All state-machine rules live in
// the Controller — see
// `lib/features/recording/application/recording_practice_controller.dart`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/features/recording/application/recording_practice_controller.dart';
import 'package:ukulele_app/features/recording/domain/self_rating.dart';
import 'package:ukulele_app/features/recording/presentation/widgets/save_record_button.dart';

class RecordingPage extends ConsumerWidget {
  const RecordingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final RecordingPracticeState state =
        ref.watch(recordingPracticeControllerProvider);
    final RecordingPracticeController controller =
        ref.read(recordingPracticeControllerProvider.notifier);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('录音回放'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            // Disclaimer banner — required by the brief. Says
            // explicitly that we do NOT call the microphone and do
            // NOT save / play real audio.
            const DisclaimerBanner(),
            const SizedBox(height: 16),
            // Live status card.
            StatusCard(state: state),
            const SizedBox(height: 16),
            // MM:SS timer.
            ElapsedDisplay(state: state),
            const SizedBox(height: 16),
            // Primary controls.
            ControlRow(state: state, controller: controller),
            const SizedBox(height: 16),
            // "重新录一遍" secondary action.
            ResetButton(state: state, controller: controller),
            const SizedBox(height: 24),
            // Self-rating section.
            _SectionTitle(theme: theme, text: '本次自评'),
            const SizedBox(height: 8),
            SelfRatingSelector(
              state: state,
              onChanged: controller.setSelfRating,
            ),
            const SizedBox(height: 24),
            // Free-form note section.
            _SectionTitle(theme: theme, text: '备注（哪里弹错了 / 下次注意什么）'),
            const SizedBox(height: 8),
            NoteField(state: state, onChanged: controller.setNote),
            const SizedBox(height: 16),
            // Save section (T013.4A). Lives in its own widget so
            // the visual state machine ("disabled / enabled /
            // 正在保存… / 已保存") is testable in isolation.
            SaveRecordButton(
              state: state,
              onPressed: () => _onSavePressed(context, controller),
            ),
          ],
        ),
      ),
    );
  }

  /// Drives the save flow and surfaces the contract-mandated
  /// SnackBars:
  /// - `success` -> "已保存到练习记录".
  /// - `failure` -> "保存失败，请重试".
  /// - `ignored` -> silent (no SnackBar).
  Future<void> _onSavePressed(
    BuildContext context,
    RecordingPracticeController controller,
  ) async {
    final SaveRecordingResult result = await controller.saveCurrentTake();
    if (!context.mounted) {
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    switch (result) {
      case SaveRecordingResult.success:
        messenger.showSnackBar(
          const SnackBar(
            key: ValueKey<String>('recording-save-success-snackbar'),
            content: Text('已保存到练习记录'),
            duration: Duration(seconds: 2),
          ),
        );
      case SaveRecordingResult.failure:
        messenger.showSnackBar(
          const SnackBar(
            key: ValueKey<String>('recording-save-failure-snackbar'),
            content: Text('保存失败，请重试'),
            duration: Duration(seconds: 2),
          ),
        );
      case SaveRecordingResult.ignored:
        // Intentional no-op. The brief is explicit: ignored is
        // NOT a failure and must NOT show an error SnackBar.
        break;
    }
  }
}

/// Disclaimer banner — required by the brief, must clearly say the
/// page does NOT touch the microphone / save audio / play audio.
class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      key: const ValueKey<String>('recording-disclaimer'),
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
              '当前版本是"录音回放流程练习版"。'
              '不会调用麦克风，不会保存真实音频，也不会播放真实音频。'
              '这里只用于帮助用户建立"录一遍、听一遍、自我评价"的练习流程。',
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

/// Card showing the current status (ready / recording / playback /
/// done). Drives the rest of the page's enablement via the
/// underlying state.
class StatusCard extends StatelessWidget {
  const StatusCard({super.key, required this.state});

  final RecordingPracticeState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Icon(
              _iconFor(state),
              size: 28,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '当前状态',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    state.statusLabel,
                    key: const ValueKey<String>('recording-status-label'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(RecordingPracticeState state) {
    if (state.isRecording) {
      return Icons.fiber_manual_record;
    }
    if (state.isPlaying) {
      return Icons.play_arrow;
    }
    if (state.hasRecording) {
      return Icons.check_circle_outline;
    }
    return Icons.mic_none;
  }
}

/// Big MM:SS readout of [RecordingPracticeState.elapsedSeconds].
class ElapsedDisplay extends StatelessWidget {
  const ElapsedDisplay({super.key, required this.state});

  final RecordingPracticeState state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Container(
        key: const ValueKey<String>('recording-elapsed-display'),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          state.formattedElapsed,
          style: theme.textTheme.displaySmall?.copyWith(
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Primary controls: start / stop / play / stop-playback.
///
/// The enablement rules come straight from the brief:
/// - `start` is disabled ONLY while a recording is already in
///   progress OR while a save is in flight. Tapping it while the
///   simulated playback is running is allowed and MUST stop
///   playback + start a new take — the controller enforces the
///   transition, the UI just routes (T012_FIX_RECORDING_PLAYBACK_START_BUTTON).
/// - `stop` is disabled unless we are recording (and not saving).
/// - `play` is disabled unless we have a take AND we are not
///   recording AND we are not already playing AND we are not
///   saving.
/// - `stop-playback` is disabled unless we are playing.
class ControlRow extends StatelessWidget {
  const ControlRow({
    super.key,
    required this.state,
    required this.controller,
  });

  final RecordingPracticeState state;
  final RecordingPracticeController controller;

  @override
  Widget build(BuildContext context) {
    // `start` is tappable as long as we are not already recording
    // and not in the middle of a save — including during
    // playback. The controller will stop playback and start a new
    // take; the UI just has to expose the button.
    final bool canStart = !state.isRecording && !state.isSaving;
    final bool canStop = state.isRecording && !state.isSaving;
    final bool canPlay = state.hasRecording &&
        !state.isRecording &&
        !state.isPlaying &&
        !state.isSaving;
    final bool canStopPlayback = state.isPlaying && !state.isSaving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey<String>('recording-start'),
                onPressed: canStart ? controller.startRecording : null,
                icon: const Icon(Icons.fiber_manual_record),
                label: const Text('开始模拟录音'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey<String>('recording-stop'),
                onPressed: canStop ? controller.stopRecording : null,
                icon: const Icon(Icons.stop),
                label: const Text('停止录音'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.tonalIcon(
                key: const ValueKey<String>('recording-play'),
                onPressed: canPlay ? controller.play : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('模拟回放'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey<String>('recording-stop-playback'),
                onPressed: canStopPlayback ? controller.stopPlayback : null,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('停止回放'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Secondary "重新录一遍" button. Clears the current take and goes
/// back to the initial state. Disabled while a recording is in
/// progress (the user must stop first), while a save is in flight
/// (must NOT wipe the take being saved), or when nothing has been
/// recorded yet (nothing to reset).
class ResetButton extends StatelessWidget {
  const ResetButton({
    super.key,
    required this.state,
    required this.controller,
  });

  final RecordingPracticeState state;
  final RecordingPracticeController controller;

  @override
  Widget build(BuildContext context) {
    final bool canReset = !state.isRecording &&
        !state.isSaving &&
        (state.hasRecording || state.isPlaying);
    return OutlinedButton.icon(
      key: const ValueKey<String>('recording-reset'),
      onPressed: canReset ? controller.reset : null,
      icon: const Icon(Icons.refresh),
      label: const Text('重新录一遍'),
    );
  }
}

/// Three-way self-rating choice: good / okay / retry.
///
/// Renders as a [SegmentedButton] so all three options are visible
/// at once and tap targets are large.
///
/// Disabled while recording, while saving, and after a successful
/// save — the saved record is the source of truth.
class SelfRatingSelector extends StatelessWidget {
  const SelfRatingSelector({
    super.key,
    required this.state,
    required this.onChanged,
  });

  final RecordingPracticeState state;
  final ValueChanged<SelfRating?> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool disabled = state.isRecording || state.isSaving || state.isSaved;
    return SegmentedButton<SelfRating>(
      key: const ValueKey<String>('recording-self-rating'),
      segments: const <ButtonSegment<SelfRating>>[
        ButtonSegment<SelfRating>(
          value: SelfRating.good,
          label: Text('还不错'),
          icon: Icon(Icons.sentiment_very_satisfied),
        ),
        ButtonSegment<SelfRating>(
          value: SelfRating.okay,
          label: Text('一般'),
          icon: Icon(Icons.sentiment_neutral),
        ),
        ButtonSegment<SelfRating>(
          value: SelfRating.retry,
          label: Text('需要重练'),
          icon: Icon(Icons.refresh),
        ),
      ],
      selected: <SelfRating>{if (state.selfRating != null) state.selfRating!},
      showSelectedIcon: false,
      emptySelectionAllowed: true,
      onSelectionChanged: disabled
          ? null
          : (Set<SelfRating> selection) {
              // SegmentedButton with multi=false (default) returns
              // a set of size 0 or 1. Forward the single value
              // (or null) to the controller.
              onChanged(selection.isEmpty ? null : selection.first);
            },
    );
  }
}

/// Multi-line free-form note field. Disabled while recording,
/// while saving, and after a successful save.
///
/// Kept as a [StatefulWidget] so we own a single
/// [TextEditingController] for the lifetime of this widget and do
/// not fight the framework on selection / cursor position every
/// time the parent rebuilds.
class NoteField extends StatefulWidget {
  const NoteField({
    super.key,
    required this.state,
    required this.onChanged,
  });

  final RecordingPracticeState state;
  final ValueChanged<String> onChanged;

  @override
  State<NoteField> createState() => _NoteFieldState();
}

class _NoteFieldState extends State<NoteField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.state.note);
  }

  @override
  void didUpdateWidget(covariant NoteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the controller's text no longer matches the state — e.g.
    // because the user tapped "重新录一遍" and the state reset to
    // empty — push the new value into the field. We do NOT push
    // on every keystroke (the field already mirrors itself).
    if (widget.state.note != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.state.note,
        selection: TextSelection.collapsed(offset: widget.state.note.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool disabled = widget.state.isRecording ||
        widget.state.isSaving ||
        widget.state.isSaved;
    return TextField(
      key: const ValueKey<String>('recording-note'),
      controller: _controller,
      enabled: !disabled,
      maxLines: 4,
      minLines: 3,
      onChanged: disabled ? null : widget.onChanged,
      decoration: InputDecoration(
        hintText: disabled ? '录音结束后可填写备注…' : '例如：C→Am 切换慢了，第三小节节奏不稳。',
        filled: true,
        fillColor: disabled
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Small section header used between major blocks.
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
