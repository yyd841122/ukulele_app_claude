// Riverpod controller for the practice record detail page (T013.4C).
//
// Scope:
// - Hand-written [AsyncNotifier] (no `@riverpod` codegen) per the
//   project convention (T007-T013.4A).
// - Loads a single [PracticeRecord] via
//   [PracticeRecordRepository.getById]. The Repository owns the
//   row → domain conversion; this controller does NOT touch Drift,
//   the DAO, the row class, or the data table.
// - The page is driven by the [AsyncValue] envelope
//   (Loading / Error / Data). "Not Found" is encoded as
//   [DetailLoadStatus.notFound] inside the [PracticeRecordDetailState]
//   object — NOT as an error — so the page can show a dedicated
//   view without rendering a misleading "加载失败" message.
// - Delete is implemented as a separate state machine
//   ([DeleteResult]) so the page can disable the delete button,
//   block re-confirmation, and recover on failure without losing
//   the loaded record. The in-flight status is published through
//   [PracticeRecordDetailState.isDeleting] so the page can
//   observe it via `ref.watch` and rebuild without depending on
//   a separate UI-side lock.
//
// Reactive delete contract (T013.4C_FIX_DELETE_PROGRESS_CONTRACT):
// - `PracticeRecordDetailState.isDeleting` is the SINGLE source
//   of truth for "a delete is currently in flight". The page
//   MUST read it from the watched [AsyncValue] so a state change
//   triggers a rebuild. The previously-private `_isDeleting` bool
//   is kept only as a synchronous guard so a second concurrent
//   `deleteCurrentRecord` call cannot race past the gate before
//   the state update has propagated — the UI lock is then purely
//   a cosmetic reinforcement, never the authoritative signal.
// - When the delete starts the controller publishes a NEW
//   [AsyncData<PracticeRecordDetailState>] with `isDeleting =
//   true` and the SAME loaded record. The loaded record is
//   intentionally preserved so the page can keep showing the
//   detail body (the brief forbids clearing the loaded record
//   to represent "正在删除…").
// - When the delete completes (success OR failure) the
//   controller publishes another state with `isDeleting = false`
//   so the page restores the button. On success the page pops
//   back to the list; on failure the same record stays mounted
//   and the user can retry.
// - On a disposed Provider the publish is skipped — `state = ...`
//   after `ref.mounted == false` would throw.
//
// Disposal / race safety:
// - The Provider is `autoDispose` so a popped detail page
//   tears the controller down on its own. Riverpod guarantees the
//   `build` future completes before any `onDispose` runs, so no
//   stale "is loading" state can survive a pop.
// - Stale results after an await are guarded by `ref.mounted`
//   (mirrors the [TodayPracticeController] pattern).
// - Delete requests are sequential: a second `deleteCurrentRecord`
//   while a delete is in flight is an `ignored` outcome and
//   produces no Repository call. The id passed to
//   [PracticeRecordRepository.delete] is the one the controller
//   loaded for — we never re-read `state` to fabricate a
//   different id mid-flight.
// - The controller deliberately does NOT navigate. Navigation
//   (pop / SnackBar) is the page's responsibility — keeping the
//   controller framework-free of `BuildContext` makes it
//   trivially testable.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/features/practice_records/data/practice_record_repository.dart';
import 'package:ukulele_app/features/practice_records/data/practice_record_repository_provider.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_record.dart';

/// Outcome of [PracticeRecordDetailController.deleteCurrentRecord].
enum DeleteResult {
  /// The Repository removed the row. The page pops back to the
  /// list.
  success,

  /// The call was deliberately dropped. Reasons include:
  /// - the controller is still loading,
  /// - the loaded record is in [DetailLoadStatus.notFound] state,
  /// - a delete for this controller instance is already in
  ///   flight (the page must not fire a second click),
  /// - the Provider was disposed mid-flight.
  ///
  /// `ignored` is NOT a failure. The UI MUST NOT show a
  /// "删除失败" SnackBar in response to this outcome.
  ignored,

  /// The Repository threw. The loaded record is preserved; the
  /// user can retry the same delete. The UI MAY show a
  /// "删除失败，请重试" SnackBar.
  failure,
}

/// Why the controller could not surface a record.
///
/// Distinct from a load error: `notFound` means
/// `repository.getById(...)` returned `null` (the row simply
/// does not exist). `loaded` means we have a [PracticeRecord].
enum DetailLoadStatus {
  /// A row was found and decoded.
  loaded,

  /// `repository.getById(...)` returned `null`. The page must
  /// show the dedicated "not found" view — NOT the error view
  /// and NOT the delete button.
  notFound,
}

