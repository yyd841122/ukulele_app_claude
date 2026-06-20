// Tests for the [MetronomePage] widget (T010).
//
// Scope:
// - Verifies the page renders the title, the audio-disclaimer
//   copy, the BPM hero, the start/stop button, the BPM +/- and
//   preset chips, the beats-per-bar selector, and the sound
//   toggle.
// - Verifies that tapping BPM + / BPM - updates the displayed
//   BPM, that tapping the start/stop button flips the label,
//   that picking a preset BPM updates the display, that
//   selecting a different beats-per-bar updates the indicator,
//   and that toggling the sound switch flips the subtitle.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/features/metronome/application/metronome_controller.dart';
import 'package:ukulele_app/features/metronome/presentation/metronome_page.dart';
import 'package:ukulele_app/features/metronome/presentation/widgets/bpm_controls.dart';

/// Sets a tall test surface so the page (which is a ListView) fits
/// in the viewport without needing to scroll.
Future<void> _useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
}

Future<void> _pumpPage(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(
        home: MetronomePage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('MetronomePage', () {
    testWidgets('renders title, BPM hero, controls, and audio disclaimer',
        (WidgetTester tester) async {
      await _useTallSurface(tester);
      await _pumpPage(tester);

      // AppBar title.
      expect(find.text('节拍器'), findsOneWidget);

      // Audio disclaimer banner copy is present.
      expect(
        find.textContaining('当前版本为可视化节拍器'),
        findsOneWidget,
      );

      // BPM hero — initial 80.
      expect(find.text('80 BPM'), findsOneWidget);
      // Beat 1 of 4 in the indicator.
      expect(find.text('第 1 / 4 拍'), findsOneWidget);
      // Downbeat accent.
      expect(find.text('重拍'), findsOneWidget);

      // Start / stop button shows "开始".
      expect(find.text('开始'), findsOneWidget);

      // BPM controls.
      expect(find.text('BPM -'), findsOneWidget);
      expect(find.text('BPM +'), findsOneWidget);
      for (final int preset in BpmControls.presets) {
        expect(find.text('$preset'), findsWidgets);
      }

      // Beats-per-bar options.
      for (final int beats in const <int>[2, 3, 4, 6]) {
        expect(find.text('$beats'), findsWidgets);
      }

      // Sound toggle exists with the visual-only disclaimer.
      expect(find.text('开启声音'), findsOneWidget);
      expect(
        find.textContaining('可视化节拍'),
        findsWidgets,
      );
    });

    testWidgets('tapping BPM + increments the displayed BPM',
        (WidgetTester tester) async {
      await _useTallSurface(tester);
      await _pumpPage(tester);

      await tester
          .tap(find.byKey(const ValueKey<String>('metronome-bpm-increase')));
      await tester.pumpAndSettle();

      expect(find.text('81 BPM'), findsOneWidget);
      expect(find.text('80 BPM'), findsNothing);
    });

    testWidgets('tapping BPM - decrements the displayed BPM',
        (WidgetTester tester) async {
      await _useTallSurface(tester);
      await _pumpPage(tester);

      await tester
          .tap(find.byKey(const ValueKey<String>('metronome-bpm-decrease')));
      await tester.pumpAndSettle();

      expect(find.text('79 BPM'), findsOneWidget);
    });

    testWidgets('tapping a preset chip jumps to that BPM',
        (WidgetTester tester) async {
      await _useTallSurface(tester);
      await _pumpPage(tester);

      await tester.tap(
        find.byKey(const ValueKey<String>('metronome-bpm-preset-100')),
      );
      await tester.pumpAndSettle();

      expect(find.text('100 BPM'), findsOneWidget);
    });

    testWidgets('tapping start flips the label to stop',
        (WidgetTester tester) async {
      await _useTallSurface(tester);
      await _pumpPage(tester);

      expect(find.text('开始'), findsOneWidget);
      await tester
          .tap(find.byKey(const ValueKey<String>('metronome-start-stop')));
      await tester.pumpAndSettle();

      expect(find.text('停止'), findsOneWidget);
      expect(find.text('开始'), findsNothing);

      // Stop again flips it back.
      await tester
          .tap(find.byKey(const ValueKey<String>('metronome-start-stop')));
      await tester.pumpAndSettle();

      expect(find.text('开始'), findsOneWidget);
      expect(find.text('停止'), findsNothing);
    });

    testWidgets('changing beats-per-bar updates the indicator',
        (WidgetTester tester) async {
      await _useTallSurface(tester);
      await _pumpPage(tester);

      expect(find.text('第 1 / 4 拍'), findsOneWidget);

      // Tap "3" in the beats-per-bar selector. Two widgets render
      // "3": the 3-beat segment AND the 100 BPM preset chip. Tap
      // the one inside the SegmentedButton to be unambiguous.
      final Finder threeSegment = find.descendant(
        of: find.byKey(
          const ValueKey<String>('metronome-beats-per-bar-selector'),
        ),
        matching: find.text('3'),
      );
      await tester.tap(threeSegment);
      await tester.pumpAndSettle();

      expect(find.text('第 1 / 3 拍'), findsOneWidget);
    });

    testWidgets('toggling the sound switch flips its subtitle',
        (WidgetTester tester) async {
      await _useTallSurface(tester);
      await _pumpPage(tester);

      // Off state subtitle is present.
      expect(
        find.text('当前版本为可视化节拍，声音将在后续任务接入。'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('metronome-sound-toggle')),
      );
      await tester.pumpAndSettle();

      // On state subtitle is now present, off-state copy is gone.
      expect(
        find.text(
          '已开启（当前仍为可视化节拍，声音将在后续任务接入）',
        ),
        findsOneWidget,
      );
      expect(
        find.text('当前版本为可视化节拍，声音将在后续任务接入。'),
        findsNothing,
      );
    });

    testWidgets(
      'ticking the controller advances the visible beat indicator',
      (WidgetTester tester) async {
        await _useTallSurface(tester);
        await _pumpPage(tester);

        final BuildContext ctx = tester.element(
          find.byType(MetronomePage),
        );
        final ProviderContainer container = ProviderScope.containerOf(ctx);
        final MetronomeController controller =
            container.read(metronomeControllerProvider.notifier);

        controller.tickForTesting();
        await tester.pumpAndSettle();

        expect(find.text('第 2 / 4 拍'), findsOneWidget);
        expect(find.text('轻拍'), findsOneWidget);
      },
    );
  });
}
