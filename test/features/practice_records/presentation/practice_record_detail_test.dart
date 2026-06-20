// Tests for the practice record detail page + controller (T013.4C).
//
// Strategy:
// - The controller is exercised through a real
//   `ProviderContainer` with `practiceRecordRepositoryProvider`
//   overridden with a `_FakePracticeRecordRepository` that
//   exposes a `Completer`-gated `getById` and `delete` so tests
//   can resolve or reject async operations deterministically. No
//   Drift, no native database.
// - Widget tests pump the page through a `ProviderScope` and
//   verify the four states (Loading / Error / Not Found / Data).
// - The list page subscription is exercised in a separate
//   integration-style test: a watchAll stream is wired through
//   the fake repository, and we verify that `delete` removes
//   the row from the next emission.
// - Every StreamController, Completer, ProviderContainer and
//   database resource is closed through `addTearDown`.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ukulele_app/features/practice_records/application/practice_record_detail_controller.dart';
import 'package:ukulele_app/features/practice_records/data/practice_record_repository.dart';
import 'package:ukulele_app/features/practice_records/data/practice_record_repository_provider.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_record.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_tag.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_type.dart';
import 'package:ukulele_app/features/practice_records/domain/self_assessment.dart';
import 'package:ukulele_app/features/practice_records/presentation/practice_record_detail_page.dart';

