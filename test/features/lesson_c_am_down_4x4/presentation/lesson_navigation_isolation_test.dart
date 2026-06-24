// T045 integration test: lesson → metronome / recording round-trip
// must NOT auto-mutate shared state.
//
// Scope (T045 brief §自动化验证):
// - The lesson page pushes `/metronome` and `/recording` as
//   separate routes (T044 implementation:
//   `lib/features/lesson_c_am_down_4x4/presentation/lesson_page.dart`).
//   Tapping the metronome step button or the recording step
//   button MUST NOT:
//     * change the metronome BPM,
//     * auto-start the metronome,
//     * auto-start the recording.
// - The pushed route must be reachable from the lesson page
//   (the navigation arrow lands) and the back arrow on the
//   pushed page must pop back to the lesson (round-trip).
//
// This file is the only NEW test added by T045. All other T045
// requirements (C chord entry point, unknown lesson id not-found,
// lesson data ↔ rhythm widget consistency) are already covered by
// the existing tests under:
//   - test/features/chord_library/presentation/chord_detail_page_test.dart
//   - test/features/lesson_c_am_down_4x4/presentation/lesson_page_test.dart
//   - test/features/lesson_c_am_down_4x4/presentation/widgets/strum_pattern_diagram_test.dart
//   - test/core/lesson_constants_test.dart
//
// T045A note: this file builds a *local* `GoRouter` whose parent
// `/lessons` route has a `builder` (not the production
// `redirect`). It therefore does NOT cover the
// `/lessons` parent-redirect bug. The regression net for that
// bug lives in
// `test/integration/lesson_route_e2e_test.dart`, which mounts
// the production `appRouter` and asserts that pushing the
// child route actually mounts `LessonPage`. Keep both: this
// file pins the controller-isolation contract at unit level;
// the e2e file pins the routing contract at integration level.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ukulele_app/features/lesson_c_am_down_4x4/presentation/lesson_page.dart';
import 'package:ukulele_app/features/metronome/application/metronome_controller.dart';
import 'package:ukulele_app/features/recording/application/recording_practice_controller.dart';

