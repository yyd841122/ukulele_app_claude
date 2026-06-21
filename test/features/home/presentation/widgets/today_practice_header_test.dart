// Tests for the user-facing copy of the home page header.
//
// T015C_FIX_DEVICE_COPY_AND_LARGE_TEXT_LAYOUT scope:
// - The "T007 临时实现：installDate 后续由 T013 本地设置持久化。"
//   line that was rendered under the "已完成" counter on the
//   device-acceptance screenshots has been removed. The header
//   must now stop at the completed-count line.
//
// We render the header directly with a fabricated state, scan
// every visible Text widget for the forbidden T007 / T013 tokens,
// and assert none of them appear. We also assert the headline
// ("今日练习"), the day pill, and the completion counter are still
// present, so a future regression that hides everything does not
// slip through.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:ukulele_app/features/home/application/today_practice_controller.dart';
import 'package:ukulele_app/features/home/domain/built_in_practice_plan.dart';
import 'package:ukulele_app/features/home/domain/practice_task.dart';
import 'package:ukulele_app/features/home/domain/practice_task_icon.dart';
import 'package:ukulele_app/features/home/domain/practice_task_status.dart';
import 'package:ukulele_app/features/home/presentation/widgets/today_practice_header.dart';

/// Builds a minimal valid [TodayPracticeState] for the header
/// widget to render. We do not exercise the controller here — the
/// header is a pure projection of the state and is the only thing
/// the user sees.
TodayPracticeState _buildState() {
  return TodayPracticeState(
    today: DateTime(2026, 6, 20),
    installDate: DateTime(2026, 6, 20),
    dayIndex: 1,
    plan: const BuiltInPracticePlan(
      dayIndex: 1,
      title: '认识琴弦',
      estimatedMinutes: 15,
      tasks: <PracticeTask>[
        PracticeTask(
          id: 'day1_tuner',
          title: '调音 G / C / E / A',
          description: '逐弦手动调音，确保 G/C/E/A 四根弦音准。',
          estimatedMinutes: 5,
          routePath: '/tuner',
          iconName: PracticeTaskIcon.tuner,
          status: PracticeTaskStatus.todo,
        ),
        PracticeTask(
          id: 'day1_single_note',
          title: '单音 C / E 练习',
          description: '练习按出 C 弦与 E 弦的基础单音。',
          estimatedMinutes: 5,
          routePath: '/single-note',
          iconName: PracticeTaskIcon.singleNote,
          status: PracticeTaskStatus.todo,
        ),
        PracticeTask(
          id: 'day1_metronome',
          title: '节拍器 80 BPM 跟拍',
          description: '用节拍器 80 BPM 跟拍单音练习。',
          estimatedMinutes: 5,
          routePath: '/metronome',
          iconName: PracticeTaskIcon.metronome,
          status: PracticeTaskStatus.todo,
        ),
      ],
    ),
    completedTaskIds: const <String>{'day1_tuner'},
  );
}

void main() {
  setUpAll(() async {
    // The header formats the today's date with the `intl` package
    // using the `zh_CN` locale — initialise the locale data once
    // for the whole test file.
    await initializeDateFormatting('zh_CN');
  });

  group('TodayPracticeHeader — user copy', () {
    testWidgets('shows the headline, day pill and completion counter',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TodayPracticeHeader(state: _buildState()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('今日练习'), findsOneWidget);
      expect(find.text('Day 1'), findsOneWidget);
      expect(find.text('已完成：1 / 3'), findsOneWidget);
    });

    testWidgets(
        'does NOT render the historical T007 / T013 placeholder '
        'line', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TodayPracticeHeader(state: _buildState()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder allText = find.byType(Text);
      final List<String> visible = <String>[];
      for (final Element el in allText.evaluate()) {
        final Text w = el.widget as Text;
        final String? data = w.data;
        if (data != null) {
          visible.add(data);
        }
      }
      // Forbidden tokens from the device-acceptance screenshots.
      const List<String> forbidden = <String>[
        'T007',
        'T013',
        '临时实现',
        '后续由',
        '后续任务',
        '后续接入',
        '占位',
      ];
      for (final String token in forbidden) {
        for (final String text in visible) {
          expect(text, isNot(contains(token)),
              reason: 'Header must not render "$token"; got "$text"');
        }
      }
      // Also assert the exact placeholder line is gone.
      expect(
        find.text('T007 临时实现：installDate 后续由 T013 本地设置持久化。'),
        findsNothing,
      );
    });
  });
}
