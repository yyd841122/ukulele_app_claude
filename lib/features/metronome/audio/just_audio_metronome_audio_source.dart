// Production [MetronomeAudioSource] backed by `just_audio ^0.10.5`
// (T052 / TDD §6.2.2).
//
// Why two [AudioPlayer] instances and not one?
//   - We pre-load two distinct assets: a higher-pitched click for
//     the downbeat and a lower-pitched click for the offbeats.
//   - Calling `setAsset` on a single player for every click would
//     re-decode the asset on every tick, adding tens of milliseconds
//     of jitter at high BPMs.
//   - With two players we just `seek(Duration.zero)` + `play()`,
//     which is the recommended fast-path in just_audio's docs.
//
// The constructor does not touch the platform channel — it only
// allocates the Dart-side `AudioPlayer` wrappers — so the Provider
// is safe to construct in `flutter test`. The first call to
// `ensureLoaded()` or `playClick()` would, however, hit the
// platform channel and surface `MissingPluginException`; tests
// therefore inject a [FakeMetronomeAudioSource] instead.

import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'package:ukulele_app/features/metronome/audio/metronome_audio_source.dart';

/// JustAudio-backed metronome click source. Plays the high pitch
/// click for downbeats and the low pitch click for offbeats.
class JustAudioMetronomeAudioSource implements MetronomeAudioSource {
  JustAudioMetronomeAudioSource({
    AudioPlayer? highPlayer,
    AudioPlayer? lowPlayer,
  })  : _highPlayer = highPlayer ?? AudioPlayer(),
        _lowPlayer = lowPlayer ?? AudioPlayer();

  static const String highAsset = 'assets/audio/metronome_click_high.wav';
  static const String lowAsset = 'assets/audio/metronome_click_low.wav';

  final AudioPlayer _highPlayer;
  final AudioPlayer _lowPlayer;

  Future<void>? _loadFuture;
  bool _disposed = false;

  @override
  Future<void> ensureLoaded() {
    // Coalesce concurrent callers. The first call performs the
    // actual `setAsset`; later calls await the same future.
    return _loadFuture ??= _doLoad();
  }

  Future<void> _doLoad() async {
    // Pin LoopMode.off (T031E contract — see
    // lib/shared/services/audio_playback_gateway.dart).
    await _highPlayer.setLoopMode(LoopMode.off);
    await _lowPlayer.setLoopMode(LoopMode.off);
    await _highPlayer.setAsset(highAsset);
    await _lowPlayer.setAsset(lowAsset);
  }

  @override
  Future<void> playClick({required bool isAccent}) async {
    if (_disposed) {
      return;
    }
    // Preload on first use so callers do not have to call
    // `ensureLoaded()` themselves. Errors here (e.g. asset missing
    // on a misconfigured build) surface as a thrown exception —
    // we intentionally do not swallow them.
    await ensureLoaded();
    final AudioPlayer player = isAccent ? _highPlayer : _lowPlayer;
    // Restart from the beginning each time so the click is always
    // heard from t=0, never mid-tail of a previous click.
    await player.seek(Duration.zero);
    await player.play();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    // `AudioPlayer.dispose()` is idempotent per just_audio docs.
    await _highPlayer.dispose();
    await _lowPlayer.dispose();
  }
}
