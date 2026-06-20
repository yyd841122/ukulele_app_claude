// Practice record detail page (T013.4C).
//
// Scope:
// - Receives [recordId] from the router (the `:recordId` path
//   parameter of `/records/:recordId`) — it is NEVER hardcoded.
// - Drives the page through the [AsyncValue] envelope of
//   [practiceRecordDetailControllerProvider]:
//     * Loading  — spinner + "正在加载练习记录…".
//     * Error    — friendly Chinese copy + 重试 button. The raw
//                 `Object error` / `StackTrace` are NOT rendered
//                 to the user; they are debugPrint'd for
//                 engineering triage and then dropped.
//     * Not Found— "未找到这条练习记录" + 返回练习记录列表
//                 button. The delete button is intentionally
//                 absent in this state — there is nothing to
//                 delete.
//     * Data     — full read-only detail with a 删除 button.
// - Delete is gated by a confirmation dialog; while the delete is
//   in flight the page disables the delete button AND the
//   back-button is allowed (the list's `watchAll()` subscription
//   reflects the deletion whether or not we popped, so the user
//   can leave the detail page at any time and the list stays
//   consistent).
// - The page is `ConsumerStatefulWidget` so it can own the
//   ScaffoldMessenger-driven SnackBar lifecycle and the delete
//   confirmation dialog without leaking BuildContext across
//   async gaps.
//
// Reactive delete contract (T013.4C_FIX_DELETE_PROGRESS_CONTRACT):
// - The "is a delete in flight?" signal is read from the watched
//   [PracticeRecordDetailState.isDeleting] field, NOT from a
//   side-channel on the controller. A state change rebuilds the
//   `_DataView`, which disables the delete button AND swaps its
//   icon + label to "正在删除…". The page does NOT keep its own
//   UI lock — duplicating the controller's guard would let the
//   two drift apart.
// - The confirmation dialog can only open when the watched
//   `isDeleting == false`. Tapping the delete button while a
//   delete is in flight is a no-op — the button's `onPressed` is
//   null and the controller's guard rejects any race that slips
//   through.
// - The loaded record is intentionally preserved across the
//   in-flight transition. The detail body stays on screen; only
//   the delete affordance changes. After failure, the page
//   restores the delete affordance so the user can retry.
// - The success SnackBar is shown exactly once per delete. It is
//   emitted from a single `_confirmAndDelete` invocation
//   (gated by the controller's in-flight check) and lives on the
//   root ScaffoldMessenger provided by `MaterialApp.router` —
//   not on the detail page's Scaffold, so the pop-then-show
//   sequence does not enqueue a duplicate.
//
// Reuse:
// - Date, duration, PracticeType, SelfAssessment formatters are
//   re-exported from the T013.4B list item file. We deliberately
//   do NOT introduce a second copy of these mappings — the brief
//   requires "复用 T013.4B 已有的日期、时长、PracticeType 和
//   SelfAssessment 显示映射，不得创建互相矛盾的第二套文案".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ukulele_app/features/practice_records/application/practice_record_detail_controller.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_record.dart';
import 'package:ukulele_app/features/practice_records/presentation/widgets/practice_record_list_item.dart';

/// Practice record detail page.
///
/// Loads a [PracticeRecord] by [recordId] (sourced from the
/// router) and renders one of four views. The delete flow lives
/// at the bottom of the Data view.
class PracticeRecordDetailPage extends ConsumerStatefulWidget {
  const PracticeRecordDetailPage({super.key, required this.recordId});

  final String recordId;

  @override
  ConsumerState<PracticeRecordDetailPage> createState() =>
      _PracticeRecordDetailPageState();
}

