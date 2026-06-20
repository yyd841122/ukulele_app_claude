// T013.3_FIX_PENDING_RESULT_AND_INSTALL_DATE_BOUNDARY widget smoke
// test.
//
// Verifies that the UkuleleApp boots, the home page renders the
// "today's practice" copy, Day 1 is the active day, and at
// least one task card is visible — without ever calling the
// production `path_provider` (which is unavailable in a unit
// test environment). The install-date service is overridden to
// a `DriftInstallDateService` pointing at a fresh in-memory
// `UserSettingsRepository` (which itself wraps a fresh
// in-memory `AppDatabase`), and the `appDatabaseProvider` is
// overridden to the SAME database so the test exercises the
// Drift path end-to-end.
//
// The in-memory database is closed via `addTearDown(db.close)`.

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:ukulele_app/app/app.dart';
import 'package:ukulele_app/data/database/app_database.dart';
import 'package:ukulele_app/data/database/app_database_provider.dart';
import 'package:ukulele_app/shared/providers/app_clock_provider.dart';
import 'package:ukulele_app/shared/repositories/drift_user_settings_repository.dart';
import 'package:ukulele_app/shared/services/drift_install_date_service.dart';
import 'package:ukulele_app/shared/services/install_date_service.dart';
import 'package:ukulele_app/shared/services/install_date_service_provider.dart';

void main() {
  setUpAll(() async {
    // The home page renders a localised date; the intl package
    // requires an explicit locale-data initialisation in unit
    // tests.
    await initializeDateFormatting('zh_CN');
  });

  testWidgets('App boots and home page renders', (WidgetTester tester) async {
    // Fresh in-memory DB; the same DB is wired into
    // `appDatabaseProvider` (so the default
    // `completedTasksRepositoryProvider` and the test's
    // `UserSettingsRepository` share it).
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final DateTime fixed = DateTime(2026, 6, 20, 9, 0);
    final InstallDateService installService = DriftInstallDateService(
      repository: DriftUserSettingsRepository(database: db),
      clock: () => fixed,
    );
    await tester.pumpWidget(
      ProviderScope(
        // Pin "today" to a known instant and route the install
        // date through a Drift service backed by the test DB —
        // never call the production `path_provider` code path.
        overrides: <Override>[
          appDatabaseProvider.overrideWithValue(db),
          appClockProvider.overrideWithValue(() => fixed),
          installDateServiceProvider.overrideWithValue(installService),
        ],
        child: const UkuleleApp(),
      ),
    );
    await tester.pumpAndSettle();

    // The MaterialApp.router is configured.
    expect(find.byType(MaterialApp), findsOneWidget);

    // Home page app bar title.
    expect(find.text('Ukulele App'), findsWidgets);

    // T007 home shows "今日练习" header.
    expect(find.text('今日练习'), findsOneWidget);

    // Day 1 indicator is rendered.
    expect(find.text('Day 1'), findsOneWidget);

    // At least one task card is rendered (Day 1 has 3 tasks).
    expect(find.byType(Checkbox), findsNWidgets(3));
  });
}
