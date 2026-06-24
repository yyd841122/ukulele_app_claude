// Tests for [LessonPage] (T044).
//
// Scope:
// - Known lesson id renders the full content (title, description,
//   4 beat chord labels, both navigation buttons).
// - Unknown / empty lesson id renders a friendly not-found
//   placeholder (mirrors `ChordDetailPage`).
// - The "开始课程" entry-point button on the chord detail page
//   navigates to `/lessons/c_am_down_4x4` (push, not go).
// - The strum pattern diagram uses the lesson data — we assert
//   the widget receives the exact `StrumPattern` instance from
//   `kBuiltInLessons` and not a hard-coded copy (T044 §Q1 fix).
// - 320x800 narrow screen renders without overflow.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ukulele_app/core/constants/lesson_constants.dart';
import 'package:ukulele_app/features/lesson_c_am_down_4x4/presentation/lesson_page.dart';
import 'package:ukulele_app/features/lesson_c_am_down_4x4/presentation/widgets/lesson_intro_card.dart';
import 'package:ukulele_app/features/lesson_c_am_down_4x4/presentation/widgets/strum_pattern_diagram.dart';

void main() {
  group('LessonPage', () {
    testWidgets(
        'renders known lesson id with title, description, '
        'beat labels and navigation buttons', (WidgetTester tester) async {
      // Tall surface so the ListView reaches the step cards
      // without needing an inline scroll. We still scroll
      // below to be robust against future copy growth.
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const LessonPage(lessonId: 'c_am_down_4x4'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Lesson lesson = kBuiltInLessons.first;

      // Title appears in the AppBar AND in the page header — use
      // findsWidgets to stay robust to future copy placement.
      expect(find.text(lesson.title), findsWidgets);
      // Description (the one-sentence copy from the constant).
      expect(find.textContaining(lesson.description), findsOneWidget);
      // Beat chord labels rendered by the data-driven diagram:
      // beats 1-2 → "C" (×2), beats 3-4 → "Am" (×2).
      expect(find.text('C'), findsNWidgets(2));
      expect(find.text('Am'), findsNWidgets(2));
      // Time signature text rendered by the data-driven diagram.
      expect(find.text('4/4'), findsOneWidget);
      // Beat numbers rendered by the data-driven diagram (1, 2,
      // 3, 4 each appear at least once; the same digits also
      // appear inside the step-number avatar for Step 1/2/3, so
      // we assert `>= 1` instead of `== 1`).
      expect(find.text('1'), findsWidgets);
      expect(find.text('2'), findsWidgets);
      expect(find.text('3'), findsWidgets);
      expect(find.text('4'), findsOneWidget);
      // Scroll the list until the step buttons are visible, then
      // verify the metronome (Step 1 + 2) and recording (Step 3)
      // navigation buttons all rendered.
      final Finder scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('调整到 60 BPM 后开始'),
        200,
        scrollable: scrollable,
      );
      expect(find.text('调整到 60 BPM 后开始'), findsOneWidget);
      expect(find.text('调整到 80 BPM 后开始'), findsOneWidget);
      expect(find.text('录音复盘'), findsOneWidget);
    });

    testWidgets('unknown lesson id shows a friendly not-found state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const LessonPage(lessonId: 'lesson_does_not_exist'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No diagram is drawn.
      expect(find.byType(CAmDownStrumPatternDiagram), findsNothing);
      // Friendly copy is shown with the id echoed back to the user.
      expect(find.textContaining('未找到'), findsOneWidget);
      expect(find.textContaining('lesson_does_not_exist'), findsOneWidget);
      // A way back to home is offered.
      expect(find.text('返回首页'), findsOneWidget);
    });

    testWidgets('empty lesson id shows a friendly not-found state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const LessonPage(lessonId: ''),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The empty id is echoed inside the not-found message and
      // the strum-pattern diagram is not rendered.
      expect(find.textContaining('未找到'), findsOneWidget);
      expect(find.byType(CAmDownStrumPatternDiagram), findsNothing);
      expect(find.text('返回首页'), findsOneWidget);
    });

    testWidgets('entry-point card navigates to /lessons/:id on tap',
        (WidgetTester tester) async {
      // Spy router: any push to /lessons/:id lands here so we can
      // assert the route was reached without spinning up the full
      // app router (which would require the chord library to
      // also be wired up under ProviderScope).
      final GoRouter router = GoRouter(
        initialLocation: '/chords/c',
        routes: <RouteBase>[
          GoRoute(
            path: '/chords',
            name: 'chords',
            builder: (BuildContext context, GoRouterState state) =>
                const _EntryPointHost(),
            routes: <RouteBase>[
              GoRoute(
                path: ':chordId',
                name: 'chord-detail',
                builder: (BuildContext context, GoRouterState state) =>
                    const _EntryPointHost(),
              ),
            ],
          ),
          GoRoute(
            path: '/lessons',
            name: 'lessons',
            // Parent route in the spy: a real entry point would
            // land on the lesson detail directly, but go_router
            // requires a builder / pageBuilder / redirect on
            // every GoRoute. The host renders nothing — the test
            // taps the entry-point card from the chord-detail
            // host (`/chords/c`) and only ever visits the
            // child route `/lessons/:lessonId`.
            builder: (BuildContext context, GoRouterState state) =>
                const _LessonListHost(),
            routes: <RouteBase>[
              GoRoute(
                path: ':lessonId',
                name: 'lesson-detail',
                builder: (BuildContext context, GoRouterState state) =>
                    _LessonSpy(
                  id: state.pathParameters['lessonId'] ?? '',
                ),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // Sanity: the entry-point host (chord detail surrogate) is
      // mounted and the LessonIntroCard it embeds is visible.
      expect(find.byType(LessonIntroCard), findsOneWidget);

      // Tap the "开始课程" button. The router pushes
      // /lessons/c_am_down_4x4 and the spy renders "route=<id>".
      await tester.tap(find.text('开始课程'));
      await tester.pumpAndSettle();

      expect(find.text('route=c_am_down_4x4'), findsOneWidget);
    });

    testWidgets('strum pattern diagram is fed by the lesson data',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const LessonPage(lessonId: 'c_am_down_4x4'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Exactly one diagram is on the page; the widget receives
      // the lesson's StrumPattern instance. Reading the field off
      // the widget (rather than re-deriving the chord sequence
      // from the DOM) is the only way to assert the data-flow
      // contract: the page passes the lesson pattern to the
      // widget, the widget does not re-hardcode it.
      final CAmDownStrumPatternDiagram diagram =
          tester.widget(find.byType(CAmDownStrumPatternDiagram));
      expect(diagram.strumPattern, equals(kBuiltInLessons.first.strumPattern));
      // And the rhythm matches the lesson payload.
      expect(diagram.strumPattern.id, 'down_4x4_c_am');
      expect(diagram.strumPattern.chordSequencePerBeat,
          <String>['C', 'C', 'Am', 'Am']);
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
        ProviderScope(
          child: MaterialApp(
            home: const LessonPage(lessonId: 'c_am_down_4x4'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LessonPage), findsOneWidget);
      // No layout exceptions, no RenderFlex overflowed.
      expect(tester.takeException(), isNull,
          reason: 'narrow screen must not produce a layout exception');
    });
  });
}

/// Surrogate "chord detail" host that simply embeds a
/// [LessonIntroCard]. Used by the entry-point navigation test
/// above to avoid mounting the real [ChordDetailPage] (which
/// would need the chord library ProviderScope wired up).
class _EntryPointHost extends StatelessWidget {
  const _EntryPointHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('C 和弦')),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: LessonIntroCard(),
        ),
      ),
    );
  }
}

/// Spy page that lands whenever something pushes /lessons/:id.
/// Renders the resolved id so the test can assert on it.
class _LessonSpy extends StatelessWidget {
  const _LessonSpy({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('lesson spy')),
      body: Center(child: Text('route=$id')),
    );
  }
}

/// Empty host for the parent /lessons route. Never reached in
/// the entry-point test, but required by go_router so the
/// parent GoRoute has a builder.
class _LessonListHost extends StatelessWidget {
  const _LessonListHost();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.shrink());
  }
}
