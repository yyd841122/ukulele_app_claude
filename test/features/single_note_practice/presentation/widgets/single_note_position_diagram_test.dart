// Tests for the [SingleNotePositionDiagram] widget.
//
// T009 scope:
// - Smoke test: pumping the widget for every shipped note does not
//   throw and renders the expected number of instances.
// - Pin [visibleSingleNoteStringOrder] to [4, 3, 2, 1] so the
//   diagram cannot silently flip back to the data-model order.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/features/single_note_practice/data/built_in_single_notes.dart';
import 'package:ukulele_app/features/single_note_practice/domain/single_note.dart';
import 'package:ukulele_app/features/single_note_practice/presentation/widgets/single_note_position_diagram.dart';

void main() {
  group('SingleNotePositionDiagram', () {
    testWidgets('renders every shipped note without throwing',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  for (final SingleNote n in kBuiltInSingleNotes)
                    SingleNotePositionDiagram(note: n),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byType(SingleNotePositionDiagram),
        findsNWidgets(kBuiltInSingleNotes.length),
      );
    });

    testWidgets('renders compact variant without labels',
        (WidgetTester tester) async {
      final SingleNote c =
          kBuiltInSingleNotes.firstWhere((SingleNote n) => n.id == 'c');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 88,
                height: 96,
                child: SingleNotePositionDiagram(
                  note: c,
                  width: 88,
                  showLabels: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SingleNotePositionDiagram), findsOneWidget);
    });
  });

  group('visibleSingleNoteStringOrder', () {
    test('returns [4, 3, 2, 1] to match the chord diagram', () {
      // The diagram is rendered in the conventional beginner
      // "chart" orientation: G, C, E, A from left to right.
      // Because the data model numbers strings 1..4 as A, E, C, G,
      // the visible left-to-right order is the reverse: [4, 3, 2, 1].
      // Pin the mapping so a future refactor cannot silently flip
      // the diagram back to the data-model order.
      expect(visibleSingleNoteStringOrder(), <int>[4, 3, 2, 1]);
    });

    test('exposes four entries, one per string', () {
      final List<int> order = visibleSingleNoteStringOrder();
      expect(order.length, 4);
      expect(order.toSet(), <int>{1, 2, 3, 4});
    });
  });
}