/// Immutable state for the detail page's loaded branch.
///
/// `record == null` ⇔ `loadStatus == DetailLoadStatus.notFound`.
@immutable
class PracticeRecordDetailState {
  const PracticeRecordDetailState._({
    required this.loadStatus,
    required this.record,
    required this.isDeleting,
  });

  /// "Not found" — nothing to render. The page uses the
  /// AsyncValue envelope for Loading/Error; this object only
  /// describes the Data branch.
  factory PracticeRecordDetailState.notFound() =>
      const PracticeRecordDetailState._(
        loadStatus: DetailLoadStatus.notFound,
        record: null,
        isDeleting: false,
      );

  factory PracticeRecordDetailState.loaded(PracticeRecord record) =>
      PracticeRecordDetailState._(
        loadStatus: DetailLoadStatus.loaded,
        record: record,
        isDeleting: false,
      );

  final DetailLoadStatus loadStatus;
  final PracticeRecord? record;

  /// `true` while a delete is in flight. The page reads this
  /// from the watched [AsyncValue] so a state change rebuilds
  /// the delete button and the surrounding detail body. The
  /// loaded [record] is preserved across the transition — the
  /// brief forbids clearing the loaded record to signal
  /// progress.
  final bool isDeleting;

  /// Convenience: `true` iff a record is currently held.
  bool get isLoaded => loadStatus == DetailLoadStatus.loaded;

  /// Convenience: `true` iff the controller's last successful
  /// `getById` returned `null`.
  bool get isNotFound => loadStatus == DetailLoadStatus.notFound;

  /// Returns a copy of this state with the given fields replaced.
  /// [isDeleting] is the field that varies during a delete; the
  /// other fields stay constant across the lifecycle of a
  /// single detail page.
  PracticeRecordDetailState copyWith({
    DetailLoadStatus? loadStatus,
    PracticeRecord? record,
    bool? isDeleting,
  }) {
    return PracticeRecordDetailState._(
      loadStatus: loadStatus ?? this.loadStatus,
      record: record ?? this.record,
      isDeleting: isDeleting ?? this.isDeleting,
    );
  }
}

