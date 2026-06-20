// Tests for [DriftInstallDateService]
// (T013.3_FIX_PENDING_RESULT_AND_INSTALL_DATE_BOUNDARY).
//
// Strategy:
// - The service is wired through a [UserSettingsRepository]. The
//   in-memory implementation
//   ([DriftUserSettingsRepository] against a
//   `NativeDatabase.memory()` executor) is used so tests do not
//   need to mock the Drift table objects. This proves the
//   Repository-only boundary: the service knows nothing about
//   the schema.
// - Each test owns its in-memory database and closes it on
//   teardown. The single-flight guard is reset implicitly by
//   constructing a fresh service per test, so tests cannot
//   leak in-flight writes to each other.
// - Concurrency tests use `Future.wait` to fire N callers
//   simultaneously and assert that only ONE row gets written
//   to the DB — this is the core contract of single-flight.
// - Pre-seed scenarios (e.g. format-exception tests) use the
//   pure-in-memory `_InMemoryUserSettingsRepository` so the
//   pre-seed write is not recorded as a service write.
//
// Timezone contract under test:
// - Strings with `Z` are read as UTC.
// - Strings with an explicit `±HH:MM` offset are converted to
//   UTC.
// - Naive ISO strings (no `Z`, no offset), pure date strings,
//   and unparseable garbage all throw [FormatException].
// - The service can be constructed without an `AppDatabase`
//   (the Repository abstraction is the only required surface).

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/data/database/app_database.dart';
import 'package:ukulele_app/shared/repositories/drift_user_settings_repository.dart';
import 'package:ukulele_app/shared/repositories/user_settings_repository.dart';
import 'package:ukulele_app/shared/services/drift_install_date_service.dart';

void main() {
  ({AppDatabase db, DriftInstallDateService service, _RecordingRepo repo})
      setup({
    DateTime Function()? clock,
  }) {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final _RecordingRepo repo = _RecordingRepo(db);
    final DriftInstallDateService service = DriftInstallDateService(
      repository: repo,
      clock: clock,
    );
    return (db: db, service: service, repo: repo);
  }

  group('DriftInstallDateService', () {
    test('first call persists the current UTC instant', () async {
      final DateTime fixed = DateTime.utc(2026, 6, 20, 9);
      final ({
        AppDatabase db,
        DriftInstallDateService service,
        _RecordingRepo repo,
      }) ctx = setup(
        clock: () => fixed,
      );
      final DateTime result = await ctx.service.getInstallDate();
      expect(result.toUtc(), fixed);
      // The Repository's setValue was called exactly once.
      expect(ctx.repo.writes, hasLength(1));
      expect(ctx.repo.writes.single.key, kInstallDateKey);
      expect(
        ctx.repo.writes.single.value,
        fixed.toIso8601String(),
      );
    });

    test('second call returns the persisted value without rewriting', () async {
      final DateTime first = DateTime.utc(2026, 6, 20, 9);
      final ({
        AppDatabase db,
        DriftInstallDateService service,
        _RecordingRepo repo,
      }) ctx = setup(
        clock: () => first,
      );
      await ctx.service.getInstallDate();
      // Same repo, but a different "now". The service must NOT
      // re-record.
      final DateTime second = DateTime.utc(2026, 6, 21, 12);
      final DriftInstallDateService sameClock = DriftInstallDateService(
        repository: ctx.repo,
        clock: () => second,
      );
      final DateTime result = await sameClock.getInstallDate();
      expect(result.toUtc(), first);
      // Still one write.
      expect(ctx.repo.writes, hasLength(1));
    });

    test(
        'a brand-new service against an existing Repository reads the same date',
        () async {
      final DateTime first = DateTime.utc(2026, 6, 20, 9);
      final ({
        AppDatabase db,
        DriftInstallDateService service,
        _RecordingRepo repo,
      }) ctx = setup(
        clock: () => first,
      );
      await ctx.service.getInstallDate();
      // Second service, same repo (cold-start simulation):
      final DriftInstallDateService fresh = DriftInstallDateService(
        repository: ctx.repo,
      );
      final DateTime result = await fresh.getInstallDate();
      expect(result.toUtc(), first);
    });

    test('concurrent first-launch calls write exactly one row', () async {
      final DateTime fixed = DateTime.utc(2026, 6, 20, 9);
      final ({
        AppDatabase db,
        DriftInstallDateService service,
        _RecordingRepo repo,
      }) ctx = setup(
        clock: () => fixed,
      );
      final List<Future<DateTime>> calls = <Future<DateTime>>[
        for (int i = 0; i < 10; i++) ctx.service.getInstallDate(),
      ];
      final List<DateTime> results = await Future.wait(calls);
      for (final DateTime r in results) {
        expect(r.toUtc(), fixed);
      }
      // ... and only one write happened.
      expect(ctx.repo.writes, hasLength(1));
    });

    test('throws FormatException when the persisted value is not ISO-8601',
        () async {
      // Use the pure-in-memory repo so the pre-seed is
      // distinguishable from a service write.
      final _InMemoryUserSettingsRepository repo =
          _InMemoryUserSettingsRepository();
      final DriftInstallDateService service = DriftInstallDateService(
        repository: repo,
      );
      await repo.setValue(
        key: kInstallDateKey,
        value: 'not-a-date',
        updatedAt: DateTime.utc(2026, 6, 20, 9),
      );
      repo.writes.clear();
      expect(
        () => service.getInstallDate(),
        throwsA(isA<FormatException>()),
      );
      // The bad row is NOT silently overwritten by the service.
      expect(repo.writes, isEmpty);
    });

    test('a failed parse does not leave the single-flight slot stuck',
        () async {
      final _InMemoryUserSettingsRepository repo =
          _InMemoryUserSettingsRepository();
      final DriftInstallDateService service = DriftInstallDateService(
        repository: repo,
      );
      await repo.setValue(
        key: kInstallDateKey,
        value: 'garbage-1',
        updatedAt: DateTime.utc(2026, 6, 20, 9),
      );
      await expectLater(
        service.getInstallDate(),
        throwsA(isA<FormatException>()),
      );
      // Repair the row, then call again — this MUST succeed and
      // return the repaired value.
      await repo.setValue(
        key: kInstallDateKey,
        value: DateTime.utc(2026, 6, 20, 9).toIso8601String(),
        updatedAt: DateTime.utc(2026, 6, 20, 10),
      );
      final DateTime ok = await service.getInstallDate();
      expect(ok.toUtc(), DateTime.utc(2026, 6, 20, 9));
    });

    test('offset ISO (e.g. +08:00) is read as UTC', () async {
      final _InMemoryUserSettingsRepository repo =
          _InMemoryUserSettingsRepository();
      final DriftInstallDateService service = DriftInstallDateService(
        repository: repo,
      );
      // 17:30 in +08:00 == 09:30 UTC. The service MUST return
      // the UTC projection.
      await repo.setValue(
        key: kInstallDateKey,
        value: '2026-06-20T17:30:00+08:00',
        updatedAt: DateTime.utc(2026, 6, 20, 9),
      );
      final DateTime result = await service.getInstallDate();
      expect(result, DateTime.utc(2026, 6, 20, 9, 30));
      expect(result.isUtc, isTrue);
    });

    test('naive ISO without timezone designator is rejected', () async {
      final _InMemoryUserSettingsRepository repo =
          _InMemoryUserSettingsRepository();
      final DriftInstallDateService service = DriftInstallDateService(
        repository: repo,
      );
      await repo.setValue(
        key: kInstallDateKey,
        value: '2026-06-20T09:30:00',
        updatedAt: DateTime.utc(2026, 6, 20, 9),
      );
      expect(
        () => service.getInstallDate(),
        throwsA(isA<FormatException>()),
      );
    });

    test('pure date string is rejected', () async {
      final _InMemoryUserSettingsRepository repo =
          _InMemoryUserSettingsRepository();
      final DriftInstallDateService service = DriftInstallDateService(
        repository: repo,
      );
      await repo.setValue(
        key: kInstallDateKey,
        value: '2026-06-20',
        updatedAt: DateTime.utc(2026, 6, 20, 9),
      );
      expect(
        () => service.getInstallDate(),
        throwsA(isA<FormatException>()),
      );
    });

    test('UTC Z ISO is read as UTC and preserves milliseconds', () async {
      final _InMemoryUserSettingsRepository repo =
          _InMemoryUserSettingsRepository();
      final DriftInstallDateService service = DriftInstallDateService(
        repository: repo,
      );
      final DateTime stamp = DateTime.utc(2026, 6, 20, 9, 30, 45, 123);
      await repo.setValue(
        key: kInstallDateKey,
        value: stamp.toIso8601String(),
        updatedAt: stamp,
      );
      final DateTime result = await service.getInstallDate();
      expect(result, stamp);
      expect(result.isUtc, isTrue);
    });

    test('service is constructible with only a Repository (no AppDatabase)',
        () async {
      // The Repository-only boundary: we hand the service an
      // in-memory Repository (no AppDatabase). The service
      // contract is satisfied by the [UserSettingsRepository]
      // interface alone.
      final _InMemoryUserSettingsRepository repo =
          _InMemoryUserSettingsRepository();
      final DriftInstallDateService service = DriftInstallDateService(
        repository: repo,
      );
      final DateTime result = await service.getInstallDate();
      expect(result.isUtc, isTrue);
      // A second call returns the same persisted value.
      final DateTime again = await service.getInstallDate();
      expect(again, result);
      // Only one write happened.
      expect(repo.writes, hasLength(1));
    });
  });
}

