// Tests for the practice records list controller + page (T013.4B).
//
// Strategy:
// - The controller is exercised via a real `ProviderContainer`
//   with `practiceRecordRepositoryProvider` overridden with a
//   fake in-memory repository (no Drift, no native database).
// - Widget tests pump the page through a `ProviderScope` and
//   verify the four states (Loading / Error / Empty / Data).
// - Stream tests use a `StreamController` that the fake
//   repository pipes into; the controller subscribes on build
//   and we drive subsequent emissions to verify the page reacts
//   without polling. No `sleep` is used.
// - Every StreamController, ProviderContainer and database
//   resource is disposed through `addTearDown`.
//
// Why widget tests use `tester.runAsync` to drive stream events:
// - `WidgetTester.pump` / `pumpAndSettle` run inside a fake-async
//   clock. A broadcast stream is driven by the REAL clock; if
//   the test tries to `pump()` for ever, the event never lands
//   because fake time never advances on its own. The fix is to
//   emit from inside `tester.runAsync` (which temporarily
//   disables the fake clock and runs real microtasks/timers),
//   then `pump()` once to flush the resulting widget rebuilds.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ukulele_app/features/practice_records/application/practice_records_list_controller.dart';
import 'package:ukulele_app/features/practice_records/data/practice_record_repository.dart';
import 'package:ukulele_app/features/practice_records/data/practice_record_repository_provider.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_record.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_tag.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_type.dart';
import 'package:ukulele_app/features/practice_records/domain/self_assessment.dart';
import 'package:ukulele_app/features/practice_records/presentation/practice_records_page.dart';
import 'package:ukulele_app/features/practice_records/presentation/widgets/practice_record_list_item.dart';

/// Polls [condition] until it returns `true`, or fails the test
/// when [deadline] elapses. Used by widget tests that wait for a
/// post-emission rebuild — `tester.pump()` advances the fake
/// clock one frame at a time, so we loop a few pumps with
/// `runAsync` interleaving to let the broadcast stream events
/// reach the controller.
Future<void> _waitForInFakeAsync(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 3),
  String? reason,
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out${reason != null ? " waiting for $reason" : ""}');
    }
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    });
    await tester.pump();
  }
}

