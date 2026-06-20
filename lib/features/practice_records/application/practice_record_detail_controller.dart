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
//   the loaded record.
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
  });

  /// "Not found" — nothing to render. The page uses the
  /// AsyncValue envelope for Loading/Error; this object only
  /// describes the Data branch.
  factory PracticeRecordDetailState.notFound() =>
      const PracticeRecordDetailState._(
        loadStatus: DetailLoadStatus.notFound,
        record: null,
      );

  factory PracticeRecordDetailState.loaded(PracticeRecord record) =>
      PracticeRecordDetailState._(
        loadStatus: DetailLoadStatus.loaded,
        record: record,
      );

  final DetailLoadStatus loadStatus;
  final PracticeRecord? record;

  /// Convenience: `true` iff a record is currently held.
  bool get isLoaded => loadStatus == DetailLoadStatus.loaded;

  /// Convenience: `true` iff the controller's last successful
  /// `getById` returned `null`.
  bool get isNotFound => loadStatus == DetailLoadStatus.notFound;
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

  /// `true` while a delete is in flight. Read by the page to
  /// disable the delete button and block the confirmation
  /// dialog from re-opening.
  bool _isDeleting = false;

  @override
  Future<PracticeRecordDetailState> build() async {
    // Reset the delete guard whenever the controller is rebuilt
    // — this includes the initial build AND any retry-driven
    // invalidation. A stale `_isDeleting` from a previous lifetime
    // must not carry over.
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

  /// Whether a delete is currently in flight.
  ///
  /// The page uses this to (a) disable the delete button,
  /// (b) suppress re-entry into the confirmation dialog, and
  /// (c) show a "正在删除…" affordance. Re-reading this from the
  /// page keeps the UI and the controller in lock-step.
  bool get isDeleting => _isDeleting;

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

    final String idToDelete = current.record!.id;
    final PracticeRecordRepository repository =
        ref.read(practiceRecordRepositoryProvider);
    try {
      await repository.delete(idToDelete);
    } catch (_) {
      // Reset the guard before re-checking `mounted` so a
      // future retry on a still-mounted Provider is not blocked
      // by a stale `_isDeleting`.
      _isDeleting = false;
      if (!ref.mounted) {
        return DeleteResult.ignored;
      }
      return DeleteResult.failure;
    }

    if (!ref.mounted) {
      // Provider was disposed between our await and here. The
      // Repository already removed the row — but the page is
      // gone, so we just report `ignored`. The list page's
      // `watchAll()` subscription will see the deletion on its
      // own.
      return DeleteResult.ignored;
    }
    _isDeleting = false;
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
