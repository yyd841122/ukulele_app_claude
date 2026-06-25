// Riverpod controller for the local visual metronome (T010).
//
// Design notes:
// - The controller uses a hand-written [Notifier] (no `@riverpod`
//   codegen) per the project convention (T007 / T008 / T009).
// - The real-time tick is driven by a `Timer.periodic`. To keep
//   unit tests independent of the real clock, the "advance one
//   beat" logic is exposed as the public [tickForTesting] method.
//   Tests should NEVER sleep — they call [tickForTesting] directly.
// - The timer is created lazily on the first [start]. Repeated
//   [start] calls are no-ops if a timer already exists — the
//   requirement "start 不应重复创建多个 timer" is enforced by
//   checking `_timer != null` before creating a new one.
// - [dispose] cancels the timer and releases it, so navigating away
//   from /metronome (or hot-restarting in tests) cannot leak it.
// - Beats are 1-based (1..beatsPerBar). After the last beat, the
//   next tick wraps to 1. This is a deliberate "musical"
//   convention; tests pin the rule.
// - `stop()` resets `currentBeat` to 1. This is documented in the
//   state docs and pinned by tests — see [stop]. The alternative
//   (leaving the counter where it was) was rejected because it
//   would surprise a beginner tapping "stop" and then "start".
// - Settings are in memory only — see the task brief.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/features/metronome/audio/metronome_audio_source.dart';
import 'package:ukulele_app/features/metronome/audio/metronome_audio_source_provider.dart';
import 'package:ukulele_app/features/metronome/domain/metronome_settings.dart';

/// Default bounds and defaults. Kept at file scope so tests can
/// reference them by name.
const int kMetronomeDefaultBpm = 80;
const int kMetronomeMinBpm = 40;
const int kMetronomeMaxBpm = 200;
const int kMetronomeDefaultBeatsPerBar = 4;

/// Live state of the metronome.
@immutable
class MetronomeState {
  const MetronomeState({
    required this.settings,
    required this.isRunning,
    required this.currentBeat,
    required this.tickCount,
  });

  /// Current user-tunable settings.
  final MetronomeSettings settings;

  /// Whether the periodic timer is active.
  final bool isRunning;

  /// 1-based beat pointer, always in `1..settings.beatsPerBar`.
  final int currentBeat;

  /// Total number of ticks observed since the controller was built.
  /// Useful for tests and for future stats. Independent of
  /// start/stop — it never decreases.
  final int tickCount;

  /// Accent of the *current* beat, derived from `currentBeat`.
  BeatAccent get currentAccent =>
      currentBeat == 1 ? BeatAccent.downbeat : BeatAccent.offbeat;

  /// Convenience: the current BPM.
  int get bpm => settings.bpm;

  /// Convenience: beats per bar.
  int get beatsPerBar => settings.beatsPerBar;

  /// Returns a copy with the given fields replaced. `currentBeat`
  /// is clamped into `1..settings.beatsPerBar` defensively.
  MetronomeState copyWith({
    MetronomeSettings? settings,
    bool? isRunning,
    int? currentBeat,
    int? tickCount,
  }) {
    final MetronomeSettings s = settings ?? this.settings;
    final int nextBeat = (currentBeat ?? this.currentBeat).clamp(
      1,
      s.beatsPerBar,
    );
    return MetronomeState(
      settings: s,
      isRunning: isRunning ?? this.isRunning,
      currentBeat: nextBeat,
      tickCount: tickCount ?? this.tickCount,
    );
  }
}

/// Riverpod notifier for the metronome page.
///
/// The default factory is exposed via [metronomeControllerProvider]
/// below. The class itself is public so tests can construct a
/// throwaway instance and call [tickForTesting] without going
/// through a provider.
class MetronomeController extends Notifier<MetronomeState> {
  Timer? _timer;
  late final MetronomeAudioSource _audioSource;

  @override
  MetronomeState build() {
    // Resolve the audio source via the Provider so tests can
    // override it. We `read` (not `watch`) because the audio
    // source is a long-lived service whose identity never changes.
    _audioSource = ref.read(metronomeAudioSourceProvider);
    // Re-arm cleanup: when the provider is disposed (e.g. the page
    // pops), cancel the timer and release the audio source.
    ref.onDispose(_cancelTimer);
    ref.onDispose(() {
      // `dispose()` is documented as idempotent on the audio
      // source, so calling it here twice (if a test also tears
      // the provider down) is safe.
      unawaited(_audioSource.dispose());
    });
    return MetronomeState(
      settings: const MetronomeSettings(
        bpm: kMetronomeDefaultBpm,
        minBpm: kMetronomeMinBpm,
        maxBpm: kMetronomeMaxBpm,
        beatsPerBar: kMetronomeDefaultBeatsPerBar,
        soundEnabled: false,
      ),
      isRunning: false,
      currentBeat: 1,
      tickCount: 0,
    );
  }