class _PracticeRecordDetailPageState
    extends ConsumerState<PracticeRecordDetailPage> {
  @override
  Widget build(BuildContext context) {
    final AsyncValue<PracticeRecordDetailState> asyncState = ref.watch(
      practiceRecordDetailControllerProvider(widget.recordId),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('练习记录详情'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          // Go back via the router so the navigation contract is
          // owned by GoRouter. If the page was opened directly
          // (no parent on the stack), fall back to /records so
          // the user is never stranded.
          onPressed: () => _popOrGoRecords(context),
        ),
      ),
      body: SafeArea(
        child: asyncState.when(
          loading: () => const _LoadingView(),
          error: (Object error, StackTrace stackTrace) {
            debugPrint(
              'practiceRecordDetailControllerProvider build failed: '
              '$error\n$stackTrace',
            );
            return _ErrorView(
              onRetry: () => ref.invalidate(
                practiceRecordDetailControllerProvider(widget.recordId),
              ),
            );
          },
          data: (PracticeRecordDetailState state) {
            if (state.isNotFound) {
              return _NotFoundView(
                onBackToList: () => _popOrGoRecords(context),
              );
            }
            final PracticeRecord record = state.record!;
            final PracticeRecordDetailController controller = ref.read(
              practiceRecordDetailControllerProvider(widget.recordId).notifier,
            );
            // The in-flight signal is read from the WATCHED
            // state — this is the only source of truth for the
            // UI. When the controller publishes
            // `isDeleting = true`, the parent `ref.watch` rebuilds
            // us and the button is disabled in the same frame.
            return _DataView(
              record: record,
              isDeleting: state.isDeleting,
              onDeletePressed: () => _confirmAndDelete(context, controller),
            );
          },
        ),
      ),
    );
  }

  /// Pops back to the list. If the page was reached without a
  /// parent route on the stack (a direct push from somewhere
  /// else), falls back to a router-level `go` so the user is
  /// never left stranded on a dead-end page.
  void _popOrGoRecords(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/records');
  }

  /// Shows the delete confirmation dialog and, on confirmation,
  /// drives the controller's delete method. SnackBars are shown
  /// via the page's own `ScaffoldMessenger` so they are scoped to
  /// the detail page's lifecycle.
  Future<void> _confirmAndDelete(
    BuildContext context,
    PracticeRecordDetailController controller,
  ) async {
    // Re-entrancy guard #1: read the in-flight signal from the
    // CURRENTLY watched state (NOT a cached controller getter).
    // This is the same signal that the delete button's
    // `onPressed: isDeleting ? null : onDeletePressed` already
    // checks, so under normal use this branch is unreachable —
    // but we keep it because the controller is the authoritative
    // source and the UI lock is only a UX hint.
    final AsyncValue<PracticeRecordDetailState> current = ref.read(
      practiceRecordDetailControllerProvider(widget.recordId),
    );
    final PracticeRecordDetailState? currentValue = current.value;
    if (currentValue == null || currentValue.isDeleting) {
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => const _DeleteConfirmDialog(),
    );
    if (confirmed != true) {
      return;
    }
    if (!mounted) {
      // The widget was disposed while the dialog was open. The
      // controller will refuse the call on its own (ref.mounted
      // check), but bailing out here also avoids scheduling a
      // SnackBar on a torn-down page.
      return;
    }
    // Re-entrancy guard #2: by the time the dialog closes, the
    // user may have re-opened another dialog, or a previous
    // delete may still be in flight. Re-read the watched state
    // so a concurrent `isDeleting = true` publish from the
    // controller short-circuits this call BEFORE we touch the
    // Repository.
    final AsyncValue<PracticeRecordDetailState> beforeCall = ref.read(
      practiceRecordDetailControllerProvider(widget.recordId),
    );
    final PracticeRecordDetailState? beforeCallValue = beforeCall.value;
    if (beforeCallValue == null || beforeCallValue.isDeleting) {
      return;
    }

    final DeleteResult result = await controller.deleteCurrentRecord();
    if (!context.mounted) {
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    switch (result) {
      case DeleteResult.success:
        messenger.showSnackBar(
          const SnackBar(
            key: ValueKey<String>('practice-record-delete-success-snackbar'),
            content: Text('练习记录已删除'),
            duration: Duration(seconds: 2),
          ),
        );
        // Pop back to the list. `watchAll()` on the list page
        // already reflects the deletion — we do NOT manipulate
        // the list's in-memory state. The SnackBar lives on the
        // ROOT ScaffoldMessenger (provided by
        // `MaterialApp.router`), not on the detail page's
        // Scaffold, so it survives the pop and is NOT queued a
        // second time — this branch runs exactly once per
        // successful delete.
        if (!context.mounted) return;
        _popOrGoRecords(context);
      case DeleteResult.failure:
        messenger.showSnackBar(
          const SnackBar(
            key: ValueKey<String>('practice-record-delete-failure-snackbar'),
            content: Text('删除失败，请重试'),
            duration: Duration(seconds: 2),
          ),
        );
      case DeleteResult.ignored:
        // Intentional no-op: a duplicate click or a stale
        // controller. Must NOT show an error SnackBar.
        break;
    }
  }
}

