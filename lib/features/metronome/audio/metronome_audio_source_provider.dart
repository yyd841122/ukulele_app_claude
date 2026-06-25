// Riverpod provider for the metronome audio source (T052).
//
// The default factory wires [JustAudioMetronomeAudioSource] (the
// production just_audio-backed implementation). Tests override this
// provider with a fake via `ProviderScope(overrides: ...)` or
// `ProviderContainer(overrides: ...)`.
//
// Provider lifecycle note:
//   - The provider is intentionally `Provider` (not a `Notifier`)
//     and holds a single long-lived audio source. The metronome
//     controller does not `watch` it — it `read`s it once inside
//     `build()` so the controller does not rebuild on audio
//     source changes (there are none, but the contract is clear).
//   - `ref.onDispose` on the controller, not on the provider,
//     owns the lifecycle of the underlying `AudioPlayer`s; that
//     keeps the source alive for tests that read the provider
//     without spinning up a metronome controller.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/features/metronome/audio/just_audio_metronome_audio_source.dart';
import 'package:ukulele_app/features/metronome/audio/metronome_audio_source.dart';

/// Provides the application-wide [MetronomeAudioSource].
///
/// Default production implementation is [JustAudioMetronomeAudioSource].
/// Tests override this provider with a fake.
final Provider<MetronomeAudioSource> metronomeAudioSourceProvider =
    Provider<MetronomeAudioSource>((Ref ref) {
  return JustAudioMetronomeAudioSource();
});
