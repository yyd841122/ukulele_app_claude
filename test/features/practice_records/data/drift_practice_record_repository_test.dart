// Tests for [DriftPracticeRecordRepository] (T013.2, T032).
//
// Strategy:
// - Each test gets its own `AppDatabase.forTesting(...)` so the
//   schema starts empty. We use `addTearDown(db.close)` so each
//   test cleans up after itself (the database is *not* owned by
//   any provider in this task — the calling test owns its life
//   cycle).
// - Tests pin a deterministic UTC clock via the repository's
//   optional `clock` parameter. `createdAt` / `updatedAt` are then
//   reproducible across runs.
// - We assert on the *domain* `PracticeRecord`, not on the Drift
//   generated row class, to make sure the Repository is the only
//   place that converts `PracticeType` / `PracticeTag` /
//   `SelfAssessment` / JSON ↔ the typed values.
//
// T013.2_FIX_REPOSITORY_SCOPE_AND_CONTRACTS additions:
// - `practiceTags` immutability is pinned end-to-end: a caller that
//   mutates the input list after the Repository accepts it must NOT
//   see the change reflected on the stored record.
// - The watch subscription test exercises the *live* stream —
//   subscribe first, then insert / delete, and verify subsequent
//   emissions. `take(1)` is not used to validate post-subscribe
//   state.
// - `_decode` must always return `createdAt` / `updatedAt` with
//   `isUtc == true`.
//
// T032_REAL_AUDIO_PRACTICE_RECORD_SCHEMA_UPGRADE additions:
// - New "audioFilePath (T032)" group pins the persistence-layer
//   contract for the audio path field:
//     * round-trips verbatim (no normalisation),
//     * null round-trips as null,
//     * visible on listRecent / watchAll,
//     * delete() does NOT touch the audio file on disk — that
//       is T034's responsibility, and the Repository is a pure
//       persistence boundary.

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/data/database/app_database.dart';
import 'package:ukulele_app/features/practice_records/data/drift_practice_record_repository.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_record.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_tag.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_type.dart';
import 'package:ukulele_app/features/practice_records/domain/self_assessment.dart';

