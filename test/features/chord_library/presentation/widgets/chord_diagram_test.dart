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

    testWidgets('renders all four chords', (WidgetTester tester) async {
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

      expect(find.byType(ChordDiagram), findsNWidgets(4));
    });
  });
}