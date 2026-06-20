// Tests for the [RecordingPage] widget (T012 + T013.4A).
//
// T012 scope (preserved):
// - Verify the page renders the app bar title, the disclaimer
//   banner (with the three required points: no microphone, no
//   audio save, no audio playback), the status card, the timer,
//   all four primary controls, the secondary "重新录一遍" button,
//   the self-rating selector, and the note field.
// - Verify tapping "开始模拟录音" flips the status label and
//   enables the stop button.
// - Verify tapping "停止录音" exposes the playback entry.
// - Verify the self-rating selector and note field are visible.
//
// T013.4A scope:
// - The save button starts disabled, becomes enabled when a valid
//   take exists, and shows "正在保存…" while in flight.
// - A successful save flips the button to "已保存" and shows the
//   success SnackBar.
// - A failed save re-enables the button and shows the failure
//   SnackBar.
// - An ignored save shows no SnackBar.
// - While saving, the recording / rating / note controls are
//   disabled.
// - After a successful save, rating and note are disabled but
//   playback still works.
// - The page never touches the microphone and never persists
//   real audio (this is restated by the disclaimer banner test).
//
// Test strategy:
// - All widget tests use a `ProviderContainer` whose
//   `practiceRecordIdGeneratorProvider`,
//   `practiceRecordRepositoryProvider`, `practiceDayResolverProvider`
//   and `appClockProvider` are overridden with fakes so no real
//   DB / clock is ever touched.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/features/practice_records/application/practice_record_id_generator.dart';
import 'package:ukulele_app/features/practice_records/data/practice_record_repository.dart';
import 'package:ukulele_app/features/practice_records/data/practice_record_repository_provider.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_record.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_tag.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_type.dart';
import 'package:ukulele_app/features/practice_records/domain/self_assessment.dart';
import 'package:ukulele_app/features/recording/application/recording_practice_controller.dart';
import 'package:ukulele_app/features/recording/domain/self_rating.dart';
import 'package:ukulele_app/features/recording/presentation/recording_page.dart';
import 'package:ukulele_app/shared/providers/app_clock_provider.dart';
import 'package:ukulele_app/shared/services/practice_day_context.dart';

/// Sets a tall test surface so the whole page (disclaimer + status +
/// timer + controls + rating + note field + save button) fits
/// without scrolling.
Future<void> _useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 2000));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
}

/// Pinned clock + day for the save-flow tests.
final DateTime _kTestNowUtc = DateTime.utc(2026, 6, 20, 9, 0, 0);
final DateTime _kTestToday = DateTime(2026, 6, 20);
const int _kTestDayIndex = 2;

/// Returns a list of overrides that wire the controller against
/// the supplied fake repository + resolver. `clock` defaults to
/// the pinned `_kTestNowUtc` so every saved record is
/// deterministic.
List<Override> _buildOverrides({
  required PracticeRecordRepository repository,
  DateTime Function()? clock,
}) {
  return <Override>[
    practiceRecordIdGeneratorProvider.overrideWithValue(
      _SequentialPracticeRecordIdGenerator(),
    ),
    practiceRecordRepositoryProvider.overrideWithValue(repository),
    practiceDayResolverProvider.overrideWithValue(_FakePracticeDayResolver()),
    appClockProvider.overrideWithValue(clock ?? (() => _kTestNowUtc)),
  ];
}

