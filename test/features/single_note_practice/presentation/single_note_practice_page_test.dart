// Tests for the [SingleNotePracticePage] widget.
//
// T009 scope:
// - Verify the page renders the title, intro blurb, current note
//   header, diagram, info card, progress, and the three controls.
// - Verify tapping "下一个" advances the current note, tapping
//   "标记已练习" flips the label and increments the count, and
//   tapping "上一个" walks backward.
// - Verify an open string shows the "不需要按品" copy.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/features/single_note_practice/data/built_in_single_notes.dart';
import 'package:ukulele_app/features/single_note_practice/domain/single_note.dart';
import 'package:ukulele_app/features/single_note_practice/presentation/single_note_practice_page.dart';
import 'package:ukulele_app/features/single_note_practice/presentation/widgets/single_note_info_card.dart';
import 'package:ukulele_app/features/single_note_practice/presentation/widgets/single_note_position_diagram.dart';

/// Sets a tall test surface so the entire page (header, diagram,
/// info card, progress, controls) fits in the viewport without
/// needing to scroll. Used by tests that need to interact with
/// elements scattered top-to-bottom.
Future<void> _useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
}

void main() {
  group('SingleNotePracticePage', () {
    testWidgets('renders title, intro blurb, controls and diagram',
        (WidgetTester tester) async {
      await _useTallSurface(tester);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SingleNotePracticePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // App bar title.
      expect(find.text('单音练习'), findsOneWidget);
      // Intro blurb is shown.
      expect(find.textContaining('入门单音练习'), findsOneWidget);
      // Initial current note header — the row has two Text widgets
      // ("当前：" and the display name), so use textContaining to
      // avoid coupling to the row layout.
      expect(
        find.textContaining(kBuiltInSingleNotes.first.displayName),
        findsWidgets,
      );
      // Diagram widget is on the page.
      expect(find.byType(SingleNotePositionDiagram), findsOneWidget);
      // Info card widget is on the page.
      expect(find.byType(SingleNoteInfoCard), findsOneWidget);
      // Progress label.
      expect(
        find.text('已练习 0 / ${kBuiltInSingleNotes.length}'),
        findsOneWidget,
      );

      // The three controls fit in the tall surface.
      expect(find.text('上一个'), findsOneWidget);
      expect(find.text('下一个'), findsOneWidget);
      expect(find.text('标记已练习'), findsOneWidget);
    });

    testWidgets('shows the open-string copy for an open note',
        (WidgetTester tester) async {
      // C is shipped as 3rd-string open. Walk to it (it is the
      // first note anyway) and verify the "不需要按品" copy.
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SingleNotePracticePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The page already starts on C; assert the open-string callout
      // is rendered at least once.
      expect(find.text('空弦，不需要按品'), findsOneWidget);
      expect(find.text('空弦，不需要用手指'), findsOneWidget);
    });

    testWidgets('"下一个" advances to the next note', (WidgetTester tester) async {
      await _useTallSurface(tester);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SingleNotePracticePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('下一个'));
      await tester.pumpAndSettle();

      // Now showing the second note.
      expect(
        find.textContaining(kBuiltInSingleNotes[1].displayName),
        findsWidgets,
      );
    });

    testWidgets('"上一个" walks back and wraps at the start',
        (WidgetTester tester) async {
      await _useTallSurface(tester);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SingleNotePracticePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // From the first note, previous wraps to the last.
      await tester.tap(find.text('上一个'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(kBuiltInSingleNotes.last.displayName),
        findsWidgets,
      );

      // Now previous walks back to the previous (second-to-last).
      await tester.tap(find.text('上一个'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          kBuiltInSingleNotes[kBuiltInSingleNotes.length - 2].displayName,
        ),
        findsWidgets,
      );
    });

    testWidgets('"标记已练习" toggles the flag and updates progress',
        (WidgetTester tester) async {
      await _useTallSurface(tester);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SingleNotePracticePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mark the first note as practiced.
      await tester.tap(find.text('标记已练习'));
      await tester.pumpAndSettle();

      expect(
          find.text('已练习 1 / ${kBuiltInSingleNotes.length}'), findsOneWidget);
      // The button label flipped.
      expect(find.text('取消已练习'), findsOneWidget);
      expect(find.text('标记已练习'), findsNothing);

      // Toggle off.
      await tester.tap(find.text('取消已练习'));
      await tester.pumpAndSettle();
      expect(
          find.text('已练习 0 / ${kBuiltInSingleNotes.length}'), findsOneWidget);
      expect(find.text('标记已练习'), findsOneWidget);
    });

    testWidgets('renders every shipped note at least once via the diagram',
        (WidgetTester tester) async {
      await _useTallSurface(tester);
      // Smoke test: walk through every note using prev/next and
      // assert the display name changes each time.
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SingleNotePracticePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (int i = 0; i < kBuiltInSingleNotes.length; i++) {
        expect(
          find.textContaining(kBuiltInSingleNotes[i].displayName),
          findsWidgets,
          reason: 'Note ${kBuiltInSingleNotes[i].id} not rendered',
        );
        await tester.tap(find.text('下一个'));
        await tester.pumpAndSettle();
      }
    });
  });

  group('SingleNoteInfoCard', () {
    testWidgets('renders a fretted note with fret and finger info',
        (WidgetTester tester) async {
      final SingleNote d =
          kBuiltInSingleNotes.firstWhere((SingleNote n) => n.id == 'd');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleNoteInfoCard(note: d),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('第 2 品'), findsOneWidget);
      // Finger line: "第 1 根手指（食指）"
      expect(find.text('第 1 根手指（食指）'), findsOneWidget);
    });

    testWidgets('renders an open note with the open-string copy',
        (WidgetTester tester) async {
      final SingleNote c =
          kBuiltInSingleNotes.firstWhere((SingleNote n) => n.id == 'c');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleNoteInfoCard(note: c),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('空弦，不需要按品'), findsOneWidget);
      expect(find.text('空弦，不需要用手指'), findsOneWidget);
    });
  });
}
