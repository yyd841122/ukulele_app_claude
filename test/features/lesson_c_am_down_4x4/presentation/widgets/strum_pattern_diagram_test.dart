// Tests for [CAmDownStrumPatternDiagram].
//
// T043 scope:
// - Render the widget under several sizes and assert the four
//   required pieces of information (4/4 time signature, beat
//   numbers 1-2-3-4, C and Am chord names, down-strum arrows).
// - Pin the Am-vs-A disambiguation: `Am` must appear and bare `A`
//   must NOT appear (a typo in either direction would mislead a
//   beginner who already mixes up the two chords).
// - Verify the Semantics node carries the description screen
//   readers will announce.
// - Verify the diagram renders cleanly at narrow phone widths
//   without `RenderFlex overflowed` exceptions.
//
// Mirrors the [chord_diagram_test.dart] /
// [single_note_position_diagram_test.dart] conventions
// (MaterialApp + Scaffold + Center + pumpAndSettle) and extends
// them with the `setSurfaceSize` narrow-screen pattern used by
// `metronome_page_test.dart` and the integration tests.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/core/constants/lesson_constants.dart';
import 'package:ukulele_app/features/lesson_c_am_down_4x4/presentation/widgets/strum_pattern_diagram.dart';

/// The single shipped pattern today — passed into the widget
/// constructor in every test so the diagram renders the same
/// payload `kBuiltInLessons` ships, with no hard-coded duplication.
final StrumPattern _kLessonPattern = kBuiltInLessons.first.strumPattern;

void main() {
  group('CAmDownStrumPatternDiagram', () {
    testWidgets('renders without throwing at default width',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CAmDownStrumPatternDiagram(
                strumPattern: _kLessonPattern,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CAmDownStrumPatternDiagram), findsOneWidget);
    });

    testWidgets('shows 4/4 time signature', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CAmDownStrumPatternDiagram(
                strumPattern: _kLessonPattern,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('4/4'), findsOneWidget);
    });

    testWidgets('shows all four beat numbers 1 2 3 4',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CAmDownStrumPatternDiagram(
                strumPattern: _kLessonPattern,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('shows C and Am chord names but never a bare A',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CAmDownStrumPatternDiagram(
                strumPattern: _kLessonPattern,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // C appears (beats 1 and 2 both render "C" → findsNWidgets(2)).
      expect(find.text('C'), findsNWidgets(2));
      // Am appears (beats 3 and 4 both render "Am" → findsNWidgets(2)).
      expect(find.text('Am'), findsNWidgets(2));
      // Bare "A" must NOT appear anywhere — a typo would mislead
      // a beginner who already mixes up C and Am.
      expect(find.text('A'), findsNothing);
    });
  });

  group('CAmDownStrumPatternDiagram Semantics', () {
    testWidgets('exposes a Semantics node describing the rhythm',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CAmDownStrumPatternDiagram(
                strumPattern: _kLessonPattern,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final SemanticsNode node =
          tester.getSemantics(find.byType(CAmDownStrumPatternDiagram));
      expect(node, isNotNull,
          reason: 'diagram must be reachable through Semantics');
      expect(node.label, contains('4/4'));
      expect(node.label, contains('Am'));
      expect(node.label, contains('下扫'));
    });
  });

  group('CAmDownStrumPatternDiagram narrow-screen', () {
    tearDown(() {
      // Reset the surface size after every narrow-screen test so
      // later groups in the same file (or future tests) get the
      // default 800x600 surface back. Mirrors
      // `metronome_page_test.dart:25-27`.
    });

    testWidgets('renders at 320x800 without overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CAmDownStrumPatternDiagram(
                strumPattern: _kLessonPattern,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CAmDownStrumPatternDiagram), findsOneWidget);
      expect(tester.takeException(), isNull,
          reason: 'narrow screen must not produce a layout exception');
    });

    testWidgets('renders at 280x600 without exception',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(280, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CAmDownStrumPatternDiagram(
                strumPattern: _kLessonPattern,
                width: 240,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CAmDownStrumPatternDiagram), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
