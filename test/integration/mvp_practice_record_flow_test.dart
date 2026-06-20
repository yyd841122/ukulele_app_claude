// T014_MVP_PRACTICE_RECORD_FLOW_INTEGRATION
//
// End-to-end (vertical) integration test for the MVP practice
// record flow. The test mounts the real production `appRouter`
// and the real production pages, wired against a real in-memory
// Drift database, and exercises the user-visible flow:
//
//   模拟录音
//   -> 保存 PracticeRecord
//   -> 记录列表自动显示
//   -> 打开记录详情
//   -> 删除记录
//   -> 返回空列表
//
// This test is intentionally distinct from the per-feature
// widget tests in `test/features/...`:
//
//   * It uses the *real* `appRouter` (not a test-only
//     GoRouter fixture), so the /recording, /records and
//     /records/:recordId routes are exactly the ones shipped
//     to production.
//   * It does NOT mock the `PracticeRecordRepository`. The
//     Repository is the production `DriftPracticeRecordRepository`
//     wired against an in-memory `AppDatabase`.
//   * It does NOT directly call any Drift table or DAO. All
//     persistence goes through the real Repository. The final
//     state assertion re-reads the row through
//     `PracticeRecordRepository.getById` (not through a Drift
//     table access).
//   * The only allowed overrides are time / id sources and
//     the in-memory database instance — every other Provider
//     resolves to its production default.
//
// Allowed overrides (per task brief):
//   * `appDatabaseProvider`               -> in-memory DB
//   * `appClockProvider`                  -> pinned clock
//   * `installDateServiceProvider`        -> pinned install date
//   * `practiceRecordIdGeneratorProvider` -> deterministic id
//
// All resources are disposed through `addTearDown`. The test
// never `sleep`s, never depends on real wall-clock time, and
// never relies on a random UUID's specific value (the generator
// returns a valid UUID v4 — see _SequentialIdGenerator).
//
// IMPORTANT: this file is the ONLY new test file created for
// T014. It contributes a single `testWidgets` block. The
// baseline before this task was 397; after this task it is
// 398 (397 + 1 - 0).

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:uuid/uuid.dart';

import 'package:ukulele_app/app/app.dart';
import 'package:ukulele_app/data/database/app_database.dart';
import 'package:ukulele_app/data/database/app_database_provider.dart';
import 'package:ukulele_app/features/practice_records/application/practice_record_id_generator.dart';
import 'package:ukulele_app/features/practice_records/data/practice_record_repository.dart';
import 'package:ukulele_app/features/practice_records/data/practice_record_repository_provider.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_record.dart';
import 'package:ukulele_app/features/recording/domain/self_rating.dart';
import 'package:ukulele_app/shared/providers/app_clock_provider.dart';
import 'package:ukulele_app/shared/repositories/drift_user_settings_repository.dart';
import 'package:ukulele_app/shared/services/drift_install_date_service.dart';
import 'package:ukulele_app/shared/services/install_date_service.dart';
import 'package:ukulele_app/shared/services/install_date_service_provider.dart';

