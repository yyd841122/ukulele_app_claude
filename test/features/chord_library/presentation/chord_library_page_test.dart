// Tests for the chord library list page.
//
// T008 scope:
// - Verify the page renders the title, intro blurb, and one card per
//   built-in chord.
// - Verify tapping a card pushes the matching detail route.
// - Verify the page reads from [chordLibraryProvider] (not from a
//   hard-coded constant) by overriding the provider.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ukulele_app/features/chord_library/application/chord_library_controller.dart';
import 'package:ukulele_app/features/chord_library/data/built_in_chords.dart';
import 'package:ukulele_app/features/chord_library/domain/chord.dart';
import 'package:ukulele_app/features/chord_library/presentation/chord_library_page.dart';

void main() {
  group('ChordLibraryPage', () {
    testWidgets('renders title, blurb and a card for every chord',
        (WidgetTester tester) async {
      // Bump the test viewport so all 7 cards fit without scrolling
      // — T053 added G7 / Dm / Em to the library, so the page is
      // taller than the default 800×600 test surface.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: const ChordLibraryPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('和弦库'), findsOneWidget);
      // Intro blurb (substring match is robust to future copy edits).
      expect(find.text('从 4 个基础和弦开始'), findsOneWidget);

      // A card per built-in chord (asserted via display name).
      for (final Chord chord in kBuiltInChords) {
        expect(
          find.text(chord.displayName),
          findsOneWidget,
          reason: 'Missing card for ${chord.id}',
        );
      }
    });

    testWidgets('tapping a card pushes /chords/:id',
        (WidgetTester tester) async {
      final GoRouter router = GoRouter(
        initialLocation: '/chords',
        routes: <RouteBase>[
          GoRoute(
            path: '/chords',
            name: 'chords',
            builder: (BuildContext context, GoRouterState state) =>
                const ChordLibraryPage(),
            routes: <RouteBase>[
              GoRoute(
                path: ':chordId',
                name: 'chord-detail',
                builder: (BuildContext context, GoRouterState state) =>
                    _RouteSpy(
                  id: state.pathParameters['chordId'] ?? '',
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

      // Tap the C card.
      await tester.tap(find.text('C 和弦'));
      await tester.pumpAndSettle();

      expect(find.text('route=c'), findsOneWidget);
    });

    testWidgets('library list can be overridden via provider',
        (WidgetTester tester) async {
      // A future task may swap the data source; ensure the page
      // reads from `chordLibraryProvider` and not from the
      // built-in constant directly.
      const List<Chord> empty = <Chord>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            chordLibraryProvider.overrideWithValue(empty),
          ],
          child: MaterialApp(
            home: const ChordLibraryPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title + blurb still render; no chord cards are present.
      expect(find.text('和弦库'), findsOneWidget);
      expect(find.text('C 和弦'), findsNothing);
    });
  });
}

/// Routes pushed by the test land here so we can assert on the path.
class _RouteSpy extends StatelessWidget {
  const _RouteSpy({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('route=$id')),
    );
  }
}
