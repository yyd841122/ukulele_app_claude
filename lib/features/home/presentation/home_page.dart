// Home page — T013.3_FIX_LOCAL_DAY_AND_ERROR_UI.
//
// T013.3_FIX_LOCAL_DAY_AND_ERROR_UI scope:
// - The error view no longer surfaces the raw `error` object.
//   We deliberately drop the `Object error` / `StackTrace`
//   parameters on the floor — they are still received from
//   `AsyncValue.error` (Riverpod requires the signature) but
//   they are NOT rendered. The user sees ONLY a fixed friendly
//   string ('加载今日练习失败，请重试。') and the retry button.
//   Internal exception details (Drift errors, ProviderException
//   chains, local file paths, etc.) must never leak into the
//   widget tree. They MAY be `debugPrint`-ed for engineering,
//   but never displayed.
// - `_HomeErrorView` no longer takes an `error` field — it only
//   needs `onRetry`.
//
// T013.3_FIX_PENDING_RESULT_AND_INSTALL_DATE_BOUNDARY scope:
// - The toggle result is now [ToggleTaskResult] (not `bool`).
//   We only show the "保存失败，请重试" SnackBar when the result
//   is `failure`. `ignored` results (duplicate click, unknown
//   id, provider disposed, cross-day) are silent — they are
//   not failures.
// - The card receives an `isPending` flag driven by
//   `state.pendingTaskIds`. A user cannot fire a second click
//   while the first write is still in flight (the Checkbox
//   renders as disabled).
//
// T013.3 baseline (unchanged):
// - The controller is `AsyncNotifier`. The page MUST handle the
//   AsyncValue envelope:
//     * `AsyncLoading` → spinner.
//     * `AsyncError` → error text + retry button. Retry calls
//       `ref.invalidate(todayPracticeControllerProvider)` so
//       `build()` re-runs against the current overrides.
//     * `AsyncData` → today's plan as before.
// - Layout outside the AsyncValue handling is unchanged: the
//   header, task cards, and quick actions stay exactly where
//   they were in T007.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ukulele_app/features/home/application/today_practice_controller.dart';
import 'package:ukulele_app/features/home/presentation/widgets/home_quick_actions.dart';
import 'package:ukulele_app/features/home/presentation/widgets/today_practice_header.dart';
import 'package:ukulele_app/features/home/presentation/widgets/today_practice_task_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TodayPracticeState> asyncState =
        ref.watch(todayPracticeControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ukulele App'),
      ),
      body: SafeArea(
        child: asyncState.when(
          loading: () => const _HomeLoadingView(),
          error: (Object error, StackTrace stackTrace) {
            // Surface the failure to the engineering log so we
            // can still triage from CI artefacts, but DO NOT
            // render it. The user sees a fixed friendly message
            // and a retry button only.
            debugPrint(
              'todayPracticeControllerProvider build failed: $error\n'
              '$stackTrace',
            );
            return _HomeErrorView(
              onRetry: () => ref.invalidate(todayPracticeControllerProvider),
            );
          },
          data: (TodayPracticeState state) => _HomeDataView(state: state),
        ),
      ),
    );
  }
}

class _HomeLoadingView extends StatelessWidget {
  const _HomeLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载今日练习…'),
          ],
        ),
      ),
    );
  }
}

class _HomeErrorView extends StatelessWidget {
  const _HomeErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text(
              '加载今日练习失败，请重试。',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeDataView extends ConsumerWidget {
  const _HomeDataView({required this.state});

  final TodayPracticeState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TodayPracticeController controller =
        ref.read(todayPracticeControllerProvider.notifier);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        TodayPracticeHeader(state: state),
        const SizedBox(height: 16),
        ...state.plan.tasks.map(
          (task) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TodayPracticeTaskCard(
              task: task,
              isPending: state.isTaskPending(task.id),
              onTap: () => context.push(task.routePath),
              onToggleCompleted: (_) => _handleToggle(
                context: context,
                controller: controller,
                taskId: task.id,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const HomeQuickActions(),
      ],
    );
  }

  Future<void> _handleToggle({
    required BuildContext context,
    required TodayPracticeController controller,
    required String taskId,
  }) async {
    final ToggleTaskResult result = await controller.toggleTaskCompleted(
      taskId,
    );
    if (result == ToggleTaskResult.failure && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('保存失败，请重试'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
