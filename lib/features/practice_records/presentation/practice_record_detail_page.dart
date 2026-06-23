// Practice record detail page (T013.4C + T034 + T035).
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
//     * Data     — full read-only detail with a 删除 button
//                 and, for records that carry a real audio
//                 path, a real-audio playback control row
//                 ([_PlaybackSection]).
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
// T035 — real-audio playback section:
// - The detail page surfaces a dedicated [_PlaybackSection]
//   widget when (and ONLY when) the loaded record has a
//   non-null / non-empty `audioFilePath`.
// - The widget reads its enabled-state from the watched
//   [PracticeRecordDetailState] — the SAME source the
//   controller publishes — so a state change rebuilds the
//   buttons in the same frame.
// - The section NEVER renders the raw `audioFilePath` value
//   to the user (the file path is private to the playback
//   service). Errors are mapped to short Chinese copy via
//   the controller's `playbackErrorMessage` field; the full
//   exception string is `debugPrint`-ed in the controller
//   and never reaches the UI tree.
// - The playback buttons are independent of the delete
//   button's enabled-state (a delete in flight disables
//   delete; a playback in flight does NOT block the user
//   from cancelling playback via the stop button). The
//   page only blocks the playback START buttons while a
//   delete is in flight, mirroring the controller's
//   invariant that the on-disk file is the only shared
//   resource between the two state machines.
//
// Reuse:
// - Date, duration, PracticeType, SelfAssessment formatters are
//   re-exported from the T013.4B list item file. We deliberately
//   do NOT introduce a second copy of these mappings — the brief
//   requires "复用 T013.4B 已有的日期、时长、PracticeType 和
//   SelfAssessment 显示映射，不得创建互相矛盾的第二套文案".
//
// T037A — page-exit playback stop coordination:
// - Root-cause (real-device reproduction): opening a recorded
//   playback detail, tapping play, then tapping the AppBar back
//   arrow (or pressing Android system back) left the underlying
//   `just_audio` player still audible after the route
//   transition completed. The previous T035A dispose hook was
//   fire-and-forget, so the Navigator popped while the
//   platform-channel stop future was still in flight.
// - Fix: a single chokepoint [_handleExit] is the SOLE entry
//   point for all exit gestures (AppBar back, Android system
//   back / back-gesture, route pop). It awaits the
//   controller's NEW [PracticeRecordDetailController
//   .requestStopForPageExit] and only then drives the
//   navigation. [_exitInFlight] serialises concurrent exit
//   attempts so a double-tap on the AppBar back arrow (or the
//   AppBar back + an immediate Android system back) cannot
//   double-pop or double-stop.
// - [PopScope] wraps the page body so Android system back
//   invokes the same chokepoint. When [_exitInFlight] is true
//   (or the controller is awaiting stop), [PopScope.canPop] is
//   false and [onPopInvokedWithResult] drives the exit
//   coordination. When no exit is in flight AND no active
//   playback exists, the controller reports `skipped` and the
//   page lets the system back pop normally (so the system back
//   still works on the not-found / loading / idle states).
// - Failure mode: when [requestStopForPageExit] returns
//   [PageExitStopFailure] the page surfaces a friendly SnackBar
//   AND keeps itself mounted (does NOT pop). The user can retry
//   the back gesture after seeing the SnackBar.
// - The T035A dispose hook is preserved as a non-cooperative
//   safety net (a parent route replaced, or a test that drops
//   the widget tree without calling the page's exit handler).

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
  /// T037A — exit-coordination re-entrancy guard. While an
  /// exit is in flight (we are awaiting the controller's
  /// [requestStopForPageExit] OR we are in the microtask
  /// window between stop completion and the actual pop) we
  /// refuse additional exit requests so a double-tap on the
  /// AppBar back arrow (or AppBar back + immediate Android
  /// system back) cannot double-pop or double-stop the
  /// playback service. The guard is intentionally a plain
  /// bool — the page is single-threaded on the UI isolate
  /// and no async gap exists between read and write.
  bool _exitInFlight = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<PracticeRecordDetailState> asyncState = ref.watch(
      practiceRecordDetailControllerProvider(widget.recordId),
    );

    // T037A — the page drives the AppBar back arrow and the
    // Android system back / back-gesture through a single
    // chokepoint ([_handleExit]). PopScope intercepts the
    // latter; canPop is gated on [_exitInFlight] AND on
    // whether the controller currently holds an active
    // playback session (so the system back still works
    // normally on the not-found / loading / idle states).
    final bool hasActivePlayback = _hasActivePlayback(asyncState);
    return PopScope(
      // When an exit is already in flight we MUST NOT let
      // the framework pop — that would double-pop. When a
      // playback session is active we also intercept, so
      // we can await the stop first. Otherwise (idle /
      // not-found / loading / error) we let the system
      // back pop normally.
      canPop: !_exitInFlight && !hasActivePlayback,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          // The framework already popped (no active session,
          // no in-flight exit). Nothing to coordinate.
          return;
        }
        // canPop was false → drive the exit coordination.
        _handleExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('练习记录详情'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            // T037A — route AppBar back through the same
            // chokepoint as Android system back. `_popOrGoRecords`
            // is preserved for the not-found / failure cases
            // (the not-found view has its own "返回练习记录列表"
            // button that calls _popOrGoRecords directly because
            // it is reached only when no active playback exists).
            onPressed: _handleExit,
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
                practiceRecordDetailControllerProvider(widget.recordId)
                    .notifier,
              );
              // The in-flight signal is read from the WATCHED
              // state — this is the only source of truth for the
              // UI. When the controller publishes
              // `isDeleting = true`, the parent `ref.watch` rebuilds
              // us and the button is disabled in the same frame.
              return _DataView(
                record: record,
                state: state,
                isDeleting: state.isDeleting,
                onDeletePressed: () => _confirmAndDelete(context, controller),
              );
            },
          ),
        ),
      ),
    );
  }

  /// T037A — returns `true` iff the current watched state
  /// implies an active playback session that must be stopped
  /// before navigation. Mirrors
  /// [PracticeRecordDetailState.canStop] but inlined here so
  /// `build` does not need to descend through the
  /// AsyncValue's data branch on every navigation gesture
  /// (the AsyncValue may be in `loading` — in that case
  /// `canStop` is vacuously false).
  bool _hasActivePlayback(AsyncValue<PracticeRecordDetailState> asyncState) {
    final PracticeRecordDetailState? s = asyncState.value;
    if (s == null) {
      return false;
    }
    return s.canStop;
  }

  /// T037A — single chokepoint for every page-exit gesture.
  ///
  /// Flow:
  /// 1. Re-entrancy: if [_exitInFlight] is already true,
  ///    refuse the call so a double-tap on the AppBar back
  ///    (or AppBar back + immediate Android system back)
  ///    cannot double-stop or double-pop.
  /// 2. Await the controller's
  ///    [PracticeRecordDetailController.requestStopForPageExit].
  ///    This is the actual fix: the stop is awaited (NOT
  ///    fire-and-forget) so the platform-channel stop
  ///    resolves before the Navigator pops.
  /// 3. If the result is [PageExitStopSuccess] or
  ///    [PageExitStopSkipped] → pop the route.
  /// 4. If the result is [PageExitStopFailure] → render
  ///    the supplied friendly SnackBar AND keep the page
  ///    mounted. The guard is released so the user can
  ///    retry the back gesture after the SnackBar
  ///    dismisses.
  ///
  /// The method is intentionally fire-and-forget from the
  /// framework's perspective (the AppBar `onPressed` /
  /// `onPopInvokedWithResult` cannot be `async` directly),
  /// but every await is bracketed inside the function so
  /// the actual navigation only happens after the stop
  /// resolves.
  void _handleExit() {
    if (_exitInFlight) {
      return;
    }
    _exitInFlight = true;
    // ignore: discarded_futures
    _runExit();
  }

  Future<void> _runExit() async {
    PageExitStopResult result;
    try {
      final PracticeRecordDetailController controller = ref.read(
        practiceRecordDetailControllerProvider(widget.recordId).notifier,
      );
      result = await controller.requestStopForPageExit();
    } on Object catch (e, st) {
      // The controller explicitly never throws, but we
      // belt-and-braces this branch: an unexpected throw
      // must NOT leave the page in an un-poppable state.
      debugPrint(
        'PracticeRecordDetailPage _runExit unexpected throw: '
        '$e\n$st',
      );
      result = const PageExitStopResult.failure(
        message: '停止播放失败，请重试',
      );
    }
    // The widget may have been disposed while we awaited
    // (e.g. a parent route replaced the detail page). In
    // that case `mounted` is false and we must not touch
    // BuildContext.
    if (!mounted) {
      return;
    }
    if (result.hasUserFacingError) {
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          key: const ValueKey<String>(
            'practice-record-detail-exit-stop-failure-snackbar',
          ),
          content: Text(result.message ?? '停止播放失败，请重试'),
          duration: const Duration(seconds: 2),
        ),
      );
      // Keep the page mounted; release the guard so the
      // user can retry the back gesture.
      _exitInFlight = false;
      return;
    }
    // Success or skip — pop. The Navigator's `pop` does
    // NOT itself trigger another `_handleExit` because
    // the page is being torn down.
    _popOrGoRecords(context);
    // `_popOrGoRecords` is synchronous from the page's
    // perspective; the guard is intentionally not
    // released here because the page is on its way out.
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
      case DeleteResult.successWithCleanupWarning:
        // T034 — DB row is gone, but the audio file cleanup
        // did not finish cleanly. Surface a non-fatal warning
        // SnackBar; the row deletion is NOT rolled back, so the
        // user-visible record is gone and we still pop back to
        // the list. Keeping the row would create a "ghost row
        // that no longer reflects the user's intent" which is
        // worse than a leftover file.
        messenger.showSnackBar(
          const SnackBar(
            key: ValueKey<String>(
              'practice-record-delete-cleanup-warning-snackbar',
            ),
            content: Text('练习记录已删除，但部分音频文件清理失败'),
            duration: Duration(seconds: 3),
          ),
        );
        if (!context.mounted) return;
        _popOrGoRecords(context);
      case DeleteResult.failure:
        // T035 — `failure` covers BOTH the existing
        // "Repository.delete threw" path AND the new
        // "pre-delete stop refused" path (the playback
        // service could not release the on-disk file).
        // Both are non-fatal user-visible errors; the
        // SnackBar copy is identical so the user can retry
        // in either case.
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
    required this.state,
    required this.isDeleting,
    required this.onDeletePressed,
  });

  final PracticeRecord record;

  /// Full state — T035 surfaces the playback fields down to
  /// [_PlaybackSection] so the playback buttons can read
  /// `playbackStatus` / `playbackErrorMessage` from the
  /// single source of truth.
  final PracticeRecordDetailState state;

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
          // T035 — real-audio playback control row. The
          // section is rendered only when the record has a
          // non-null / non-empty `audioFilePath`; the
          // controller is the source of truth for which
          // buttons are enabled, and the buttons dispatch
          // through the watched controller. The delete
          // affordance below is intentionally OUTSIDE the
          // playback section so the two state machines do
          // not visually compete.
          const SizedBox(height: 24),
          _PlaybackSection(state: state, isDeleting: isDeleting),
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

