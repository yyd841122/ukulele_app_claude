// Tests for [PracticeRecord]'s audioFilePath contract (T032).
//
// Why this file exists:
// - T013.1 reserved `audio_file_path` as nullable in the Drift
//   schema, but the production Repository path was never wired
//   into the real-audio pipeline (T031 only just plugged in the
//   real recorder).
// - T032 is the first task that pins a *behavioural* contract on
//   the domain model: the field is **nullable, default null**,
//   round-trips verbatim, and the constructor accepts the path
//   without normalising it. This test pins that contract from
//   the domain side; the Repository / Drift tests pin it from
//   the persistence side.
//
// What is NOT in scope here:
// - File-system checks (does the path point to a real file?).
//   T033 owns the AudioFileStorageService / recorder → path
//   association; this test deliberately does not depend on it.
// - Path sanitisation (does the path look like a recording
//   path?). Same reason — T033 / T034 own path safety.
// - The mapper / Repository behaviour. Those have their own
//   dedicated tests in `drift_practice_record_repository_test.dart`
//   and `practice_record_detail_test.dart`.

import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/features/practice_records/domain/practice_record.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_tag.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_type.dart';

void main() {
  group('PracticeRecord.audioFilePath', () {
    test(
        'default value is null when the constructor is called without '
        'passing audioFilePath', () {
      // T032 contract pin: PracticeRecord.audioFilePath is nullable
      // and defaults to null. Old records (saved before T031 wired
      // the real recorder) survive the v1 → v2 schema upgrade with
      // audioFilePath = null; this is the same null the domain
      // produces when a caller forgets to specify the path.
      final PracticeRecord record = PracticeRecord(
        id: 'rec-default',
        practiceDate: DateTime(2026, 6, 22),
        dayIndex: 1,
        primaryPracticeType: PracticeType.singleNote,
        practiceTags: const <PracticeTag>[],
        practiceContent: 'no audio attached',
        durationSeconds: 10,
        isCompleted: false,
        createdAt: DateTime.utc(2026, 6, 22, 9),
        updatedAt: DateTime.utc(2026, 6, 22, 9),
      );
      expect(record.audioFilePath, isNull,
          reason: 'default audioFilePath must be null so callers '
              'do not need to pass it explicitly');
    });

    test(
        'constructor accepts a non-null audio path and stores it verbatim '
        'without normalisation', () {
      // T032 contract pin: the path is stored as-is. No trimming,
      // no platform-separator rewriting, no canonicalisation.
      // Path safety / sanitisation belongs to T033+
      // (AudioFileStorageService); T032 explicitly does not
      // validate or rewrite the path.
      const String path = 'saved/2026-06-22/uuid-here.m4a';
      final PracticeRecord record = PracticeRecord(
        id: 'rec-with-path',
        practiceDate: DateTime(2026, 6, 22),
        dayIndex: 3,
        primaryPracticeType: PracticeType.recording,
        practiceTags: const <PracticeTag>[PracticeTag.recording],
        practiceContent: 'real audio take',
        durationSeconds: 30,
        isCompleted: true,
        audioFilePath: path,
        createdAt: DateTime.utc(2026, 6, 22, 9),
        updatedAt: DateTime.utc(2026, 6, 22, 9),
      );
      expect(record.audioFilePath, path,
          reason: 'audioFilePath must be stored verbatim');
    });

    test(
        'constructor accepts an empty string without throwing '
        '(caller-supplied invalid input is allowed in T032)', () {
      // T032 explicitly does NOT validate the audioFilePath value.
      // Empty / malformed paths are the responsibility of the
      // AudioFileStorageService (T033+). The domain model itself
      // does not throw on empty-string input — that is by design.
      // This test pins the "no validation" contract so future
      // refactors do not accidentally introduce strict validation
      // here before the storage layer is ready to handle it.
      final PracticeRecord record = PracticeRecord(
        id: 'rec-empty-path',
        practiceDate: DateTime(2026, 6, 22),
        dayIndex: 1,
        primaryPracticeType: PracticeType.recording,
        practiceTags: const <PracticeTag>[],
        practiceContent: 'placeholder',
        durationSeconds: 0,
        isCompleted: false,
        audioFilePath: '',
        createdAt: DateTime.utc(2026, 6, 22, 9),
        updatedAt: DateTime.utc(2026, 6, 22, 9),
      );
      expect(record.audioFilePath, '');
    });

    test(
        'two PracticeRecord instances with the same audioFilePath but '
        'different IDs are NOT equal (id is part of identity)', () {
      // The existing `==` operator includes `audioFilePath`, so a
      // path-only match does not imply full equality. This pins
      // the equality contract so a future change to the operator
      // does not silently break identity checks elsewhere.
      final PracticeRecord a = PracticeRecord(
        id: 'rec-a',
        practiceDate: DateTime(2026, 6, 22),
        dayIndex: 1,
        primaryPracticeType: PracticeType.recording,
        practiceTags: const <PracticeTag>[],
        practiceContent: 'a',
        durationSeconds: 10,
        isCompleted: false,
        audioFilePath: 'same/path.m4a',
        createdAt: DateTime.utc(2026, 6, 22, 9),
        updatedAt: DateTime.utc(2026, 6, 22, 9),
      );
      final PracticeRecord b = PracticeRecord(
        id: 'rec-b',
        practiceDate: DateTime(2026, 6, 22),
        dayIndex: 1,
        primaryPracticeType: PracticeType.recording,
        practiceTags: const <PracticeTag>[],
        practiceContent: 'b',
        durationSeconds: 10,
        isCompleted: false,
        audioFilePath: 'same/path.m4a',
        createdAt: DateTime.utc(2026, 6, 22, 9),
        updatedAt: DateTime.utc(2026, 6, 22, 9),
      );
      expect(a, isNot(equals(b)),
          reason: 'PracticeRecord equality must include id, '
              'not just audioFilePath');
      expect(a.hashCode, isNot(equals(b.hashCode)));
    });

    test(
        'two PracticeRecord instances differing only in audioFilePath '
        '(null vs string) are NOT equal', () {
      // Pins the `==` operator's handling of the nullable
      // audioFilePath field: null vs a non-null path is a
      // meaningful difference and must show up in equality.
      final PracticeRecord nullPath = PracticeRecord(
        id: 'rec-eq',
        practiceDate: DateTime(2026, 6, 22),
        dayIndex: 1,
        primaryPracticeType: PracticeType.recording,
        practiceTags: const <PracticeTag>[],
        practiceContent: 'x',
        durationSeconds: 10,
        isCompleted: false,
        audioFilePath: null,
        createdAt: DateTime.utc(2026, 6, 22, 9),
        updatedAt: DateTime.utc(2026, 6, 22, 9),
      );
      final PracticeRecord stringPath = PracticeRecord(
        id: 'rec-eq',
        practiceDate: DateTime(2026, 6, 22),
        dayIndex: 1,
        primaryPracticeType: PracticeType.recording,
        practiceTags: const <PracticeTag>[],
        practiceContent: 'x',
        durationSeconds: 10,
        isCompleted: false,
        audioFilePath: 'a/b.m4a',
        createdAt: DateTime.utc(2026, 6, 22, 9),
        updatedAt: DateTime.utc(2026, 6, 22, 9),
      );
      expect(nullPath, isNot(equals(stringPath)),
          reason: 'null vs non-null audioFilePath must compare unequal');
    });
  });
}
