// Widget tests for [HomePage]
// (T013.3_FIX_PENDING_RESULT_AND_INSTALL_DATE_BOUNDARY).
//
// T013.3 contract under test:
// - The page renders a loading spinner while the controller is
//   still building.
// - A failure in the build path renders the error view with a
//   retry button. Pressing retry re-runs `build()`.
// - On data, the header, task cards and quick actions render as
//   before — i.e. layout outside the AsyncValue envelope is
//   unchanged.
// - Duplicate concurrent clicks (same taskId) MUST NOT show a
//   "保存失败，请重试" SnackBar — the second click is `ignored`,
//   not a failure.
// - A Repository write exception (e.g. read-only repo) MUST show
//   the SnackBar AND clear the pending flag (i.e. the Checkbox
//   re-enables) once the failure surfaces.
// - The Checkbox is rendered as DISABLED while a write is
//   pending (so a second click on the same taskId cannot even
//   fire).

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:ukulele_app/data/database/app_database.dart';
import 'package:ukulele_app/data/database/app_database_provider.dart';
import 'package:ukulele_app/features/home/application/today_practice_controller.dart';
import 'package:ukulele_app/features/home/data/completed_tasks_repository.dart';
import 'package:ukulele_app/features/home/data/completed_tasks_repository_provider.dart';
import 'package:ukulele_app/features/home/presentation/home_page.dart';
import 'package:ukulele_app/shared/services/install_date_service.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('zh_CN');
  });

  group('HomePage AsyncValue rendering', () {
    testWidgets('shows loading spinner while build is in flight',
        (WidgetTester tester) async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => DateTime(2026, 6, 20, 9)),
          installDateServiceProvider.overrideWithValue(
            _NeverCompletingInstallDateService(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HomePage()),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('正在加载今日练习…'), findsOneWidget);
    });

    testWidgets('shows error view with retry button on build failure',
        (WidgetTester tester) async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final _ToggleInstallDateService service =
          _ToggleInstallDateService(initialFailure: true);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => DateTime(2026, 6, 20, 9)),
          installDateServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HomePage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('加载今日练习失败，请重试。'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);

      service.failNext = false;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('今日练习'), findsOneWidget);
      expect(find.text('Day 1'), findsOneWidget);
    });

    testWidgets('renders data state on successful build',
        (WidgetTester tester) async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final DateTime fixed = DateTime(2026, 6, 20, 9, 0);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => fixed),
          installDateServiceProvider.overrideWithValue(
            _FakeInstallDateService(fixed),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HomePage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('今日练习'), findsOneWidget);
      expect(find.text('Day 1'), findsOneWidget);
      // Day 1 has 3 tasks → 3 checkboxes.
      expect(find.byType(Checkbox), findsNWidgets(3));
    });

    testWidgets('repository write failure -> SnackBar 保存失败，请重试 is shown',
        (WidgetTester tester) async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final DateTime fixed = DateTime(2026, 6, 20, 9, 0);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => fixed),
          installDateServiceProvider.overrideWithValue(
            _FakeInstallDateService(fixed),
          ),
          completedTasksRepositoryProvider.overrideWithValue(
            _ReadOnlyCompletedTasksRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HomePage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('保存失败，请重试'), findsOneWidget);
      // After the failure the pending flag is cleared, so the
      // Checkbox must be re-enabled (i.e. onChanged != null) so
      // the user can retry. We assert by tapping it again and
      // observing the SnackBar a second time.
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('保存失败，请重试'), findsOneWidget);
    });

    testWidgets('duplicate toggle does NOT show a failure SnackBar',
        (WidgetTester tester) async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final DateTime fixed = DateTime(2026, 6, 20, 9, 0);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => fixed),
          installDateServiceProvider.overrideWithValue(
            _FakeInstallDateService(fixed),
          ),
          completedTasksRepositoryProvider.overrideWithValue(
            _GatedCompletedTasksRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HomePage()),
        ),
      );
      await tester.pumpAndSettle();

      // Drive the duplicate-click scenario directly through the
      // controller — widget taps on a disabled Checkbox are
      // swallowed by Flutter before they ever reach
      // `onToggleCompleted`, so the only way to exercise the
      // "controller returns ignored" path is to call the
      // controller's API twice in quick succession.
      final TodayPracticeController controller =
          container.read(todayPracticeControllerProvider.notifier);
      final Completer<void> release = Completer<void>();
      _GatedCompletedTasksRepository.gate = release.future;

      final String taskId = container
          .read(todayPracticeControllerProvider)
          .value!
          .plan
          .tasks
          .first
          .id;
      // Kick off the first write. We do NOT await it yet — the
      // gate holds it open.
      final Future<ToggleTaskResult> first =
          controller.toggleTaskCompleted(taskId);
      // Let the controller publish the pending state. A single
      // pump is enough because the controller's state mutation
      // is synchronous once the microtask is drained.
      await tester.pump();
      // Fire the duplicate click. The controller's pending
      // guard returns `ignored` immediately.
      final ToggleTaskResult second =
          await controller.toggleTaskCompleted(taskId);

      expect(second, ToggleTaskResult.ignored,
          reason: 'duplicate click must return ignored');
      // No SnackBar should have been queued at this point.
      expect(find.text('保存失败，请重试'), findsNothing);
      // Drain the in-flight write so the test exits cleanly.
      release.complete();
      await first;
      await tester.pumpAndSettle();
    });

    testWidgets('Checkbox is disabled while a write is pending',
        (WidgetTester tester) async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final DateTime fixed = DateTime(2026, 6, 20, 9, 0);
      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(() => fixed),
          installDateServiceProvider.overrideWithValue(
            _FakeInstallDateService(fixed),
          ),
          completedTasksRepositoryProvider.overrideWithValue(
            _GatedCompletedTasksRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HomePage()),
        ),
      );
      await tester.pumpAndSettle();

      // Hold the write open.
      final Completer<void> release = Completer<void>();
      _GatedCompletedTasksRepository.gate = release.future;

      // Tap the first checkbox. The first write goes pending; the
      // UI rebuilds with the Checkbox disabled.
      await tester.tap(find.byType(Checkbox).first, warnIfMissed: false);
      await tester.pump();
      // Re-find the Checkbox after the rebuild; it should now be
      // disabled (onChanged == null).
      final Checkbox firstCheckbox = tester.widget<Checkbox>(
        find.byType(Checkbox).first,
      );
      expect(firstCheckbox.onChanged, isNull,
          reason: 'Checkbox must be disabled while pending');
      expect(firstCheckbox.value, isFalse,
          reason: 'pending must not flip the visual state');

      // Release the gate and let the write finish so the page
      // can settle and the test teardown can run.
      release.complete();
      await tester.pumpAndSettle();
      final Checkbox afterCheckbox = tester.widget<Checkbox>(
        find.byType(Checkbox).first,
      );
      expect(afterCheckbox.onChanged, isNotNull);
      expect(afterCheckbox.value, isTrue);
    });
  });
}

