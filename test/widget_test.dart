// T006 app shell smoke test.
//
// Verifies that the UkuleleApp boots, the home page renders and the
// placeholder home banner text is visible.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/app/app.dart';

void main() {
  testWidgets('App boots and home page renders', (WidgetTester tester) async {
    await tester.pumpWidget(const UkuleleApp());
    await tester.pumpAndSettle();

    // The MaterialApp.router is configured.
    expect(find.byType(MaterialApp), findsOneWidget);

    // Home page app bar title.
    expect(find.text('Ukulele App'), findsWidgets);

    // T006 home placeholder banner indicates "today's practice" copy.
    expect(find.text('今日练习'), findsOneWidget);
  });
}