// Riverpod controller for the recording practice flow (T012).
//
// Design notes:
// - Hand-written [Notifier] (no `@riverpod` codegen) per the
//   project convention (T007 / T008 / T009 / T010 / T011).
// - This is a *simulated* recording / playback controller. It does
//   NOT touch the microphone, does NOT read or write audio bytes,
//   does NOT request any platform permission. See the task brief
//   §边界限制 — real audio is explicitly out of scope and deferred
//   to later tasks.
// - The simulated elapsed-seconds clock uses a `Timer.periodic`
//   similar to [MetronomeController]. To keep tests independent of
//   the real clock, [tickForTesting] exposes the same one-second
//   advance publicly; tests never `sleep` and never rely on the
//   timer firing on its own.
// - The timer is created lazily on [startRecording] and reused on
//   subsequent calls — calling start twice is a no-op while a
//   timer is alive, matching the metronome's "start 不应重复创建
//   多个 timer" rule.
// - [reset] restores the initial state AND clears the self-rating
//   + note. This is the user-visible "重新录一遍" semantics.
// - [dispose] cancels the timer. `ref.onDispose` is wired so the
//   timer is released even if the consumer forgets to call
//   [dispose] explicitly.
//
// State machine (documented; tests pin every transition):
//
//   startRecording    -> isRecording = true,  isPlaying = false,
//                        hasRecording = false, elapsedSeconds = 0,
//                        selfRating = null, note = ''
//   stopRecording     -> isRecording = false, hasRecording = true
//   play              -> hasRecording = true && !isRecording:
//                          isPlaying = true, isRecording = false
//                        otherwise: no-op
//   stopPlayback      -> isPlaying = false
//   reset             -> back to initial state, clears rating + note
//   startRecording    -> while isPlaying: stops playback and begins
//                        a new recording (drops the old one).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/features/recording/domain/self_rating.dart';

/// Interval between two ticks of the simulated recording clock.
const Duration kRecordingTickInterval = Duration(seconds: 1);

/// Immutable state of the recording practice flow.
@immutable
class RecordingPracticeState {
  const RecordingPracticeState({
    required this.isRecording,
    required this.hasRecording,
    required this.isPlaying,
    required this.elapsedSeconds,
    required this.selfRating,
    required this.note,
  });

  /// `true` while a simulated recording is in progress.
  final bool isRecording;

  /// `true` iff at least one simulated take is currently held in
  /// memory. Cleared by [reset] and by starting a new take.
  final bool hasRecording;

  /// `true` while the user is listening back to the (simulated)
  /// take. Mutually exclusive with [isRecording] — see the file
  /// doc comment.
  final bool isPlaying;

  /// Whole seconds elapsed in the current simulated recording.
  /// Reset to 0 whenever a fresh recording begins.
  final int elapsedSeconds;

  /// User's self-rating for the current take. `null` until the user
  /// picks one.
  final SelfRating? selfRating;

  /// Free-form note attached to the current take. In-memory only
  /// for T012; persistence is deferred to T013.
  final String note;

  /// Returns the initial / "ready to record" state. Static factory
  /// so tests and the controller can share the same baseline.
  static const RecordingPracticeState initial = RecordingPracticeState(
    isRecording: false,
    hasRecording: false,
    isPlaying: false,
    elapsedSeconds: 0,
    selfRating: null,
    note: '',
  );

  /// MM:SS formatter for [elapsedSeconds]. Returns e.g. "00:42".
  /// Exposed so the page does not re-implement the formatting and
  /// tests can pin it.
  String get formattedElapsed {
    final int minutes = elapsedSeconds ~/ 60;
    final int seconds = elapsedSeconds % 60;
    final String mm = minutes.toString().padLeft(2, '0');
    final String ss = seconds.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  /// Human-readable status string used by the page's status card.
  String get statusLabel {
    if (isRecording) {
      return '模拟录音中';
    }
    if (isPlaying) {
      return '模拟回放中';
    }
    if (hasRecording) {
      return '已录音（可回放 / 自评）';
    }
    return '准备录音';
  }

  /// Returns a copy with the given fields replaced. `selfRating` is
  /// explicitly nullable here, so to clear it the caller passes
  /// the sentinel `clearSelfRating: true` — see [copyWith].
  RecordingPracticeState copyWith({
    bool? isRecording,
    bool? hasRecording,
    bool? isPlaying,
    int? elapsedSeconds,
    SelfRating? selfRating,
    bool clearSelfRating = false,
    String? note,
  }) {
    return RecordingPracticeState(
      isRecording: isRecording ?? this.isRecording,
      hasRecording: hasRecording ?? this.hasRecording,
      isPlaying: isPlaying ?? this.isPlaying,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      selfRating: clearSelfRating ? null : (selfRating ?? this.selfRating),
      note: note ?? this.note,
    );
  }
}

/// Riverpod controller for the recording practice page.
class RecordingPracticeController extends Notifier<RecordingPracticeState> {
  Timer? _timer;

