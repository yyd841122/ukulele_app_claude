// Fake [AudioPlaybackGateway] for unit tests (T030).
//
// Strategy:
// - Mirrors the `FakeAudioRecorderGateway` pattern from T029: pure
//   Dart, no mocktail / mockito, no platform channel.
// - Records every call (loadFile / play / pause / seek / stop / dispose)
//   with its arguments and call counts.
// - Supports fault injection: `nextLoadException` / `nextPlayException`
//   / `nextPauseException` / `nextSeekException` / `nextStopException`
//   / `nextDisposeException` to drive the service through every error
//   branch.
// - Supports stream broadcasting via `StreamController.broadcast()` so
//   multiple listeners can subscribe.
// - Supports controllable duration + position values; tests can
//   inject `nextDuration` / `currentPosition` to drive state assertions.
// - `completeOnNextPlay()` triggers a one-shot "natural completion":
//   next `play()` future completes immediately, simulating just_audio's
//   "play Future completes on natural playback end" semantics.
// - T031I: supports `simulateRealDeviceLoopAfterCompleted` to mirror
//   the real Android just_audio behaviour where, after a `completed`
//   event is emitted WITHOUT a preceding `playback.stop()`, the
//   player re-enters `ready/playing` and replays the source — the
//   regression T031I fixes. Tests flip this on to assert that the
//   controller's `_handleNaturalCompletion` actually drives
//   `playback.stop()` and breaks the loop.

import 'dart:async';

import 'package:ukulele_app/shared/services/audio_playback_gateway.dart';

/// Fake gateway for unit tests.
///
/// All methods are async; `next*` pre-seed values control returned values
/// / thrown exceptions. Call counts / argument records let tests assert
/// "the service called gateway exactly once with X".
class FakeAudioPlaybackGateway implements AudioPlaybackGateway {
  FakeAudioPlaybackGateway();

  // ---- pre-seed values (controls) ----

  /// Value returned by [loadFile]. Use `null` to simulate "load returns
  /// null duration" (still considered "loaded", state → ready).
  Duration? nextLoadResult;

  /// If set, [loadFile] throws this exception instead of completing.
  Object? nextLoadException;

  /// If set, [play] throws this exception instead of completing.
  Object? nextPlayException;

  /// If set, [pause] throws this exception instead of completing.
  Object? nextPauseException;

  /// If set, [seek] throws this exception instead of completing.
  Object? nextSeekException;

  /// If set, [stop] throws this exception instead of completing.
  Object? nextStopException;

  /// T031I: if set, [stop] throws this exception EXACTLY ONCE
  /// — when [stopCallCount] reaches [nextStopExceptionAtCallCount]
  /// (default: next stop call). The flag is consumed after the
  /// throw, so subsequent `stop()` calls succeed normally. This
  /// lets tests fault-inject the controller's
  /// `_handleNaturalCompletion` stop path WITHOUT also breaking
  /// the `loadFile` internal-stop path (which is what makes
  /// `controller.play()` succeed in the first place).
  Object? nextStopExceptionOnce;
  int nextStopExceptionAtCallCount = -1;

  /// If set, [dispose] throws this exception instead of completing.
  Object? nextDisposeException;

  /// When true, the next call to [play] will complete its future
  /// immediately (one-shot). Tests use this to drive "natural
  /// completion" → completed state transitions without running real
  /// audio.
  bool completeOnNextPlay = false;

  /// T031G: when true, the next call to [play] will keep its
  /// returned Future pending (mimics just_audio's real behaviour
  /// on Android where `AudioPlayer.play()` returns a Future that
  /// stays pending for the entire playback duration). The
  /// controller must therefore NOT `await` this Future — flipping
  /// `isPlaying = true` must happen synchronously, and the only
  /// way to flip it back is via the `playerStateStream` `completed`
  /// event (or an explicit `stop()` call).
  ///
  /// Tests that drive the controller's post-playback state
  /// machine should emit the `completed` event manually after
  /// `play()` returns. Default `false` to keep T031E tests
  /// (which rely on auto-completion microtask) working.
  bool keepPlayPending = false;

  /// T031E: tracks whether `setLoopModeOff` has been called on this
  /// gateway. Production gateway pins `LoopMode.off` on every
  /// `loadFile`; the fake mirrors the same contract so the
  /// production state machine (`isPlaying = false` after `play()`,
  /// `processingState == completed` event triggers controller
  /// auto-recovery) is correctly exercised. Tests can assert
  /// `setLoopModeOffCallCount >= 1` to pin the contract.
  int setLoopModeOffCallCount = 0;

  /// If non-null, [setLoopModeOff] throws this exception (testing
  /// the best-effort error swallow path).
  Object? nextSetLoopModeOffException;

