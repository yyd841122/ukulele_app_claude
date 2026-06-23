// Recording practice page (T012 + T013.4A + T031 + T037B).
//
// Scope:
// - MVP / placeholder-style page that lets the user walk through
//   the "record -> stop -> playback -> self-assess -> re-record ->
//   save-as-PracticeRecord" loop entirely in-memory.
// - T031 wires the page to [RecordingPracticeController], which in
//   turn drives [RealAudioRecorderService] /
//   [RealAudioPlaybackService] / [MicrophonePermissionService].
//   The page no longer pretends to be "simulated" — copy and
//   disclaimer have been updated to reflect real microphone +
//   real audio capture, with the save flow still hard-codes
//   `audioFilePath: null` because T032 (Drift schema migration)
//   has not landed. The page is therefore free to be honest
//   about what the user is doing: they ARE recording through the
//   microphone, the take IS held as a real .m4a on disk, but
//   the take is NOT yet linked to a PracticeRecord on save.
// - The widget tree is split into small private components
//   (DisclaimerBanner / StatusCard / ElapsedDisplay / ControlRow
//   / SelfRatingSelector / NoteField / ResetButton / SaveRecordButton)
//   so this file stays short and each piece is independently
//   testable via `find.byKey(...)`.
//
// T037B — page-exit audio stop coordination (real-device fix):
// - Root-cause (real-device reproduction): recording a take
//   and then tapping the AppBar back arrow (or pressing the
//   Android system back / back-gesture) left the underlying
//   `just_audio` player still audible after the route
//   transition completed — mirroring the same T037A
//   regression on the detail page. For the recording page
//   the problem is amplified: leaving the page WHILE a
//   recording is in progress leaves the native `record`
//   plugin's microphone capture running AND the MM:SS
//   ticker continuing to advance. The previous
//   fire-and-forget stop inside the controller's
//   `ref.onDispose` raced the route pop; the page did not
//   await the platform-channel stop before the Navigator
//   popped.
// - Fix: the page drives the AppBar back arrow + the
//   Android system back / back-gesture through a single
//   chokepoint [_handleExit]. The chokepoint awaits
//   [RecordingPracticeController.requestStopForPageExit]
//   — a NEW public method that returns an awaitable
//   [PageExitStopResult] (sealed class with three
//   variants: success / skipped / failure). The actual
//   `recorder.stop()` / `playback.stop()` is awaited (NOT
//   fire-and-forget) so the platform-channel stop
//   resolves BEFORE the Navigator pops. On failure the
//   page surfaces a friendly SnackBar AND keeps itself
//   mounted so the user can retry the back gesture.
// - [PopScope] wraps the [Scaffold] so Android system back
//   invokes the same chokepoint. `canPop` is gated on
//   [_exitInFlight] AND on whether the controller
//   currently holds an active session (so the system
//   back still works normally on the idle state, where
//   there is nothing to coordinate).
// - [_exitInFlight] serialises concurrent exit attempts
//   so a double-tap on the AppBar back arrow (or the
//   AppBar back + an immediate Android system back)
//   cannot double-pop or double-stop. The guard is
//   intentionally a plain bool — the page is
//   single-threaded on the UI isolate and no async gap
//   exists between read and write.
// - The controller's existing `ref.onDispose` hook is
//   preserved as a non-cooperative safety net (a parent
//   route replaced, or a test that drops the widget
//   tree without calling the page's exit handler). The
//   page's [_handleExit] is the SOLE normal exit
//   path.
// - Failure mode: when
//   [RecordingPracticeController.requestStopForPageExit]
//   returns [PageExitStopFailure] the page surfaces a
//   friendly SnackBar AND keeps the page mounted
//   (does NOT pop). The user can retry the back
//   gesture after seeing the SnackBar. The SnackBar
//   copy is "停止录音失败，请重试" or
//   "停止播放失败，请重试" — never the absolute path,
//   the exception class name, or any other PII.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ukulele_app/features/recording/application/recording_page_exit_stop_result.dart';
import 'package:ukulele_app/features/recording/application/recording_practice_controller.dart';
import 'package:ukulele_app/features/recording/domain/self_rating.dart';
import 'package:ukulele_app/features/recording/presentation/widgets/save_record_button.dart';