void main() {
  // The home page + detail page both render localised dates.
  // intl needs explicit data in a unit test environment.
  setUpAll(() async {
    await initializeDateFormatting('zh_CN');
  });

  testWidgets(
    'mvp vertical flow: record -> save -> list -> detail -> delete '
    '-> empty list',
    (WidgetTester tester) async {
      // Use a tall surface so the recording page (disclaimer +
      // status + timer + controls + rating + note + save) fits
      // without scrolling.
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      // Pinned "now" — 2026-06-20 12:00 LOCAL noon. Using
      // local-noon guarantees the local-midnight projection
      // is 2026-06-20 regardless of the test host timezone
      // (any zone from UTC-11 to UTC+11 lands on 2026-06-20).
      final DateTime fixedNow = DateTime(2026, 6, 20, 12, 0);
      // Pinned install date — 2026-06-19 12:00 UTC noon. Using
      // UTC-noon guarantees the local-midnight projection is
      // 2026-06-19 regardless of the test host timezone (any
      // zone from UTC-11 to UTC+11 lands on 2026-06-19).
      // With fixedNow and install date on the previous local
      // midnight, `calculatePracticeDayIndex` returns
      // ((1) % 7) + 1 = 2.
      final DateTime fixedInstallInstant = DateTime.utc(2026, 6, 19, 12, 0);

      // 1. Build the in-memory AppDatabase. The DriftPracticeRecord
      //    Repository will write to this database; the
      //    DriftInstallDateService will read the install date
      //    through the same database.
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      // 1a. Pre-seed the install date BEFORE the app boots. We
      //     write the ISO-8601 UTC string directly through the
      //     UserSettingsRepository so the first call to
      //     `getInstallDate()` returns the pinned instant
      //     regardless of the `DriftInstallDateService.clock`
      //     override (which would otherwise stamp the current
      //     instant on first read and overwrite our pin).
      final DriftUserSettingsRepository userSettingsRepository =
          DriftUserSettingsRepository(database: db);
      await userSettingsRepository.setValue(
        key: 'app.installDate',
        value: fixedInstallInstant.toIso8601String(),
        updatedAt: fixedInstallInstant,
      );

      // 2. Wire the real DriftInstallDateService against the
      //    same in-memory DB so the install date is read from
      //    user_settings (not path_provider). The clock here is
      //    only consulted if the row is missing — we pre-seeded
      //    it above, so the clock is never actually used.
      final InstallDateService installService = DriftInstallDateService(
        repository: userSettingsRepository,
        clock: () => fixedNow,
      );

      // 3. Build a deterministic id generator. The takeId
      //    generated for this take is what we will later assert
      //    equals the record's id.
      const String kDeterministicTakeId =
          '00000000-0000-4000-8000-000000000001';
      final _FixedIdGenerator idGenerator =
          _FixedIdGenerator(kDeterministicTakeId);

      // 4. Build the production router-backed app shell.
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            // The real production AppDatabase is the in-memory
            // test instance. Every downstream Provider (the
            // PracticeRecordRepository, the InstallDateService
            // via UserSettingsRepository, ...) sees the same
            // in-memory DB.
            appDatabaseProvider.overrideWithValue(db),
            // Pin "now" so createdAt / updatedAt are deterministic.
            appClockProvider.overrideWithValue(() => fixedNow),
            // Wire a real Drift-backed install-date service
            // against the in-memory DB; the install date is
            // persisted in user_settings.
            installDateServiceProvider.overrideWithValue(installService),
            // Deterministic id generator.
            practiceRecordIdGeneratorProvider.overrideWithValue(idGenerator),
          ],
          child: const UkuleleApp(),
        ),
      );
      await tester.pumpAndSettle();

      // The home page is the production initial route. The Day
      // indicator is rendered with the pinned install date
      // (Day 2) — pin that the app booted.
      expect(find.text('今日练习'), findsOneWidget);
      expect(find.text('Day 2'), findsOneWidget);

      // 5. Navigate to the recording page via the production
      //    quick-actions button ("录音回放"). This is the same
      //    button a real user would tap on the home page.
      await tester.tap(find.text('录音回放'));
      await tester.pumpAndSettle();

      // The recording page is up. The disclaimer banner is the
      // canonical T012 signal.
      expect(find.text('录音回放'), findsOneWidget);
      expect(find.textContaining('不会调用麦克风'), findsOneWidget);

      // 6. Start the simulated recording.
      await tester.tap(
        find.byKey(const ValueKey<String>('recording-start')),
      );
      await tester.pumpAndSettle();
      expect(find.text('模拟录音中'), findsOneWidget);

      // 7. Advance the simulated clock by 3 seconds. We use
      //    `tester.pump(Duration(seconds:1))` three times so the
      //    state machine advances WITHOUT the periodic timer
      //    firing on its own — the controller's
      //    `Timer.periodic` is bypassed by fake-async.
      for (int i = 0; i < 3; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(find.text('00:03'), findsOneWidget);

      // 8. Stop the recording. recordedDurationSeconds is frozen
      //    at 3; the page now shows "已录音（可回放 / 自评）".
      await tester.tap(
        find.byKey(const ValueKey<String>('recording-stop')),
      );
      await tester.pumpAndSettle();
      expect(find.text('已录音（可回放 / 自评）'), findsOneWidget);

      // 9. Pick a self-rating and write a note.
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey<String>('recording-self-rating')),
          matching: find.text('还不错'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('recording-note')),
        'C->Am 切换太慢',
      );
      await tester.pumpAndSettle();

      // 10. Tap "保存到练习记录". The save flow runs through
      //     PracticeDayResolver -> PracticeRecordRepository.insert
      //     -> real Drift -> real in-memory DB.
      await tester.tap(
        find.byKey(const ValueKey<String>('recording-save')),
      );
      // Pump the controller's `state = isSaving: true` publish.
      await tester.pump();
      // The SnackBar lives for 2 s; pumpAndSettle waits for
      // the SnackBar + the page rebuilds. The recording page
      // has no live periodic timer at this point
      // (isRecording == false, isPlaying == false), so
      // pumpAndSettle is safe.
      await tester.pumpAndSettle();

      // Success SnackBar + "已保存" button label.
      expect(
        find.byKey(const ValueKey<String>('recording-save-success-snackbar')),
        findsOneWidget,
      );
      expect(find.text('已保存'), findsOneWidget);

      // 11. Sanity: the practice record was persisted through
      //     the real Repository. We read the repository straight
      //     from the same ProviderScope the test is using (NOT
      //     from the Drift database directly). The id is the
      //     deterministic one the generator emitted. We use the
      //     MaterialApp element as the context — it is the root
      //     of the tree and the only place where the
      //     `ProviderScope.containerOf` is guaranteed to work
      //     regardless of which page is on top.
      final BuildContext ctx = tester.element(find.byType(MaterialApp));
      final ProviderContainer container = ProviderScope.containerOf(ctx);
      final PracticeRecordRepository repository =
          container.read(practiceRecordRepositoryProvider);
      final PracticeRecord? stored = await repository.getById(
        kDeterministicTakeId,
      );
      expect(stored, isNotNull,
          reason: 'the saved record must be retrievable through the real '
              'Repository');
      expect(stored!.id, kDeterministicTakeId,
          reason: 'detail recordId MUST equal the takeId the recording '
              'controller minted');
      expect(stored.practiceContent, 'C->Am 切换太慢',
          reason: 'note value must be stored as practiceContent');
      expect(stored.durationSeconds, 3,
          reason: 'recordedDurationSeconds (3) must be persisted');
      expect(stored.dayIndex, 2,
          reason: 'dayIndex must be derived from the pinned install date');
      expect(stored.audioFilePath, isNull,
          reason: 'simulated recording must not bind an audioFilePath');

      // 12. Pop back to the home page via the default
      //     `BackButton` widget that Flutter injects into the
      //     recording page's AppBar (the page does not set its
      //     own `leading`). Using `find.byType(BackButton)` is
      //     locale-agnostic — the default `MaterialLocalizations`
      //     tooltip string varies between builds, but the widget
      //     type does not.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('今日练习'), findsOneWidget);

      await tester.tap(find.text('练习记录'));
      await tester.pumpAndSettle();

      // 13. The records list page is up. The just-saved record
      //     is the ONLY row, and it surfaces the metadata the
      //     user entered.
      expect(find.text('练习记录'), findsOneWidget,
          reason: 'the list page AppBar must show the page title');
      // One PracticeRecordListItem — the only row.
      expect(find.text('2026-06-20 · Day 2'), findsOneWidget,
          reason: 'list row header must show the formatted date + Day');
      expect(find.text('录音练习 · 00:03'), findsOneWidget,
          reason: 'list row must show the practice type label and '
              'formatted duration');
      expect(find.text('C->Am 切换太慢'), findsOneWidget,
          reason: 'list row must show the note as practiceContent');
      expect(find.text('自评：好'), findsOneWidget,
          reason: 'self-assessment must be rendered on the list row');

      // 14. Tap the row. The page navigates to
      //     /records/<recordId>. The detail page's controller
      //     resolves the record through the real Repository.
      await tester.tap(find.text('C->Am 切换太慢'));
      await tester.pumpAndSettle();

      // Detail page is up. The app bar shows
      // "练习记录详情" and the body shows the loaded record.
      expect(find.text('练习记录详情'), findsOneWidget);
      expect(find.text('2026-06-20'), findsOneWidget);
      expect(find.text('Day 2'), findsOneWidget);
      expect(find.text('录音练习'), findsOneWidget);
      expect(find.text('00:03'), findsOneWidget);
      expect(find.text('已完成'), findsOneWidget);
      expect(find.text('好'), findsOneWidget);
      expect(find.text('录音、自评'), findsOneWidget,
          reason: 'tags must be rendered as recording + selfAssessment');
      // audioFilePath is NEVER rendered on the detail page.
      expect(find.textContaining('m4a'), findsNothing);
      expect(find.textContaining('audio'), findsNothing);
      // The recordId is the same as the takeId the controller
      // minted — this is implicit in the navigation, but pin it
      // by re-reading the row through the Repository so a future
      // regression in the route parameter is caught here.
      final PracticeRecord? reread =
          await repository.getById(kDeterministicTakeId);
      expect(reread, isNotNull);
      expect(reread!.id, kDeterministicTakeId,
          reason: 'detail recordId MUST equal the recording takeId');

      // 15. Tap the delete button. The confirmation dialog
      //     appears.
      await tester.tap(find.byKey(
        const ValueKey<String>('practice-record-detail-delete-button'),
      ));
      await tester.pump();
      expect(find.text('删除练习记录？'), findsOneWidget);

      // 16. CANCEL first. The record must still exist after
      //     the user dismisses the dialog — the brief is
      //     explicit: "先验证取消删除不会移除记录".
      await tester.tap(find.byKey(const ValueKey<String>(
          'practice-record-detail-delete-cancel-button')));
      await tester.pump();
      expect(find.text('删除练习记录？'), findsNothing);
      // The detail page is still up (we did NOT pop).
      expect(find.text('练习记录详情'), findsOneWidget);
      // The record is still in the DB.
      final PracticeRecord? afterCancel =
          await repository.getById(kDeterministicTakeId);
      expect(afterCancel, isNotNull,
          reason: 'cancel must not remove the record from the repository');

      // 17. Tap delete again, then CONFIRM. The controller
      //     calls repository.delete, the page pops back to
      //     /records, the success SnackBar fires, and the
      //     list controller's watchAll subscription re-emits
      //     with the empty list.
      await tester.tap(find.byKey(
        const ValueKey<String>('practice-record-detail-delete-button'),
      ));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>(
          'practice-record-detail-delete-confirm-button')));
      // pumpAndSettle drives the controller's
      // `state = AsyncData(isDeleting: true)` publish, the
      // Repository.delete call, the pop animation, and the
      // SnackBar animation.
      await tester.pumpAndSettle();

      // 18. The list page is back. The row is gone, and the
      //     empty-state copy is rendered.
      expect(
        find.byKey(
            const ValueKey<String>('practice-record-delete-success-snackbar')),
        findsOneWidget,
      );
      expect(find.text('还没有练习记录'), findsOneWidget,
          reason: 'list page must transition to the empty view after delete');
      expect(find.text('C->Am 切换太慢'), findsNothing,
          reason: 'the deleted record must no longer appear in the list');
      expect(find.text('2026-06-20 · Day 2'), findsNothing,
          reason: 'the deleted row must no longer appear in the list');

      // 19. Final persistence verification through the real
      //     Repository. The row must be gone.
      final PracticeRecord? afterDelete =
          await repository.getById(kDeterministicTakeId);
      expect(afterDelete, isNull,
          reason: 'repository.getById must return null after delete — '
              'proving the row was actually removed by the real '
              'Repository (not just hidden from the UI)');

      // 20. Explicit cleanup so Drift's internal StreamQueryStore
      //     timers settle before the test framework's
      //     `verifyInvariants` runs. Without this, the test
      //     ends with a pending Drift close-marker Timer and
      //     Flutter's test binding reports "A Timer is still
      //     pending even after the widget tree was disposed."
      //
      // The Drift watchAll stream was subscribed by the list
      // page's controller; when the ProviderScope tears down,
      // the subscription is cancelled and Drift schedules a
      // 0-duration Timer to mark the StreamQueryStore as
      // closed. We replace the widget tree with a bare
      // SizedBox to trigger disposal, then pump until the
      // 0-duration timer fires (fake-async processes the
      // microtask on the next pump).
      await tester.pumpWidget(const SizedBox.shrink());
      // Process the Drift close-marker timer. The timer is
      // 0-duration; a single pump is enough to let the
      // microtask run in fake-async.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));
    },
  );
}

/// ID generator that always returns a fixed UUID v4 string. The
/// string is a valid RFC 4122 v4 UUID: nibble 13 is `4` and the
/// top two bits of nibble 17 are `10` (the variant bits). The
/// test asserts on the exact value, so the generator is the
/// single source of truth for the takeId.
class _FixedIdGenerator implements PracticeRecordIdGenerator {
  _FixedIdGenerator(this._id);

  final String _id;

  @override
  String generate() => _id;
}

// Silence unused-import lints. We import `PracticeRecord`,
// `SelfRating` and `Uuid` so the test file can construct the
// PracticeRecord fixture in the rare error path. (The production
// save path uses the Controller's own builder, but we keep the
// imports visible in case a future maintainer wants to assert on
// the in-memory row state directly.)
// ignore: unused_element
typedef _SilenceUnused = (PracticeRecord, SelfRating, Uuid);