  /// T031I: when `true`, the fake simulates the real-device
  /// just_audio behaviour where, after a `completed` event is
  /// emitted, the underlying player re-enters `ready/playing` and
  /// replays the source — but ONLY if `playback.stop()` has NOT
  /// been called by the controller since the `completed` event.
  /// Once `playback.stop()` is called, the fake records that as a
  /// "stopped" barrier and stops re-emitting `completed` /
  /// `ready+playing` on subsequent ticks. This mirrors the real
  /// Android regression the user reported (playback loops forever
  /// after natural end-of-stream) and lets tests assert that the
  /// controller's `_handleNaturalCompletion` actually drives
  /// `playback.stop()` (otherwise the test would never settle —
  /// the playerStateStream keeps re-firing `completed` because
  /// the fake keeps "replaying"). Default `false` to keep every
  /// pre-T031I test deterministic.
  bool simulateRealDeviceLoopAfterCompleted = false;

  /// T031I: when [simulateRealDeviceLoopAfterCompleted] is `true`,
  /// the fake schedules extra `completed` → `ready+playing` →
  /// `completed` cycles on the playerStateStream unless
  /// [playback.stop()] has been called. The counter is for tests
  /// to assert "the fake re-emitted completed N times before the
  /// controller broke the loop". When the controller calls
  /// `playback.stop()`, the loop barrier is set and no further
  /// cycles are scheduled.
  int loopEmittedCompletedCount = 0;

  /// T031I: when `true`, the most recent `playback.stop()` call
  /// (if any) has been observed. The fake's loop scheduler checks
  /// this flag to decide whether to keep re-emitting cycles.
  /// Reset on every `play()` call (the next playback may naturally
  /// end and the controller is expected to drive stop again).
  bool _stoppedBarrier = false;

  /// When true, [pause] / [stop] future completes immediately without
  /// state changes.
  bool noOpNextPause = false;
  bool noOpNextStop = false;

  // ---- current state (tests can read) ----

  /// Current playback duration (controlled by tests).
  Duration? currentDuration;

  /// Current playback position (controlled by tests).
  Duration currentPosition = Duration.zero;

  /// Whether the player is currently in "playing" state.
  bool isPlaying = false;

  // ---- recorded calls (assertions) ----

  int loadFileCallCount = 0;
  int playCallCount = 0;
  int pauseCallCount = 0;
  int seekCallCount = 0;
  int stopCallCount = 0;
  int disposeCallCount = 0;

  String? lastLoadPath;
  Duration? lastSeekPosition;

  // ---- stream controllers ----

  final StreamController<PlaybackPlayerState> _playerStateController =
      StreamController<PlaybackPlayerState>.broadcast();
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController =
      StreamController<Duration?>.broadcast();

  // ---- gateway contract ----

  @override
  Future<Duration?> loadFile(String filePath) async {
    loadFileCallCount += 1;
    lastLoadPath = filePath;
    // T031E: production gateway pins LoopMode.off on every load;
    // mirror the call here so the fake exercises the same contract
    // path. We record the call BEFORE the loadFile exception check
    // because production's setLoopModeOff is best-effort and runs
    // before the throw. Production also wraps the call in try/catch
    // so a failing setLoopModeOff never blocks the load — the
    // fake mirrors that swallow as well.
    try {
      await setLoopModeOff();
    } on Object {
      // Best-effort: production gateway swallows loop-mode errors
      // so a missing platform channel or odd state does not
      // prevent the file from being loaded.
    }
    if (nextLoadException != null) {
      throw nextLoadException!;
    }
    // Update duration to nextLoadResult; if nextLoadResult is null, leave
    // currentDuration unchanged.
    if (nextLoadResult != null) {
      currentDuration = nextLoadResult;
      _durationController.add(nextLoadResult);
    }
    // Reset position to zero on new load.
    currentPosition = Duration.zero;
    _positionController.add(Duration.zero);
    return nextLoadResult;
  }

  @override
  Future<void> play() async {
    playCallCount += 1;
    if (nextPlayException != null) {
      throw nextPlayException!;
    }
    // T031I: each new play() resets the stopped barrier — the
    // next natural end-of-stream is a fresh opportunity for the
    // controller to drive playback.stop() to break the loop.
    _stoppedBarrier = false;
    if (keepPlayPending) {
      // T031G: mirror just_audio's real-device behaviour where
      // `AudioPlayer.play()` returns a Future that stays pending
      // for the entire playback duration. The controller
      // therefore must NOT `await` this Future; the post-play
      // state machine recovery is driven exclusively by the
      // `playerStateStream` `completed` event (or an explicit
      // stop() call).
      isPlaying = true;
      keepPlayPending = false;
      return;
    }
    if (completeOnNextPlay) {
      // T031E: simulate just_audio's natural-completion semantics
      // faithfully. In production, `play()` returns a Future that
      // hangs for the entire playback duration, then completes
      // when the file reaches the end. The
      // `processingState == completed` event on
      // `playerStateStream` is the canonical signal the
      // controller uses for auto-recovery; it is delivered AFTER
      // `play()` has returned so the controller's stream
      // subscription (set up just before `play()`) is in place to
      // receive it.
      //
      // The fake mirrors that ordering:
      //   1. mark `isPlaying = true` so any synchronous
      //      controller state writes after `play()` returns see
      //      the right "we are playing" flag;
      //   2. schedule the `completed` event on the next
      //      microtask so it lands AFTER `play()`'s return value
      //      propagates and AFTER the controller's listener is
      //      subscribed.
      isPlaying = true;
      completeOnNextPlay = false;
      scheduleMicrotask(_emitCompletedWithOptionalLoop);
      return;
    }
    // Successful play path: update isPlaying flag.
    // 注意：Service 在调用 play() 后已经把状态切到 playing，因此
    // fake 不再通过 playerStateStream emit ready+playing 事件（避免
    // 与 Service 状态机双重切换）。
    isPlaying = true;
  }