void main() {
  group('PracticeRecordsListController', () {
    test('initial state is loading before the first emission', () {
      final _StreamPracticeRecordRepository repo =
          _StreamPracticeRecordRepository();
      addTearDown(repo.close);

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          practiceRecordRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final AsyncValue<PracticeRecordsListState> value =
          container.read(practiceRecordsListControllerProvider);
      expect(value, isA<AsyncLoading<PracticeRecordsListState>>());
    });

    test('emits AsyncData with the repository snapshot', () async {
      final _StreamPracticeRecordRepository repo =
          _StreamPracticeRecordRepository();
      addTearDown(repo.close);

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          practiceRecordRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final ProviderSubscription<AsyncValue<PracticeRecordsListState>> sub =
          container.listen<AsyncValue<PracticeRecordsListState>>(
        practiceRecordsListControllerProvider,
        (AsyncValue<PracticeRecordsListState>? previous,
            AsyncValue<PracticeRecordsListState> next) {},
      );
      addTearDown(sub.close);

      // Push the seed AFTER the controller subscribes.
      repo.controller.add(<PracticeRecord>[
        _record(id: 'a'),
        _record(id: 'b'),
      ]);
      // Give the microtask queue time to forward the broadcast
      // event to the StreamNotifier's wrapper controller and
      // then to the AsyncValue.
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final AsyncValue<PracticeRecordsListState> value =
          container.read(practiceRecordsListControllerProvider);
      expect(value, isA<AsyncData<PracticeRecordsListState>>());
      final PracticeRecordsListState state = value.requireValue;
      expect(state.records.map((PracticeRecord r) => r.id), <String>['a', 'b']);
    });

    test('subsequent emissions replace the data, not append', () async {
      final _StreamPracticeRecordRepository repo =
          _StreamPracticeRecordRepository();
      addTearDown(repo.close);

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          practiceRecordRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final ProviderSubscription<AsyncValue<PracticeRecordsListState>> sub =
          container.listen<AsyncValue<PracticeRecordsListState>>(
        practiceRecordsListControllerProvider,
        (AsyncValue<PracticeRecordsListState>? previous,
            AsyncValue<PracticeRecordsListState> next) {},
      );
      addTearDown(sub.close);

      repo.controller.add(<PracticeRecord>[_record(id: 'a')]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Push a second snapshot.
      repo.controller.add(<PracticeRecord>[
        _record(id: 'x'),
        _record(id: 'y'),
        _record(id: 'z'),
      ]);

      // Poll until the second emission lands.
      final DateTime deadline = DateTime.now().add(const Duration(seconds: 2));
      while (true) {
        final AsyncValue<PracticeRecordsListState> v =
            container.read(practiceRecordsListControllerProvider);
        if (v is AsyncData<PracticeRecordsListState> &&
            v.requireValue.records.length == 3) {
          break;
        }
        if (DateTime.now().isAfter(deadline)) {
          fail('Timed out waiting for second emission');
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      final PracticeRecordsListState state =
          container.read(practiceRecordsListControllerProvider).requireValue;
      expect(state.records.map((PracticeRecord r) => r.id),
          <String>['x', 'y', 'z']);
    });

    test('stream error is surfaced as AsyncError', () async {
      final _StreamPracticeRecordRepository repo =
          _StreamPracticeRecordRepository();
      addTearDown(repo.close);

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          practiceRecordRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final ProviderSubscription<AsyncValue<PracticeRecordsListState>> sub =
          container.listen<AsyncValue<PracticeRecordsListState>>(
        practiceRecordsListControllerProvider,
        (AsyncValue<PracticeRecordsListState>? previous,
            AsyncValue<PracticeRecordsListState> next) {},
      );
      addTearDown(sub.close);

      repo.controller.add(<PracticeRecord>[_record(id: 'a')]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      repo.controller.addError(StateError('synthetic failure'));

      final DateTime deadline = DateTime.now().add(const Duration(seconds: 2));
      while (true) {
        final AsyncValue<PracticeRecordsListState> v =
            container.read(practiceRecordsListControllerProvider);
        if (v is AsyncError<PracticeRecordsListState>) {
          expect(v.error, isA<StateError>());
          return;
        }
        if (DateTime.now().isAfter(deadline)) {
          fail('Timed out waiting for AsyncError');
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });

    test('retry() re-subscribes and recovers to a fresh Data', () async {
      final _StreamPracticeRecordRepository repo =
          _StreamPracticeRecordRepository();
      addTearDown(repo.close);

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          practiceRecordRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final ProviderSubscription<AsyncValue<PracticeRecordsListState>> sub =
          container.listen<AsyncValue<PracticeRecordsListState>>(
        practiceRecordsListControllerProvider,
        (AsyncValue<PracticeRecordsListState>? previous,
            AsyncValue<PracticeRecordsListState> next) {},
      );
      addTearDown(sub.close);

      repo.controller.add(<PracticeRecord>[_record(id: 'a')]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      repo.controller.addError(StateError('synthetic failure'));

      final DateTime deadline = DateTime.now().add(const Duration(seconds: 2));
      while (container.read(practiceRecordsListControllerProvider)
          is! AsyncError<PracticeRecordsListState>) {
        if (DateTime.now().isAfter(deadline)) {
          fail('Timed out waiting for AsyncError');
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      // `retry()` re-runs build() which re-listens to the same
      // broadcast stream, so anything already buffered will NOT
      // replay automatically. We add a fresh snapshot AFTER
      // calling retry() so the re-subscribed controller picks
      // it up.
      container.read(practiceRecordsListControllerProvider.notifier).retry();
      // Yield a microtask so the invalidation has a chance to
      // take effect (the new build re-subscribes to the
      // broadcast stream).
      await Future<void>.delayed(const Duration(milliseconds: 1));
      repo.controller.add(<PracticeRecord>[
        _record(id: 'after-retry'),
      ]);

      final DateTime recoverDeadline =
          DateTime.now().add(const Duration(seconds: 2));
      while (true) {
        final AsyncValue<PracticeRecordsListState> v =
            container.read(practiceRecordsListControllerProvider);
        if (v is AsyncData<PracticeRecordsListState> &&
            v.requireValue.records.length == 1 &&
            v.requireValue.records.single.id == 'after-retry') {
          return;
        }
        if (DateTime.now().isAfter(recoverDeadline)) {
          fail('retry() did not recover');
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
  });

  group('PracticeRecordsListState', () {
    test('isEmpty reports emptiness correctly', () {
      expect(
          const PracticeRecordsListState(<PracticeRecord>[]).isEmpty, isTrue);
      expect(
        PracticeRecordsListState(<PracticeRecord>[_record(id: 'a')]).isEmpty,
        isFalse,
      );
    });
  });

  group('practiceTypeLabel', () {
    test('maps every PracticeType case to a Chinese label', () {
      expect(practiceTypeLabel(PracticeType.singleNote), '单音练习');
      expect(practiceTypeLabel(PracticeType.chord), '和弦练习');
      expect(practiceTypeLabel(PracticeType.metronome), '节拍器练习');
      expect(practiceTypeLabel(PracticeType.recording), '录音练习');
      expect(practiceTypeLabel(PracticeType.mixed), '混合练习');
      // The set is exhaustive — adding a new enum case without a
      // label produces a compile-time error here.
    });

    test('never returns the raw enum .name', () {
      for (final PracticeType type in PracticeType.values) {
        expect(
          practiceTypeLabel(type),
          isNot(equals(type.name)),
          reason: 'practiceTypeLabel($type) returned the raw enum name',
        );
      }
    });
  });

  group('selfAssessmentLabel', () {
    test('maps every SelfAssessment case to a Chinese label', () {
      expect(selfAssessmentLabel(SelfAssessment.good), '好');
      expect(selfAssessmentLabel(SelfAssessment.neutral), '一般');
      expect(selfAssessmentLabel(SelfAssessment.needsImprovement), '需改进');
    });

    test('never returns the raw enum .name', () {
      for (final SelfAssessment v in SelfAssessment.values) {
        expect(
          selfAssessmentLabel(v),
          isNot(equals(v.name)),
        );
      }
    });
  });

  group('PracticeRecordsPage', () {
    /// Builds the `GoRouter` the widget tests share: a /records
    /// route that mounts [PracticeRecordsPage] and a child
    /// `:recordId` route that mounts [_RouteSpy] so the test
    /// can assert on the id used for navigation.
    GoRouter recordsSpyRouter() {
      return GoRouter(
        initialLocation: '/records',
        routes: <RouteBase>[
          GoRoute(
            path: '/records',
            name: 'records',
            builder: (BuildContext context, GoRouterState state) =>
                const PracticeRecordsPage(),
            routes: <RouteBase>[
              GoRoute(
                path: ':recordId',
                name: 'record-detail',
                builder: (BuildContext context, GoRouterState state) =>
                    _RouteSpy(
                  id: state.pathParameters['recordId'] ?? '',
                ),
              ),
            ],
          ),
        ],
      );
    }

    Future<void> pumpPage(
      WidgetTester tester, {
      required _StreamPracticeRecordRepository repository,
      Size? surfaceSize,
      GoRouter? router,
    }) async {
      if (surfaceSize != null) {
        await tester.binding.setSurfaceSize(surfaceSize);
        addTearDown(() async {
          await tester.binding.setSurfaceSize(null);
        });
      }
      final GoRouter effectiveRouter = router ?? recordsSpyRouter();
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            practiceRecordRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp.router(routerConfig: effectiveRouter),
        ),
      );
      // Settle the first frame so the ConsumerWidget subscribes
      // to the provider; subsequent stream emissions are
      // delivered through `tester.runAsync(...) + pump()`.
      await tester.pump();
    }

    /// Emits [rows] from inside `tester.runAsync` so the
    /// broadcast stream can actually deliver them, then pumps
    /// once to flush the resulting rebuilds.
    Future<void> emitAndPump(
      WidgetTester tester,
      _StreamPracticeRecordRepository repo,
      List<PracticeRecord> rows,
    ) async {
      await tester.runAsync(() async {
        repo.controller.add(rows);
        await Future<void>.delayed(const Duration(milliseconds: 5));
      });
      await tester.pump();
    }

    /// Emits an error from inside `tester.runAsync`, then pumps
    /// once to flush the resulting rebuilds.
    Future<void> emitErrorAndPump(
      WidgetTester tester,
      _StreamPracticeRecordRepository repo,
      Object error,
    ) async {
      await tester.runAsync(() async {
        repo.controller.addError(error);
        await Future<void>.delayed(const Duration(milliseconds: 5));
      });
      await tester.pump();
    }

    testWidgets('shows the loading state on first frame',
        (WidgetTester tester) async {
      final _StreamPracticeRecordRepository repo =
          _StreamPracticeRecordRepository();
      addTearDown(repo.close);

      await pumpPage(tester, repository: repo);

      // No emission has been made — the page must show Loading.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('正在加载练习记录…'), findsOneWidget);
      expect(find.text('加载练习记录失败，请重试。'), findsNothing);
      expect(find.text('还没有练习记录'), findsNothing);
    });

    testWidgets('renders the empty state when the stream yields no rows',
        (WidgetTester tester) async {
      final _StreamPracticeRecordRepository repo =
          _StreamPracticeRecordRepository();
      addTearDown(repo.close);

      await pumpPage(tester, repository: repo);
      await emitAndPump(tester, repo, <PracticeRecord>[]);

      expect(find.text('还没有练习记录'), findsOneWidget);
      expect(find.textContaining('完成一次练习后'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('renders error state with friendly copy and a retry button',
        (WidgetTester tester) async {
      final _StreamPracticeRecordRepository repo =
          _StreamPracticeRecordRepository();
      addTearDown(repo.close);

      await pumpPage(tester, repository: repo);
      await emitAndPump(tester, repo, <PracticeRecord>[_record(id: 'a')]);
      await emitErrorAndPump(tester, repo, StateError('synthetic failure'));

      expect(find.text('加载练习记录失败，请重试。'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '重试'), findsOneWidget);
      // The raw exception string MUST NOT leak.
      expect(find.textContaining('synthetic failure'), findsNothing);
      expect(find.textContaining('StateError'), findsNothing);
    });

    testWidgets('tapping retry recovers to the data state',
        (WidgetTester tester) async {
      final _StreamPracticeRecordRepository repo =
          _StreamPracticeRecordRepository();
      addTearDown(repo.close);

      await pumpPage(tester, repository: repo);
      await emitAndPump(tester, repo, <PracticeRecord>[_record(id: 'a')]);
      await emitErrorAndPump(tester, repo, StateError('synthetic failure'));

      // Queue the recovery snapshot inside the same runAsync as
      // the tap so the re-subscribed controller picks it up.
      await tester.runAsync(() async {
        repo.controller.add(<PracticeRecord>[
          _record(id: 'after-retry'),
        ]);
        await Future<void>.delayed(const Duration(milliseconds: 5));
      });
      await tester.tap(find.widgetWithText(FilledButton, '重试'));
      await tester.pump();

      await _waitForInFakeAsync(
        tester,
        () => find
            .byKey(const ValueKey<String>('after-retry'))
            .evaluate()
            .isNotEmpty,
        reason: 'recovery row',
      );

      expect(find.text('加载练习记录失败，请重试。'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const ValueKey<String>('after-retry')), findsOneWidget);
    });

    testWidgets('renders one row per record with the repository order',
        (WidgetTester tester) async {
      final _StreamPracticeRecordRepository repo =
          _StreamPracticeRecordRepository();
      addTearDown(repo.close);

      await pumpPage(
        tester,
        repository: repo,
        surfaceSize: const Size(400, 1600),
      );
      await emitAndPump(tester, repo, <PracticeRecord>[
        _record(id: 'first', practiceContent: 'first row'),
        _record(id: 'second', practiceContent: 'second row'),
        _record(id: 'third', practiceContent: 'third row'),
      ]);

      expect(find.byKey(const ValueKey<String>('first')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('second')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('third')), findsOneWidget);

      // Top-to-bottom order must match the repository emission.
      final List<double> ys = <double>[
        tester.getTopLeft(find.byKey(const ValueKey<String>('first'))).dy,
        tester.getTopLeft(find.byKey(const ValueKey<String>('second'))).dy,
        tester.getTopLeft(find.byKey(const ValueKey<String>('third'))).dy,
      ];
      expect(ys[0] < ys[1] && ys[1] < ys[2], isTrue,
          reason: 'rows should appear in repository order top-to-bottom, '
              'got $ys');
    });

    testWidgets('row shows date, Day N, type, content, duration, completion',
        (WidgetTester tester) async {
      final _StreamPracticeRecordRepository repo =
          _StreamPracticeRecordRepository();
      addTearDown(repo.close);

      await pumpPage(
        tester,
        repository: repo,
        surfaceSize: const Size(400, 1200),
      );
      await emitAndPump(tester, repo, <PracticeRecord>[
        _record(
          id: 'row-1',
          practiceDate: DateTime(2026, 6, 20),
          dayIndex: 3,
          primaryPracticeType: PracticeType.chord,
          practiceContent: 'C->Am 切换',
          durationSeconds: 65,
          isCompleted: true,
        ),
      ]);

      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('row-1')),
          matching: find.text('2026-06-20 · Day 3'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('row-1')),
          matching: find.text('和弦练习 · 01:05'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('row-1')),
          matching: find.text('C->Am 切换'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('row-1')),
          matching: find.text('已完成'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('row shows self-assessment when present',
        (WidgetTester tester) async {
      final _StreamPracticeRecordRepository repo =
          _StreamPracticeRecordRepository();
      addTearDown(repo.close);

      await pumpPage(
        tester,
        repository: repo,
        surfaceSize: const Size(400, 1600),
      );
      await emitAndPump(tester, repo, <PracticeRecord>[
        _record(id: 'row-sa-good', selfAssessment: SelfAssessment.good),
        _record(
          id: 'row-sa-neutral',
          selfAssessment: SelfAssessment.neutral,
        ),
        _record(
          id: 'row-sa-needs',
          selfAssessment: SelfAssessment.needsImprovement,
        ),
      ]);

      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('row-sa-good')),
          matching: find.text('自评：好'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('row-sa-neutral')),
          matching: find.text('自评：一般'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('row-sa-needs')),
          matching: find.text('自评：需改进'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('row does NOT show self-assessment when null',
        (WidgetTester tester) async {
      final _StreamPracticeRecordRepository repo =
          _StreamPracticeRecordRepository();
      addTearDown(repo.close);

      await pumpPage(
        tester,
        repository: repo,
        surfaceSize: const Size(400, 1200),
      );
      await emitAndPump(tester, repo, <PracticeRecord>[
        _record(id: 'row-no-sa', selfAssessment: null),
      ]);

      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('row-no-sa')),
          matching: find.textContaining('自评'),
        ),
        findsNothing,
      );
    });

    testWidgets('row never renders audioFilePath', (WidgetTester tester) async {
      final _StreamPracticeRecordRepository repo =
          _StreamPracticeRecordRepository();
      addTearDown(repo.close);

      await pumpPage(
        tester,
        repository: repo,
        surfaceSize: const Size(400, 1200),
      );
      // Even when audioFilePath is non-null, the page must NOT
      // surface it. The contract is "audioFilePath 当前始终为
      // null" — this test pins the renderer-side rule so a
      // future regression cannot leak it.
      await emitAndPump(tester, repo, <PracticeRecord>[
        _record(
          id: 'row-with-audio',
          audioFilePath: 'recordings/secret.m4a',
        ),
      ]);

      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('row-with-audio')),
          matching: find.textContaining('recordings'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('row-with-audio')),
          matching: find.textContaining('m4a'),
        ),
        findsNothing,
      );
    });

    testWidgets(
        'tapping a row navigates to /records/:recordId with the id '
        '(matches the record.id of the tapped row)',
        (WidgetTester tester) async {
      // We assert navigation by pumping two SEPARATE widget
      // trees rather than a single tree that pops and re-taps.
      // Pop animations inside go_router need the real async
      // clock; the fake-async clock we run widget tests under
      // does not advance on its own, so a `context.pop()` from
      // inside the test would stall. Splitting the scenarios
      // keeps each assertion deterministic without compromising
      // the contract under test (each row's id reaches the
      // detail route verbatim).

      // Scenario 1: tap rec-a → /records/rec-a.
      final _StreamPracticeRecordRepository repoA =
          _StreamPracticeRecordRepository();
      addTearDown(repoA.close);
      final GoRouter routerA = recordsSpyRouter();
      await pumpPage(
        tester,
        repository: repoA,
        surfaceSize: const Size(400, 1600),
        router: routerA,
      );
      await emitAndPump(tester, repoA, <PracticeRecord>[
        _record(id: 'rec-a'),
        _record(id: 'rec-b'),
      ]);
      await tester.tap(find.byKey(const ValueKey<String>('rec-a')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('route=rec-a'), findsOneWidget,
          reason: 'tap on rec-a should push /records/rec-a and render '
              'the detail placeholder with id rec-a');

      // Scenario 2: tap rec-b → /records/rec-b (independent tree).
      final _StreamPracticeRecordRepository repoB =
          _StreamPracticeRecordRepository();
      addTearDown(repoB.close);
      final GoRouter routerB = recordsSpyRouter();
      await pumpPage(
        tester,
        repository: repoB,
        surfaceSize: const Size(400, 1600),
        router: routerB,
      );
      await emitAndPump(tester, repoB, <PracticeRecord>[
        _record(id: 'rec-a'),
        _record(id: 'rec-b'),
      ]);
      await tester.tap(find.byKey(const ValueKey<String>('rec-b')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('route=rec-b'), findsOneWidget,
          reason: 'tap on rec-b should push /records/rec-b and render '
              'the detail placeholder with id rec-b');
    });

    testWidgets('long content does not overflow on a small surface',
        (WidgetTester tester) async {
      final _StreamPracticeRecordRepository repo =
          _StreamPracticeRecordRepository();
      addTearDown(repo.close);

      // Tiny phone-sized surface — narrower than any plausible
      // tablet. If overflow handling is missing, Flutter will
      // throw a "RenderFlex overflowed" exception during layout.
      await pumpPage(
        tester,
        repository: repo,
        surfaceSize: const Size(320, 800),
      );
      await emitAndPump(tester, repo, <PracticeRecord>[
        _record(
          id: 'long',
          practiceContent: '这是一段非常非常非常非常非常非常非常非常非常非常非常非常长'
                  '的练习内容描述，用来验证当 practiceContent 超长时'
                  '列表项不会越界 overflow。' *
              5,
        ),
      ]);

      expect(find.byKey(const ValueKey<String>('long')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'the page updates without manual refresh when the stream '
        'emits a new snapshot', (WidgetTester tester) async {
      final _StreamPracticeRecordRepository repo =
          _StreamPracticeRecordRepository();
      addTearDown(repo.close);

      await pumpPage(
        tester,
        repository: repo,
        surfaceSize: const Size(400, 1200),
      );
      await emitAndPump(tester, repo, <PracticeRecord>[_record(id: 'old')]);
      expect(find.byKey(const ValueKey<String>('old')), findsOneWidget);

      // Emit a brand-new list. The page must rebuild without
      // any user interaction.
      await emitAndPump(tester, repo, <PracticeRecord>[
        _record(id: 'new-1'),
        _record(id: 'new-2'),
      ]);

      expect(find.byKey(const ValueKey<String>('new-1')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('new-2')), findsOneWidget);
      // The old row is gone.
      expect(find.byKey(const ValueKey<String>('old')), findsNothing);
    });

    testWidgets('ProviderScope dispose cancels the stream subscription',
        (WidgetTester tester) async {
      final _StreamPracticeRecordRepository repo =
          _StreamPracticeRecordRepository();
      addTearDown(repo.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            practiceRecordRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(home: PracticeRecordsPage()),
        ),
      );
      await tester.pump();
      // Drive one emission so the controller's `build()` runs and
      // subscribes to the broadcast stream.
      await tester.runAsync(() async {
        repo.controller.add(<PracticeRecord>[_record(id: 'a')]);
        await Future<void>.delayed(const Duration(milliseconds: 5));
      });
      await tester.pump();
      expect(repo.activeListenerCount, 1);

      // Replace the widget tree with an empty tree — the
      // ProviderScope is torn down, the controller's
      // `ref.onDispose` fires, the subscription is cancelled.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();
      expect(repo.activeListenerCount, 0,
          reason: 'subscription should be cancelled after ProviderScope '
              'dispose');
    });
  });
}

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

/// Repository whose `watchAll()` is wired to a broadcast
/// [StreamController] so the test can drive subsequent
/// emissions. Tracks active listener count so the
/// dispose-cancellation test can assert the subscription is
/// released.
class _StreamPracticeRecordRepository implements PracticeRecordRepository {
  _StreamPracticeRecordRepository() {
    controller = StreamController<List<PracticeRecord>>.broadcast(
      onListen: () {
        _activeListeners += 1;
      },
      onCancel: () {
        _activeListeners -= 1;
      },
    );
  }

  late final StreamController<List<PracticeRecord>> controller;
  int _activeListeners = 0;

  /// Number of currently-active listeners on the broadcast
  /// stream. The dispose-cancellation test asserts this drops
  /// back to 0 when the ProviderScope is torn down.
  int get activeListenerCount => _activeListeners;

  void close() {
    controller.close();
  }

  @override
  Stream<List<PracticeRecord>> watchAll() => controller.stream;

  @override
  Future<PracticeRecord> insert(PracticeRecord record) async => record;

  @override
  Future<PracticeRecord?> getById(String id) async => null;

  @override
  Future<List<PracticeRecord>> listRecent({int limit = 50}) async =>
      const <PracticeRecord>[];

  @override
  Future<bool> delete(String id) async => false;
}

/// Routes pushed by the test land here so the navigation test
/// can assert on the path. A `BackButton` is intentionally
/// rendered in the AppBar so the test can pop back to the list
/// without resorting to internal router APIs (the production
/// detail page renders its own leading back button the same
/// way).
class _RouteSpy extends StatelessWidget {
  const _RouteSpy({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('detail')),
      body: Center(child: Text('route=$id')),
    );
  }
}

PracticeRecord _record({
  String id = 'rec',
  DateTime? practiceDate,
  int dayIndex = 1,
  PracticeType primaryPracticeType = PracticeType.singleNote,
  List<PracticeTag> practiceTags = const <PracticeTag>[],
  String practiceContent = 'placeholder content',
  int durationSeconds = 30,
  bool isCompleted = false,
  SelfAssessment? selfAssessment,
  String? audioFilePath,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return PracticeRecord(
    id: id,
    practiceDate: practiceDate ?? DateTime(2026, 6, 20),
    dayIndex: dayIndex,
    primaryPracticeType: primaryPracticeType,
    practiceTags: practiceTags,
    practiceContent: practiceContent,
    durationSeconds: durationSeconds,
    isCompleted: isCompleted,
    selfAssessment: selfAssessment,
    audioFilePath: audioFilePath,
    createdAt: createdAt ?? DateTime.utc(2026, 6, 20, 9),
    updatedAt: updatedAt ?? DateTime.utc(2026, 6, 20, 9),
  );
}
