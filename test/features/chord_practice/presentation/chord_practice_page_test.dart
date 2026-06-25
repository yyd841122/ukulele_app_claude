// Widget tests for [ChordPracticePage] (T053).
//
// Scope:
// - Verify the page renders the default chord (first shipped chord)
//   and all 7 switch buttons.
// - Verify tapping a switch button updates the displayed chord.
// - Verify the selected switch button is visually distinct from the
//   rest (so the user can see current state at a glance).
// - Verify the page reads from the existing built-in chord list
//   (regression: a future data swap should not silently decouple
//   the practice page from the library).
// - Verify the page does NOT depend on metronome / recording
//   services (the practice page is intentionally UI-only).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/features/chord_library/application/chord_library_controller.dart';
import 'package:ukulele_app/features/chord_library/data/built_in_chords.dart';
import 'package:ukulele_app/features/chord_library/domain/chord.dart';
import 'package:ukulele_app/features/chord_practice/application/chord_practice_controller.dart';
import 'package:ukulele_app/features/chord_practice/presentation/chord_practice_page.dart';

void main() {
  group('ChordPracticePage', () {
    testWidgets('renders the default chord and 7 switch buttons',
        (WidgetTester tester) async {
      // Bump the test viewport so the whole page fits without
      // scrolling past the bottom row of switch buttons.
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ChordPracticePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // App bar title.
      expect(find.text('和弦练习'), findsOneWidget);

      // Default chord (first in the library) is shown big.
      final Chord firstChord = kBuiltInChords.first;
      expect(find.text(firstChord.name), findsWidgets);

      // One switch button per shipped chord — selected chord uses
      // FilledButton (tonal), unselected uses OutlinedButton. We
      // accept either style so the assertion is robust to which
      // chord is the default selection.
      for (final Chord chord in kBuiltInChords) {
        final int tonal = find.widgetWithText(FilledButton, chord.name).evaluate().length;
        final int outlined =
            find.widgetWithText(OutlinedButton, chord.name).evaluate().length;
        expect(
          tonal + outlined,
          greaterThanOrEqualTo(1),
          reason: 'Missing switch button for ${chord.id}',
        );
      }
    });

    testWidgets('tapping a switch button updates the displayed chord',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ChordPracticePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the G7 switch button (use ensureVisible + warnIfMissed
      // because the default test viewport can crop the bottom row).
      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'G7'),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'G7'),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      // The big display now shows G7 / G7 和弦.
      expect(find.text('G7'), findsWidgets);
      expect(find.text('G7 和弦'), findsOneWidget);

      // Provider state matches.
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(ChordPracticePage)),
      );
      expect(container.read(chordPracticeControllerProvider), 'g7');
    });

    testWidgets('selected button is rendered with the tonal style',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Force a non-default selection so the tonal (selected) button
      // is for a chord that is NOT the first one in the library.
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ChordPracticePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Dm'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Dm'),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      // The currently selected chord's switch button uses
      // FilledButton.tonal; the rest use OutlinedButton.
      expect(
        find.widgetWithText(FilledButton, 'Dm'),
        findsOneWidget,
      );
      // All other chords still render as outlined buttons.
      for (final Chord chord in kBuiltInChords) {
        if (chord.id == 'dm') {
          continue;
        }
        expect(
          find.widgetWithText(OutlinedButton, chord.name),
          findsOneWidget,
          reason: '${chord.id} should be outlined (not selected)',
        );
      }
    });

    testWidgets('tapping the same button twice keeps the selection stable',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ChordPracticePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Em'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Em'),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      // Second tap on the now-tonal button.
      await tester.tap(
        find.widgetWithText(FilledButton, 'Em'),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(ChordPracticePage)),
      );
      expect(container.read(chordPracticeControllerProvider), 'em');
    });

    testWidgets('library override is honored (decouples from built-in constant)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // A future task may swap the data source; the practice page
      // must read from `chordLibraryProvider`, not from the
      // built-in constant directly. The override is a minimal
      // smoke test — if the override works, the wiring is right.
      final Chord custom = kBuiltInChords.first;
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            chordLibraryProvider.overrideWithValue(<Chord>[custom]),
          ],
          child: const MaterialApp(
            home: ChordPracticePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, custom.name), findsOneWidget);
      // The other 6 chords are not in the override list, so their
      // switch buttons should be absent.
      for (final Chord other in kBuiltInChords) {
        if (other.id == custom.id) {
          continue;
        }
        expect(
          find.widgetWithText(OutlinedButton, other.name),
          findsNothing,
          reason: 'Override should remove ${other.id}',
        );
        expect(
          find.widgetWithText(FilledButton, other.name),
          findsNothing,
          reason: 'Override should remove ${other.id}',
        );
      }
    });
  });
}