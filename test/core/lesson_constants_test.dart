// Tests for the built-in lesson constants (T043).
//
// These tests pin the C↔Am 4/4 down-strum lesson payload so a
// future copy change cannot silently drift the rhythm away from
// `docs/learning/lesson_c_am_down_4x4.md` (which is the
// authoritative content source).

import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/core/constants/lesson_constants.dart';

void main() {
  group('kBuiltInLessons', () {
    test('contains exactly one C↔Am lesson with id "c_am_down_4x4"', () {
      expect(kBuiltInLessons, hasLength(1));
      expect(kBuiltInLessons.first.id, 'c_am_down_4x4');
    });

    test('C↔Am lesson layers on day4_chord_switch only', () {
      final Lesson lesson = kBuiltInLessons.first;
      expect(lesson.linkedTaskIds, <String>['day4_chord_switch']);
    });

    test(
        'C↔Am lesson strumPattern pins 4 beats, down-only, '
        'chord sequence [C, C, Am, Am]', () {
      final StrumPattern pattern = kBuiltInLessons.first.strumPattern;
      expect(pattern.beatsPerMeasure, 4);
      expect(pattern.direction, StrumDirection.down);
      expect(pattern.chordSequencePerBeat, <String>['C', 'C', 'Am', 'Am']);
      // Length invariant — defends against off-by-one typos in
      // the chord sequence.
      expect(pattern.chordSequencePerBeat.length, pattern.beatsPerMeasure);
    });

    test('C↔Am lesson steps are ordered 1..N with no gaps and N >= 3', () {
      final List<LessonStep> steps = kBuiltInLessons.first.steps;
      expect(steps.length, greaterThanOrEqualTo(3));
      for (int i = 0; i < steps.length; i++) {
        expect(steps[i].order, i + 1,
            reason: 'step order must be 1-based and contiguous');
      }
    });

    test(
        'C↔Am lesson steps include a 60 BPM warmup and an 80 BPM '
        'target step', () {
      final List<LessonStep> steps = kBuiltInLessons.first.steps;
      final List<int> bpms =
          steps.map((LessonStep s) => s.bpm).whereType<int>().toList();
      expect(bpms, containsAll(<int>[60, 80]));
    });
  });
}