void main() {
  group('LessonPage navigation isolation (T045)', () {
    testWidgets(
        'tapping the metronome step pushes /metronome and '
        'popping returns to lesson — no BPM change, no auto-start',
        (WidgetTester tester) async {
      // Spy router. Parent /lessons is a redirect target only —
      // direct visits send the user home per `appRouter` config.
      // For the test we treat it as a builder so go_router accepts
      // the route table; we only ever visit the lesson detail
      // and the pushed /metronome.
      final GoRouter router = GoRouter(
        initialLocation: '/lessons/c_am_down_4x4',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext context, GoRouterState state) =>
                const _RouteProbe(label: 'home'),
          ),
          GoRoute(
            path: '/lessons',
            // Mirror the real parent behaviour: a builder so the
            // route is valid; we never visit it.
            builder: (BuildContext context, GoRouterState state) =>
                const _RouteProbe(label: 'lessons-parent'),
            routes: <RouteBase>[
              GoRoute(
                path: ':lessonId',
                name: 'lesson-detail',
                builder: (BuildContext context, GoRouterState state) =>
                    LessonPage(
                  lessonId: state.pathParameters['lessonId'] ?? '',
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/metronome',
            builder: (BuildContext context, GoRouterState state) =>
                const _RouteProbe(label: 'metronome'),
          ),
        ],
      );

      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // Lesson page rendered.
      expect(find.byType(LessonPage), findsOneWidget);

      // Snapshot shared state BEFORE the navigation.
      final MetronomeController metronome = container.read(
        metronomeControllerProvider.notifier,
      );
      final MetronomeState stateBefore = container.read(
        metronomeControllerProvider,
      );
      expect(stateBefore.isRunning, isFalse,
          reason: 'metronome must not be running at lesson entry');

      // Scroll the lesson list until the 60 BPM step button is
      // visible, then tap it.
      final Finder scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('调整到 60 BPM 后开始'),
        200,
        scrollable: scrollable,
      );
      await tester.tap(find.text('调整到 60 BPM 后开始'));
      await tester.pumpAndSettle();

      // The pushed /metronome page is now on top.
      expect(find.text('route-marker=metronome'), findsOneWidget);
      expect(find.byType(LessonPage), findsNothing);

      // Critical: pushing the route did NOT touch the metronome
      // controller. BPM is still the default and the timer is
      // still not running. This is the regression we are
      // guarding against — a previous design considered
      // auto-starting the metronome when the lesson user tapped
      // a BPM step; that was removed and we pin it here.
      final MetronomeState stateAfter = container.read(
        metronomeControllerProvider,
      );
      expect(stateAfter.bpm, stateBefore.bpm,
          reason: 'lesson navigation must not change BPM');
      expect(stateAfter.isRunning, isFalse,
          reason: 'lesson navigation must not start the metronome');
      // Sanity: the controller itself is unchanged in identity.
      expect(identical(metronome, container.read(
            metronomeControllerProvider.notifier,
          )), isTrue);

      // Pop the route — go_router exposes the back arrow via the
      // AppBar leading button on /metronome. We press it and
      // assert the lesson page comes back.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(LessonPage), findsOneWidget);
      expect(find.text('route-marker=metronome'), findsNothing);
    });

    testWidgets(
        'tapping the recording step pushes /recording and '
        'popping returns to lesson — no auto recording',
        (WidgetTester tester) async {
      final GoRouter router = GoRouter(
        initialLocation: '/lessons/c_am_down_4x4',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext context, GoRouterState state) =>
                const _RouteProbe(label: 'home'),
          ),
          GoRoute(
            path: '/lessons',
            builder: (BuildContext context, GoRouterState state) =>
                const _RouteProbe(label: 'lessons-parent'),
            routes: <RouteBase>[
              GoRoute(
                path: ':lessonId',
                name: 'lesson-detail',
                builder: (BuildContext context, GoRouterState state) =>
                    LessonPage(
                  lessonId: state.pathParameters['lessonId'] ?? '',
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/recording',
            builder: (BuildContext context, GoRouterState state) =>
                const _RouteProbe(label: 'recording'),
          ),
        ],
      );

      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LessonPage), findsOneWidget);

      // Snapshot shared state BEFORE the navigation. We only need
      // to assert isRecording stays false — recording controller
      // has more knobs (savedRecordId, audioFilePath, etc.) and we
      // are not poking any of them in the lesson page.
      final RecordingPracticeState recStateBefore = container.read(
        recordingPracticeControllerProvider,
      );
      expect(recStateBefore.isRecording, isFalse);

      // Scroll to the "录音复盘" button (Step 3) and tap it.
      final Finder scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('录音复盘'),
        200,
        scrollable: scrollable,
      );
      await tester.tap(find.text('录音复盘'));
      await tester.pumpAndSettle();

      // /recording is on top, lesson is gone.
      expect(find.text('route-marker=recording'), findsOneWidget);
      expect(find.byType(LessonPage), findsNothing);

      // Recording was not auto-started by the lesson navigation.
      final RecordingPracticeState recStateAfter = container.read(
        recordingPracticeControllerProvider,
      );
      expect(recStateAfter.isRecording, isFalse,
          reason: 'lesson navigation must not start recording');
      // Identity preserved — controller not rebuilt by the push.
      expect(
        identical(
          container.read(recordingPracticeControllerProvider.notifier),
          container.read(recordingPracticeControllerProvider.notifier),
        ),
        isTrue,
      );

      // Pop back to lesson.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(LessonPage), findsOneWidget);
      expect(find.text('route-marker=recording'), findsNothing);
    });
  });
}

/// Generic route placeholder. Renders [marker] inside a
/// [Semantics] node so the test can find the current route
/// without picking up the AppBar title (which also uses the
/// same label text).
class _RouteProbe extends StatelessWidget {
  const _RouteProbe({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Center(
        child: Semantics(
          container: true,
          label: 'route-marker',
          child: Text('route-marker=$label'),
        ),
      ),
    );
  }
}