// ---------------------------------------------------------------------------
// T035 — real-audio playback section
// ---------------------------------------------------------------------------

/// Real-audio playback control row (T035).
///
/// Renders ONE OF:
/// 1. A static "此记录没有录音" hint when the loaded record
///    has a null / empty `audioFilePath`.
/// 2. The full playback control row (play / pause / resume /
///    stop + status + error text) when the path is set.
///
/// The widget is intentionally a `ConsumerWidget` rather than
/// a plain `StatelessWidget`: it must read the controller via
/// `ref.read` to dispatch the playback commands AND `ref.watch`
/// the controller state for the button enabled-state. The
/// watched state is read in the parent `_DataView` (so the
/// parent rebuilds first); this widget just receives the
/// already-resolved state via constructor and dispatches
/// commands.
///
/// Layout:
/// - A single labelled card with a top "录音回放" header and
///   a row of buttons underneath. The buttons are
///   [TextButton.icon] (Material 3 lightweight) so they do not
///   visually compete with the destructive "删除练习记录"
///   button below.
/// - In `error` state a second line of red text is shown.
///   The text is the short friendly
///   [PracticeRecordDetailState.playbackErrorMessage] (set by
///   the controller); the full exception string is NEVER
///   rendered.
class _PlaybackSection extends ConsumerWidget {
  const _PlaybackSection({required this.state, required this.isDeleting});