  /// Starts the periodic timer. No-op if already running — this
  /// guarantees the "do not create multiple timers" requirement.
  void start() {
    if (_timer != null) {
      return;
    }
    state = state.copyWith(isRunning: true);
    _timer = Timer.periodic(_intervalFor(state.bpm), (_) => _advance());
  }

  /// Stops the timer and resets [currentBeat] to 1. The reset
  /// rule is part of the contract — see file docs and tests.
  void stop() {
    _cancelTimer();
    state = state.copyWith(
      isRunning: false,
      currentBeat: 1,
    );
  }

  /// Toggles between [start] and [stop].
  void toggleRunning() {
    if (state.isRunning) {
      stop();
    } else {
      start();
    }
  }

  /// Sets the BPM, clamped into `minBpm..maxBpm`. If the metronome
  /// is running, the timer is restarted with the new interval so
  /// the tempo change takes effect on the next tick.
  void setBpm(int bpm) {
    final int clamped = state.settings.clampBpm(bpm);
    final bool wasRunning = state.isRunning;
    if (wasRunning) {
      _cancelTimer();
    }
    state = state.copyWith(settings: state.settings.copyWith(bpm: clamped));
    if (wasRunning) {
      _timer = Timer.periodic(
        _intervalFor(state.bpm),
        (_) => _advance(),
      );
    }
  }

  /// Increments BPM by 1, clamped. Convenience for the +/- buttons.
  void increaseBpm() => setBpm(state.bpm + 1);

  /// Decrements BPM by 1, clamped.
  void decreaseBpm() => setBpm(state.bpm - 1);

  /// Sets beats-per-bar. Values outside
  /// [MetronomeSettings.allowedBeatsPerBar] are ignored, leaving
  /// state unchanged — the "非法 beatsPerBar 不应破坏状态" rule.
  void setBeatsPerBar(int beats) {
    if (!MetronomeSettings.isAllowedBeatsPerBar(beats)) {
      return;
    }
    state = state.copyWith(
      settings: state.settings.copyWith(beatsPerBar: beats),
      // If `currentBeat` was at the new max, clamp it back into
      // range. `copyWith` already does this defensively.
      currentBeat: state.currentBeat,
    );
  }

  /// Toggles the `soundEnabled` flag. With no audio backend
  /// wired in T010, the visual page treats both values the same;
  /// the flag is stored so a future task can read it.
  void toggleSoundEnabled() {
    state = state.copyWith(
      settings: state.settings.copyWith(
        soundEnabled: !state.settings.soundEnabled,
      ),
    );
  }

  /// Public test entry point: advance the metronome by one beat
  /// without involving a real `Timer`. Unit tests use this
  /// exclusively — they never call [start] and never sleep.
  ///
  /// Visible for testing; the page itself should not call it.
  @visibleForTesting
  void tickForTesting() => _advance();

  /// Internal "advance one beat" logic. Updates `currentBeat`
  /// (wrap to 1 after the last beat) and increments `tickCount`.
  /// If the user has enabled the audible click, also fires a
  /// single click on the audio source — accent is the *new*
  /// current beat, not the previous one.
  void _advance() {
    final int next =
        state.currentBeat >= state.beatsPerBar ? 1 : state.currentBeat + 1;
    state = state.copyWith(
      currentBeat: next,
      tickCount: state.tickCount + 1,
    );
    _maybePlayClick(isAccent: next == 1);
  }

  /// Fires an audible click iff the user has enabled sound.
  /// Fire-and-forget — the metronome does not await playback
  /// completion; the next Timer tick can overlap a still-playing
  /// click because the click is shorter than the inter-tick gap
  /// even at the maximum BPM (200 BPM → 300 ms period; click is
  /// 20 ms). Errors are swallowed on purpose: a misbehaving
  /// audio source must not break beat progression, and the page
  /// will still show the visual beat indicator.
  void _maybePlayClick({required bool isAccent}) {
    if (!state.settings.soundEnabled) {
      return;
    }
    // We do not await — the audio engine runs in its own
    // microtask and the metronome must keep advancing on time.
    unawaited(
      _audioSource.playClick(isAccent: isAccent).catchError((Object _) {
        // Swallow: audio is best-effort, the visual beat remains
        // the source of truth for the user.
      }),
    );
  }

  /// The [Duration] between two consecutive ticks for the given
  /// BPM. `Duration` does not support fractional milliseconds, so
  /// we round to the nearest millisecond — at 200 BPM the period
  /// is 300ms anyway, so the rounding error is at most ~1ms.
  Duration _intervalFor(int bpm) {
    final double ms = 60000.0 / bpm;
    return Duration(milliseconds: ms.round());
  }

  /// Cancels the periodic timer if it exists. Idempotent.
  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Provider for the metronome page controller.
final NotifierProvider<MetronomeController, MetronomeState>
    metronomeControllerProvider =
    NotifierProvider<MetronomeController, MetronomeState>(
  MetronomeController.new,
);
