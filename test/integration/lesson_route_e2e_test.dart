// T045A integration test: lesson child route must NOT be
// redirected to home.
//
// Regression target: the `/lessons` parent `GoRoute` used to
// declare `redirect: (_, __) => '/'` to satisfy go_router's
// "a route must have a builder / pageBuilder / redirect"
// assertion. In go_router 17.x a parent redirect runs for
// every match in that subtree, including child routes — so
// `context.push('/lessons/c_am_down_4x4')` was being
// silently rewritten to `/` and `LessonPage` never mounted.
//
// The unit-level spy tests under
// `test/features/lesson_c_am_down_4x4/presentation/` do not
// catch this because they build a local `GoRouter` where the
// parent `/lessons` route has a `builder`. This file uses
// the production `appRouter` and a real
// `MaterialApp.router(routerConfig: ...)` so the redirect
// implementation is the one shipped to production.
//
// The chord-detail entry-point test
// (`'navigating from chord detail page ...'`) also exercises
// `context.push('/lessons/c_am_down_4x4')` indirectly — the
// `LessonIntroCard` "开始课程" button is the exact widget the
// user taps on a real device, so the regression cannot sneak
// back in through a refactor of the intro card's push target.
//
// Implementation note: the production `appRouter` is a
// top-level singleton. We cannot easily mock the database,
// and `HomePage` reads it through
// `todayPracticeControllerProvider`, which spins forever
// under `flutter test` without a real
// `AppDatabase.forTesting(NativeDatabase.memory())` override.
// We are testing the router's redirect logic, not HomePage,
// so we drive the router directly and mount only the router
// shell at pages that do NOT pull the database (the lesson
// pages, the C chord detail page). For the one test that
// confirms "direct /lessons → home", we drive the redirect
// to `/` and immediately stop pumping, so HomePage never
// settles on its Drift read.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/app/router.dart';
import 'package:ukulele_app/features/chord_library/presentation/chord_detail_page.dart';
import 'package:ukulele_app/features/lesson_c_am_down_4x4/presentation/lesson_page.dart';

void main() {
  setUp(() async {
    // `appRouter` is a top-level singleton; reset it to home
    // between tests so a previous test's navigation does not
    // leak into the next one.
    appRouter.go('/');
  });

  Future<void> pumpAppAt(
    WidgetTester tester,
    String initialLocation,
  ) async {
    // Set the initial location BEFORE mounting so the widget
    // tree is rooted on the page under test, not on `HomePage`.
    appRouter.go(initialLocation);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: appRouter),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('T045A: /lessons parent redirect (real appRouter)', () {
    testWidgets(
      'direct push to /lessons/<valid id> mounts LessonPage',
      (WidgetTester tester) async {
        await pumpAppAt(tester, '/lessons/c_am_down_4x4');

        // The production appRouter must resolve the child
        // route to its builder, NOT bounce us back to home.
        expect(find.byType(LessonPage), findsOneWidget);
        expect(
          appRouter.routerDelegate.currentConfiguration.uri.path,
          '/lessons/c_am_down_4x4',
        );
      },
    );

    testWidgets(
      'unknown lessonId renders LessonPage not-found state '
      'on /lessons/<id> (not the parent NotFoundPage)',
      (WidgetTester tester) async {
        await pumpAppAt(tester, '/lessons/does_not_exist');

        // LessonPage owns the friendly not-found state. The
        // route must stay at /lessons/<id>; the parent
        // redirect must NOT kick in here.
        expect(find.byType(LessonPage), findsOneWidget);
        expect(
          appRouter.routerDelegate.currentConfiguration.uri.path,
          '/lessons/does_not_exist',
        );
        // Sanity: the page renders the in-page not-found
        // placeholder rather than the app-wide 404.
        expect(find.text('课程详情'), findsOneWidget,
            reason: 'LessonPage must render its own not-found '
                'shell (AppBar title) for unknown ids');
      },
    );

    testWidgets(
      'direct visit to /lessons rewrites the route to "/"',
      (WidgetTester tester) async {
        // Mount on the chord detail page first so the
        // widget tree paints a page that does NOT read the
        // database. Then drive `appRouter.go('/lessons')` and
        // observe the router configuration change — the
        // redirect runs inside the router without needing
        // HomePage to settle on a database read.
        await pumpAppAt(tester, '/chords/c');
        expect(find.byType(ChordDetailPage), findsOneWidget);

        appRouter.go('/lessons');
        // A handful of pumps is enough for go_router to run
        // the parent redirect and update the configuration.
        // We deliberately avoid `pumpAndSettle` because the
        // redirect lands on HomePage, which spins on the
        // Drift read forever under flutter test.
        for (int i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }

        expect(
          appRouter.routerDelegate.currentConfiguration.uri.path,
          '/',
          reason: 'Parent /lessons must redirect to /; '
              'only child routes may resolve to a builder',
        );
      },
    );

    testWidgets(
      'navigating from chord detail page "开始课程" mounts LessonPage',
      (WidgetTester tester) async {
        // The C chord detail page is the only production
        // surface that embeds the lesson intro card. It
        // does NOT read the database, so we can mount it
        // directly without the HomePage database spin.
        await pumpAppAt(tester, '/chords/c');
        expect(find.byType(ChordDetailPage), findsOneWidget);
        expect(find.text('开始课程'), findsOneWidget,
            reason: 'LessonIntroCard must render the '
                '"开始课程" entry button on the C chord page');

        // Tap the intro card's action button — the exact
        // navigation the user performs on a real device.
        await tester.tap(find.text('开始课程'));
        await tester.pumpAndSettle();

        // The lesson page must be on top, not home. This is
        // the exact assertion that was failing on the user's
        // device during T045 acceptance. We assert on the
        // mounted widget (LessonPage) rather than the router
        // configuration string, because go_router updates
        // the configuration asynchronously after a push
        // while the page is built synchronously from the
        // RouteInformationParser. The
        // "direct push to /lessons/<valid id>" test already
        // pins the URL string; here we only need to confirm
        // the widget tree changes.
        expect(find.byType(LessonPage), findsOneWidget,
            reason: 'LessonPage must mount when child route '
                '/lessons/:lessonId is pushed via the '
                'production appRouter');
        // The chord detail page must be off-screen — the
        // intro card is no longer visible.
        expect(find.text('开始课程'), findsNothing,
            reason: 'After tapping "开始课程" the lesson '
                'page must replace the chord detail page');
      },
    );
  });
}