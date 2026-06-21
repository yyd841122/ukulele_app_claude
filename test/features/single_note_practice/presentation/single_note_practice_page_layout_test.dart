// Tests for the bottom navigation of the single-note practice page.
//
// T015C_FIX_DEVICE_COPY_AND_LARGE_TEXT_LAYOUT scope:
// - The previous single-row layout (3 buttons in a `Row` with
//   `Expanded`) wrapped Chinese labels vertically character-by-
//   character ("上 / 一 / 个") at 320px width with
//   `textScaleFactor = 1.4`. The new layout is a two-row column
//   so the "上一个" / "下一个" labels stay on a single line and
//   the primary "标记已练习 / 取消已练习" action has the full row
//   width.
// - Tapping "上一个" / "下一个" must still advance the active
//   note — i.e. the refactor must not break the existing
//   controller wiring.
//
// We render the page at the smallest supported surface
// (320 × 640 logical px) with `textScaler = TextScaler.linear(1.4)`
// to mirror the device-acceptance configuration, then walk the
// rendered tree to check that:
//   * the button labels render with `maxLines == 1` (so they
//     cannot wrap character-by-character);
//   * the layout does not throw a `RenderFlex` overflow;
//   * both navigation buttons are tappable and switch the
//     active note.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/features/single_note_practice/data/built_in_single_notes.dart';
import 'package:ukulele_app/features/single_note_practice/presentation/single_note_practice_page.dart';

/// Configures a 320×640 logical-px surface (the device-acceptance
/// "smallest supported phone" baseline) and a `textScaler` of
/// 1.4 — the device-acceptance baseline. Restored on tear-down.
Future<void> _useAcceptanceSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(320, 640));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
  // Pin the text scaler through the binding so the production
  // `TextScaler.linear` path picks it up. We use
  // `tester.platformDispatcher.textScaleFactorTestValue` (set in
  // the test group) — but to be self-contained per-test we
  // inject a MediaQuery override on the widget itself.
}

/// Wraps [child] in a [MediaQuery] that pins the text scaler to
/// 1.4 — the device-acceptance baseline. The widget tree the
/// production code builds still calls `MediaQuery.textScalerOf`,
/// so this override is what the framework sees.
Widget _withScaledText(Widget child) {
  return MediaQuery(
    data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
    child: child,
  );
}

void main() {
  group('SingleNotePracticePage — bottom controls layout', () {
    testWidgets(
        'prev/next/practice labels fit on a single line at '
        '320px × 1.4 textScale (no vertical char-by-char wrap)',
        (WidgetTester tester) async {
      await _useAcceptanceSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: _withScaledText(const SingleNotePracticePage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The page is a ListView; at 320×640 × 1.4 text scale the
      // bottom controls live below the initial viewport. Scroll
      // them into view so `find.text(...)` actually finds them.
      await tester.dragUntilVisible(
        find.text('上一个'),
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      // The two navigation labels and the primary action label
      // must each render with maxLines == 1. The previous layout
      // rendered them with the default maxLines == null, which
      // let Flutter break a 3-char Chinese label character-by-
      // character when the available width shrank at 1.4 scale.
      Finder labelInButton(String text, Type buttonType) {
        return find.descendant(
          of: find.ancestor(
            of: find.text(text),
            matching: find.byType(buttonType),
          ),
          matching: find.byType(Text),
        );
      }

      final Finder prevLabel = find.text('上一个');
      final Finder nextLabel = find.text('下一个');
      expect(prevLabel, findsOneWidget);
      expect(nextLabel, findsOneWidget);
      expect(
        tester.widget<Text>(labelInButton('上一个', OutlinedButton)).maxLines,
        1,
        reason: '"上一个" must stay on a single line at 1.4 text scale',
      );
      expect(
        tester.widget<Text>(labelInButton('下一个', OutlinedButton)).maxLines,
        1,
        reason: '"下一个" must stay on a single line at 1.4 text scale',
      );

      final Finder practiceLabel = find.text('标记已练习');
      expect(practiceLabel, findsOneWidget);
      expect(
        tester.widget<Text>(labelInButton('标记已练习', FilledButton)).maxLines,
        1,
        reason: '"标记已练习" must stay on a single line at 1.4 text scale',
      );

      // No RenderFlex overflow exceptions were recorded by the
      // framework during the pump.
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '"上一个" and "下一个" remain tappable and switch the '
        'active note', (WidgetTester tester) async {
      // Use a tall surface so the bottom controls are guaranteed
      // to be inside the viewport (the layout test above already
      // pinned the no-overflow contract at 320×640).
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SingleNotePracticePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Starts on the first note.
      expect(
        find.textContaining(kBuiltInSingleNotes.first.displayName),
        findsWidgets,
      );

      // Tap "下一个" → second note is shown.
      await tester.tap(find.text('下一个'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(kBuiltInSingleNotes[1].displayName),
        findsWidgets,
      );

      // Tap "上一个" → back to the first note.
      await tester.tap(find.text('上一个'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(kBuiltInSingleNotes.first.displayName),
        findsWidgets,
      );
    });

    testWidgets(
        'page renders without overflow at the device-acceptance '
        'surface (320×640, textScale 1.4)', (WidgetTester tester) async {
      await _useAcceptanceSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: _withScaledText(const SingleNotePracticePage()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The page must paint and the framework must not record an
      // overflow / RenderFlex exception.
      expect(find.byType(SingleNotePracticePage), findsOneWidget);
      expect(find.text('单音练习'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
