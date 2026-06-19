// T004 project shell smoke test.
// Verifies the placeholder App Shell renders without errors.
// Business-level tests will be added together with real features in later tasks.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/main.dart';

void main() {
  testWidgets('App shell renders placeholder text', (WidgetTester tester) async {
    await tester.pumpWidget(const UkuleleAppShell());

    expect(find.text('Ukulele App Shell'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}