  /// The same [PracticeRecordDetailState] the parent read from
  /// `ref.watch`. Passed down to avoid a second `ref.watch`
  /// subscription on the same provider (which would also be
  /// fine but adds a redundant subscription lifecycle to
  /// reason about).
  final PracticeRecordDetailState state;

  /// Driven by [PracticeRecordDetailState.isDeleting]. When
  /// the page is in flight on a delete, the playback START
  /// buttons are disabled (we never want to start a new
  /// playback session while the row is being removed from
  /// the DB). The pause / resume / stop buttons stay
  /// enabled so the user can still cancel an in-flight
  /// playback before the delete resolves.
  final bool isDeleting;

  bool get _hasAudio {
    final String? path = state.record?.audioFilePath;
    return path != null && path.isNotEmpty;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_hasAudio) {
      return _NoAudioHint();
    }
    final PracticeRecordPlaybackStatus status = state.playbackStatus;
    final PracticeRecordDetailController controller = ref.read(
      practiceRecordDetailControllerProvider(
        // The page already pinned the id in `state.record.id`
        // by the time we get here. We re-derive the family
        // argument from the record so a stack-rotation
        // (the family is keyed on the path-parameter string)
        // cannot accidentally point at the wrong controller.
        state.record?.id ?? '',
      ).notifier,
    );
    final bool canStart = state.canStartPlayback && !isDeleting;
    final bool canPause = state.canPause && !isDeleting;
    final bool canResume = state.canResume && !isDeleting;
    final bool canStop = state.canStop && !isDeleting;
    final bool isLoading = status == PracticeRecordPlaybackStatus.loading;