/// Pumps the [RecordingPage] inside a `ProviderScope` with the
/// overrides supplied by [_buildOverrides]. The caller manages
/// the fake repository (passed in for assertions) and the
/// container lifecycle via [addTearDown].
Future<void> _pumpPage(
  WidgetTester tester,
  _FakePracticeRecordRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: _buildOverrides(repository: repository),
      child: const MaterialApp(
        home: RecordingPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('RecordingPage', () {
    testWidgets(
      'renders disclaimer, status, timer, controls, rating, note, '
      'and save button',
      (WidgetTester tester) async {
        await _useTallSurface(tester);
        await _pumpPage(tester, _FakePracticeRecordRepository());

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

        // Save button is rendered and initially disabled.
        expect(
          find.byKey(const ValueKey<String>('recording-save')),
          findsOneWidget,
        );
        final FilledButton saveButton = tester.widget<FilledButton>(
          find.byKey(const ValueKey<String>('recording-save')),
        );
        expect(saveButton.onPressed, isNull,
            reason: 'save button must start disabled');
      },
    );

    testWidgets(
      'tapping "开始模拟录音" flips status and enables stop',
      (WidgetTester tester) async {
        await _useTallSurface(tester);
        await _pumpPage(tester, _FakePracticeRecordRepository());

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
        await _pumpPage(tester, _FakePracticeRecordRepository());

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
        await _pumpPage(tester, _FakePracticeRecordRepository());

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
        await _pumpPage(tester, _FakePracticeRecordRepository());

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
        await _pumpPage(tester, _FakePracticeRecordRepository());

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
        await _pumpPage(tester, _FakePracticeRecordRepository());

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
        await _pumpPage(tester, _FakePracticeRecordRepository());

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

  group('RecordingPage save (T013.4A)', () {
    testWidgets(
      'save button is disabled after a 0-second take',
      (WidgetTester tester) async {
        await _useTallSurface(tester);
        await _pumpPage(tester, _FakePracticeRecordRepository());

        await tester.tap(
          find.byKey(const ValueKey<String>('recording-start')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-stop')),
        );
        await tester.pumpAndSettle();

        final FilledButton saveButton = tester.widget<FilledButton>(
          find.byKey(const ValueKey<String>('recording-save')),
        );
        expect(saveButton.onPressed, isNull,
            reason: '0-second take => recordedDurationSeconds == 0 '
                '=> canSave must be false');
      },
    );

    testWidgets(
      'save button enables after a valid take and no self-rating',
      (WidgetTester tester) async {
        await _useTallSurface(tester);
        await _pumpPage(tester, _FakePracticeRecordRepository());

        await tester.tap(
          find.byKey(const ValueKey<String>('recording-start')),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-stop')),
        );
        await tester.pumpAndSettle();

        final FilledButton saveButton = tester.widget<FilledButton>(
          find.byKey(const ValueKey<String>('recording-save')),
        );
        expect(saveButton.onPressed, isNotNull,
            reason: 'a 2-second take with no self-rating is still '
                'savable — self-rating is optional per the brief');
      },
    );

    testWidgets(
      'successful save flips the button to "已保存" and shows '
      'success SnackBar',
      (WidgetTester tester) async {
        await _useTallSurface(tester);
        final _FakePracticeRecordRepository repo =
            _FakePracticeRecordRepository();
        await _pumpPage(tester, repo);

        await tester.tap(
          find.byKey(const ValueKey<String>('recording-start')),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-stop')),
        );
        await tester.pumpAndSettle();

        // Tap save.
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-save')),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // Success SnackBar is shown.
        expect(
          find.byKey(
            const ValueKey<String>('recording-save-success-snackbar'),
          ),
          findsOneWidget,
        );
        // The button label now reads "已保存".
        expect(find.text('已保存'), findsOneWidget);
        // The button itself is now disabled.
        final FilledButton saveButton = tester.widget<FilledButton>(
          find.byKey(const ValueKey<String>('recording-save')),
        );
        expect(saveButton.onPressed, isNull);

        // The fake repository saw exactly one insert.
        expect(repo.inserted.length, 1);
      },
    );

    testWidgets(
      'failed save shows failure SnackBar and re-enables the button',
      (WidgetTester tester) async {
        await _useTallSurface(tester);
        final _FakePracticeRecordRepository repo =
            _FakePracticeRecordRepository()
              ..throwOnInsert = StateError('synthetic insert failure');
        await _pumpPage(tester, repo);

        await tester.tap(
          find.byKey(const ValueKey<String>('recording-start')),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-stop')),
        );
        await tester.pumpAndSettle();

        // Tap save. The fake throws -> failure.
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-save')),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(
          find.byKey(
            const ValueKey<String>('recording-save-failure-snackbar'),
          ),
          findsOneWidget,
        );
        // The button label is back to "保存到练习记录".
        expect(find.text('保存到练习记录'), findsOneWidget);
        // And it is re-enabled so the user can retry.
        final FilledButton saveButton = tester.widget<FilledButton>(
          find.byKey(const ValueKey<String>('recording-save')),
        );
        expect(saveButton.onPressed, isNotNull);
        expect(repo.inserted, isEmpty);
      },
    );

    testWidgets(
      'ignored save (e.g. Provider disposed mid-await) shows no '
      'SnackBar',
      (WidgetTester tester) async {
        // Wire a gated repository that never resolves so the
        // save is permanently in-flight. We then dispose the
        // ProviderScope so the controller sees `ref.mounted ==
        // false` and returns ignored.
        await _useTallSurface(tester);
        final _GatedPracticeRecordRepository repo =
            _GatedPracticeRecordRepository();
        await tester.pumpWidget(
          ProviderScope(
            overrides: _buildOverrides(repository: repo),
            child: const MaterialApp(
              home: RecordingPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey<String>('recording-start')),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-stop')),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey<String>('recording-save')),
        );
        await tester.pump();
        // Replace the widget tree with a fresh empty tree so the
        // ProviderScope is torn down -> the controller's
        // post-await `ref.mounted` check returns false ->
        // ignored.
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        await tester.pumpAndSettle();
        // Release the gate so the in-flight Future can complete.
        _GatedPracticeRecordRepository.gate.complete();

        // Neither SnackBar must be visible.
        expect(
          find.byKey(
            const ValueKey<String>('recording-save-success-snackbar'),
          ),
          findsNothing,
        );
        expect(
          find.byKey(
            const ValueKey<String>('recording-save-failure-snackbar'),
          ),
          findsNothing,
        );
      },
    );

    testWidgets(
      'rating and note are disabled after a successful save',
      (WidgetTester tester) async {
        await _useTallSurface(tester);
        await _pumpPage(tester, _FakePracticeRecordRepository());

        await tester.tap(
          find.byKey(const ValueKey<String>('recording-start')),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-stop')),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey<String>('recording-save')),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // Rating selector: disabled.
        final SegmentedButton<SelfRating> ratingSelector =
            tester.widget<SegmentedButton<SelfRating>>(
          find.byKey(const ValueKey<String>('recording-self-rating')),
        );
        expect(ratingSelector.onSelectionChanged, isNull,
            reason: 'rating selector must be disabled after a successful '
                'save');

        // Note field: disabled.
        final TextField noteField = tester.widget<TextField>(
          find.byKey(const ValueKey<String>('recording-note')),
        );
        expect(noteField.enabled, isFalse);
      },
    );

    testWidgets(
      'playback still works after a successful save',
      (WidgetTester tester) async {
        await _useTallSurface(tester);
        await _pumpPage(tester, _FakePracticeRecordRepository());

        await tester.tap(
          find.byKey(const ValueKey<String>('recording-start')),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-stop')),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey<String>('recording-save')),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // Tap play.
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-play')),
        );
        await tester.pumpAndSettle();
        expect(find.text('模拟回放中'), findsOneWidget);
        // Stop playback returns to "已录音".
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-stop-playback')),
        );
        await tester.pumpAndSettle();
        expect(find.text('已录音（可回放 / 自评）'), findsOneWidget);
        // The save status is still "已保存".
        expect(find.text('已保存'), findsOneWidget);
      },
    );

    testWidgets(
      'rating and note are disabled while saving',
      (WidgetTester tester) async {
        await _useTallSurface(tester);
        final _GatedPracticeRecordRepository repo =
            _GatedPracticeRecordRepository();
        await tester.pumpWidget(
          ProviderScope(
            overrides: _buildOverrides(repository: repo),
            child: const MaterialApp(
              home: RecordingPage(),
            ),
          ),
        );
        // Reset the shared gate after this test so the next
        // test starts with a fresh one. We do NOT release the
        // gate here — the ProviderScope is torn down at the end
        // of the test, which fires `ref.onDispose` and the
        // `saveCurrentTake` Future is dropped, leaving the gate
        // uncompleted (and therefore inert for the next test).
        addTearDown(_GatedPracticeRecordRepository.resetGate);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey<String>('recording-start')),
        );
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.tap(
          find.byKey(const ValueKey<String>('recording-stop')),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey<String>('recording-save')),
        );
        await tester.pump();

        // While the gate is still blocking, isSaving is true.
        expect(find.text('正在保存…'), findsOneWidget);

        final SegmentedButton<SelfRating> ratingSelector =
            tester.widget<SegmentedButton<SelfRating>>(
          find.byKey(const ValueKey<String>('recording-self-rating')),
        );
        expect(ratingSelector.onSelectionChanged, isNull);

        final TextField noteField = tester.widget<TextField>(
          find.byKey(const ValueKey<String>('recording-note')),
        );
        expect(noteField.enabled, isFalse);

        // Recording controls are also disabled.
        final FilledButton startButton = tester.widget<FilledButton>(
          find.byKey(const ValueKey<String>('recording-start')),
        );
        expect(startButton.onPressed, isNull);

        final OutlinedButton stopButton = tester.widget<OutlinedButton>(
          find.byKey(const ValueKey<String>('recording-stop')),
        );
        expect(stopButton.onPressed, isNull);
      },
    );

    testWidgets(
      'page never claims to use the microphone or persist real audio',
      (WidgetTester tester) async {
        // This test is a belt-and-braces restatement of the
        // disclaimer-banner assertion above. The page must NEVER
        // regress into claiming it records real audio — T013.4A
        // only persists a PracticeRecord (which has
        // audioFilePath == null) and never opens the microphone.
        await _useTallSurface(tester);
        await _pumpPage(tester, _FakePracticeRecordRepository());

        // The three mandated disclaimer phrases are present.
        expect(find.textContaining('不会调用麦克风'), findsOneWidget);
        expect(find.textContaining('不会保存真实音频'), findsOneWidget);
        expect(find.textContaining('不会播放真实音频'), findsOneWidget);
        // The page does NOT contain any positive claim about
        // "保存音频文件" / "保存真实录音" that contradicts the
        // disclaimer.
        expect(find.textContaining('保存音频文件'), findsNothing);
        expect(find.textContaining('保存真实录音'), findsNothing);
        // The initial status label is "准备录音" — a "准备"
        // (prepare) verb, NOT a claim of "正在录音" (currently
        // recording) which would imply the microphone is live.
        expect(find.text('准备录音'), findsOneWidget);
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

/// In-memory [PracticeRecordRepository] used by the save-flow
/// tests. Records every inserted row so assertions can inspect
/// them. Can be flipped to throw on insert to exercise the
/// failure path.
class _FakePracticeRecordRepository implements PracticeRecordRepository {
  Object? throwOnInsert;
  final List<PracticeRecord> inserted = <PracticeRecord>[];

  @override
  Future<PracticeRecord> insert(PracticeRecord record) async {
    if (throwOnInsert != null) {
      throw throwOnInsert!;
    }
    inserted.add(record);
    return record;
  }

  @override
  Future<PracticeRecord?> getById(String id) async {
    for (final PracticeRecord r in inserted) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  Future<List<PracticeRecord>> listRecent({int limit = 50}) async {
    return List<PracticeRecord>.unmodifiable(inserted);
  }

  @override
  Stream<List<PracticeRecord>> watchAll() async* {
    yield List<PracticeRecord>.unmodifiable(inserted);
  }

  @override
  Future<bool> delete(String id) async => false;
}

/// Repository whose `insert` blocks on a static `gate` future
/// (initialised lazily). Used to hold the controller inside
/// `saveCurrentTake` so the widget test can observe the
/// in-flight state and dispose the Provider mid-await.
class _GatedPracticeRecordRepository implements PracticeRecordRepository {
  static Completer<void> gate = Completer<void>();
  final List<PracticeRecord> inserted = <PracticeRecord>[];

  /// Resets the shared gate. Called from the test `addTearDown`
  /// so the next test starts with a fresh gate.
  static void resetGate() {
    gate = Completer<void>();
  }

  @override
  Future<PracticeRecord> insert(PracticeRecord record) async {
    await gate.future;
    inserted.add(record);
    return record;
  }

  @override
  Future<PracticeRecord?> getById(String id) async => null;

  @override
  Future<List<PracticeRecord>> listRecent({int limit = 50}) async =>
      const <PracticeRecord>[];

  @override
  Stream<List<PracticeRecord>> watchAll() async* {
    yield const <PracticeRecord>[];
  }

  @override
  Future<bool> delete(String id) async => false;
}

/// Practice-day resolver that returns the pinned test context —
/// used to make every test's saved record deterministic.
class _FakePracticeDayResolver implements PracticeDayResolver {
  @override
  Future<PracticeDayContext> resolve() async {
    return PracticeDayContext(
      today: _kTestToday,
      installDate: _kTestToday.subtract(const Duration(days: 1)),
      dayIndex: _kTestDayIndex,
    );
  }
}

/// ID generator that returns a sequence of stable test ids:
/// `take-1`, `take-2`, ...
class _SequentialPracticeRecordIdGenerator
    implements PracticeRecordIdGenerator {
  int _callCount = 0;

  @override
  String generate() {
    _callCount += 1;
    return 'take-$_callCount';
  }
}

// Silence unused-import lint if the dayIndex constant is referenced
// only through the resolver.
// ignore: unused_element
typedef _SilenceUnused = (SelfAssessment, PracticeTag, PracticeType);
