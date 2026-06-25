// Metronome audio source abstraction (T052 / TDD §6.2.2).
//
// The metronome controller depends on this interface, not on a
// concrete audio engine. Production wires [JustAudioMetronomeAudioSource];
// tests inject a fake to keep `flutter test` free of platform
// channels. The contract is intentionally minimal so it stays
// implementation-agnostic (just_audio today, but the controller
// does not care).

/// Plays a single percussive click for one metronome beat.
///
/// Implementations are expected to be cheap to construct (no
/// platform channel work in the constructor) so the
/// [metronomeAudioSourceProvider] can be overridden in tests
/// without a real player attached.
abstract class MetronomeAudioSource {
  /// Preload the click assets so that the first [playClick] call
  /// does not have to wait for asset decoding. Safe to call more
  /// than once — subsequent calls are no-ops once loaded.
  Future<void> ensureLoaded();

  /// Trigger a single click. [isAccent] distinguishes the downbeat
  /// (first beat of a bar) from the offbeats. Implementations are
  /// allowed to be fire-and-forget — the metronome does not await
  /// the future and tolerates overlapping calls.
  Future<void> playClick({required bool isAccent});

  /// Release any resources held by the source. Must be idempotent
  /// (Riverpod may invoke it more than once during teardown).
  Future<void> dispose();
}
