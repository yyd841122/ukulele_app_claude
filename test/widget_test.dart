// T007 widget smoke test.
//
// Verifies that the UkuleleApp boots, the home page renders, "today's
// practice" copy is shown, Day 1 is the active day, and at least one
// task card is visible.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:ukulele_app/app/app.dart';
import 'package:ukulele_app/features/home/application/today_practice_controller.dart';
import 'package:ukulele_app/shared/services/install_date_service.dart';

void main() {
  setUpAll(() async {
    // The home page renders a localised date; the intl package requires
    // an explicit locale-data initialisation in unit tests.
    await initializeDateFormatting('zh_CN');
  });

  testWidgets('App boots and home page renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // Pin "today" to a known instant so the test is deterministic.
        overrides: <Override>[
          clockProvider.overrideWithValue(
            () => DateTime(2026, 6, 20, 9, 0),
          ),
          installDateServiceProvider.overrideWithValue(
            InMemoryInstallDateService(
              clock: () => DateTime(2026, 6, 20, 9, 0),
            ),
          ),
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
