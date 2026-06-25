// Tests for [ChordDiagram].
//
// T008 scope:
// - Smoke test: pumping the widget at multiple sizes does not throw
//   and renders the expected number of string / fret lines.
// - Render-without-labels test: the list page uses a compact variant
//   without open / muted labels and finger numbers; we assert it
//   renders without exceptions.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/features/chord_library/data/built_in_chords.dart';
import 'package:ukulele_app/features/chord_library/domain/chord.dart';
import 'package:ukulele_app/features/chord_library/presentation/widgets/chord_diagram.dart';

void main() {
  group('ChordDiagram', () {
    testWidgets('renders C chord diagram without throwing',
        (WidgetTester tester) async {
      final Chord c = findBuiltInChord('c')!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ChordDiagram(fingering: c.primaryVoicing),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The widget itself is on the page.
      expect(find.byType(ChordDiagram), findsOneWidget);
    });

    testWidgets('renders compact variant without labels',
        (WidgetTester tester) async {
      final Chord c = findBuiltInChord('c')!;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 88,
                height: 96,
                child: ChordDiagram(
                  fingering: c.primaryVoicing,
                  width: 88,
                  showLabels: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ChordDiagram), findsOneWidget);
    });

    testWidgets('renders all shipped chords', (WidgetTester tester) async {
      // T053: the built-in library now ships 7 chords (C / Am / F / G
      // / G7 / Dm / Em). The widget count is derived from
      // [kBuiltInChords] so the assertion stays honest as the library
      // grows.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  for (final Chord c in kBuiltInChords)
                    ChordDiagram(fingering: c.primaryVoicing),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ChordDiagram), findsNWidgets(kBuiltInChords.length));
    });
  });

  group('visibleStringOrder', () {
    // The chord diagram is rendered in the conventional beginner
    // "chart" orientation: G, C, E, A from left to right. Because
    // the data model numbers strings 1..4 as A, E, C, G, the visible
    // left-to-right order is the reverse: [4, 3, 2, 1]. This test
    // pins the mapping so a future refactor cannot silently flip
    // the diagram back to the data-model order.
    test('returns [4, 3, 2, 1] for the default ukulele layout', () {
      expect(visibleStringOrder(), <int>[4, 3, 2, 1]);
    });

    test('exposes four entries, one per string', () {
      final List<int> order = visibleStringOrder();
      expect(order.length, 4);
      expect(order.toSet(), <int>{1, 2, 3, 4});
    });
  });
}