/// In-test wrapper around [DriftUserSettingsRepository] that
/// records every `setValue` call so tests can assert on write
/// count + value.
class _RecordingRepo implements UserSettingsRepository {
  _RecordingRepo(this._db);

  final AppDatabase _db;
  late final DriftUserSettingsRepository _delegate =
      DriftUserSettingsRepository(database: _db);

  /// Every `setValue` call lands here.
  final List<({String key, String value, DateTime updatedAt})> writes =
      <({String key, String value, DateTime updatedAt})>[];

  @override
  Future<String?> getValue(String key) => _delegate.getValue(key);

  @override
  Future<void> setValue({
    required String key,
    required String value,
    required DateTime updatedAt,
  }) async {
    await _delegate.setValue(
      key: key,
      value: value,
      updatedAt: updatedAt,
    );
    writes.add((key: key, value: value, updatedAt: updatedAt));
  }

  @override
  Future<bool> deleteValue(String key) => _delegate.deleteValue(key);
}

/// Pure in-memory [UserSettingsRepository] used by the
/// pre-seeding tests (no Drift / AppDatabase wiring required).
class _InMemoryUserSettingsRepository implements UserSettingsRepository {
  final Map<String, String> _values = <String, String>{};
  final List<({String key, String value, DateTime updatedAt})> writes =
      <({String key, String value, DateTime updatedAt})>[];

  @override
  Future<String?> getValue(String key) async => _values[key];

  @override
  Future<void> setValue({
    required String key,
    required String value,
    required DateTime updatedAt,
  }) async {
    _values[key] = value;
    writes.add((key: key, value: value, updatedAt: updatedAt));
  }

  @override
  Future<bool> deleteValue(String key) async {
    return _values.remove(key) != null;
  }
}