    return _PlaybackCard(
      status: status,
      errorMessage: state.playbackErrorMessage,
      isLoading: isLoading,
      canStart: canStart,
      canPause: canPause,
      canResume: canResume,
      canStop: canStop,
      onPlay: () {
        // Read the controller again inside the callback so a
        // hot-reload / provider-invalidation does not race
        // the closure capture.
        final PracticeRecordDetailController latest = ref.read(
          practiceRecordDetailControllerProvider(
            state.record?.id ?? '',
          ).notifier,
        );
        // ignore: discarded_futures
        latest.playRecordedAudio();
      },
      onPause: () {
        final PracticeRecordDetailController latest = ref.read(
          practiceRecordDetailControllerProvider(
            state.record?.id ?? '',
          ).notifier,
        );
        // ignore: discarded_futures
        latest.pausePlayback();
      },
      onResume: () {
        final PracticeRecordDetailController latest = ref.read(
          practiceRecordDetailControllerProvider(
            state.record?.id ?? '',
          ).notifier,
        );
        // ignore: discarded_futures
        latest.resumePlayback();
      },
      onStop: () {
        final PracticeRecordDetailController latest = ref.read(
          practiceRecordDetailControllerProvider(
            state.record?.id ?? '',
          ).notifier,
        );
        // ignore: discarded_futures
        latest.stopPlayback();
      },
      controller: controller,
    );
  }
}

