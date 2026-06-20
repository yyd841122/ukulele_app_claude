// Tests for the built-in standard ukulele tuning data.
//
// T011 scope:
// - Verify G / C / E / A are all present in the built-in library.
// - Verify internal [stringNumber] semantics are still T008 /
//   T009 carry-over: 1 = A, 2 = E, 3 = C, 4 = G.
// - Verify the *display* order is G, C, E, A.
// - Verify every entry passes structural validation
//   ([TuningString.validate]).
// - Verify no user-facing string contains misleading pitch-order
//   words: "lowest / highest / 最低 / 最高 / 最细 / 最粗".
// - Verify the data does not expose a frequency / cents / pitch
//   field — i.e. we did NOT secretly wire up a real tuner
//   model.

import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/features/tuner/data/standard_ukulele_tuning.dart';
import 'package:ukulele_app/features/tuner/domain/tuning_string.dart';

void main() {
  group('kBuiltInTuningStrings', () {
    test('contains exactly four entries', () {
      expect(kBuiltInTuningStrings.length, 4);
    });

    test('contains the G / C / E / A notes', () {
      final List<String> names =
          kBuiltInTuningStrings.map((TuningString s) => s.stringName).toList();
      expect(names, containsAll(<String>['G', 'C', 'E', 'A']));
    });

    test('internal stringNumber semantics are 1=A, 2=E, 3=C, 4=G', () {
      // Direct lookup so a typo in the constants is caught by
      // CI rather than by a beginner at 23:00.
      expect(findBuiltInTuningString(1)?.stringName, 'A');
      expect(findBuiltInTuningString(2)?.stringName, 'E');
      expect(findBuiltInTuningString(3)?.stringName, 'C');
      expect(findBuiltInTuningString(4)?.stringName, 'G');
    });

    test('every entry passes structural validation', () {
      for (final TuningString s in kBuiltInTuningStrings) {
        expect(s.validate(), isNull,
            reason: 'stringNumber=${s.stringNumber} failed: ${s.validate()}');
      }
    });

    test('every entry has a non-empty description, tip and mistake', () {
      for (final TuningString s in kBuiltInTuningStrings) {
        expect(s.description, isNotEmpty);
        expect(s.beginnerTip, isNotEmpty);
        expect(s.commonMistake, isNotEmpty);
        expect(s.displayName, isNotEmpty);
      }
    });
  });

  group('Display order', () {
    test('kTuningStringDisplayOrder is G, C, E, A (4, 3, 2, 1)', () {
      expect(kTuningStringDisplayOrder, <int>[4, 3, 2, 1]);
    });

    test('tuningStringsInDisplayOrder returns G, C, E, A', () {
      final List<TuningString> ordered = tuningStringsInDisplayOrder();
      expect(ordered.length, 4);
      expect(ordered.map((TuningString s) => s.stringName).toList(),
          <String>['G', 'C', 'E', 'A']);
      expect(
        ordered.map((TuningString s) => s.stringNumber).toList(),
        <int>[4, 3, 2, 1],
      );
    });
  });

  group('Misleading pitch-order copy is forbidden', () {
    // The brief explicitly bans words like "lowest / highest /
    // 最低 / 最高 / 最细 / 最粗" because on a re-entrant high-G
    // ukulele the pitch walk is non-monotonic. We pin every
    // user-facing field on every entry.
    test('no entry mentions lowest / highest / 最低 / 最高 / 最细 / 最粗', () {
      const List<String> banned = <String>[
        'lowest',
        'highest',
        'low',
        'high',
        '最低',
        '最高',
        '最细',
        '最粗',
      ];
      for (final TuningString s in kBuiltInTuningStrings) {
        for (final String field in <String>[
          s.displayName,
          s.description,
          s.beginnerTip,
          s.commonMistake,
        ]) {
          final String lower = field.toLowerCase();
          for (final String word in banned) {
            expect(
              lower.contains(word.toLowerCase()),
              isFalse,
              reason:
                  'stringNumber=${s.stringNumber} field "$field" contains banned word "$word"',
            );
          }
        }
      }
    });
  });

  group('No real-tuner fields are exposed', () {
    test('TuningString does NOT carry a frequency or cents field', () {
      // Pin the model shape: a future contributor who tries to
      // add a "real" tuner model will have to add a new class
      // and update the brief — and that should fail loudly in
      // review, not silently pass this test.
      const TuningString s = TuningString(
        stringNumber: 1,
        stringName: 'A',
        displayName: '1 弦 · A',
        description: '',
        beginnerTip: '',
        commonMistake: '',
      );
      expect(s.toString(), isNot(contains('Hz')));
      expect(s.toString(), isNot(contains('cents')));
      expect(s.toString(), isNot(contains('frequency')));
    });
  });

  group('findBuiltInTuningString', () {
    test('returns null for unknown stringNumbers', () {
      expect(findBuiltInTuningString(0), isNull);
      expect(findBuiltInTuningString(-1), isNull);
      expect(findBuiltInTuningString(5), isNull);
      expect(findBuiltInTuningString(99), isNull);
    });

    test('returns the matching entry for known stringNumbers', () {
      for (final int n in const <int>[1, 2, 3, 4]) {
        final TuningString? s = findBuiltInTuningString(n);
        expect(s, isNotNull, reason: 'no entry for stringNumber=$n');
        expect(s!.stringNumber, n);
      }
    });
  });
}
