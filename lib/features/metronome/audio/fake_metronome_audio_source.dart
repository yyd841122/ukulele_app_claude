// Fake [MetronomeAudioSource] used by metronome tests.
//
// Lives under `lib/` so both the controller test and the page
// test can `import` it through the public package path. The
// constructor is marked `@visibleForTesting` to make the intent
// obvious and to keep the test-only symbol from leaking into
// production call sites.
//
// The fake records every `playClick` call (with the accent flag)
// so tests can assert exactly when the metronome would have made
// a sound, without ever touching a platform audio channel.

import 'package:flutter/foundation.dart';

import 'package:ukulele_app/features/metronome/audio/metronome_audio_source.dart';

/// In-memory [MetronomeAudioSource] for unit and widget tests.
///
/// `ensureLoaded` increments [ensureLoadedCalls] and resolves
/// immediately. `playClick` appends `(isAccent: ...)` to
/// [recordedCalls]. `dispose` flips [isDisposed] to `true` and
/// resolves.
@visibleForTesting
class FakeMetronomeAudioSource implements MetronomeAudioSource {
  final List<bool> recordedCalls = <bool>[];
  int ensureLoadedCalls = 0;
  bool isDisposed = false;
  bool throwOnPlayClick = false;

  @override
  Future<void> ensureLoaded() async {
    ensureLoadedCalls += 1;
  }

  @override
  Future<void> playClick({required bool isAccent}) async {
    if (throwOnPlayClick) {
      throwOnPlayClick = false; // throw once, then recover
      throw StateError('FakeMetronomeAudioSource: configured to throw');
    }
    recordedCalls.add(isAccent);
  }

  @override
  Future<void> dispose() async {
    isDisposed = true;
  }
}