/// Stub install-date service for tests.
class _FakeInstallDateService implements InstallDateService {
  _FakeInstallDateService(this._fixed);
  final DateTime _fixed;
  @override
  Future<DateTime> getInstallDate() async => _fixed;
}

/// Install-date service that never resolves — used to keep the
/// controller in AsyncLoading.
class _NeverCompletingInstallDateService implements InstallDateService {
  @override
  Future<DateTime> getInstallDate() {
    return Completer<DateTime>().future;
  }
}

/// Toggleable install-date service for the retry test.
class _ToggleInstallDateService implements InstallDateService {
  _ToggleInstallDateService({required bool initialFailure})
      : failNext = initialFailure;

  bool failNext;

  @override
  Future<DateTime> getInstallDate() async {
    if (failNext) {
      throw StateError('synthetic install date failure');
    }
    return DateTime(2026, 6, 20, 9);
  }
}

/// Read-only completed-tasks repository. `getCompletedTaskIds`
/// returns empty so `build()` resolves; writes throw.
class _ReadOnlyCompletedTasksRepository implements CompletedTasksRepository {
  @override
  Future<Set<String>> getCompletedTaskIds(DateTime date) async =>
      const <String>{};

  @override
  Stream<Set<String>> watchCompletedTaskIds(DateTime date) =>
      const Stream<Set<String>>.empty();

  @override
  Future<void> markCompleted({
    required DateTime date,
    required String taskId,
    required DateTime completedAt,
  }) async {
    throw StateError('read-only repository');
  }

  @override
  Future<bool> unmarkCompleted({
    required DateTime date,
    required String taskId,
  }) async {
    throw StateError('read-only repository');
  }
}

/// Gated completed-tasks repository: writes block until
/// `_GatedCompletedTasksRepository.gate` completes.
class _GatedCompletedTasksRepository implements CompletedTasksRepository {
  static Future<void>? gate;

  @override
  Future<Set<String>> getCompletedTaskIds(DateTime date) async =>
      const <String>{};

  @override
  Stream<Set<String>> watchCompletedTaskIds(DateTime date) =>
      const Stream<Set<String>>.empty();

  @override
  Future<void> markCompleted({
    required DateTime date,
    required String taskId,
    required DateTime completedAt,
  }) async {
    final Future<void>? g = gate;
    if (g != null) {
      await g;
    }
  }

  @override
  Future<bool> unmarkCompleted({
    required DateTime date,
    required String taskId,
  }) async {
    final Future<void>? g = gate;
    if (g != null) {
      await g;
    }
    return true;
  }
}
