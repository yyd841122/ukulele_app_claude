// Practice records list page (T013.4B).
//
// Scope (T013.4B):
// - Subscribes to [practiceRecordsListControllerProvider], which
//   wraps [PracticeRecordRepository.watchAll].
// - Renders four states:
//     * Loading       — spinner + "正在加载练习记录…"
//     * Error         — friendly Chinese copy + 重试 button. The
//                       `Object error` / `StackTrace` from
//                       AsyncValue.error is intentionally NOT
//                       rendered; only the fixed message + retry
//                       button is shown.
//     * Empty         — "还没有练习记录" copy + helper hint.
//     * Data          — Material ListView of
//                       [PracticeRecordListItem]s, each tapping
//                       into `/records/:recordId`. The existing
//                       router entry (T006) is reused unchanged —
//                       the detail page is still a placeholder.
// - Repository ordering is preserved verbatim. The list is NEVER
//   re-sorted here.
// - Each row uses `record.id` as the ListView key so React-like
//   reconciliation matches the same logical record across
//   emissions.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ukulele_app/features/practice_records/application/practice_records_list_controller.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_record.dart';
import 'package:ukulele_app/features/practice_records/presentation/widgets/practice_record_list_item.dart';

/// Practice records list page.
///
/// Reads from [practiceRecordsListControllerProvider] and
/// dispatches to the four state views.
class PracticeRecordsPage extends ConsumerWidget {
  const PracticeRecordsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PracticeRecordsListState> asyncState =
        ref.watch(practiceRecordsListControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('练习记录'),
      ),
      body: SafeArea(
        child: asyncState.when(
          loading: () => const _LoadingView(),
          // The `Object error` / `StackTrace` parameters are
          // required by Riverpod's AsyncValue signature but MUST
          // NOT be rendered — internal exception details
          // (Drift errors, ProviderException chains, …) leak
          // implementation and confuse the user. We
          // `debugPrint` them for engineering triage.
          error: (Object error, StackTrace stackTrace) {
            debugPrint(
              'practiceRecordsListControllerProvider stream error: '
              '$error\n$stackTrace',
            );
            return _ErrorView(
              onRetry: () => ref
                  .read(practiceRecordsListControllerProvider.notifier)
                  .retry(),
            );
          },
          data: (PracticeRecordsListState state) {
            if (state.isEmpty) {
              return const _EmptyView();
            }
            return _RecordsListView(records: state.records);
          },
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

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
            Text('正在加载练习记录…'),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

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
              '加载练习记录失败，请重试。',
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

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.note_alt_outlined, size: 48),
            const SizedBox(height: 16),
            Text(
              '还没有练习记录',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '完成一次练习后，记录会出现在这里。',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordsListView extends StatelessWidget {
  const _RecordsListView({required this.records});

  final List<PracticeRecord> records;

  @override
  Widget build(BuildContext context) {
    // The Repository emits the list in its own order; we forward
    // it verbatim. `record.id` is stable and unique per record
    // (minted by `PracticeRecordIdGenerator`), so it is the
    // correct ListView key.
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: records.length,
      separatorBuilder: (BuildContext context, int index) =>
          const Divider(height: 1),
      itemBuilder: (BuildContext context, int index) {
        final PracticeRecord record = records[index];
        return PracticeRecordListItem(
          // Stable, unique per logical record — same id across
          // stream emissions, so Flutter's element tree reuses
          // widgets rather than tearing down on every refresh.
          key: ValueKey<String>(record.id),
          record: record,
          onTap: () => context.push('/records/${record.id}'),
        );
      },
    );
  }
}
