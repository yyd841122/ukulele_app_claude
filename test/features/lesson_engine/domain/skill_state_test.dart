// Unit tests for the T057 Skill Model (T057_ADAPTIVE_LEARNING_SYSTEM).
//
// Scope:
// - SkillState equality / immutability round-trip.
// - SkillState asserts the axes are in 0.0..1.0.
// - SkillState.withAxis clamps out-of-range values to the
//   legal range.
// - SkillState.initial is the "no evidence" seed.

import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/features/lesson_engine/domain/skill_state.dart';

void main() {
  group('SkillState', () {
    test('equality is value-based', () {
      const SkillState a = SkillState(rhythm: 0.2, chord: 0.4, note: 0.6);
      const SkillState b = SkillState(rhythm: 0.2, chord: 0.4, note: 0.6);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different fields produce non-equal states', () {
      const SkillState a = SkillState(rhythm: 0.2, chord: 0.4, note: 0.6);
      const SkillState b = SkillState(rhythm: 0.2, chord: 0.4, note: 0.7);
      expect(a, isNot(equals(b)));
    });

    test('initial seed is (0, 0, 0)', () {
      expect(SkillState.initial.rhythm, 0.0);
      expect(SkillState.initial.chord, 0.0);
      expect(SkillState.initial.note, 0.0);
    });

    test('overall is the average of the three axes', () {
      const SkillState s = SkillState(rhythm: 0.3, chord: 0.6, note: 0.9);
      expect(s.overall, closeTo(0.6, 1e-9));
    });

    test('withAxis replaces one axis', () {
      const SkillState s = SkillState(rhythm: 0.2, chord: 0.4, note: 0.6);
      final SkillState next = s.withAxis(chord: 0.8);
      expect(next.rhythm, 0.2);
      expect(next.chord, 0.8);
      expect(next.note, 0.6);
      // The original is not mutated.
      expect(s.chord, 0.4);
    });

    test('withAxis clamps out-of-range values to [0.0, 1.0]', () {
      const SkillState s = SkillState(rhythm: 0.2, chord: 0.4, note: 0.6);
      expect(s.withAxis(rhythm: -0.5).rhythm, 0.0);
      expect(s.withAxis(rhythm: 1.5).rhythm, 1.0);
      expect(s.withAxis(chord: -0.1).chord, 0.0);
      expect(s.withAxis(note: 99.0).note, 1.0);
    });

    test('withAxis clamps NaN to 0.0', () {
      const SkillState s = SkillState(rhythm: 0.2, chord: 0.4, note: 0.6);
      final SkillState next = s.withAxis(rhythm: double.nan);
      expect(next.rhythm, 0.0);
    });

    test('constructor asserts axes are in [0.0, 1.0]', () {
      expect(
        () => SkillState(rhythm: -0.1, chord: 0.5, note: 0.5),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => SkillState(rhythm: 1.5, chord: 0.5, note: 0.5),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => SkillState(rhythm: 0.5, chord: double.nan, note: 0.5),
        throwsA(isA<AssertionError>()),
      );
    });

    test('toString includes each axis with two decimals', () {
      const SkillState s = SkillState(rhythm: 0.2, chord: 0.4, note: 0.6);
      final String repr = s.toString();
      expect(repr, contains('0.20'));
      expect(repr, contains('0.40'));
      expect(repr, contains('0.60'));
    });
  });
}