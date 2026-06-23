// Recording-page exit stop result (T037B).
//
// Sealed result returned by
// [RecordingPracticeController.requestStopForPageExit].
//
// Three top-level states:
// - [success] — the underlying `recorder.stop()` or
//   `playback.stop()` resolved; the page may pop.
// - [skipped] — there was nothing to stop; the page may pop
//   immediately without surfacing a SnackBar.
// - [failure] — the underlying `stop()` threw; the page MUST
//   render the supplied friendly message AND keep itself
//   mounted so the user can retry the back gesture.
//
// T037B intentionally mirrors the T037A detail-page contract
// shape so the two pages can be reasoned about uniformly. The
// sealed class is defined in a recording-feature file (rather
// than being shared across both controllers) so the two state
// machines remain compile-time decoupled — a future change to
// either page's result shape will not accidentally ripple into
// the other.
//
// Why a dedicated sealed class instead of reusing
// [PageExitStopResult] from the detail controller: the
// recording page's exit must await BOTH a possible
// `recorder.stop()` (in `isRecording` state) AND a possible
// `playback.stop()` (in `isPlaying` / `paused` / `hasRecording`
// state), so a failure can come from two different services
// and surface two different user-visible copy strings
// ("停止录音失败，请重试" vs "停止播放失败，请重试"). Reusing the
// detail page's result would force the recording page to
// pick ONE message format for BOTH failure sources — a
// UX regression we explicitly want to avoid.
library;

/// T037B — outcome of
/// [RecordingPracticeController.requestStopForPageExit].
sealed class PageExitStopResult {
  const PageExitStopResult();

  /// Named constructor for the success variant.
  const factory PageExitStopResult.success() = PageExitStopSuccess;

  /// Named constructor for the skip variant.
  const factory PageExitStopResult.skipped({
    required PageExitStopSkipReason reason,
  }) = PageExitStopSkipped;

  /// Named constructor for the failure variant.
  const factory PageExitStopResult.failure({
    required String message,
  }) = PageExitStopFailure;

  /// The page may navigate away.
  ///
  /// `true` for [PageExitStopSuccess] and [PageExitStopSkipped]
  /// (a back gesture that had nothing to stop still pops the
  /// route). `false` for [PageExitStopFailure] (the page must
  /// retain its mount so the user can retry the back gesture
  /// after the SnackBar dismisses).
  bool get shouldPop => switch (this) {
        PageExitStopSuccess() => true,
        PageExitStopSkipped() => true,
        PageExitStopFailure() => false,
      };

  /// Convenience: `true` iff the page must keep itself mounted
  /// and surface [message] as a SnackBar.
  bool get hasUserFacingError => switch (this) {
        PageExitStopSuccess() => false,
        PageExitStopSkipped() => false,
        PageExitStopFailure() => true,
      };

  /// Short, safe, non-PII message for the page's SnackBar.
  /// `null` when [hasUserFacingError] is `false`.
  ///
  /// T037B contract: the message is one of the two
  /// recording-page-specific strings ("停止录音失败，请重试" /
  /// "停止播放失败，请重试"). It MUST NOT include the on-disk
  /// audio path, the underlying exception class name, the
  /// stack trace, or any other PII. The full exception is
  /// `debugPrint`-ed by the controller for engineering
  /// triage but is NEVER rendered to the user.
  String? get message => switch (this) {
        PageExitStopSuccess() => null,
        PageExitStopSkipped() => null,
        PageExitStopFailure(:final message) => message,
      };
}

/// The page-exit stop completed cleanly. The page may pop
/// without surfacing a SnackBar.
class PageExitStopSuccess extends PageExitStopResult {
  const PageExitStopSuccess();
}

/// The page-exit stop was skipped because there was nothing
/// to stop (or the controller / provider was in a state that
/// does not require a stop). The page may pop immediately
/// without surfacing a SnackBar.
///
/// The [reason] is captured for diagnostics / tests; the
/// page treats every skip as "pop immediately".
class PageExitStopSkipped extends PageExitStopResult {
  const PageExitStopSkipped({required this.reason});

  /// Why the controller skipped the stop attempt.
  final PageExitStopSkipReason reason;
}

/// The page-exit stop failed — the underlying
/// `recorder.stop()` or `playback.stop()` threw. The page
/// MUST render the supplied [message] as a SnackBar AND keep
/// itself mounted so the user can retry the back gesture
/// after the SnackBar dismisses.
class PageExitStopFailure extends PageExitStopResult {
  const PageExitStopFailure({required this.message});

  @override
  final String message;
}

/// T037B — sub-reason for [PageExitStopSkipped]. Used only
/// for diagnostics / tests; the page treats every skip as
/// "pop immediately".
enum PageExitStopSkipReason {
  /// Controller was disposed or Provider unmounted before
  /// the stop attempt. Mirrors the T037A disposition so
  /// cross-page debugging is uniform.
  disposed,

  /// Controller has no published state yet (rare race at
  /// build time).
  noState,

  /// `isRecording == false && isPlaying == false && takeId == null`
  /// — there is nothing to stop. The page may pop normally.
  idle,

  /// Controller's state machine reports an active session
  /// (`isRecording == true` while the underlying
  /// `RealAudioRecorderService` is already in a terminal
  /// state, or `isPlaying == true` while the underlying
  /// `RealAudioPlaybackService` is already in a terminal
  /// state). Defensive skip so we never call
  /// `service.stop()` in a state the service refuses (it
  /// would throw `InvalidRecorderStateException` /
  /// `InvalidPlaybackStateException`).
  serviceAlreadyTerminal,
}