// ---------------------------------------------------------------------------
// View widgets
// ---------------------------------------------------------------------------

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
              key: const ValueKey<String>(
                  'practice-record-detail-error-retry-button'),
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

class _NotFoundView extends StatelessWidget {
  const _NotFoundView({required this.onBackToList});

  final VoidCallback onBackToList;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.search_off, size: 48),
            const SizedBox(height: 16),
            Text(
              '未找到这条练习记录',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '记录可能已被删除，或链接已失效。',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey<String>(
                  'practice-record-detail-not-found-back-button'),
              onPressed: onBackToList,
              child: const Text('返回练习记录列表'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DataView extends StatelessWidget {
  const _DataView({
    required this.record,
    required this.isDeleting,
    required this.onDeletePressed,
  });

  final PracticeRecord record;

  /// Driven by [PracticeRecordDetailState.isDeleting] — the
  /// SAME signal that the controller published when the delete
  /// started. When this is `true` the delete button is disabled
  /// (`onPressed: null`) and its icon + label swap to a
  /// "正在删除…" affordance, so the user can see the page is
  /// still responsive without being able to fire a second
  /// confirmation.
  final bool isDeleting;
  final VoidCallback onDeletePressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _DetailField(
            label: '练习日期',
            value: formatPracticeDate(record.practiceDate),
          ),
          _DetailField(
            label: 'Day',
            value: 'Day ${record.dayIndex}',
          ),
          _DetailField(
            label: '练习类型',
            value: practiceTypeLabel(record.primaryPracticeType),
          ),
          _DetailField(
            label: '练习时长',
            value: formatPracticeDuration(record.durationSeconds),
          ),
          _DetailField(
            label: '完成状态',
            value: record.isCompleted ? '已完成' : '未完成',
          ),
          _DetailField(
            label: '自评',
            // Explicit "未填写" for the null case — chosen over
            // hiding the row so the field layout is stable and
            // the user can see what the record did NOT capture.
            value: record.selfAssessment == null
                ? '未填写'
                : selfAssessmentLabel(record.selfAssessment!),
          ),
          // The tag row's value cell carries a stable Key so
          // tests (and any future instrumentation) can scope
          // assertions to "the rendered tags column" without
          // colliding with the field label "自评" when
          // [PracticeTag.selfAssessment] is one of the tags.
          _DetailField(
            label: '标签',
            valueKey:
                const ValueKey<String>('practice-record-detail-tags-value'),
            value: record.practiceTags.isEmpty
                ? '无'
                : record.practiceTags.map(practiceTagLabel).join('、'),
          ),
          // Practice content gets its own block because the
          // value can be long; wrapping it in a constrained
          // Text widget prevents horizontal overflow on small
          // surfaces.
          const SizedBox(height: 16),
          Text(
            '练习内容',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            record.practiceContent,
            key: const ValueKey<String>('practice-record-detail-content'),
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          // Delete action — uses an OutlinedButton rather than
          // a colored FilledButton so the destructive intent
          // is signalled by an icon + label, not by red-only
          // color (the brief forbids "仅靠颜色表达风险的控件").
          // The button is disabled while a delete is in flight
          // so a second click cannot open a duplicate
          // confirmation dialog and the Repository can never be
          // called twice for the same id from the UI.
          OutlinedButton.icon(
            key: const ValueKey<String>('practice-record-detail-delete-button'),
            onPressed: isDeleting ? null : onDeletePressed,
            icon: isDeleting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
            label: Text(isDeleting ? '正在删除…' : '删除练习记录'),
          ),
        ],
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({
    required this.label,
    required this.value,
    this.valueKey,
  });

  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              key: valueKey,
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

/// Confirmation dialog shown before a destructive delete.
///
/// Explicitly states "删除后无法恢复" so the user understands
/// the consequence. Uses [TextButton] + label ("取消" / "删除")
/// so the destructive intent is conveyed by words, not only by
/// red color.
class _DeleteConfirmDialog extends StatelessWidget {
  const _DeleteConfirmDialog();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AlertDialog(
      title: const Text('删除练习记录？'),
      content: const Text(
        '删除后无法恢复，确定要删除这条练习记录吗？',
      ),
      actions: <Widget>[
        TextButton(
          key: const ValueKey<String>(
              'practice-record-detail-delete-cancel-button'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          key: const ValueKey<String>(
              'practice-record-detail-delete-confirm-button'),
          // Color is reinforced by the label "删除" + the icon —
          // we never rely on red alone to signal destruction.
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('删除'),
        ),
      ],
    );
  }
}
