// Domain model for the local visual metronome (T010).
//
// Scope:
// - Settings (BPM, beats-per-bar, sound flag) are kept in memory only.
//   No Drift, no SharedPreferences, no network — see the task brief
//   §边界限制.
// - A [MetronomeSettings] is an immutable snapshot; the live
//   [MetronomeState] in the controller carries a copy and updates it
//   through `copyWith`.
// - The accent of the *current* beat ([BeatAccent]) is derived, not
//   stored, because it is a function of `currentBeat` and
//   `beatsPerBar`. Storing the accent on the state object would mean
//   keeping two fields in sync.

import 'package:flutter/foundation.dart';

/// User-tunable parameters of the metronome. The controller owns a
/// mutable copy; consumers should treat instances as snapshots.
@immutable
class MetronomeSettings {
  const MetronomeSettings({
    required this.bpm,
    required this.minBpm,
    required this.maxBpm,
    required this.beatsPerBar,
    required this.soundEnabled,
  });

  /// Beats per minute. Always in `minBpm..maxBpm`.
  final int bpm;

  /// Lower clamp for [bpm].
  final int minBpm;

  /// Upper clamp for [bpm].
  final int maxBpm;

  /// Beats per bar (top number of the time signature). Always one of
  /// [MetronomeSettings.allowedBeatsPerBar].
  final int beatsPerBar;

  /// Whether the user has asked for a real audio click. The MVP
  /// ships with no audio backend, so the page is required to
  /// explain this in the UI. The field is kept on the state so a
  /// future task can wire it to `flutter_audio_capture` / a tone
  /// generator without changing the public controller API.
  final bool soundEnabled;

  /// The beats-per-bar values the UI exposes. Anything outside this
  /// set is rejected by [copyWith].
  static const List<int> allowedBeatsPerBar = <int>[2, 3, 4, 6];

  /// Returns `true` iff [b] is one of the allowed beats-per-bar
  /// values.
  static bool isAllowedBeatsPerBar(int b) =>
      allowedBeatsPerBar.contains(b);

  /// Clamps [value] into `minBpm..maxBpm`. The clamp bounds are the
  /// *destination* settings' bounds, which lets the helper work for
  /// both the existing instance and an upcoming one.
  int clampBpm(int value) {
    if (value < minBpm) {
      return minBpm;
    }
    if (value > maxBpm) {
      return maxBpm;
    }
    return value;
  }

  /// Returns a copy with the given fields replaced. Values that
  /// fall outside the allowed range are coerced silently — this
  /// matches the controller's invariants and keeps the page from
  /// having to clamp on every keystroke.
  MetronomeSettings copyWith({
    int? bpm,
    int? beatsPerBar,
    bool? soundEnabled,
    int? minBpm,
    int? maxBpm,
  }) {
    final int newMin = minBpm ?? this.minBpm;
    final int newMax = maxBpm ?? this.maxBpm;
    final int newBpm = (bpm ?? this.bpm).clamp(newMin, newMax);
    final int newBeats = beatsPerBar ?? this.beatsPerBar;
    return MetronomeSettings(
      bpm: newBpm,
      minBpm: newMin,
      maxBpm: newMax,
      beatsPerBar:
          isAllowedBeatsPerBar(newBeats) ? newBeats : this.beatsPerBar,
      soundEnabled: soundEnabled ?? this.soundEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetronomeSettings &&
          other.bpm == bpm &&
          other.minBpm == minBpm &&
          other.maxBpm == maxBpm &&
          other.beatsPerBar == beatsPerBar &&
          other.soundEnabled == soundEnabled);

  @override
  int get hashCode => Object.hash(
        bpm,
        minBpm,
        maxBpm,
        beatsPerBar,
        soundEnabled,
      );
}

/// Accent of the *current* beat. Derived, not stored — see file
/// docs.
enum BeatAccent {
  /// The first beat of a bar. UI shows "重拍".
  downbeat,

  /// Any non-first beat. UI shows "轻拍".
  offbeat,
}