class RecordingPage extends ConsumerStatefulWidget {
  const RecordingPage({super.key});

  @override
  ConsumerState<RecordingPage> createState() => _RecordingPageState();
}

class _RecordingPageState extends ConsumerState<RecordingPage> {
  /// T037B — exit-coordination re-entrancy guard. While an
  /// exit is in flight (we are awaiting the controller's
  /// [RecordingPracticeController.requestStopForPageExit] OR
  /// we are in the microtask window between stop completion
  /// and the actual pop) we refuse additional exit requests
  /// so a double-tap on the AppBar back arrow (or AppBar back
  /// + immediate Android system back) cannot double-pop or
  /// double-stop the audio services. The guard is intentionally
  /// a plain bool — the page is single-threaded on the UI
  /// isolate and no async gap exists between read and write.
  bool _exitInFlight = false;

  @override
  Widget build(BuildContext context) {
    final RecordingPracticeState state =
        ref.watch(recordingPracticeControllerProvider);
    final RecordingPracticeController controller =
        ref.read(recordingPracticeControllerProvider.notifier);
    final ThemeData theme = Theme.of(context);

    // T037B — the page drives the AppBar back arrow and the
    // Android system back / back-gesture through a single
    // chokepoint ([_handleExit]). PopScope intercepts the
    // latter; canPop is gated on [_exitInFlight] AND on
    // whether the controller currently holds an active
    // session (so the system back still works normally on
    // the idle state, where there is nothing to
    // coordinate).
    final bool hasActiveSession = _hasActiveSession(state);
    return PopScope(
      canPop: !_exitInFlight && !hasActiveSession,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          // The framework already popped (no active session,
          // no in-flight exit). Nothing to coordinate.
          return;
        }
        // canPop was false → drive the exit coordination.
        _handleExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('录音回放'),
          leading: BackButton(
            // T037B — route AppBar back through the same
            // chokepoint as Android system back. We use
            // the stock [BackButton] widget (NOT a
            // custom `IconButton`) so Flutter's built-in
            // back-button heuristics (e.g. widget
            // testing's `pageBack` helper, the Cupertino
            // back-button fallback) still recognise the
            // leading affordance as a "back button" —
            // the [BackButton] widget preserves the
            // `BackButton` type identity while letting us
            // override `onPressed` to drive
            // [_handleExit]. The visual is identical to
            // the pre-T037B default AppBar leading.
            key: const ValueKey<String>('recording-back-button'),
            onPressed: _handleExit,
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              // T031 disclaimer banner. Says explicitly that the
              // page uses the real microphone, the take lives in
              // the app's private storage, and saving into a
              // PracticeRecord is still being rolled out (T032+).
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
      ),
    );
  }

  /// T037B — returns `true` iff the current watched state
  /// implies an active audio session that must be stopped
  /// before navigation.
  ///
  /// The state machine has four "active" branches:
  /// - `isRecording == true` — the recorder service is
  ///   actively capturing from the microphone; the
  ///   platform-channel stop MUST be awaited before the
  ///   page exits or the microphone stays open.
  /// - `isPlaying == true` — the playback service is
  ///   actively driving the underlying player; the
  ///   platform-channel stop MUST be awaited before the
  ///   page exits or the user hears audio bleeding past
  ///   the page boundary (the T037A regression).
  /// - `isPlaying == false && takeId != null && !isRecording`
  ///   — the page has a recorded take ready for replay
  ///   (or paused mid-playback); the playback service may
  ///   still hold the on-disk file handle. The page-exit
  ///   stop releases the file handle so a subsequent
  ///   `deleteIfExists` (during save-or-delete on the
  ///   detail page) does not race the player.
  bool _hasActiveSession(RecordingPracticeState state) {
    if (state.isRecording) {
      return true;
    }
    if (state.isPlaying) {
      return true;
    }
    if (state.takeId != null) {
      return true;
    }
    return false;
  }

  /// T037B — single chokepoint for every page-exit gesture.
  ///
  /// Flow:
  /// 1. Re-entrancy: if [_exitInFlight] is already true,
  ///    refuse the call so a double-tap on the AppBar back
  ///    (or AppBar back + immediate Android system back)
  ///    cannot double-stop or double-pop.
  /// 2. Await the controller's
  ///    [RecordingPracticeController.requestStopForPageExit].
  ///    This is the actual fix: the stop is awaited (NOT
  ///    fire-and-forget) so the platform-channel stop
  ///    resolves before the Navigator pops.
  /// 3. If the result is [PageExitStopSuccess] or
  ///    [PageExitStopSkipped] → pop the route.
  /// 4. If the result is [PageExitStopFailure] → render
  ///    the supplied friendly SnackBar AND keep the page
  ///    mounted. The guard is released so the user can
  ///    retry the back gesture after the SnackBar
  ///    dismisses.
  ///
  /// The method is intentionally fire-and-forget from the
  /// framework's perspective (the AppBar `onPressed` /
  /// `onPopInvokedWithResult` cannot be `async` directly),
  /// but every await is bracketed inside the function so
  /// the actual navigation only happens after the stop
  /// resolves.
  void _handleExit() {
    if (_exitInFlight) {
      return;
    }
    _exitInFlight = true;
    // ignore: discarded_futures
    _runExit();
  }

  Future<void> _runExit() async {
    PageExitStopResult result;
    try {
      final RecordingPracticeController controller = ref.read(
        recordingPracticeControllerProvider.notifier,
      );
      result = await controller.requestStopForPageExit();
    } on Object catch (e, st) {
      // The controller explicitly never throws, but we
      // belt-and-braces this branch: an unexpected throw
      // must NOT leave the page in an un-poppable state.
      debugPrint(
        'RecordingPage _runExit unexpected throw: '
        '$e\n$st',
      );
      // The throw must be mapped to the playback failure
      // variant because the controller's stop surface is
      // exclusively a playback / recording stop. We pick
      // the recording-failure message as the conservative
      // default because the throw happened OUTSIDE the
      // controller's expected branches — there is no
      // context for the page to pick a more specific
      // message. The full exception is debugPrint-ed.
      result = const PageExitStopResult.failure(
        message: '停止录音失败，请重试',
      );
    }
    // The widget may have been disposed while we awaited
    // (e.g. a parent route replaced the recording page).
    // In that case `mounted` is false and we must not
    // touch BuildContext.
    if (!mounted) {
      return;
    }
    if (result.hasUserFacingError) {
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      // T037B — distinguish recorder-stop failures from
      // playback-stop failures by inspecting the
      // controller's current state. The recorder-stop
      // failure message is "停止录音失败，请重试" and the
      // playback-stop failure message is
      // "停止播放失败，请重试". The controller already
      // returns the correct message in the failure
      // result; we re-derive the key from the message so
      // the SnackBar key (which tests use to find the
      // SnackBar) is stable.
      final String message = result.message ?? '停止录音失败，请重试';
      final String key = message == '停止播放失败，请重试'
          ? 'recording-page-exit-stop-playback-failure-snackbar'
          : 'recording-page-exit-stop-recording-failure-snackbar';
      messenger.showSnackBar(
        SnackBar(
          key: ValueKey<String>(key),
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
      // Keep the page mounted; release the guard so the
      // user can retry the back gesture.
      _exitInFlight = false;
      return;
    }
    // Success or skip — pop. The Navigator's `pop` does
    // NOT itself trigger another `_handleExit` because
    // the page is being torn down.
    _popOrGoHome(context);
    // `_popOrGoHome` is synchronous from the page's
    // perspective; the guard is intentionally not
    // released here because the page is on its way out.
  }

  /// Pops back to the parent route. If the page was reached
  /// without a parent route on the stack (a direct push
  /// from somewhere else), falls back to a router-level
  /// `go` so the user is never left stranded on a dead-end
  /// page.
  void _popOrGoHome(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/');
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

/// Disclaimer banner — required by T031. Says explicitly that
/// the page uses the real microphone, that the take lives only
/// in the current session, and that persisting the take into a
/// PracticeRecord (so the saved record can replay the audio
/// later) is still being rolled out by T032+.
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
              '本页使用本机麦克风录制练习片段。'
              '录音暂存在本机，保存到练习记录将在后续步骤接入，'
              '当前录音仅保存在本次会话中。',
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
/// The enablement rules come straight from the T031 + T031C
/// brief:
/// - `start` is disabled while a recording is in progress, while
///   a permission check is in flight, while a save is in flight,
///   or while playback is running. The controller is the
///   belt-and-braces guard against
///   `play || recording` mutual exclusion (T031C pins this with a
///   dedicated widget test so the user can never start a
///   recording while playback is running).
/// - `stop` is disabled unless we are recording (and not
///   saving / checking permission).
/// - `play` is disabled unless we have a recorded take AND we
///   are not recording AND we are not already playing AND we
///   are not saving AND we are not checking permission. After
///   natural completion the controller flips `isPlaying = false`
///   (T031C) so `play` re-enables and the user can replay from 0.
/// - `stop-playback` is disabled unless we are playing. After
///   natural completion the controller flips `isPlaying = false`
///   (T031C) so `stop-playback` auto-disables — the user no
///   longer has to tap "停止回放" after the file ends.
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
    final bool isCheckingPermission =
        state.permission == RecordingPermissionStatus.checking;
    final bool canStart = !state.isRecording &&
        !state.isSaving &&
        !state.isPlaying &&
        !isCheckingPermission;
    final bool canStop = state.isRecording && !state.isSaving;
    final bool canPlay = state.hasRecordedTake &&
        !state.isRecording &&
        !state.isPlaying &&
        !state.isSaving &&
        !isCheckingPermission;
    final bool canStopPlayback = state.isPlaying && !state.isSaving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey<String>('recording-start'),
                onPressed: canStart ? () => controller.startRecording() : null,
                icon: const Icon(Icons.fiber_manual_record),
                label: const Text('开始录音'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey<String>('recording-stop'),
                onPressed: canStop ? () => controller.stopRecording() : null,
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
                onPressed: canPlay ? () => controller.play() : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('回放'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey<String>('recording-stop-playback'),
                onPressed:
                    canStopPlayback ? () => controller.stopPlayback() : null,
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
/// progress (the user must stop first), while a save is in
/// flight, or when nothing has been recorded yet (nothing to
/// reset).
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
        (state.hasRecording ||
            state.isPlaying ||
            state.permission == RecordingPermissionStatus.denied ||
            state.permission == RecordingPermissionStatus.permanentDenied ||
            state.permission == RecordingPermissionStatus.restricted);
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
/// Disabled while recording, while saving, while checking
/// permission, and after a successful save — the saved record
/// is the source of truth.
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
    final bool isCheckingPermission =
        state.permission == RecordingPermissionStatus.checking;
    final bool disabled = state.isRecording ||
        state.isSaving ||
        state.isSaved ||
        isCheckingPermission;
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
              onChanged(selection.isEmpty ? null : selection.first);
            },
    );
  }
}

/// Multi-line free-form note field. Disabled while recording,
/// while saving, while checking permission, and after a
/// successful save.
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
    final bool isCheckingPermission =
        widget.state.permission == RecordingPermissionStatus.checking;
    final bool disabled = widget.state.isRecording ||
        widget.state.isSaving ||
        widget.state.isSaved ||
        isCheckingPermission;
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