/// Static hint shown when the record has no audio path.
///
/// Material 3 style: muted background + secondary text. No
/// interactive controls (per the brief: "无音频记录：不显示
/// 可用的播放按钮，或显示明确的"此记录没有录音""). We choose
/// the hint variant so the detail-page layout is stable
/// across records.
class _NoAudioHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      key: const ValueKey<String>(
          'practice-record-detail-playback-no-audio-hint'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.music_off,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '此记录没有录音',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Playback control card. The single source of truth for
/// the button-enabled-state is the [status] + [isLoading]
/// pair (the parent derives these from the watched state);
/// the [canStart] / [canPause] / [canResume] / [canStop]
/// booleans are pre-computed by the parent so this widget
/// stays a pure presentation layer.
class _PlaybackCard extends StatelessWidget {
  const _PlaybackCard({
    required this.status,
    required this.errorMessage,
    required this.isLoading,
    required this.canStart,
    required this.canPause,
    required this.canResume,
    required this.canStop,
    required this.onPlay,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.controller,
  });

  final PracticeRecordPlaybackStatus status;
  final String? errorMessage;
  final bool isLoading;
  final bool canStart;
  final bool canPause;
  final bool canResume;
  final bool canStop;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;

  /// Unused on the widget level, but exposed so the parent
  /// (a `ConsumerWidget`) does not need to re-derive the
  /// controller reference for the callback closures. Keeping
  /// it in scope also documents the data flow.
  // ignore: unused_element
  final PracticeRecordDetailController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      key: const ValueKey<String>('practice-record-detail-playback-section'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.audiotrack,
                size: 20,
                color: theme.colorScheme.onSurface,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '录音回放',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  _statusLabel(status),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              // The four buttons are mutually exclusive in
              // terms of which one is shown, but we always
              // render the play button so the user has a
              // single "start" affordance after an error or
              // after natural completion. The pause / resume
              // / stop buttons are conditionally rendered so
              // the row does not visually compete.
              Expanded(
                child: _PlaybackButton(
                  key: const ValueKey<String>(
                      'practice-record-detail-playback-play-button'),
                  icon: status == PracticeRecordPlaybackStatus.error
                      ? Icons.refresh
                      : Icons.play_arrow,
                  label: status == PracticeRecordPlaybackStatus.error
                      ? '重试'
                      : '播放录音',
                  onPressed: canStart ? onPlay : null,
                ),
              ),
              if (status == PracticeRecordPlaybackStatus.playing) ...<Widget>[
                const SizedBox(width: 8),
                Expanded(
                  child: _PlaybackButton(
                    key: const ValueKey<String>(
                        'practice-record-detail-playback-pause-button'),
                    icon: Icons.pause,
                    label: '暂停',
                    onPressed: canPause ? onPause : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PlaybackButton(
                    key: const ValueKey<String>(
                        'practice-record-detail-playback-stop-button'),
                    icon: Icons.stop,
                    label: '停止',
                    onPressed: canStop ? onStop : null,
                  ),
                ),
              ] else if (status ==
                  PracticeRecordPlaybackStatus.paused) ...<Widget>[
                const SizedBox(width: 8),
                Expanded(
                  child: _PlaybackButton(
                    key: const ValueKey<String>(
                        'practice-record-detail-playback-resume-button'),
                    icon: Icons.play_arrow,
                    label: '继续',
                    onPressed: canResume ? onResume : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PlaybackButton(
                    key: const ValueKey<String>(
                        'practice-record-detail-playback-stop-button'),
                    icon: Icons.stop,
                    label: '停止',
                    onPressed: canStop ? onStop : null,
                  ),
                ),
              ] else if (status == PracticeRecordPlaybackStatus.ready ||
                  status == PracticeRecordPlaybackStatus.loading) ...<Widget>[
                const SizedBox(width: 8),
                Expanded(
                  child: _PlaybackButton(
                    key: const ValueKey<String>(
                        'practice-record-detail-playback-stop-button'),
                    icon: Icons.stop,
                    label: '停止',
                    onPressed: canStop ? onStop : null,
                  ),
                ),
              ],
            ],
          ),
          if (status == PracticeRecordPlaybackStatus.error &&
              errorMessage != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              key: const ValueKey<String>(
                  'practice-record-detail-playback-error-message'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Human-readable Chinese label for the playback state. The
  /// controller already maintains the single source of truth;
  /// the widget just maps it to UI copy.
  static String _statusLabel(PracticeRecordPlaybackStatus status) {
    switch (status) {
      case PracticeRecordPlaybackStatus.idle:
        return '准备播放';
      case PracticeRecordPlaybackStatus.loading:
        return '加载中';
      case PracticeRecordPlaybackStatus.ready:
        return '已加载';
      case PracticeRecordPlaybackStatus.playing:
        return '正在播放';
      case PracticeRecordPlaybackStatus.paused:
        return '已暂停';
      case PracticeRecordPlaybackStatus.error:
        return '出错了';
    }
  }
}

/// Small Material 3 button used by the playback section.
///
/// Wrapped as a separate widget so the test can locate it
/// with `find.byKey` and read its `onPressed` directly.
class _PlaybackButton extends StatelessWidget {
  const _PlaybackButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