void main() {
  /// Builds a fresh in-memory database + repository with a pinned
  /// clock. Returns the trio so tests can poke at the database
  /// directly (e.g. to plant corrupt rows).
  ({AppDatabase db, DriftPracticeRecordRepository repo}) setup({
    DateTime? now,
  }) {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final DriftPracticeRecordRepository repo = DriftPracticeRecordRepository(
      database: db,
      clock: () => now ?? DateTime.utc(2026, 6, 20, 9, 30),
    );
    return (db: db, repo: repo);
  }

  /// A clock that ticks forward by 1s on each invocation. Used by
  /// the ordering test so that `createdAt` differs between rows
  /// inserted via the same repository. (Drift stores DateTime
  /// columns as integer seconds, so a 1ms increment would not
  /// produce distinguishable timestamps at the SQLite layer.)
  ({AppDatabase db, DriftPracticeRecordRepository repo}) setupIncrementing() {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    int n = 0;
    final DriftPracticeRecordRepository repo = DriftPracticeRecordRepository(
      database: db,
      clock: () => DateTime.utc(2026, 6, 20, 9).add(Duration(seconds: n++)),
    );
    return (db: db, repo: repo);
  }

  // Shared collector for the watchAll post-subscribe test. Reset
  // per-test via `setUp` so cross-test bleed is impossible.
  late List<List<PracticeRecord>> emissions;
  setUp(() {
    emissions = <List<PracticeRecord>>[];
  });

  /// Polls [emissions] until it reaches [hasLength] entries.
  /// Drift's watch streams are async; the test driver must wait
  /// for the table-update notification to round-trip before
  /// asserting on the latest emission.
  Future<void> waitForEmissions(
    List<List<PracticeRecord>> emissions, {
    required int hasLength,
  }) async {
    final DateTime deadline = DateTime.now().add(const Duration(seconds: 2));
    while (emissions.length < hasLength) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Timed out waiting for emission #$hasLength '
            '(saw ${emissions.length})');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  group('DriftPracticeRecordRepository.insert', () {
    test('round-trips a fully-populated record', () async {
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup(now: DateTime.utc(2026, 6, 20, 9, 30));
      final DateTime practiceDate = DateTime(2026, 6, 20);

      final PracticeRecord input = PracticeRecord(
        id: 'rec-1',
        practiceDate: practiceDate,
        dayIndex: 1,
        primaryPracticeType: PracticeType.singleNote,
        practiceTags: <PracticeTag>[PracticeTag.tuner, PracticeTag.metronome],
        practiceContent: 'Day 1: 单音 C/E 练习',
        durationSeconds: 60,
        isCompleted: true,
        selfAssessment: SelfAssessment.good,
        audioFilePath: 'recordings/x.m4a',
        createdAt: DateTime.utc(2026, 6, 20, 9, 0),
        updatedAt: DateTime.utc(2026, 6, 20, 9, 0),
      );

      final PracticeRecord inserted = await ctx.repo.insert(input);

      // `createdAt` / `updatedAt` are stamped by the repository.
      expect(inserted.createdAt, DateTime.utc(2026, 6, 20, 9, 30));
      expect(inserted.updatedAt, DateTime.utc(2026, 6, 20, 9, 30));

      final PracticeRecord? roundTripped = await ctx.repo.getById('rec-1');
      expect(roundTripped, isNotNull);
      // Field-by-field comparison. The Repository's UTC contract
      // guarantees `createdAt` / `updatedAt` come back with
      // `isUtc == true`, so `==` works against the in-memory
      // `inserted` value.
      expect(roundTripped!.id, inserted.id);
      expect(roundTripped.practiceDate, inserted.practiceDate);
      expect(roundTripped.dayIndex, inserted.dayIndex);
      expect(roundTripped.primaryPracticeType, inserted.primaryPracticeType);
      expect(roundTripped.practiceTags, inserted.practiceTags);
      expect(roundTripped.practiceContent, inserted.practiceContent);
      expect(roundTripped.durationSeconds, inserted.durationSeconds);
      expect(roundTripped.isCompleted, inserted.isCompleted);
      expect(roundTripped.selfAssessment, inserted.selfAssessment);
      expect(roundTripped.audioFilePath, inserted.audioFilePath);
      expect(roundTripped.createdAt, inserted.createdAt);
      expect(roundTripped.updatedAt, inserted.updatedAt);
      // UTC contract: both fields must be flagged `isUtc == true`
      // even though drift can return the column with `isUtc == false`.
      expect(roundTripped.createdAt.isUtc, isTrue);
      expect(roundTripped.updatedAt.isUtc, isTrue);
      expect(roundTripped.practiceDate, DateTime(2026, 6, 20));
      expect(roundTripped.primaryPracticeType, PracticeType.singleNote);
      expect(
        roundTripped.practiceTags,
        equals(<PracticeTag>[PracticeTag.tuner, PracticeTag.metronome]),
      );
      expect(roundTripped.selfAssessment, SelfAssessment.good);
      expect(roundTripped.audioFilePath, 'recordings/x.m4a');
    });

    test('round-trips nullable fields (no tags, no assessment, no audio)',
        () async {
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup();
      final PracticeRecord input = PracticeRecord(
        id: 'rec-min',
        practiceDate: DateTime(2026, 6, 21),
        dayIndex: 2,
        primaryPracticeType: PracticeType.metronome,
        practiceTags: const <PracticeTag>[],
        practiceContent: 'Day 2: 节拍器 80 BPM',
        durationSeconds: 30,
        isCompleted: false,
        selfAssessment: null,
        audioFilePath: null,
        createdAt: DateTime.utc(2026, 6, 21, 8),
        updatedAt: DateTime.utc(2026, 6, 21, 8),
      );

      final PracticeRecord inserted = await ctx.repo.insert(input);
      final PracticeRecord? roundTripped = await ctx.repo.getById('rec-min');

      // Field-by-field comparison (see the other test's note).
      expect(roundTripped, isNotNull);
      expect(roundTripped!.id, inserted.id);
      expect(roundTripped.practiceDate, inserted.practiceDate);
      expect(roundTripped.dayIndex, inserted.dayIndex);
      expect(roundTripped.primaryPracticeType, inserted.primaryPracticeType);
      expect(roundTripped.practiceTags, inserted.practiceTags);
      expect(roundTripped.practiceContent, inserted.practiceContent);
      expect(roundTripped.durationSeconds, inserted.durationSeconds);
      expect(roundTripped.isCompleted, inserted.isCompleted);
      expect(roundTripped.selfAssessment, inserted.selfAssessment);
      expect(roundTripped.audioFilePath, inserted.audioFilePath);
      expect(roundTripped.practiceTags, isEmpty);
      expect(roundTripped.selfAssessment, isNull);
      expect(roundTripped.audioFilePath, isNull);
      expect(roundTripped.isCompleted, isFalse);
    });

    test('practiceDate is normalised to local midnight', () async {
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup();
      await ctx.repo.insert(
        _record(id: 'rec-mid', practiceDate: DateTime(2026, 6, 20, 14, 23)),
      );
      final PracticeRecord? stored = await ctx.repo.getById('rec-mid');
      expect(stored!.practiceDate, DateTime(2026, 6, 20));
      expect(stored.practiceDate.hour, 0);
      expect(stored.practiceDate.minute, 0);
      expect(stored.practiceDate.second, 0);
    });

    test('rejects empty id', () async {
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup();
      expect(
        () => ctx.repo.insert(_record(id: '')),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects empty practiceContent', () async {
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup();
      expect(
        () => ctx.repo.insert(_record(practiceContent: '')),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects dayIndex < 1', () async {
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup();
      expect(
        () => ctx.repo.insert(_record(dayIndex: 0)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects dayIndex > 7', () async {
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup();
      expect(
        () => ctx.repo.insert(_record(dayIndex: 8)),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects negative durationSeconds', () async {
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup();
      expect(
        () => ctx.repo.insert(_record(durationSeconds: -1)),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('PracticeRecord immutability', () {
    test(
        'caller mutation of input practiceTags does not leak into the stored '
        'record (insert path)', () async {
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup();
      final List<PracticeTag> tags = <PracticeTag>[PracticeTag.tuner];
      final PracticeRecord input = PracticeRecord(
        id: 'imm-1',
        practiceDate: DateTime(2026, 6, 20),
        dayIndex: 1,
        primaryPracticeType: PracticeType.singleNote,
        practiceTags: tags,
        practiceContent: 'immutability check',
        durationSeconds: 10,
        isCompleted: false,
        createdAt: DateTime.utc(2026, 6, 20, 9),
        updatedAt: DateTime.utc(2026, 6, 20, 9),
      );

      final PracticeRecord inserted = await ctx.repo.insert(input);

      // The list is unmodifiable from the caller's perspective.
      expect(
        () => inserted.practiceTags.add(PracticeTag.metronome),
        throwsUnsupportedError,
      );
      expect(
        () => inserted.practiceTags.clear(),
        throwsUnsupportedError,
      );
      // The original input list was captured by reference; mutating
      // it after the insert must NOT retroactively change the
      // stored record.
      tags.add(PracticeTag.recording);
      tags.add(PracticeTag.selfAssessment);

      final PracticeRecord? roundTripped = await ctx.repo.getById('imm-1');
      expect(roundTripped, isNotNull);
      expect(
        roundTripped!.practiceTags,
        equals(<PracticeTag>[PracticeTag.tuner]),
      );
    });

    test('inserted.practiceTags is unmodifiable (write attempt throws)',
        () async {
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup();
      final PracticeRecord input = PracticeRecord(
        id: 'imm-2',
        practiceDate: DateTime(2026, 6, 20),
        dayIndex: 1,
        primaryPracticeType: PracticeType.singleNote,
        practiceTags: <PracticeTag>[PracticeTag.tuner, PracticeTag.metronome],
        practiceContent: 'immutability check 2',
        durationSeconds: 10,
        isCompleted: false,
        createdAt: DateTime.utc(2026, 6, 20, 9),
        updatedAt: DateTime.utc(2026, 6, 20, 9),
      );
      final PracticeRecord inserted = await ctx.repo.insert(input);
      expect(
        () => inserted.practiceTags.add(PracticeTag.recording),
        throwsUnsupportedError,
      );
    });

    test('round-tripped record also exposes unmodifiable practiceTags',
        () async {
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup();
      final PracticeRecord input = PracticeRecord(
        id: 'imm-3',
        practiceDate: DateTime(2026, 6, 20),
        dayIndex: 1,
        primaryPracticeType: PracticeType.singleNote,
        practiceTags: <PracticeTag>[PracticeTag.tuner],
        practiceContent: 'immutability check 3',
        durationSeconds: 10,
        isCompleted: false,
        createdAt: DateTime.utc(2026, 6, 20, 9),
        updatedAt: DateTime.utc(2026, 6, 20, 9),
      );
      await ctx.repo.insert(input);
      final PracticeRecord? stored = await ctx.repo.getById('imm-3');
      expect(stored, isNotNull);
      expect(
        () => stored!.practiceTags.add(PracticeTag.recording),
        throwsUnsupportedError,
      );
    });
  });

  group('DriftPracticeRecordRepository.getById', () {
    test('returns null for unknown id', () async {
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup();
      expect(await ctx.repo.getById('not-there'), isNull);
    });

    test('rejects empty id', () async {
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup();
      expect(
        () => ctx.repo.getById(''),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('DriftPracticeRecordRepository.listRecent', () {
    test('orders by practiceDate DESC, createdAt DESC', () async {
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setupIncrementing();
      // Three records; the timestamps vary on both axes.
      await ctx.repo.insert(
        _record(
          id: 'a',
          practiceDate: DateTime(2026, 6, 18),
        ),
      );
      await ctx.repo.insert(
        _record(
          id: 'b',
          practiceDate: DateTime(2026, 6, 20),
        ),
      );
      await ctx.repo.insert(
        _record(
          id: 'c',
          practiceDate: DateTime(2026, 6, 20),
          // Same day as `b` but later createdAt → comes first.
        ),
      );

      final List<PracticeRecord> rows = await ctx.repo.listRecent();
      expect(
        rows.map((PracticeRecord r) => r.id).toList(),
        equals(<String>['c', 'b', 'a']),
      );
    });

    test('honours the limit parameter', () async {
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup();
      for (int i = 0; i < 5; i++) {
        await ctx.repo.insert(
          _record(id: 'r$i', practiceDate: DateTime(2026, 6, 20 - i)),
        );
      }
      final List<PracticeRecord> rows = await ctx.repo.listRecent(limit: 2);
      expect(rows, hasLength(2));
      expect(
        rows.map((PracticeRecord r) => r.id).toList(),
        equals(<String>['r0', 'r1']),
      );
    });

    test('rejects limit <= 0', () async {
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup();
      expect(
          () => ctx.repo.listRecent(limit: 0), throwsA(isA<ArgumentError>()));
    });
  });

  group('DriftPracticeRecordRepository.watchAll', () {
    test('emits the full list ordered like listRecent', () async {
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup(now: DateTime.utc(2026, 6, 20, 10));
      await ctx.repo
          .insert(_record(id: 'x', practiceDate: DateTime(2026, 6, 18)));
      await ctx.repo
          .insert(_record(id: 'y', practiceDate: DateTime(2026, 6, 20)));

      final List<List<PracticeRecord>> initialEmissions =
          await ctx.repo.watchAll().take(1).toList();
      expect(initialEmissions, hasLength(1));
      expect(
        initialEmissions.single.map((PracticeRecord r) => r.id).toList(),
        equals(<String>['y', 'x']),
      );
    });

    test('emits post-subscribe inserts and deletes', () async {
      // T013.2_FIX_REPOSITORY_SCOPE_AND_CONTRACTS: subscribe
      // first (empty DB), then drive writes and assert each
      // emission's contents. `take(1)` is only used to consume the
      // very first empty emission, not to short-circuit the test.
      // We poll the shared `emissions` list (rather than relying
      // on `Future.delayed`) so the test is robust against
      // scheduling jitter.
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup();

      final StreamSubscription<List<PracticeRecord>> sub =
          ctx.repo.watchAll().listen((List<PracticeRecord> rows) {
        emissions.add(List<PracticeRecord>.unmodifiable(rows));
      });
      addTearDown(sub.cancel);

      // First emission: empty.
      await waitForEmissions(emissions, hasLength: 1);
      expect(emissions.single, isEmpty);

      // Insert one row — wait for the next emission.
      await ctx.repo.insert(_record(id: 'after-1'));
      await waitForEmissions(emissions, hasLength: 2);
      expect(
        emissions[1].map((PracticeRecord r) => r.id).toList(),
        equals(<String>['after-1']),
      );

      // Insert another — wait for the next emission.
      await ctx.repo.insert(_record(id: 'after-2'));
      await waitForEmissions(emissions, hasLength: 3);
      expect(
        emissions[2].map((PracticeRecord r) => r.id).toList(),
        equals(<String>['after-1', 'after-2']),
      );

      // Delete — wait for the next emission.
      await ctx.repo.delete('after-1');
      await waitForEmissions(emissions, hasLength: 4);
      expect(
        emissions[3].map((PracticeRecord r) => r.id).toList(),
        equals(<String>['after-2']),
      );
    });
  });

  group('DriftPracticeRecordRepository.delete', () {
    test('removes the row and returns true', () async {
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup();
      await ctx.repo.insert(_record(id: 'rec-del'));
      expect(await ctx.repo.delete('rec-del'), isTrue);
      expect(await ctx.repo.getById('rec-del'), isNull);
    });

    test('returns false when nothing matched', () async {
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup();
      expect(await ctx.repo.delete('nope'), isFalse);
    });

    test('rejects empty id', () async {
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup();
      expect(() => ctx.repo.delete(''), throwsA(isA<ArgumentError>()));
    });
  });

  group('DriftPracticeRecordRepository.decode (corrupt data)', () {
    test('throws on unknown PracticeType string', () async {
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup();
      await _plantRaw(
        ctx.db,
        id: 'bad-type',
        primaryPracticeType: 'not-a-real-type',
      );
      expect(
        () => ctx.repo.getById('bad-type'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on unknown SelfAssessment string', () async {
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup();
      await _plantRaw(
        ctx.db,
        id: 'bad-sa',
        selfAssessment: 'not-real',
      );
      expect(
        () => ctx.repo.getById('bad-sa'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on unknown PracticeTag inside the JSON array', () async {
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup();
      await _plantRaw(
        ctx.db,
        id: 'bad-tag',
        practiceTagsJson: '["tuner","not-a-real-tag"]',
      );
      expect(
        () => ctx.repo.getById('bad-tag'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws on corrupt (non-JSON) practiceTagsJson', () async {
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup();
      await _plantRaw(
        ctx.db,
        id: 'bad-json',
        practiceTagsJson: 'not json',
      );
      expect(
        () => ctx.repo.getById('bad-json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws when practiceTagsJson is a JSON object (not array)', () async {
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup();
      await _plantRaw(
        ctx.db,
        id: 'bad-shape',
        practiceTagsJson: '{"tuner":true}',
      );
      expect(
        () => ctx.repo.getById('bad-shape'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  // -----------------------------------------------------------------
  // T032_REAL_AUDIO_PRACTICE_RECORD_SCHEMA_UPGRADE — explicit
  // audioFilePath coverage on the persistence boundary.
  //
  // The "round-trips a fully-populated record" group above already
  // covers `audioFilePath == 'recordings/x.m4a'` and the "round-trips
  // nullable fields" group covers `audioFilePath == null`. The
  // tests below pin the specific T032 contract points that the
  // detail / list / migration tests rely on:
  //
  //   - Repository.decode(DB null)  → domain null
  //   - Repository.decode(DB string) → domain string (verbatim)
  //   - Repository does NOT validate / normalise the path
  //   - Repository.delete does NOT touch the audio file (the
  //     audio file lifecycle is owned by T034; the Repository
  //     here MUST stay a pure persistence boundary)
  // -----------------------------------------------------------------

  group('DriftPracticeRecordRepository audioFilePath (T032)', () {
    test(
        'insert + getById round-trips a non-null audioFilePath verbatim '
        '(no normalisation, no trimming)', () async {
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup();
      const String path = 'saved/2026-06-22/rec-with-path.m4a';
      await ctx.repo.insert(
        _record(
          id: 'rec-with-path',
          audioFilePath: path,
          primaryPracticeType: PracticeType.recording,
        ),
      );
      final PracticeRecord? stored = await ctx.repo.getById('rec-with-path');
      expect(stored, isNotNull);
      expect(stored!.audioFilePath, path,
          reason: 'audioFilePath must round-trip verbatim — the '
              'Repository must not normalise the path');
    });

    test(
        'insert + getById round-trips audioFilePath = null '
        '(DB null → domain null)', () async {
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup();
      await ctx.repo.insert(
        _record(id: 'rec-no-audio', audioFilePath: null),
      );
      final PracticeRecord? stored = await ctx.repo.getById('rec-no-audio');
      expect(stored, isNotNull);
      expect(stored!.audioFilePath, isNull,
          reason: 'audioFilePath must round-trip null verbatim');
    });

    test(
        'listRecent / watchAll surface audioFilePath from every row '
        '(string and null paths both visible)', () async {
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup();
      await ctx.repo.insert(
        _record(
          id: 'rec-list-1',
          audioFilePath: 'saved/2026-06-22/one.m4a',
          primaryPracticeType: PracticeType.recording,
        ),
      );
      await ctx.repo.insert(
        _record(
          id: 'rec-list-2',
          audioFilePath: null,
          primaryPracticeType: PracticeType.recording,
        ),
      );

      // listRecent
      final List<PracticeRecord> list = await ctx.repo.listRecent();
      expect(list, hasLength(2));
      final Map<String, String?> byId = <String, String?>{
        for (final PracticeRecord r in list) r.id: r.audioFilePath,
      };
      expect(byId['rec-list-1'], 'saved/2026-06-22/one.m4a');
      expect(byId['rec-list-2'], isNull);

      // watchAll — verify the stream surfaces the same shapes.
      final List<List<PracticeRecord>> emissions =
          await ctx.repo.watchAll().take(1).toList();
      expect(emissions, hasLength(1));
      final List<PracticeRecord> snapshot = emissions.single;
      expect(snapshot, hasLength(2));
      final Map<String, String?> watchById = <String, String?>{
        for (final PracticeRecord r in snapshot) r.id: r.audioFilePath,
      };
      expect(watchById['rec-list-1'], 'saved/2026-06-22/one.m4a');
      expect(watchById['rec-list-2'], isNull);
    });

    test(
        'delete() removes only the DB row — it MUST NOT touch any audio '
        'file on disk (T032 contract; the audio file lifecycle is '
        'T034\'s responsibility)', () async {
      // Plant a real file at a known temp path. The Repository
      // has no File / Directory dependency — this test pins
      // "Repository does not delete the audio file" by checking
      // the file is still on disk after the DB row is removed.
      final Directory tempDir =
          await Directory.systemTemp.createTemp('t032_repo_delete_');
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final File fakeAudio = File('${tempDir.path}/saved/rec.m4a')
        ..createSync(recursive: true);
      await fakeAudio.writeAsBytes(<int>[0, 1, 2, 3]);

      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup();
      await ctx.repo.insert(
        _record(
          id: 'rec-del-audio',
          audioFilePath: fakeAudio.path,
        ),
      );
      // Sanity: the file is on disk before delete.
      expect(await fakeAudio.exists(), isTrue);

      final bool deleted = await ctx.repo.delete('rec-del-audio');
      expect(deleted, isTrue);
      // The DB row is gone.
      expect(await ctx.repo.getById('rec-del-audio'), isNull);
      // The audio file MUST still be on disk — the Repository
      // does not own the file lifecycle. T034 will wire
      // "delete row → delete file" at a higher layer.
      expect(await fakeAudio.exists(), isTrue,
          reason: 'Repository.delete must not touch audio files on disk '
              '— that is T034\'s responsibility');
    });

    test(
        'audioFilePath is exposed on the returned PracticeRecord from '
        'insert() so the caller can inspect the value that was persisted',
        () async {
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup();
      const String path = 'saved/2026-06-22/returned.m4a';
      final PracticeRecord inserted = await ctx.repo.insert(
        _record(
          id: 'rec-returned',
          audioFilePath: path,
        ),
      );
      // The contract: the value the Repository returned is the
      // value it actually persisted. If the Repository were to
      // silently coerce the path (e.g. to null), the caller
      // would never know.
      expect(inserted.audioFilePath, path);
    });

    test(
        'audioFilePath is NOT validated — empty string survives '
        'insert + read back unchanged (T033 owns real validation)', () async {
      // T032 explicitly does NOT validate the audioFilePath. Empty
      // strings are accepted because (a) the storage layer is
      // still T033 / T034 work, (b) the Repository contract today
      // is "store the value the caller passed".
      final ({AppDatabase db, DriftPracticeRecordRepository repo}) ctx =
          setup();
      await ctx.repo.insert(
        _record(id: 'rec-empty-audio-path', audioFilePath: ''),
      );
      final PracticeRecord? stored =
          await ctx.repo.getById('rec-empty-audio-path');
      expect(stored, isNotNull);
      expect(stored!.audioFilePath, '');
    });
  });
}

// ----- helpers -----

PracticeRecord _record({
  String id = 'rec',
  DateTime? practiceDate,
  int dayIndex = 1,
  PracticeType primaryPracticeType = PracticeType.singleNote,
  List<PracticeTag> practiceTags = const <PracticeTag>[],
  String practiceContent = 'placeholder content',
  int durationSeconds = 10,
  bool isCompleted = false,
  SelfAssessment? selfAssessment,
  String? audioFilePath,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return PracticeRecord(
    id: id,
    practiceDate: practiceDate ?? DateTime(2026, 6, 20),
    dayIndex: dayIndex,
    primaryPracticeType: primaryPracticeType,
    practiceTags: practiceTags,
    practiceContent: practiceContent,
    durationSeconds: durationSeconds,
    isCompleted: isCompleted,
    selfAssessment: selfAssessment,
    audioFilePath: audioFilePath,
    createdAt: createdAt ?? DateTime.utc(2026, 6, 20, 9),
    updatedAt: updatedAt ?? DateTime.utc(2026, 6, 20, 9),
  );
}

/// Plants a raw row bypassing the Repository's validation. Used
/// only by the "decode" tests that need to plant corrupt rows.
Future<void> _plantRaw(
  AppDatabase db, {
  required String id,
  String primaryPracticeType = 'singleNote',
  String practiceTagsJson = '[]',
  String? selfAssessment,
  DateTime? practiceDate,
  DateTime? createdAt,
  DateTime? updatedAt,
}) async {
  final DateTime pd = practiceDate ?? DateTime(2026, 6, 20);
  final DateTime ca = createdAt ?? DateTime.utc(2026, 6, 20, 9);
  final DateTime ua = updatedAt ?? DateTime.utc(2026, 6, 20, 9);
  await db.into(db.practiceRecords).insert(
        PracticeRecordsCompanion.insert(
          id: id,
          practiceDate: pd,
          dayIndex: 1,
          primaryPracticeType: primaryPracticeType,
          practiceTagsJson: practiceTagsJson,
          practiceContent: 'planted row',
          durationSeconds: 10,
          selfAssessment: selfAssessment == null
              ? const Value.absent()
              : Value<String>(selfAssessment),
          createdAt: ca,
          updatedAt: ua,
        ),
      );
}