/// Riverpod controller for the practice record detail page.
///
/// Family-parameterised on the record id from the router
/// (`/records/:recordId`). Loading happens on [build]; the page
/// simply watches the resulting [AsyncValue] and dispatches to
/// the four views. Each family argument creates its own controller
/// instance (one per route entry on the stack).
class PracticeRecordDetailController
    extends AsyncNotifier<PracticeRecordDetailState> {
  PracticeRecordDetailController(this.recordId);

  /// The id from the route. Stored as a field because the
  /// [AsyncNotifier.build] contract takes no arguments — the
  /// value is supplied at construction time by the
  /// [AsyncNotifierProvider.family] builder.
  final String recordId;

  /// Synchronous guard against concurrent deletes. The
  /// authoritative in-flight signal is published through
  /// [PracticeRecordDetailState.isDeleting]; this field only
  /// prevents two callers from racing past the gate before the
  /// state update has propagated. It is intentionally kept
  /// separate from `state` so a stale `state` cannot accidentally
  /// unlock a still-in-flight delete.
  bool _isDeleting = false;

  @override
  Future<PracticeRecordDetailState> build() async {
    // Reset the delete guard whenever the controller is rebuilt
    // — this includes the initial build AND any retry-driven
    // invalidation. A stale `_isDeleting` from a previous lifetime
    // must not carry over, and a fresh state object starts with
    // `isDeleting = false` by construction.
    _isDeleting = false;

    if (recordId.isEmpty) {
      // The router never produces an empty id, but defensively
      // map it to "not found" rather than throwing — the page
      // shows the same user-visible view either way and the
      // controller never leaks an exception to the widget tree.
      return PracticeRecordDetailState.notFound();
    }

    final PracticeRecordRepository repository =
        ref.read(practiceRecordRepositoryProvider);
    final PracticeRecord? record = await repository.getById(recordId);
    if (record == null) {
      return PracticeRecordDetailState.notFound();
    }
    return PracticeRecordDetailState.loaded(record);
  }

  /// Deletes the record currently held by this controller.
  ///
  /// Contract:
  /// - Returns [DeleteResult.success] only when the Repository
  ///   actually removed a row.
  /// - Returns [DeleteResult.ignored] if the controller is still
  ///   loading, the record is in [DetailLoadStatus.notFound], a
  ///   delete is already in flight, or the Provider was disposed
  ///   mid-flight. NEVER throws.
  /// - Returns [DeleteResult.failure] when the Repository threw.
  ///   The previously-loaded record is preserved — `state.value`
  ///   remains valid so the user can retry.
  ///
  /// Reactive state publication:
  /// - Before the await, the controller publishes a state with
  ///   `isDeleting = true` so the page can disable the button,
  ///   block a second confirmation, and show a "正在删除…"
  ///   affordance. The loaded record is preserved.
  /// - After the Repository call resolves, the controller
  ///   publishes another state with `isDeleting = false` so the
  ///   page restores the button (and pops on success).
  Future<DeleteResult> deleteCurrentRecord() async {
    if (_isDeleting) {
      // A delete is already in flight; refuse the duplicate so
      // the Repository is never called twice for the same id.
      return DeleteResult.ignored;
    }
    final PracticeRecordDetailState? current = state.value;
    if (current == null) {
      // Still loading (or in error) — refuse the click so we do
      // not attempt to delete a half-initialised record.
      return DeleteResult.ignored;
    }
    if (!current.isLoaded || current.record == null) {
      // Not Found — the page should not surface a delete button
      // here at all, but the controller is the source of truth
      // and MUST refuse the call.
      return DeleteResult.ignored;
    }

    // Lock BEFORE the await so a second concurrent call that
    // races past the guard above still sees the lock.
    _isDeleting = true;
    // Publish the in-flight state. `state = ...` triggers a
    // rebuild for any widget currently watching the provider,
    // which is exactly what the page needs in order to disable
    // the button and surface a "正在删除…" affordance without
    // keeping its own UI lock.
    state = AsyncData<PracticeRecordDetailState>(current.copyWith(
      isDeleting: true,
    ));

    final String idToDelete = current.record!.id;
    final PracticeRecordRepository repository =
        ref.read(practiceRecordRepositoryProvider);
    try {
      await repository.delete(idToDelete);
    } catch (_) {
      // Reset the synchronous guard before re-checking
      // `mounted` so a future retry on a still-mounted Provider
      // is not blocked by a stale `_isDeleting`.
      _isDeleting = false;
      if (!ref.mounted) {
        return DeleteResult.ignored;
      }
      // Publish the recovered state so the page restores the
      // button. We re-read `state.value` (the latest published
      // value, which carries `isDeleting = true`) and copy it
      // with `isDeleting = false`. The loaded record is
      // preserved — the brief forbids clearing it to signal
      // progress.
      final PracticeRecordDetailState? afterFailure = state.value;
      if (afterFailure != null) {
        state = AsyncData<PracticeRecordDetailState>(afterFailure.copyWith(
          isDeleting: false,
        ));
      }
      return DeleteResult.failure;
    }

    if (!ref.mounted) {
      // Provider was disposed between our await and here. The
      // Repository already removed the row — but the page is
      // gone, so we just report `ignored`. The list page's
      // `watchAll()` subscription will see the deletion on its
      // own.
      _isDeleting = false;
      return DeleteResult.ignored;
    }
    _isDeleting = false;
    // Publish the recovered state so a watcher that is still
    // mounted (e.g. a future-proof listener) sees a clean
    // `isDeleting = false`. The page's success branch pops the
    // route immediately after, so this publish is mostly
    // defensive — but it is harmless and keeps the invariant
    // "after a delete resolves, state.isDeleting == false".
    final PracticeRecordDetailState? afterSuccess = state.value;
    if (afterSuccess != null) {
      state = AsyncData<PracticeRecordDetailState>(afterSuccess.copyWith(
        isDeleting: false,
      ));
    }
    return DeleteResult.success;
  }
}

/// Provider for the practice record detail controller.
///
/// Family-parameterised on the [String] recordId so each route
/// entry mounts its own controller instance. `autoDispose`
/// ensures the controller is torn down (and its load future is
/// effectively cancelled from the UI's perspective) when the
/// page pops. The type is intentionally left un-typed: the
/// underlying [AsyncNotifierProviderFamily] is `@internal` in
/// Riverpod 3.x and is not part of the public API; the caller's
/// expression `practiceRecordDetailControllerProvider('id')`
/// returns the correct `AsyncValue<PracticeRecordDetailState>`
/// regardless of whether we annotate the family itself.
// ignore: prefer_typing_uninitialized_variables
final practiceRecordDetailControllerProvider = AsyncNotifierProvider.autoDispose
    .family<PracticeRecordDetailController, PracticeRecordDetailState, String>(
  PracticeRecordDetailController.new,
);