  @override
  RecordingPracticeState build() {
    // Make sure the timer is cancelled when the provider is torn
    // down — e.g. when the page pops. Mirrors the metronome.
    ref.onDispose(_cancelTimer);
    return RecordingPracticeState.initial;
  }

  /// Starts a simulated recording.
  ///
  /// Behaviour:
  /// - If [state.isRecording] is already true, this is a no-op (the
  ///   timer is reused — see file docs).
  /// - If [state.isPlaying] is true, playback is stopped first so
  ///   the two states are mutually exclusive.
  /// - `hasRecording` is reset because the user is starting a new
  ///   take; `elapsedSeconds` resets to 0; `selfRating` and `note`
  ///   are cleared as well because the previous take is being
  ///   dropped — leaving stale metadata would create the confusing
  ///   "no recording yet but a self-rating is still selected"
  ///   state (T012_FIX).
  void startRecording() {
    if (state.isRecording) {
      return;
    }
    _cancelTimer();
    state = state.copyWith(
      isRecording: true,
      isPlaying: false,
      hasRecording: false,
      elapsedSeconds: 0,
      clearSelfRating: true,
      note: '',
    );
    _timer = Timer.periodic(kRecordingTickInterval, (_) => _advance());
  }

  /// Stops the simulated recording.
  ///
  /// Behaviour:
  /// - If we were not recording, this is a no-op.
  /// - The current take is "kept" (`hasRecording = true`) so the
  ///   user can play it back, rate it, or re-record.
  void stopRecording() {
    if (!state.isRecording) {
      return;
    }
    _cancelTimer();
    state = state.copyWith(
      isRecording: false,
      hasRecording: true,
    );
  }

  /// Simulates playback of the current take.
  ///
  /// Behaviour:
  /// - No-op unless `hasRecording && !isRecording` — i.e. there
  ///   must be a take AND we must not be recording at the same
  ///   time.
  /// - On success, sets `isPlaying = true` and starts the timer so
  ///   the elapsed-time counter advances during playback (the UI
  ///   reuses the same MM:SS display for symmetry).
  void play() {
    if (!state.hasRecording || state.isRecording) {
      return;
    }
    if (state.isPlaying) {
      return;
    }
    state = state.copyWith(isPlaying: true);
    _timer = Timer.periodic(kRecordingTickInterval, (_) => _advance());
  }

  /// Stops playback.
  ///
  /// Behaviour:
  /// - No-op unless we are currently playing.
  /// - `hasRecording` stays true so the user can play it again.
  void stopPlayback() {
    if (!state.isPlaying) {
      return;
    }
    _cancelTimer();
    state = state.copyWith(isPlaying: false);
  }

  /// Restores the initial state and clears the self-rating + note.
  ///
  /// Used by the "重新录一遍" button.
  void reset() {
    _cancelTimer();
    state = RecordingPracticeState.initial;
  }

  /// Records the user's self-assessment for the current take.
  ///
  /// No-op while recording (the user has no take to rate yet).
  /// `null` clears the rating — useful for testing.
  void setSelfRating(SelfRating? rating) {
    if (state.isRecording) {
      return;
    }
    if (rating == null) {
      state = state.copyWith(clearSelfRating: true);
    } else {
      state = state.copyWith(selfRating: rating);
    }
  }

  /// Stores the free-form note for the current take.
  ///
  /// No-op while recording (no take exists yet). Empty string
  /// clears the note.
  void setNote(String value) {
    if (state.isRecording) {
      return;
    }
    state = state.copyWith(note: value);
  }

  /// Public test entry point: advance the simulated clock by one
  /// tick. Tests call this directly and never sleep or rely on the
  /// timer firing.
  ///
  /// Mirrors [MetronomeController.tickForTesting].
  @visibleForTesting
  void tickForTesting() => _advance();

  /// Internal "advance one second" logic. Increments
  /// [RecordingPracticeState.elapsedSeconds] by one. Used by both
  /// the real `Timer.periodic` callback and [tickForTesting].
  void _advance() {
    state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
  }

  /// Cancels the periodic timer if it exists. Idempotent.
  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Provider for the recording practice page controller.
final NotifierProvider<RecordingPracticeController, RecordingPracticeState>
    recordingPracticeControllerProvider =
    NotifierProvider<RecordingPracticeController, RecordingPracticeState>(
  RecordingPracticeController.new,
);