  @override
  Future<void> pause() async {
    pauseCallCount += 1;
    if (nextPauseException != null) {
      throw nextPauseException!;
    }
    if (noOpNextPause) {
      noOpNextPause = false;
      return;
    }
    isPlaying = false;
  }

  @override
  Future<void> seek(Duration? position) async {
    seekCallCount += 1;
    lastSeekPosition = position;
    if (nextSeekException != null) {
      throw nextSeekException!;
    }
    if (position != null) {
      currentPosition = position;
      _positionController.add(position);
    }
  }

  @override
  Future<void> stop() async {
    stopCallCount += 1;
    if (nextStopExceptionOnce != null &&
        nextStopExceptionAtCallCount == stopCallCount) {
      final Object err = nextStopExceptionOnce!;
      nextStopExceptionOnce = null;
      throw err;
    }
    if (nextStopException != null) {
      throw nextStopException!;
    }
    // T031I: every successful `playback.stop()` raises the loop
    // barrier — the fake stops re-emitting `completed` /
    // `ready+playing` cycles until the next `play()` resets it.
    // This mirrors the real-device behaviour the user reported
    // where the underlying player only stops looping once a
    // `stop()` is actually driven by the controller.
    _stoppedBarrier = true;
    if (noOpNextStop) {
      noOpNextStop = false;
      return;
    }
    isPlaying = false;
  }

  @override
  Future<void> dispose() async {
    disposeCallCount += 1;
    if (nextDisposeException != null) {
      throw nextDisposeException!;
    }
    // Close stream controllers (only once).
    if (!_playerStateController.isClosed) {
      await _playerStateController.close();
    }
    if (!_positionController.isClosed) {
      await _positionController.close();
    }
    if (!_durationController.isClosed) {
      await _durationController.close();
    }
  }

  @override
  Future<void> setLoopModeOff() async {
    setLoopModeOffCallCount += 1;
    if (nextSetLoopModeOffException != null) {
      throw nextSetLoopModeOffException!;
    }
  }

  @override
  Stream<PlaybackPlayerState> get playerStateStream =>
      _playerStateController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  Duration get position => currentPosition;

  @override
  Duration? get duration => currentDuration;

  // ---- test helpers ----

  /// Emit a `playerStateStream` event.
  void emitPlayerState(PlaybackPlayerState state) {
    _playerStateController.add(state);
  }

  /// T031I: emits a `completed` playerStateStream event. When
  /// `simulateRealDeviceLoopAfterCompleted` is `true` AND the
  /// controller has NOT yet driven `playback.stop()` (i.e.
  /// `_stoppedBarrier` is `false`), the fake re-arms the
  /// completed → ready+playing → completed cycle to mirror the
  /// real Android just_audio regression. The cycle is broken as
  /// soon as `playback.stop()` is called (raises `_stoppedBarrier`).
  ///
  /// This is the core T031I risk-simulation helper: tests flip
  /// `simulateRealDeviceLoopAfterCompleted` on and assert that
  /// the controller's `_handleNaturalCompletion` actually drives
  /// `playback.stop()` (otherwise the test would never settle
  /// because the fake keeps re-firing `completed`).
  void _emitCompletedWithOptionalLoop() {
    if (_playerStateController.isClosed) {
      return;
    }
    loopEmittedCompletedCount += 1;
    _playerStateController.add(
      const PlaybackPlayerState(
        playing: false,
        processingState: PlaybackProcessingState.completed,
      ),
    );
    if (!simulateRealDeviceLoopAfterCompleted || _stoppedBarrier) {
      return;
    }
    // Mirror the real-device loop: schedule the next cycle on a
    // fresh event-loop tick so the controller has a chance to
    // react to the first `completed` event (call stop, flip
    // isPlaying, etc.) before the fake re-arms.
    Future<void>.delayed(Duration.zero).then((_) {
      if (_playerStateController.isClosed || _stoppedBarrier) {
        return;
      }
      _playerStateController.add(
        const PlaybackPlayerState(
          playing: true,
          processingState: PlaybackProcessingState.ready,
        ),
      );
      Future<void>.delayed(Duration.zero).then((_) {
        if (_playerStateController.isClosed || _stoppedBarrier) {
          return;
        }
        _emitCompletedWithOptionalLoop();
      });
    });
  }

  /// Emit a `positionStream` event.
  void emitPosition(Duration position) {
    currentPosition = position;
    _positionController.add(position);
  }

  /// Emit a `durationStream` event.
  void emitDuration(Duration? duration) {
    currentDuration = duration;
    _durationController.add(duration);
  }
}
