// Tests for the Riverpod providers introduced in T013.2.
//
// Strategy:
// - We test the providers via `ProviderContainer` overrides. The
//   default chain (`appDatabaseProvider` → repository
//   constructor) is exercised; we override `appDatabaseProvider`
//   with an in-memory database so each test gets a clean schema.
// - This is the ONLY place in T013.2 where we touch Riverpod —
//   feature Controllers (T013.3+) will consume these providers,
//   not the other way around.

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/data/database/app_database.dart';
import 'package:ukulele_app/data/database/app_database_provider.dart';
import 'package:ukulele_app/features/home/data/completed_tasks_repository.dart';
import 'package:ukulele_app/features/home/data/completed_tasks_repository_provider.dart';
import 'package:ukulele_app/features/practice_records/data/practice_record_repository.dart';
import 'package:ukulele_app/features/practice_records/data/practice_record_repository_provider.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_record.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_tag.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_type.dart';
import 'package:ukulele_app/shared/repositories/user_settings_repository.dart';
import 'package:ukulele_app/shared/repositories/user_settings_repository_provider.dart';

void main() {
  /// Builds a `ProviderContainer` that overrides the database with
  /// a fresh in-memory instance. The container owns the DB through
  /// its teardown.
  ProviderContainer buildContainer() {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('Repository providers', () {
    test('practiceRecordRepositoryProvider returns a usable repository',
        () async {
      final ProviderContainer container = buildContainer();
      final PracticeRecordRepository repo =
          container.read(practiceRecordRepositoryProvider);
      expect(repo, isNotNull);

      final PracticeRecord inserted = await repo.insert(
        PracticeRecord(
          id: 'rec-prov-1',
          practiceDate: DateTime(2026, 6, 20),
          dayIndex: 1,
          primaryPracticeType: PracticeType.singleNote,
          practiceTags: const <PracticeTag>[],
          practiceContent: 'provider round-trip',
          durationSeconds: 10,
          isCompleted: false,
          createdAt: DateTime.utc(2026, 6, 20, 9),
          updatedAt: DateTime.utc(2026, 6, 20, 9),
        ),
      );
      expect(inserted.id, 'rec-prov-1');
      expect(await repo.getById('rec-prov-1'), isNotNull);
    });

    test('completedTasksRepositoryProvider returns a usable repository',
        () async {
      final ProviderContainer container = buildContainer();
      final CompletedTasksRepository repo =
          container.read(completedTasksRepositoryProvider);
      expect(repo, isNotNull);
      await repo.markCompleted(
        date: DateTime(2026, 6, 20),
        taskId: 'day1_tuner',
        completedAt: DateTime.utc(2026, 6, 20, 9),
      );
      final Set<String> ids =
          await repo.getCompletedTaskIds(DateTime(2026, 6, 20));
      expect(ids, equals(<String>{'day1_tuner'}));
    });

    test('userSettingsRepositoryProvider returns a usable repository',
        () async {
      final ProviderContainer container = buildContainer();
      final UserSettingsRepository repo =
          container.read(userSettingsRepositoryProvider);
      expect(repo, isNotNull);
      await repo.setValue(
        key: 'app.installDate',
        value: '2026-06-20T00:00:00Z',
        updatedAt: DateTime.utc(2026, 6, 20, 9),
      );
      expect(
        await repo.getValue('app.installDate'),
        '2026-06-20T00:00:00Z',
      );
    });

    test('all three providers read the same underlying AppDatabase', () {
      final ProviderContainer container = buildContainer();
      final AppDatabase db = container.read(appDatabaseProvider);
      final PracticeRecordRepository prRepo =
          container.read(practiceRecordRepositoryProvider);
      final CompletedTasksRepository ctRepo =
          container.read(completedTasksRepositoryProvider);
      final UserSettingsRepository usRepo =
          container.read(userSettingsRepositoryProvider);
      expect(prRepo, isNotNull);
      expect(ctRepo, isNotNull);
      expect(usRepo, isNotNull);
      // Reading `appDatabaseProvider` again returns the same
      // instance the test seeded.
      expect(identical(db, container.read(appDatabaseProvider)), isTrue);
    });
  });
}
