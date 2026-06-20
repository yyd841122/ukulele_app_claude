// Tests for the [TunerPage] widget (T011).
//
// Scope:
// - Verifies the page renders the title, the manual-only
//   disclaimer copy, the G-C-E-A summary, the four string
//   cards, the progress label, the action row, and the four
//   "我已调好" toggle buttons.
// - Verifies tapping "我已调好" on a single string increments
//   the progress label and flips the button label to
//   "已调好（取消）".
// - Verifies tapping "全部重置" returns the progress to 0/4.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/features/tuner/presentation/tuner_page.dart';
import 'package:ukulele_app/features/tuner/presentation/widgets/tuner_disclaimer.dart';
import 'package:ukulele_app/features/tuner/presentation/widgets/tuning_progress.dart';
import 'package:ukulele_app/features/tuner/presentation/widgets/tuning_string_card.dart';

/// Sets a tall test surface so the entire page (header, summary,
/// progress, four cards, action row) fits in the viewport
/// without needing to scroll. Used by tests that need to
/// interact with elements scattered top-to-bottom.
Future<void> _useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 2000));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
}

Future<void> _pumpPage(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(
        home: TunerPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('TunerPage', () {
    testWidgets(
        'renders title, disclaimer, summary, four cards and '
        'progress', (WidgetTester tester) async {
      await _useTallSurface(tester);
      await _pumpPage(tester);

      // AppBar title.
      expect(find.text('调音辅助'), findsOneWidget);

      // Manual-only disclaimer banner copy is present. The
      // title "手动调音指导" appears both in the disclaimer
      // banner and (intentionally) inside the disclaimer body,
      // so we use a ">=1" matcher for the broad phrase and
      // `findsOneWidget` for the more specific sub-phrases.
      expect(
        find.textContaining('手动调音指导'),
        findsWidgets,
      );
      expect(
        find.textContaining('不会调用麦克风'),
        findsOneWidget,
      );
      expect(
        find.textContaining('不会识别声音'),
        findsOneWidget,
      );
      expect(
        find.textContaining('不会检测频率'),
        findsOneWidget,
      );

      // G-C-E-A summary is present.
      expect(find.text('G - C - E - A'), findsOneWidget);
      expect(
        find.textContaining('本页面只做弦名指导'),
        findsOneWidget,
      );

      // Disclaimer widget is rendered as a single component.
      expect(find.byType(TunerDisclaimer), findsOneWidget);

      // Progress widget renders with 0/4.
      expect(find.byType(TuningProgress), findsOneWidget);
      expect(find.text('已确认 0 / 4'), findsOneWidget);

      // Four TuningStringCards are rendered.
      expect(find.byType(TuningStringCard), findsNWidgets(4));

      // Each card displays its display name.
      expect(find.text('4 弦 · G'), findsOneWidget);
      expect(find.text('3 弦 · C'), findsOneWidget);
      expect(find.text('2 弦 · E'), findsOneWidget);
      expect(find.text('1 弦 · A'), findsOneWidget);

      // Each card shows the "我已调好" toggle button.
      expect(find.text('我已调好'), findsNWidgets(4));

      // Action row buttons.
      expect(find.text('全部重置'), findsOneWidget);
      expect(find.text('全部标记已调好'), findsOneWidget);
    });

    testWidgets('tapping "我已调好" on a single card increments progress',
        (WidgetTester tester) async {
      await _useTallSurface(tester);
      await _pumpPage(tester);

      // The first card (G) is the leftmost in display order, so
      // tap its toggle button.
      await tester.tap(
        find.byKey(const ValueKey<String>('tuning-toggle-4')),
      );
      await tester.pumpAndSettle();

      // Progress advanced to 1/4.
      expect(find.text('已确认 1 / 4'), findsOneWidget);
      expect(find.text('已确认 0 / 4'), findsNothing);
      // The G card's button label flipped.
      expect(find.text('已调好（取消）'), findsOneWidget);
      expect(find.text('我已调好'), findsNWidgets(3));
    });

    testWidgets('tapping the same toggle twice returns to 0/4',
        (WidgetTester tester) async {
      await _useTallSurface(tester);
      await _pumpPage(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('tuning-toggle-4')),
      );
      await tester.pumpAndSettle();
      expect(find.text('已确认 1 / 4'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('tuning-toggle-4')),
      );
      await tester.pumpAndSettle();
      expect(find.text('已确认 0 / 4'), findsOneWidget);
      expect(find.text('我已调好'), findsNWidgets(4));
    });

    testWidgets('tapping "全部重置" returns to 0/4', (WidgetTester tester) async {
      await _useTallSurface(tester);
      await _pumpPage(tester);

      // Confirm three strings individually.
      await tester.tap(
        find.byKey(const ValueKey<String>('tuning-toggle-4')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('tuning-toggle-3')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey<String>('tuning-toggle-2')),
      );
      await tester.pumpAndSettle();

      expect(find.text('已确认 3 / 4'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('tuner-reset-all')),
      );
      await tester.pumpAndSettle();

      expect(find.text('已确认 0 / 4'), findsOneWidget);
      expect(find.text('我已调好'), findsNWidgets(4));
    });

    testWidgets('"全部标记已调好" sets allConfirmed and shows the banner',
        (WidgetTester tester) async {
      await _useTallSurface(tester);
      await _pumpPage(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('tuner-confirm-all')),
      );
      await tester.pumpAndSettle();

      expect(find.text('已确认 4 / 4'), findsOneWidget);
      expect(find.text('已调好（取消）'), findsNWidgets(4));
      expect(
        find.textContaining('四根弦都已确认'),
        findsOneWidget,
      );
    });
  });
}
