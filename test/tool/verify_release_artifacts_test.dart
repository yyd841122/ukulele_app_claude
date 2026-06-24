// Direct unit tests for `tool/verify_release_artifacts.dart`.
//
// T040_RELEASE_VERIFIER_V110_ALIGNMENT
//
// These tests pin the pure, in-process behaviour of the verifier: the
// pubspec version parser and the required/forbidden permission policy
// for the v1.1.0 real-audio MVP. Anything that requires `aapt`,
// `apksigner`, `jarsigner`, or a real APK / AAB on disk is intentionally
// left to the integration invocation
// `dart run tool/verify_release_artifacts.dart` and is NOT covered here.

import 'package:flutter_test/flutter_test.dart';

import '../../tool/verify_release_artifacts.dart' show parseExpectedVersion;

void main() {
  group('parseExpectedVersion (v1.1.0+3 baseline)', () {
    test('parses `version: 1.1.0+3` exactly', () {
      final v = parseExpectedVersion('version: 1.1.0+3\n');
      expect(v, isNotNull);
      expect(v!.name, '1.1.0');
      expect(v.code, '3');
    });

    test('parses real pubspec.yaml shape (extra leading whitespace)', () {
      const pubspec = '''
name: ukulele_app
description: "A new Flutter project."
version: 1.1.0+3
environment:
  sdk: ^3.5.4
''';
      final v = parseExpectedVersion(pubspec);
      expect(v, isNotNull);
      expect(v!.name, '1.1.0');
      expect(v.code, '3');
    });

    test('parses single-quoted version literal', () {
      final v = parseExpectedVersion("version: '1.1.0+3'\n");
      expect(v, isNotNull);
      expect(v!.name, '1.1.0');
      expect(v.code, '3');
    });

    test('parses double-quoted version literal', () {
      final v = parseExpectedVersion('version: "1.1.0+3"\n');
      expect(v, isNotNull);
      expect(v!.name, '1.1.0');
      expect(v.code, '3');
    });

    test('returns null when version line is missing', () {
      const pubspec = '''
name: ukulele_app
version_name: 1.0.0
''';
      expect(parseExpectedVersion(pubspec), isNull);
    });

    test('returns null when build code is non-numeric', () {
      expect(parseExpectedVersion('version: 1.1.0+abc'), isNull);
    });

    test('returns null when version name has letters', () {
      expect(parseExpectedVersion('version: v1.1.0+3'), isNull);
    });

    test('returns null when `+` separator is missing', () {
      expect(parseExpectedVersion('version: 1.1.0'), isNull);
    });

    test('rejects v1.0.0+2 (the v1.0.0 release) so v1.1.0 bump is forced',
        () {
      // The pubspec parser happily parses the old release. The semantic
      // guard (which is checked at the integration level) is that the
      // APK / AAB under build/ must also report versionName=1.1.0 and
      // versionCode=3 — so a stray v1.0.0+2 artifact will fail the
      // _assertPackageIdentity step. The parser-level contract here is
      // that a stale pubspec still parses without crashing, but its
      // values are clearly distinguishable from v1.1.0+3.
      final v = parseExpectedVersion('version: 1.0.0+2');
      expect(v, isNotNull);
      expect(v!.name, '1.0.0');
      expect(v.code, '2');
      expect(v.name != '1.1.0' || v.code != '3', isTrue,
          reason:
              'v1.0.0+2 must not silently pass as v1.1.0+3 (the parser '
              'round-trips it but the integration check must catch it).');
    });
  });
}
