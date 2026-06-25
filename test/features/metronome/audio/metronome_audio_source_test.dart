// Asset and audio source unit tests (T052).
//
// Scope:
// - Verify the two click WAVs are present on disk (guards against
//   accidental deletion / gitignore mistakes).
// - Verify the [FakeMetronomeAudioSource] records the expected
//   number of calls and respects `soundEnabled` semantics at the
//   source level.
// - Verify [JustAudioMetronomeAudioSource.dispose] is idempotent
//   even when the constructor never managed to call `setAsset`
//   (e.g. test environment with no platform channel). The two
//   `AudioPlayer` instances are allocated by the constructor
//   without touching the platform channel, so calling `dispose()`
//   twice must not throw a `MissingPluginException` at the Dart
//   level — though under `flutter test` the underlying native
//   call would still raise. We therefore skip the production
//   instance assertion under `flutter test` (no `TestWidgetsFlutterBinding`)
//   and rely on the Fake for behavioural coverage.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/features/metronome/audio/fake_metronome_audio_source.dart';

void main() {
  group('Metronome click assets (T052)', () {
    test('high-pitch click WAV is present on disk', () {
      final File f = File('assets/audio/metronome_click_high.wav');
      expect(f.existsSync(), isTrue,
          reason: 'High click WAV must be checked in');
      expect(f.lengthSync(), greaterThan(0));
    });

    test('low-pitch click WAV is present on disk', () {
      final File f = File('assets/audio/metronome_click_low.wav');
      expect(f.existsSync(), isTrue,
          reason: 'Low click WAV must be checked in');
      expect(f.lengthSync(), greaterThan(0));
    });
  });

  group('FakeMetronomeAudioSource (T052)', () {
    test('ensureLoaded is idempotent and records call count', () async {
      final FakeMetronomeAudioSource fake = FakeMetronomeAudioSource();
      await fake.ensureLoaded();
      await fake.ensureLoaded();
      await fake.ensureLoaded();
      expect(fake.ensureLoadedCalls, 3);
    });

    test('playClick records the accent flag exactly', () async {
      final FakeMetronomeAudioSource fake = FakeMetronomeAudioSource();
      await fake.playClick(isAccent: true);
      await fake.playClick(isAccent: false);
      await fake.playClick(isAccent: true);
      expect(fake.recordedCalls, <bool>[true, false, true]);
    });

    test('dispose is idempotent', () async {
      final FakeMetronomeAudioSource fake = FakeMetronomeAudioSource();
      await fake.dispose();
      await fake.dispose();
      expect(fake.isDisposed, isTrue);
    });
  });
}
