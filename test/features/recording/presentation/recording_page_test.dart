// Tests for the [RecordingPage] widget (T012).
//
// Scope:
// - Verify the page renders the app bar title, the disclaimer
//   banner (with the three required points: no microphone, no
//   audio save, no audio playback), the status card, the timer,
//   all four primary controls, the secondary "重新录一遍" button,
//   the self-rating selector, and the note field.
// - Verify tapping "开始模拟录音" flips the status label and
//   enables the stop button.
// - Verify tapping "停止录音" exposes the playback entry.
// - Verify the self-rating selector and note field are visible.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/features/recording/application/recording_practice_controller.dart';
import 'package:ukulele_app/features/recording/presentation/recording_page.dart';

/// Sets a tall test surface so the whole page (disclaimer + status +
/// timer + controls + rating + note field) fits without scrolling.
Future<void> _useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1800));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
}

Future<void> _pumpPage(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(
        home: RecordingPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('RecordingPage', () {
    testWidgets(
      'renders disclaimer, status, timer, controls, rating and note',
      (WidgetTester tester) async {
        await _useTallSurface(tester);
        await _pumpPage(tester);

        // App bar title.
        expect(find.text('录音回放'), findsOneWidget);

        // Disclaimer banner copy is present. The brief mandates
        // three explicit points: no microphone, no audio save, no
        // audio playback.
        expect(
          find.textContaining('不会调用麦克风'),
          findsOneWidget,
        );
        expect(
          find.textContaining('不会保存真实音频'),
          findsOneWidget,
        );
        expect(
          find.textContaining('不会播放真实音频'),
          findsOneWidget,
        );

        // Initial status is "准备录音".
        expect(find.text('准备录音'), findsOneWidget);

        // Initial timer reads 00:00.
        expect(find.text('00:00'), findsOneWidget);

        // All four primary controls are present.
        expect(find.text('开始模拟录音'), findsOneWidget);
        expect(find.text('停止录音'), findsOneWidget);
        expect(find.text('模拟回放'), findsOneWidget);
        expect(find.text('停止回放'), findsOneWidget);

        // Secondary "重新录一遍" button.
        expect(find.text('重新录一遍'), findsOneWidget);

        // Self-rating selector labels.
        expect(find.text('还不错'), findsOneWidget);
        expect(find.text('一般'), findsOneWidget);
        expect(find.text('需要重练'), findsOneWidget);

        // Note field exists (find by key, since the TextField's
        // inner label is empty until the user types).
        expect(
          find.byKey(const ValueKey<String>('recording-note')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping "开始模拟录音" flips status and enables stop',
      (WidgetTester tester) async {
        await _useTallSurface(tester);
        await _pumpPage(tester);

        // Initial status.
        expect(find.text('准备录音'), findsOneWidget);

        // The stop button is initially disabled — tap it via
        // tapping start, then assert stop is now tappable.
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-start')),
        );
        await tester.pumpAndSettle();

        expect(find.text('模拟录音中'), findsOneWidget);
        // Stop button should now be enabled (we verify by tapping
        // it in the next test).
      },
    );

    testWidgets(
      'tapping "停止录音" exposes the playback entry',
      (WidgetTester tester) async {
        await _useTallSurface(tester);
        await _pumpPage(tester);

        await tester.tap(
          find.byKey(const ValueKey<String>('recording-start')),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey<String>('recording-stop')),
        );
        await tester.pumpAndSettle();

        expect(find.text('已录音（可回放 / 自评）'), findsOneWidget);

        // The play button is now active — tap it and the status
        // label should switch to "模拟回放中".
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-play')),
        );
        await tester.pumpAndSettle();
        expect(find.text('模拟回放中'), findsOneWidget);

        // Stop playback returns us to the "已录音" status.
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-stop-playback')),
        );
        await tester.pumpAndSettle();
        expect(find.text('已录音（可回放 / 自评）'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping a self-rating button selects it',
      (WidgetTester tester) async {
        await _useTallSurface(tester);
        await _pumpPage(tester);

        // Get to a state where rating is allowed.
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-start')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-stop')),
        );
        await tester.pumpAndSettle();

        // Tap "需要重练" inside the rating selector.
        await tester.tap(
          find.descendant(
            of: find.byKey(
              const ValueKey<String>('recording-self-rating'),
            ),
            matching: find.text('需要重练'),
          ),
        );
        await tester.pumpAndSettle();

        // Reading state via the provider confirms the choice.
        final BuildContext ctx = tester.element(find.byType(RecordingPage));
        final ProviderContainer container = ProviderScope.containerOf(ctx);
        expect(
          container
              .read(recordingPracticeControllerProvider)
              .selfRating
              .toString(),
          'SelfRating.retry',
        );
      },
    );

    testWidgets(
      'typing into the note field updates the controller state',
      (WidgetTester tester) async {
        await _useTallSurface(tester);
        await _pumpPage(tester);

        await tester.tap(
          find.byKey(const ValueKey<String>('recording-start')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-stop')),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey<String>('recording-note')),
          'C->Am 切换太慢',
        );
        await tester.pumpAndSettle();

        final BuildContext ctx = tester.element(find.byType(RecordingPage));
        final ProviderContainer container = ProviderScope.containerOf(ctx);
        expect(
          container.read(recordingPracticeControllerProvider).note,
          'C->Am 切换太慢',
        );
      },
    );

    testWidgets(
      'note field is disabled while recording',
      (WidgetTester tester) async {
        await _useTallSurface(tester);
        await _pumpPage(tester);

        await tester.tap(
          find.byKey(const ValueKey<String>('recording-start')),
        );
        await tester.pumpAndSettle();

        final TextField noteField = tester.widget<TextField>(
          find.byKey(const ValueKey<String>('recording-note')),
        );
        expect(noteField.enabled, isFalse);

        // Cleanup: stop recording so the timer is cancelled.
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-stop')),
        );
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      '"重新录一遍" returns to the initial state',
      (WidgetTester tester) async {
        await _useTallSurface(tester);
        await _pumpPage(tester);

        await tester.tap(
          find.byKey(const ValueKey<String>('recording-start')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-stop')),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey<String>('recording-reset')),
        );
        await tester.pumpAndSettle();

        expect(find.text('准备录音'), findsOneWidget);
        expect(find.text('00:00'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping "开始模拟录音" while playing starts a new take',
      (WidgetTester tester) async {
        // T012_FIX_RECORDING_PLAYBACK_START_BUTTON: the page must
        // expose the "开始模拟录音" button while the simulated
        // playback is running, so the user can stop playback and
        // start a new take in one tap (matching the controller
        // contract).
        await _useTallSurface(tester);
        await _pumpPage(tester);

        // Record a short take so we can play it back.
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-start')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-stop')),
        );
        await tester.pumpAndSettle();

        // Enter playback.
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-play')),
        );
        await tester.pumpAndSettle();
        expect(find.text('模拟回放中'), findsOneWidget);

        // While playing, the "开始模拟录音" button must remain
        // enabled. The previous implementation disabled it here,
        // which broke the controller contract that allows
        // startRecording() to interrupt playback.
        final FilledButton startButton = tester.widget<FilledButton>(
          find.byKey(const ValueKey<String>('recording-start')),
        );
        expect(startButton.onPressed, isNotNull);

        // Tap it. The page must transition to "模拟录音中" and
        // leave playback behind.
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-start')),
        );
        await tester.pumpAndSettle();
        expect(find.text('模拟录音中'), findsOneWidget);
        expect(find.text('模拟回放中'), findsNothing);

        // The controller should also be in the recording state
        // and the clock should have been reset to 00:00.
        expect(find.text('00:00'), findsOneWidget);

        // Cleanup the timer.
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-stop')),
        );
        await tester.pumpAndSettle();
      },
    );
  });
}