void main() {
  group('PracticeRecordDetailController', () {
    test('build surfaces AsyncData(loaded) when the row exists', () async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
        'r-1': _record(id: 'r-1', practiceContent: 'row content'),
      });
      addTearDown(repo.close);

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          practiceRecordRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final AsyncValue<PracticeRecordDetailState> value = await _awaitData(
        container,
        practiceRecordDetailControllerProvider('r-1'),
      );
      expect(value, isA<AsyncData<PracticeRecordDetailState>>());
      final PracticeRecordDetailState state = value.requireValue;
      expect(state.isLoaded, isTrue);
      expect(state.isNotFound, isFalse);
      expect(state.record?.id, 'r-1');
      expect(state.record?.practiceContent, 'row content');
    });

    test('build surfaces AsyncData(notFound) when getById returns null',
        () async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{});
      addTearDown(repo.close);

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          practiceRecordRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final AsyncValue<PracticeRecordDetailState> value = await _awaitData(
        container,
        practiceRecordDetailControllerProvider('missing'),
      );
      final PracticeRecordDetailState state = value.requireValue;
      expect(state.isNotFound, isTrue);
      expect(state.record, isNull);
    });

    test('build surfaces AsyncError when getById throws', () async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{});
      addTearDown(repo.close);
      repo.nextGetByIdError = StateError('synthetic failure');

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          practiceRecordRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      // Wait for the error to surface. The error is exposed as
      // AsyncError on the AsyncValue. We hold a `listen`
      // subscription so the autoDispose provider is not torn
      // down before `build` resolves.
      final ProviderSubscription<AsyncValue<PracticeRecordDetailState>>
          errorSub = container.listen<AsyncValue<PracticeRecordDetailState>>(
        practiceRecordDetailControllerProvider('boom'),
        (
          AsyncValue<PracticeRecordDetailState>? previous,
          AsyncValue<PracticeRecordDetailState> next,
        ) {},
      );
      addTearDown(errorSub.close);
      final DateTime deadline = DateTime.now().add(const Duration(seconds: 2));
      while (true) {
        final AsyncValue<PracticeRecordDetailState> v =
            container.read(practiceRecordDetailControllerProvider('boom'));
        if (v is AsyncError<PracticeRecordDetailState>) {
          expect(v.error, isA<StateError>());
          return;
        }
        if (DateTime.now().isAfter(deadline)) {
          fail('Timed out waiting for AsyncError');
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });

    test('deleteCurrentRecord returns success and removes the row', () async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
        'r-1': _record(id: 'r-1'),
      });
      addTearDown(repo.close);

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          practiceRecordRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      // Force build to settle.
      await _awaitData(
        container,
        practiceRecordDetailControllerProvider('r-1'),
      );

      final DeleteResult result = await container
          .read(practiceRecordDetailControllerProvider('r-1').notifier)
          .deleteCurrentRecord();
      expect(result, DeleteResult.success);
      expect(repo.deleteCalls, <String>['r-1']);
      // The repository's watchAll stream reflects the deletion.
      final List<PracticeRecord> live = await repo.watchAll().first;
      expect(live, isEmpty);
    });

    test(
        'deleteCurrentRecord ignores a duplicate click while a delete '
        'is in flight — repository is called once', () async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
        'r-1': _record(id: 'r-1'),
      });
      addTearDown(repo.close);
      // Gate the delete so we can fire two concurrent deletes.
      repo.deleteCompleters['r-1'] = Completer<bool>();

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          practiceRecordRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await _awaitData(
        container,
        practiceRecordDetailControllerProvider('r-1'),
      );

      final PracticeRecordDetailController controller = container.read(
        practiceRecordDetailControllerProvider('r-1').notifier,
      );

      // Fire the first delete — gated by the Completer.
      final Future<DeleteResult> first = controller.deleteCurrentRecord();
      // Yield a microtask so the controller flips `_isDeleting`.
      await Future<void>.delayed(const Duration(milliseconds: 1));

      // Fire a second delete. The controller MUST refuse this.
      final Future<DeleteResult> second = controller.deleteCurrentRecord();
      await Future<void>.delayed(const Duration(milliseconds: 1));
      expect(repo.deleteCalls, <String>['r-1'],
          reason: 'only one delete should reach the repository');
      expect(await second, DeleteResult.ignored,
          reason: 'second concurrent delete must be ignored');

      // Unblock the first delete and verify it succeeds.
      repo.deleteCompleters['r-1']!.complete(true);
      expect(await first, DeleteResult.success);
    });

    test('deleteCurrentRecord returns failure and keeps the record on throw',
        () async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
        'r-1': _record(id: 'r-1'),
      });
      addTearDown(repo.close);
      // Make the delete fail. We stage the error through
      // [nextDeleteError] so the throw happens while the
      // controller is already awaiting (and therefore catches
      // it as a normal Future rejection) — eager
      // `completeError` would surface as an unhandled async
      // error.
      repo.nextDeleteError = StateError('synthetic delete failure');

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          practiceRecordRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await _awaitData(
        container,
        practiceRecordDetailControllerProvider('r-1'),
      );

      final DeleteResult result = await container
          .read(practiceRecordDetailControllerProvider('r-1').notifier)
          .deleteCurrentRecord();
      expect(result, DeleteResult.failure);

      // The record is still loaded — the user can retry.
      final AsyncValue<PracticeRecordDetailState> v =
          container.read(practiceRecordDetailControllerProvider('r-1'));
      expect(v, isA<AsyncData<PracticeRecordDetailState>>());
      expect(v.requireValue.record?.id, 'r-1');
    });

    test('after a failed delete, a second delete attempt can succeed',
        () async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
        'r-1': _record(id: 'r-1'),
      });
      addTearDown(repo.close);

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          practiceRecordRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await _awaitData(
        container,
        practiceRecordDetailControllerProvider('r-1'),
      );
      final PracticeRecordDetailController controller = container.read(
        practiceRecordDetailControllerProvider('r-1').notifier,
      );

      // First delete: fail.
      repo.nextDeleteError = StateError('boom');
      expect(await controller.deleteCurrentRecord(), DeleteResult.failure);

      // Second delete: succeed.
      repo.deleteCompleters['r-1'] = Completer<bool>()..complete(true);
      expect(await controller.deleteCurrentRecord(), DeleteResult.success);
      expect(repo.deleteCalls, <String>['r-1', 'r-1']);
    });

    test('deleteCurrentRecord is ignored while the controller is loading',
        () async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
        'r-1': _record(id: 'r-1'),
      });
      addTearDown(repo.close);
      // Gate getById so the controller never resolves.
      repo.getByIdCompleters['r-1'] = Completer<PracticeRecord?>();

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          practiceRecordRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      // Touch the provider so build is in flight — also keep a
      // listen subscription so the autoDispose provider is not
      // torn down.
      final ProviderSubscription<AsyncValue<PracticeRecordDetailState>>
          loadSub = container.listen<AsyncValue<PracticeRecordDetailState>>(
        practiceRecordDetailControllerProvider('r-1'),
        (
          AsyncValue<PracticeRecordDetailState>? previous,
          AsyncValue<PracticeRecordDetailState> next,
        ) {},
      );
      addTearDown(loadSub.close);
      // Give the microtask queue a tick.
      await Future<void>.delayed(const Duration(milliseconds: 1));

      final PracticeRecordDetailController controller = container.read(
        practiceRecordDetailControllerProvider('r-1').notifier,
      );
      expect(await controller.deleteCurrentRecord(), DeleteResult.ignored);
      expect(repo.deleteCalls, isEmpty);
    });

    test('deleteCurrentRecord is ignored for the NotFound state', () async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{});
      addTearDown(repo.close);

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          practiceRecordRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await _awaitData(
        container,
        practiceRecordDetailControllerProvider('missing'),
      );
      final PracticeRecordDetailController controller = container.read(
        practiceRecordDetailControllerProvider('missing').notifier,
      );
      expect(await controller.deleteCurrentRecord(), DeleteResult.ignored);
      expect(repo.deleteCalls, isEmpty);
    });
  });

  group('PracticeRecordDetailPage', () {
    /// Builds the `GoRouter` the widget tests share: a /records
    /// route that mounts [PracticeRecordDetailPage] directly
    /// (no list page in front). The page is reached by pushing
    /// `/records/<id>`. The [initialLocation] defaults to
    /// `/records/r-1`; tests that exercise a different id (or
    /// multiple ids in sequence) supply their own.
    GoRouter detailOnlyRouter([String initialLocation = '/records/r-1']) {
      return GoRouter(
        initialLocation: initialLocation,
        routes: <RouteBase>[
          GoRoute(
            path: '/records',
            name: 'records',
            builder: (BuildContext context, GoRouterState state) =>
                const _RecordsSentinelPage(),
            routes: <RouteBase>[
              GoRoute(
                path: ':recordId',
                name: 'record-detail',
                builder: (BuildContext context, GoRouterState state) =>
                    PracticeRecordDetailPage(
                  recordId: state.pathParameters['recordId'] ?? '',
                ),
              ),
            ],
          ),
        ],
      );
    }

    Future<void> pumpDetailPage(
      WidgetTester tester, {
      required _FakePracticeRecordRepository repository,
      String? locationOverride,
      GoRouter? router,
    }) async {
      final GoRouter effectiveRouter =
          router ?? detailOnlyRouter(locationOverride ?? '/records/r-1');
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            practiceRecordRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp.router(routerConfig: effectiveRouter),
        ),
      );
      await tester.pump();
    }

    /// Drives `getById` to completion and pumps the resulting
    /// rebuild. Runs real-time (via `tester.runAsync`) so the
    /// Future can actually advance under the fake-async clock,
    /// then pumps once to flush the rebuild. Two pump
    /// iterations are issued because the AsyncNotifier fires
    /// its first post-build notification on a microtask, not
    /// on the build call itself. For tests that exercise
    /// success (`AsyncData`), the second pump flushes the
    /// post-data rebuild; for tests that exercise error
    /// (`AsyncError`), the same two pumps flush the
    /// post-error rebuild.
    Future<void> settleGetById(WidgetTester tester) async {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();
    }

    testWidgets('shows the loading state on first frame',
        (WidgetTester tester) async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
        'r-1': _record(id: 'r-1'),
      });
      addTearDown(repo.close);
      // Gate getById so the controller stays in loading state.
      repo.getByIdCompleters['r-1'] = Completer<PracticeRecord?>();

      await pumpDetailPage(tester, repository: repo);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('正在加载练习记录…'), findsOneWidget);
      expect(find.text('加载练习记录失败，请重试。'), findsNothing);
      expect(find.text('未找到这条练习记录'), findsNothing);
    });

    testWidgets('renders the not-found view with no delete button',
        (WidgetTester tester) async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: const <String, PracticeRecord>{});
      addTearDown(repo.close);

      await pumpDetailPage(tester, repository: repo);
      await settleGetById(tester);

      expect(find.text('未找到这条练习记录'), findsOneWidget);
      expect(
          find.byKey(const ValueKey<String>(
              'practice-record-detail-not-found-back-button')),
          findsOneWidget);
      // The delete button MUST NOT appear in the not-found view.
      expect(
          find.byKey(
              const ValueKey<String>('practice-record-detail-delete-button')),
          findsNothing);
    });

    testWidgets('renders the data view with all expected fields',
        (WidgetTester tester) async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
        'r-1': _record(
          id: 'r-1',
          practiceDate: DateTime(2026, 6, 20),
          dayIndex: 3,
          primaryPracticeType: PracticeType.chord,
          practiceTags: const <PracticeTag>[
            PracticeTag.tuner,
            PracticeTag.metronome
          ],
          practiceContent: 'C->Am 切换',
          durationSeconds: 65,
          isCompleted: true,
          selfAssessment: SelfAssessment.good,
          audioFilePath: 'recordings/secret.m4a',
        ),
      });
      addTearDown(repo.close);

      await pumpDetailPage(tester, repository: repo);
      await settleGetById(tester);

      // Date matches the list format exactly.
      expect(find.text('2026-06-20'), findsOneWidget);
      expect(find.text('Day 3'), findsOneWidget);
      expect(find.text('和弦练习'), findsOneWidget);
      expect(find.text('01:05'), findsOneWidget);
      expect(find.text('已完成'), findsOneWidget);
      expect(find.text('好'), findsOneWidget);
      // Tags joined with "、".
      expect(find.text('调音、节拍器'), findsOneWidget);
      // The practice content is rendered in a Text widget
      // keyed by [ValueKey('practice-record-detail-content')].
      expect(
        find.byKey(const ValueKey<String>('practice-record-detail-content')),
        findsOneWidget,
      );
      expect(
        find.text('C->Am 切换'),
        findsOneWidget,
      );
      // audioFilePath is never rendered.
      expect(find.textContaining('recordings'), findsNothing);
      expect(find.textContaining('m4a'), findsNothing);
      // Delete button is present in the data view.
      expect(
          find.byKey(
              const ValueKey<String>('practice-record-detail-delete-button')),
          findsOneWidget);
    });

    testWidgets(
        'shows "未填写" when selfAssessment is null and "无" when tags are empty',
        (WidgetTester tester) async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
        'r-empty': _record(
          id: 'r-empty',
          selfAssessment: null,
          practiceTags: const <PracticeTag>[],
        ),
      });
      addTearDown(repo.close);

      await pumpDetailPage(tester,
          repository: repo, locationOverride: '/records/r-empty');
      await settleGetById(tester);

      expect(find.text('未填写'), findsOneWidget);
      expect(find.text('无'), findsOneWidget);
    });

    testWidgets('renders the error view without leaking the exception',
        (WidgetTester tester) async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{});
      addTearDown(repo.close);
      repo.nextGetByIdError = StateError('synthetic failure');

      await pumpDetailPage(tester,
          repository: repo, locationOverride: '/records/boom');
      await settleGetById(tester);

      expect(find.text('加载练习记录失败，请重试。'), findsOneWidget);
      expect(find.textContaining('synthetic failure'), findsNothing);
      expect(find.textContaining('StateError'), findsNothing);
    });

    testWidgets('tapping retry recovers to the data state',
        (WidgetTester tester) async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
        'r-1': _record(id: 'r-1'),
      });
      addTearDown(repo.close);
      // First attempt: fail.
      repo.nextGetByIdError = StateError('synthetic failure');

      await pumpDetailPage(tester, repository: repo);
      await settleGetById(tester);

      expect(find.text('加载练习记录失败，请重试。'), findsOneWidget);

      // Prepare the recovery — the next getById call will
      // succeed because the seed already contains 'r-1'. The
      // previous failed attempt was thrown via [nextGetByIdError]
      // which is now nulled out.
      // Tap retry, then pump through the recovery.
      await tester.tap(find.byKey(
          const ValueKey<String>('practice-record-detail-error-retry-button')));
      await tester.pump();

      // Wait for the new build to settle on Data.
      final DateTime deadline = DateTime.now().add(const Duration(seconds: 3));
      while (find
          .byKey(const ValueKey<String>('practice-record-detail-content'))
          .evaluate()
          .isEmpty) {
        if (DateTime.now().isAfter(deadline)) {
          fail('Retry did not transition to Data');
        }
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(find.text('加载练习记录失败，请重试。'), findsNothing);
    });

    testWidgets('every PracticeType renders the Chinese label',
        (WidgetTester tester) async {
      // Exercise all five enum cases via five separate trees so
      // each test path is independent. Each tree uses a unique
      // record id from the fake repo.
      const List<PracticeType> types = <PracticeType>[
        PracticeType.singleNote,
        PracticeType.chord,
        PracticeType.metronome,
        PracticeType.recording,
        PracticeType.mixed,
      ];
      const List<String> labels = <String>[
        '单音练习',
        '和弦练习',
        '节拍器练习',
        '录音练习',
        '混合练习',
      ];

      for (int i = 0; i < types.length; i++) {
        final String id = 'type-$i';
        final _FakePracticeRecordRepository repo =
            _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
          id: _record(id: id, primaryPracticeType: types[i]),
        });
        addTearDown(repo.close);

        await pumpDetailPage(tester,
            repository: repo, locationOverride: '/records/$id');
        await settleGetById(tester);
        expect(find.text(labels[i]), findsOneWidget,
            reason: 'PracticeType.${types[i].name} should map to "$labels[i]"');
        // Make sure the raw enum .name never leaks.
        expect(find.text(types[i].name), findsNothing,
            reason: 'raw enum .name must not be shown');
      }
    });

    testWidgets('every SelfAssessment renders the Chinese label',
        (WidgetTester tester) async {
      const List<SelfAssessment> values = <SelfAssessment>[
        SelfAssessment.good,
        SelfAssessment.neutral,
        SelfAssessment.needsImprovement,
      ];
      const List<String> labels = <String>['好', '一般', '需改进'];

      for (int i = 0; i < values.length; i++) {
        final String id = 'sa-$i';
        final _FakePracticeRecordRepository repo =
            _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
          id: _record(id: id, selfAssessment: values[i]),
        });
        addTearDown(repo.close);

        await pumpDetailPage(tester,
            repository: repo, locationOverride: '/records/$id');
        await settleGetById(tester);
        expect(find.text(labels[i]), findsOneWidget,
            reason:
                'SelfAssessment.${values[i].name} should map to "$labels[i]"');
        expect(find.text(values[i].name), findsNothing);
      }
    });

    testWidgets('every PracticeTag renders the Chinese label',
        (WidgetTester tester) async {
      const List<PracticeTag> tags = <PracticeTag>[
        PracticeTag.tuner,
        PracticeTag.singleNote,
        PracticeTag.chord,
        PracticeTag.metronome,
        PracticeTag.recording,
        PracticeTag.selfAssessment,
      ];
      const List<String> labels = <String>[
        '调音',
        '单音',
        '和弦',
        '节拍器',
        '录音',
        '自评',
      ];

      for (int i = 0; i < tags.length; i++) {
        final String id = 'tag-$i';
        final _FakePracticeRecordRepository repo =
            _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
          id: _record(id: id, practiceTags: <PracticeTag>[tags[i]]),
        });
        addTearDown(repo.close);

        await pumpDetailPage(tester,
            repository: repo, locationOverride: '/records/$id');
        await settleGetById(tester);
        // The page's tags-value Text widget carries a stable
        // [ValueKey]. Find it directly and assert its data.
        final Finder tagValueFinder = find
            .byKey(const ValueKey<String>('practice-record-detail-tags-value'));
        expect(tagValueFinder, findsOneWidget,
            reason:
                'PracticeTag.${tags[i].name}: the tags-value cell should be present');
        expect(
          (tester.widget<Text>(tagValueFinder)).data,
          labels[i],
          reason: 'PracticeTag.${tags[i].name} should map to "$labels[i]"',
        );
        expect(find.text(tags[i].name), findsNothing);
      }
    });

    testWidgets('audioFilePath is never rendered even when non-null',
        (WidgetTester tester) async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
        'r-audio': _record(id: 'r-audio', audioFilePath: 'synthetic/path.m4a'),
      });
      addTearDown(repo.close);

      await pumpDetailPage(tester,
          repository: repo, locationOverride: '/records/r-audio');
      await settleGetById(tester);

      expect(find.textContaining('synthetic'), findsNothing);
      expect(find.textContaining('m4a'), findsNothing);
      expect(find.textContaining('path'), findsNothing);
    });

    testWidgets('long content does not overflow on a small surface',
        (WidgetTester tester) async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
        'r-long': _record(
          id: 'r-long',
          practiceContent: '这是一段非常非常非常非常非常非常非常非常非常非常非常非常'
                  '长的练习内容描述，用来验证当 practiceContent 超长时'
                  '详情页不会越界 overflow。' *
              5,
        ),
      });
      addTearDown(repo.close);

      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      await pumpDetailPage(tester,
          repository: repo, locationOverride: '/records/r-long');
      await settleGetById(tester);

      expect(
          find.byKey(const ValueKey<String>('practice-record-detail-content')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'tapping delete opens the confirmation dialog with cancel + '
        'delete buttons', (WidgetTester tester) async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
        'r-1': _record(id: 'r-1'),
      });
      addTearDown(repo.close);

      await pumpDetailPage(tester, repository: repo);
      await settleGetById(tester);

      await tester.tap(find.byKey(
          const ValueKey<String>('practice-record-detail-delete-button')));
      await tester.pump();

      expect(find.text('删除练习记录？'), findsOneWidget);
      expect(find.text('删除后无法恢复，确定要删除这条练习记录吗？'), findsOneWidget);
      expect(
          find.byKey(const ValueKey<String>(
              'practice-record-detail-delete-cancel-button')),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey<String>(
              'practice-record-detail-delete-confirm-button')),
          findsOneWidget);
    });

    testWidgets(
        'cancel in the confirmation dialog does NOT call the repository',
        (WidgetTester tester) async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
        'r-1': _record(id: 'r-1'),
      });
      addTearDown(repo.close);

      await pumpDetailPage(tester, repository: repo);
      await settleGetById(tester);

      await tester.tap(find.byKey(
          const ValueKey<String>('practice-record-detail-delete-button')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>(
          'practice-record-detail-delete-cancel-button')));
      await tester.pump();

      expect(repo.deleteCalls, isEmpty,
          reason: 'cancel must not call repository.delete');
      // Dialog is dismissed.
      expect(find.text('删除练习记录？'), findsNothing);
    });

    testWidgets(
        'confirming delete passes the current recordId to the repository, '
        'shows the success snackbar, and pops back to /records',
        (WidgetTester tester) async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
        'r-1': _record(id: 'r-1'),
      });
      addTearDown(repo.close);

      await pumpDetailPage(tester, repository: repo);
      await settleGetById(tester);

      await tester.tap(find.byKey(
          const ValueKey<String>('practice-record-detail-delete-button')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>(
          'practice-record-detail-delete-confirm-button')));
      // Allow the controller, the SnackBar animation, AND the
      // go_router pop animation to settle. After pop the
      // detail page's Scaffold is torn down, so the SnackBar
      // (which lives on the root ScaffoldMessenger provided by
      // `MaterialApp.router`) is the only SnackBar still in
      // the tree. We must wait for the route transition so we
      // do not observe the pre-pop state where the detail
      // page's Scaffold and the list page's Scaffold are both
      // mounted and the SnackBar appears in two Scaffold
      // scopes simultaneously.
      await tester.pumpAndSettle();

      expect(repo.deleteCalls, <String>['r-1'],
          reason: 'only the current recordId should reach the repository');
      // After the route transition settles, the SnackBar is
      // shown exactly once on the surviving list page.
      expect(
          find.byKey(const ValueKey<String>(
              'practice-record-delete-success-snackbar')),
          findsOneWidget);
      // The page is popped — the sentinel list page should be on top.
      expect(find.byType(_RecordsSentinelPage), findsOneWidget,
          reason: 'detail page must pop back to the list after delete');
    });

    testWidgets(
        'delete failure keeps the detail page, keeps the record, and '
        'shows the friendly failure snackbar without the exception',
        (WidgetTester tester) async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
        'r-1': _record(id: 'r-1', practiceContent: 'still here'),
      });
      addTearDown(repo.close);
      repo.nextDeleteError = StateError('synthetic delete failure');

      await pumpDetailPage(tester, repository: repo);
      await settleGetById(tester);

      await tester.tap(find.byKey(
          const ValueKey<String>('practice-record-detail-delete-button')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>(
          'practice-record-detail-delete-confirm-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Detail page is still mounted.
      expect(
          find.byKey(
              const ValueKey<String>('practice-record-detail-delete-button')),
          findsOneWidget);
      // Record content is preserved.
      expect(
        find.byKey(const ValueKey<String>('practice-record-detail-content')),
        findsOneWidget,
      );
      expect(find.text('still here'), findsOneWidget);
      expect(
          find.byKey(const ValueKey<String>(
              'practice-record-delete-failure-snackbar')),
          findsOneWidget);
      // No exception text leaked.
      expect(find.textContaining('synthetic delete failure'), findsNothing);
    });

    testWidgets('after a delete failure the user can retry and succeed',
        (WidgetTester tester) async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
        'r-1': _record(id: 'r-1'),
      });
      addTearDown(repo.close);

      await pumpDetailPage(tester, repository: repo);
      await settleGetById(tester);

      // First attempt: fail.
      repo.nextDeleteError = StateError('boom');

      await tester.tap(find.byKey(
          const ValueKey<String>('practice-record-detail-delete-button')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>(
          'practice-record-detail-delete-confirm-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // After failure, the detail page is still up and the
      // failure snackbar is visible.
      expect(
          find.byKey(
              const ValueKey<String>('practice-record-detail-delete-button')),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey<String>(
              'practice-record-delete-failure-snackbar')),
          findsOneWidget);

      // Second attempt: succeed. Wait for the failure snackbar
      // to dismiss before retrying — the SnackBar lives for
      // 2 s and we want it out of the tree so the success
      // snackbar can be asserted without ambiguity.
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await tester.tap(find.byKey(
          const ValueKey<String>('practice-record-detail-delete-button')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>(
          'practice-record-detail-delete-confirm-button')));
      await tester.pumpAndSettle();

      expect(repo.deleteCalls, <String>['r-1', 'r-1'],
          reason: 'two delete attempts should reach the repository');
      expect(find.byType(_RecordsSentinelPage), findsOneWidget);
    });

    testWidgets(
        'dispose during load does not leak exceptions or post-dispose '
        'state updates', (WidgetTester tester) async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
        'r-1': _record(id: 'r-1'),
      });
      addTearDown(repo.close);
      // Gate getById so we can control when the load resolves.
      final Completer<PracticeRecord?> gate = Completer<PracticeRecord?>();
      repo.getByIdCompleters['r-1'] = gate;

      await pumpDetailPage(tester, repository: repo);

      // Tear down the widget tree while the controller is still
      // loading.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      // Now resolve the load — the controller should silently
      // drop the result, NOT push it into a torn-down widget.
      gate.complete(_record(id: 'r-1'));

      // Pump a few frames; the test must not surface any
      // exceptions from the now-disposed controller.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'dispose during delete does not leak exceptions and the list '
        'still updates via watchAll', (WidgetTester tester) async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
        'r-1': _record(id: 'r-1'),
      });
      addTearDown(repo.close);
      // Gate delete so we can drop the widget tree while the
      // delete is in flight.
      final Completer<bool> deleteGate = Completer<bool>();
      repo.deleteCompleters['r-1'] = deleteGate;

      await pumpDetailPage(tester, repository: repo);
      await settleGetById(tester);

      // Tap confirm.
      await tester.tap(find.byKey(
          const ValueKey<String>('practice-record-detail-delete-button')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>(
          'practice-record-detail-delete-confirm-button')));
      await tester.pump();

      // Drop the widget tree while the delete is in flight.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      // Now resolve the delete.
      deleteGate.complete(true);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    });

    // -----------------------------------------------------------------
    // Reactive delete contract (T013.4C_FIX_DELETE_PROGRESS_CONTRACT)
    //
    // These tests verify that the in-flight delete status is
    // observable through Riverpod state and drives a real UI
    // rebuild — not a side-channel bool on the controller. Each
    // test uses a Completer-gated delete so the pending state is
    // observable in the widget tree.
    // -----------------------------------------------------------------

    testWidgets(
        'while a delete is pending, the page shows a "正在删除…" affordance '
        'and the loaded record is preserved', (WidgetTester tester) async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
        'r-1': _record(id: 'r-1', practiceContent: 'body content'),
      });
      addTearDown(repo.close);
      // Gate the delete so we can observe the in-flight state.
      repo.deleteCompleters['r-1'] = Completer<bool>();

      await pumpDetailPage(tester, repository: repo);
      await settleGetById(tester);

      // Sanity: detail is up before delete.
      expect(find.text('body content'), findsOneWidget);

      await tester.tap(find.byKey(
          const ValueKey<String>('practice-record-detail-delete-button')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>(
          'practice-record-detail-delete-confirm-button')));
      // Pump once so the controller's
      // `state = AsyncData(isDeleting: true)` rebuild propagates.
      await tester.pump();

      // In-flight affordance is visible.
      expect(find.text('正在删除…'), findsOneWidget,
          reason: 'page must surface a clear in-flight affordance while delete '
              'is pending');
      // The delete button is still on the tree (with `onPressed: null`)
      // so the user sees the affordance instead of the button vanishing.
      expect(
          find.byKey(
              const ValueKey<String>('practice-record-detail-delete-button')),
          findsOneWidget);
      // The loaded record is preserved — clearing it is forbidden by the
      // brief.
      expect(find.text('body content'), findsOneWidget,
          reason: 'loaded record must be preserved while delete is pending');
      // The repository call already landed.
      expect(repo.deleteCalls, <String>['r-1']);

      // Resolve the gate so the test cleans up. The success branch
      // pops the route; we don't assert on the popped state here.
      repo.deleteCompleters['r-1']!.complete(true);
      await tester.pumpAndSettle();
    });

    testWidgets(
        'while a delete is pending, the delete button is disabled and '
        'a second tap does not open a second confirmation dialog',
        (WidgetTester tester) async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
        'r-1': _record(id: 'r-1'),
      });
      addTearDown(repo.close);
      repo.deleteCompleters['r-1'] = Completer<bool>();

      await pumpDetailPage(tester, repository: repo);
      await settleGetById(tester);

      await tester.tap(find.byKey(
          const ValueKey<String>('practice-record-detail-delete-button')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>(
          'practice-record-detail-delete-confirm-button')));
      await tester.pump();

      // The button is in the tree but disabled (onPressed: null).
      final Finder deleteButtonFinder = find.byKey(
          const ValueKey<String>('practice-record-detail-delete-button'));
      final OutlinedButton button =
          tester.widget<OutlinedButton>(deleteButtonFinder);
      expect(button.onPressed, isNull,
          reason: 'delete button must be disabled while delete is pending');

      // A second tap on the (disabled) button does NOT open a second
      // dialog. We tap it anyway — Flutter's gesture system still
      // dispatches taps to disabled widgets when probed via
      // `tester.tap` on the same finder, so the page-level guard is
      // what stops the dialog from re-appearing.
      await tester.tap(deleteButtonFinder, warnIfMissed: false);
      await tester.pump();
      expect(find.text('删除练习记录？'), findsNothing,
          reason: 'a second confirmation dialog must NOT open while delete '
              'is pending');

      // Repository.delete was called exactly once.
      expect(repo.deleteCalls, <String>['r-1'],
          reason: 'repository.delete must be called exactly once during a '
              'single in-flight delete');

      // Resolve the gate so the test cleans up.
      repo.deleteCompleters['r-1']!.complete(true);
      await tester.pumpAndSettle();
    });

    testWidgets(
        'while a delete is pending, a concurrent second tap does not '
        're-fire the repository and does not open a second dialog',
        (WidgetTester tester) async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
        'r-1': _record(id: 'r-1'),
      });
      addTearDown(repo.close);
      // Two delete gates so the controller can finish its delete while
      // a second tap is in flight. We only need the first delete to
      // happen — the second is what we're asserting against.
      repo.deleteCompleters['r-1'] = Completer<bool>();

      await pumpDetailPage(tester, repository: repo);
      await settleGetById(tester);

      await tester.tap(find.byKey(
          const ValueKey<String>('practice-record-detail-delete-button')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>(
          'practice-record-detail-delete-confirm-button')));
      await tester.pump();

      // Yield microtasks so the in-flight state has propagated.
      await tester.pump(const Duration(milliseconds: 10));

      // Force a second tap directly on the delete button. The
      // controller's `_isDeleting` lock AND the page's
      // `isDeleting` state both refuse the call. The dialog MUST
      // NOT re-appear and the Repository MUST NOT be called
      // again.
      final Finder deleteButtonFinder = find.byKey(
          const ValueKey<String>('practice-record-detail-delete-button'));
      await tester.tap(deleteButtonFinder, warnIfMissed: false);
      await tester.pump();
      expect(find.text('删除练习记录？'), findsNothing,
          reason: 'no second confirmation dialog while delete is pending');
      expect(repo.deleteCalls, <String>['r-1'],
          reason: 'repository.delete must be called exactly once');

      // Cleanup: resolve the first delete and let the page pop.
      repo.deleteCompleters['r-1']!.complete(true);
      await tester.pumpAndSettle();
    });

    testWidgets(
        'after a delete failure, the detail page stays up with the record, '
        'isDeleting is released, and the delete button is re-enabled',
        (WidgetTester tester) async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
        'r-1': _record(id: 'r-1', practiceContent: 'kept content'),
      });
      addTearDown(repo.close);
      // Stage a synthetic delete failure. The fake yields a
      // microtask before throwing so the controller's `await`
      // observes it as a normal rejection rather than an unhandled
      // async error.
      repo.nextDeleteError = StateError('synthetic delete failure');

      await pumpDetailPage(tester, repository: repo);
      await settleGetById(tester);

      await tester.tap(find.byKey(
          const ValueKey<String>('practice-record-detail-delete-button')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>(
          'practice-record-detail-delete-confirm-button')));
      await tester.pump();
      // Allow the failure path to publish the recovered state.
      await tester.pump(const Duration(milliseconds: 50));

      // Detail page is still mounted.
      expect(
          find.byKey(
              const ValueKey<String>('practice-record-detail-delete-button')),
          findsOneWidget);
      // The loaded record is preserved.
      expect(
        find.byKey(const ValueKey<String>('practice-record-detail-content')),
        findsOneWidget,
      );
      expect(find.text('kept content'), findsOneWidget);
      // The "正在删除…" affordance has been released — the button
      // label is back to its idle copy.
      expect(find.text('正在删除…'), findsNothing,
          reason: 'isDeleting must be released after a failure');
      expect(find.text('删除练习记录'), findsOneWidget,
          reason: 'delete button label must be restored after a failure');
      // The button is enabled again (onPressed != null).
      final OutlinedButton restoredButton = tester.widget<OutlinedButton>(
          find.byKey(
              const ValueKey<String>('practice-record-detail-delete-button')));
      expect(restoredButton.onPressed, isNotNull,
          reason: 'delete button must be re-enabled after a failure');
      // The friendly failure SnackBar is shown.
      expect(
          find.byKey(const ValueKey<String>(
              'practice-record-delete-failure-snackbar')),
          findsOneWidget);
      // No exception text leaked.
      expect(find.textContaining('synthetic delete failure'), findsNothing);
    });

    testWidgets(
        'after a delete failure, a follow-up retry calls the repository '
        'a second time', (WidgetTester tester) async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
        'r-1': _record(id: 'r-1'),
      });
      addTearDown(repo.close);

      await pumpDetailPage(tester, repository: repo);
      await settleGetById(tester);

      // First attempt: fail.
      repo.nextDeleteError = StateError('boom');
      await tester.tap(find.byKey(
          const ValueKey<String>('practice-record-detail-delete-button')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>(
          'practice-record-detail-delete-confirm-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
          find.byKey(
              const ValueKey<String>('practice-record-detail-delete-button')),
          findsOneWidget);
      // The delete button is back to its idle, enabled state.
      expect(find.text('删除练习记录'), findsOneWidget);

      // Wait for the failure SnackBar to dismiss so the
      // success SnackBar can be asserted without ambiguity.
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Second attempt: succeed.
      await tester.tap(find.byKey(
          const ValueKey<String>('practice-record-detail-delete-button')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>(
          'practice-record-detail-delete-confirm-button')));
      await tester.pumpAndSettle();

      expect(repo.deleteCalls, <String>['r-1', 'r-1'],
          reason: 'a failed delete followed by a retry must reach the '
              'repository twice');
      expect(find.byType(_RecordsSentinelPage), findsOneWidget);
    });

    testWidgets(
        'on successful delete, the page pops back to the list and only '
        'one success SnackBar is rendered end-to-end',
        (WidgetTester tester) async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
        'r-1': _record(id: 'r-1'),
      });
      addTearDown(repo.close);

      await pumpDetailPage(tester, repository: repo);
      await settleGetById(tester);

      await tester.tap(find.byKey(
          const ValueKey<String>('practice-record-detail-delete-button')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>(
          'practice-record-detail-delete-confirm-button')));
      // Allow the controller, the SnackBar animation, AND the
      // go_router pop animation to settle.
      await tester.pumpAndSettle();

      // Single success SnackBar on the surviving list page —
      // NOT two (one queued behind the first on the root
      // ScaffoldMessenger).
      expect(
          find.byKey(const ValueKey<String>(
              'practice-record-delete-success-snackbar')),
          findsOneWidget,
          reason:
              'exactly one success SnackBar must appear after a single delete');
      // No failure SnackBar leaked.
      expect(
          find.byKey(const ValueKey<String>(
              'practice-record-delete-failure-snackbar')),
          findsNothing);
      // Popped back to the list.
      expect(find.byType(_RecordsSentinelPage), findsOneWidget);
    });

    testWidgets(
        'on successful delete, no second success SnackBar appears after '
        'the first one dismisses', (WidgetTester tester) async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
        'r-1': _record(id: 'r-1'),
      });
      addTearDown(repo.close);

      await pumpDetailPage(tester, repository: repo);
      await settleGetById(tester);

      await tester.tap(find.byKey(
          const ValueKey<String>('practice-record-detail-delete-button')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>(
          'practice-record-detail-delete-confirm-button')));
      await tester.pumpAndSettle();

      // The first SnackBar is on screen.
      expect(
          find.byKey(const ValueKey<String>(
              'practice-record-delete-success-snackbar')),
          findsOneWidget);

      // Wait long enough for the SnackBar's 2 s duration to elapse
      // AND for any queued follow-up SnackBar to surface. The
      // 5 s buffer is generous on purpose — a queued second
      // SnackBar typically appears within 100 ms after the first
      // dismisses, so anything that lands within the buffer is a
      // real bug, not a timing flake. We then pumpAndSettle so
      // any in-flight exit animation completes before we assert.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey<String>(
              'practice-record-delete-success-snackbar')),
          findsNothing,
          reason: 'no queued second success SnackBar should appear after the '
              'first one dismisses');
      // Repository.delete was called exactly once.
      expect(repo.deleteCalls, <String>['r-1']);
    });

    testWidgets(
        'dispose during an in-flight delete publishes no post-dispose '
        'state and surfaces no exception', (WidgetTester tester) async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
        'r-1': _record(id: 'r-1'),
      });
      addTearDown(repo.close);
      final Completer<bool> deleteGate = Completer<bool>();
      repo.deleteCompleters['r-1'] = deleteGate;

      await pumpDetailPage(tester, repository: repo);
      await settleGetById(tester);

      await tester.tap(find.byKey(
          const ValueKey<String>('practice-record-detail-delete-button')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>(
          'practice-record-detail-delete-confirm-button')));
      await tester.pump();

      // The in-flight state has been published and the page
      // shows "正在删除…".
      expect(find.text('正在删除…'), findsOneWidget);

      // Drop the widget tree while the delete is pending.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // Resolving the gate now must NOT cause the controller to
      // publish a state update into a torn-down Provider. The
      // controller's `ref.mounted` check short-circuits, returning
      // `ignored` instead of pushing the recovered state. No
      // exception should surface.
      deleteGate.complete(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull,
          reason: 'dispose during delete must not surface an exception');
    });
  });

  group('practiceRecordDetailControllerProvider family', () {
    test('different ids create different controller instances', () async {
      final _FakePracticeRecordRepository repo =
          _FakePracticeRecordRepository(seed: <String, PracticeRecord>{
        'a': _record(id: 'a', practiceContent: 'A'),
        'b': _record(id: 'b', practiceContent: 'B'),
      });
      addTearDown(repo.close);

      final ProviderContainer container = ProviderContainer(
        overrides: <Override>[
          practiceRecordRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      final AsyncValue<PracticeRecordDetailState> a = await _awaitData(
        container,
        practiceRecordDetailControllerProvider('a'),
      );
      final AsyncValue<PracticeRecordDetailState> b = await _awaitData(
        container,
        practiceRecordDetailControllerProvider('b'),
      );
      expect(a.requireValue.record?.practiceContent, 'A');
      expect(b.requireValue.record?.practiceContent, 'B');
    });
  });
}

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

/// Polls the [ProviderContainer] until the [provider]'s
/// [AsyncValue] transitions out of [AsyncLoading]. Returns the
/// first non-loading value. Times out after 2 s — every test
/// that uses this helper has a seeded or a Completer-gated
/// `getById`, so a real timeout is a controller bug.
///
/// The function installs a permanent [listen] subscription so
/// the underlying `autoDispose` family provider is kept alive
/// for the duration of the test; otherwise the very first
/// `container.read(provider)` call would dispose the
/// controller before `build` resolves and the value would stay
/// `AsyncLoading` forever. The subscription is closed through
/// `addTearDown`.
Future<AsyncValue<PracticeRecordDetailState>> _awaitData(
  ProviderContainer container,
  Refreshable<AsyncValue<PracticeRecordDetailState>> provider, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final ProviderSubscription<AsyncValue<PracticeRecordDetailState>>
      subscription = container.listen<AsyncValue<PracticeRecordDetailState>>(
    provider,
    (
      AsyncValue<PracticeRecordDetailState>? previous,
      AsyncValue<PracticeRecordDetailState> next,
    ) {},
  );
  addTearDown(subscription.close);

  final DateTime deadline = DateTime.now().add(timeout);
  while (true) {
    final AsyncValue<PracticeRecordDetailState> v = container.read(provider);
    if (v is! AsyncLoading<PracticeRecordDetailState>) {
      return v;
    }
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for AsyncData');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// Repository whose `getById` and `delete` are gated through
/// per-id [Completer]s so tests can resolve or fail the async
/// calls deterministically. `watchAll` is wired to a broadcast
/// stream so the integration test (delete → list update) can
/// assert that the list reflects the deletion.
class _FakePracticeRecordRepository implements PracticeRecordRepository {
  _FakePracticeRecordRepository({required Map<String, PracticeRecord> seed}) {
    _store.addAll(seed);
    _controller = StreamController<List<PracticeRecord>>.broadcast(
      onListen: () {
        _activeListeners += 1;
        _controller.add(_snapshot());
      },
      onCancel: () {
        _activeListeners -= 1;
      },
    );
  }

  final Map<String, PracticeRecord> _store = <String, PracticeRecord>{};
  late final StreamController<List<PracticeRecord>> _controller;
  int _activeListeners = 0;

  /// Active listeners on the broadcast stream. Used by tests
  /// that need to assert the controller's subscription is
  /// released.
  int get activeListenerCount => _activeListeners;

  /// Optional per-id completer for `getById`. If absent, the
  /// seed value (or null) is returned.
  final Map<String, Completer<PracticeRecord?>> getByIdCompleters =
      <String, Completer<PracticeRecord?>>{};

  /// If non-null, the next call to [getById] throws this error
  /// after the await is in flight. See [nextDeleteError] for
  /// the rationale (avoid unhandled async errors from eager
  /// `completeError` calls).
  Object? nextGetByIdError;

  /// Optional per-id completer for `delete`. If absent, the
  /// delete removes the row immediately.
  final Map<String, Completer<bool>> deleteCompleters =
      <String, Completer<bool>>{};

  /// If non-null, the next call to [delete] with any id throws
  /// this error after `deleteCalls.add(...)` is recorded. Set
  /// by tests that want a Repository failure but need the
  /// throw to happen WHILE a `Future` listener is already
  /// attached (so `await` can catch it) — pre-completing a
  /// Completer with `completeError` before a listener attaches
  /// makes the framework complain about an unhandled async
  /// error.
  Object? nextDeleteError;

  /// Captured delete calls in order.
  final List<String> deleteCalls = <String>[];

  List<PracticeRecord> _snapshot() => _store.values.toList(growable: false);

  void close() {
    _controller.close();
  }

  @override
  Future<PracticeRecord?> getById(String id) async {
    if (nextGetByIdError != null) {
      final Object err = nextGetByIdError!;
      nextGetByIdError = null;
      // Yield a real microtask before throwing so the caller
      // is genuinely `await`-ing when the error is thrown.
      // In widget tests this is critical: a sync `throw` from
      // inside `build` is reported as an unhandled async error
      // by the framework.
      await Future<void>.delayed(const Duration(milliseconds: 1));
      throw err;
    }
    final Completer<PracticeRecord?>? gate = getByIdCompleters[id];
    if (gate != null) {
      return gate.future;
    }
    return _store[id];
  }

  @override
  Future<bool> delete(String id) async {
    deleteCalls.add(id);
    if (nextDeleteError != null) {
      final Object err = nextDeleteError!;
      nextDeleteError = null;
      // Yielding a microtask before throwing gives the
      // test framework's awaiter a chance to attach, so the
      // error is observed as a regular Future rejection rather
      // than an unhandled async error.
      await Future<void>.delayed(Duration.zero);
      throw err;
    }
    final Completer<bool>? gate = deleteCompleters[id];
    final bool ok;
    if (gate != null) {
      // The Completer's `completeError(...)` (when used by the
      // test) MUST run while the future has a listener — i.e.
      // here, inside the `await` — otherwise the test framework
      // sees an unhandled async error. To support "set up an
      // error to fire when delete is called", the test assigns
      // a Completer and calls `completeError` AFTER `await` is
      // already in flight; we therefore simply await whatever
      // the Completer holds when we get here.
      ok = await gate.future;
    } else {
      ok = true;
    }
    if (ok) {
      _store.remove(id);
      _controller.add(_snapshot());
    }
    return ok;
  }

  @override
  Stream<List<PracticeRecord>> watchAll() => _controller.stream;

  @override
  Future<PracticeRecord> insert(PracticeRecord record) async {
    _store[record.id] = record;
    _controller.add(_snapshot());
    return record;
  }

  @override
  Future<List<PracticeRecord>> listRecent({int limit = 50}) async =>
      _snapshot();
}

/// Empty placeholder that sits behind the detail route so a
/// successful pop lands somewhere we can assert on. Renders a
/// single text widget the test can locate.
class _RecordsSentinelPage extends StatelessWidget {
  const _RecordsSentinelPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('records-sentinel')),
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
