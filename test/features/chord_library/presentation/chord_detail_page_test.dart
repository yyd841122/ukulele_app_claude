// Tests for the chord detail page.
//
// T008 scope:
// - Render a real chord (e.g. C) and verify the page shows the
//   diagram widget, name, description and tips.
// - Render an unknown id and verify the page shows a friendly
//   "not found" placeholder instead of crashing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/features/chord_library/data/built_in_chords.dart';
import 'package:ukulele_app/features/chord_library/domain/chord.dart';
import 'package:ukulele_app/features/chord_library/presentation/chord_detail_page.dart';
import 'package:ukulele_app/features/chord_library/presentation/widgets/chord_diagram.dart';

void main() {
  group('ChordDetailPage', () {
    testWidgets('renders C chord details', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const ChordDetailPage(chordId: 'c'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Chord c = findBuiltInChord('c')!;

      // App bar title uses display name (may appear in multiple
      // places — the app bar AND the heading).
      expect(find.text(c.displayName), findsWidgets);
      // Description is rendered.
      expect(find.textContaining(c.description), findsOneWidget);
      expect(find.text('练习提示'), findsOneWidget);
      // Diagram widget is on the page.
      expect(find.byType(ChordDiagram), findsOneWidget);
    });

    testWidgets('renders Am chord details', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const ChordDetailPage(chordId: 'am'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Chord am = findBuiltInChord('am')!;
      expect(find.text(am.displayName), findsWidgets);
      expect(find.textContaining(am.description), findsOneWidget);
    });

    testWidgets('unknown chord id shows a friendly not-found state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const ChordDetailPage(chordId: 'cmaj7'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No diagram is drawn.
      expect(find.byType(ChordDiagram), findsNothing);
      // Friendly copy is shown.
      expect(find.textContaining('未找到'), findsOneWidget);
      // A way back to the library is offered.
      expect(find.text('返回和弦库'), findsOneWidget);
    });

    testWidgets('empty chord id shows a friendly not-found state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const ChordDetailPage(chordId: ''),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('未找到'), findsOneWidget);
      expect(find.byType(ChordDiagram), findsNothing);
    });

    testWidgets('shows related chord section for C',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const ChordDetailPage(chordId: 'c'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // C declares relatedChordIds = [am, f, g]. The detail page
      // renders a "相关和弦" heading plus one chip per related id.
      // All of this lives below the fold of the ListView, so we
      // scroll until the heading is visible before asserting.
      final Finder scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('相关和弦'),
        100,
        scrollable: scrollable,
      );
      expect(find.text('相关和弦'), findsOneWidget);

      // Each related chord's short name appears as a chip label.
      final Chord c = findBuiltInChord('c')!;
      final List<String> expectedNames = c.relatedChordIds
          .map((String id) => findBuiltInChord(id)?.name ?? id.toUpperCase())
          .toList();
      for (final String name in expectedNames) {
        await tester.scrollUntilVisible(
          find.text(name),
          100,
          scrollable: scrollable,
        );
        expect(find.text(name), findsWidgets,
            reason: 'Missing related chip label "$name"');
      }
    });
  });
}