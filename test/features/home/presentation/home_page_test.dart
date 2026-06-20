// Widget tests for [HomePage] (T013.3).
//
// T013.3 contract under test:
// - The page renders a loading spinner while the controller is
//   still building.
// - A failure in the build path renders the error view with a
//   retry button. Pressing retry re-runs `build()` (the test
//   re-fixes the underlying service before the second attempt).
// - On data, the header, task cards and quick actions render as
//   before — i.e. layout outside the AsyncValue envelope is
//   unchanged.

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
    // The home page renders a localised date; the intl package
    // requires an explicit locale-data initialisation in unit
    // tests.
    await initializeDateFormatting('zh_CN');
  });

  group('HomePage AsyncValue rendering', () {
    testWidgets('shows loading spinner while build is in flight',
        (WidgetTester tester) async {
      // Slow install-date service: we never resolve it in this
      // test, so the controller stays in AsyncLoading.
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
      // We do NOT await `.future` — the controller should remain
      // in loading.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HomePage()),
        ),
      );
      // Allow the initial frame to land.
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
      // Allow the error to surface.
      await tester.pumpAndSettle();
      expect(find.text('加载今日练习失败，请重试。'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);

      // Flip the service to succeed and tap retry.
      service.failNext = false;
      await tester.tap(find.text('重试'));
      // Re-pump to let the retry resolve and the page re-render
      // with the data state.
      await tester.pumpAndSettle();
      // The data state is now showing: header + task cards are
      // present.
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

    testWidgets('toggle returns false -> SnackBar 保存失败，请重试 is shown',
        (WidgetTester tester) async {
      // We pin a controller that always returns false on
      // toggleTaskCompleted. We use a custom controller binding
      // by overriding the notifier via a small wrapper. Because
      // AsyncNotifier construction is fixed by the
      // `AsyncNotifierProvider` constructor, we instead override
      // the install-date service so the controller's build
      // succeeds but the `completedTasksRepositoryProvider` can
      // be made to throw.
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
      // Tap the first checkbox.
      await tester.tap(find.byType(Checkbox).first);
      // The toggle fails (read-only repo), so a SnackBar is
      // shown.
      await tester.pump(); // schedule the SnackBar
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('保存失败，请重试'), findsOneWidget);
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
    // Intentionally never completes.
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
