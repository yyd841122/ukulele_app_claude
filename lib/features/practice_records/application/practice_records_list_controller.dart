// Riverpod controller for the practice records list page (T013.4B).
//
// Scope:
// - Hand-written [StreamNotifier] (no `@riverpod` codegen) per the
//   project convention (T007-T013.4A).
// - The list is sourced from
//   [PracticeRecordRepository.watchAll]; the Repository owns the
//   `practiceDate DESC, createdAt DESC` ordering and the row →
//   domain conversion, and this controller does NOT touch the
//   database, the Drift row class, or the ordering logic.
// - The controller exposes an [AsyncValue] envelope so the page
//   can render Loading / Error / Data uniformly — it does NOT
//   surface the [Object] / [StackTrace] that [AsyncError] carries
//   into the widget tree. The UI shows a fixed friendly message;
//   engineering details (Drift errors, ProviderException chains,
//   local file paths, …) MUST never leak.
//
// Retry semantics:
// - `retry()` calls [Ref.invalidate] on this provider. Riverpod
//   re-runs [build], which subscribes to a fresh
//   `repository.watchAll()` stream, and the page transitions
//   back through Loading → Data on the next emission.
//
// Disposal:
// - `ref.onDispose` cancels the active [StreamSubscription] and
//   closes the intermediate [StreamController] so a disposed
//   provider never leaks a listener into the underlying Drift
//   table watcher.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/features/practice_records/data/practice_record_repository.dart';
import 'package:ukulele_app/features/practice_records/data/practice_record_repository_provider.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_record.dart';

/// State for [PracticeRecordsListController].
///
/// The controller emits this immutable snapshot to the widget
/// tree whenever the repository's `watchAll` stream produces a
/// new list. The list is forwarded verbatim — the Repository
/// already enforces the `practiceDate DESC, createdAt DESC`
/// ordering and we deliberately do NOT re-sort it here.
@immutable
class PracticeRecordsListState {
  const PracticeRecordsListState(this.records);

  /// The records surfaced by the latest emission from
  /// `repository.watchAll()`. Repository-owned order; UI MUST NOT
  /// re-sort.
  final List<PracticeRecord> records;

  /// `true` iff the list is empty. The page uses this to decide
  /// between the Empty and Data views.
  bool get isEmpty => records.isEmpty;
}

/// Riverpod controller for the practice records list page.
///
/// Subscribes to [PracticeRecordRepository.watchAll] and republishes
/// the records as a [PracticeRecordsListState]. The page consumes
/// this provider via [practiceRecordsListControllerProvider].
class PracticeRecordsListController
    extends StreamNotifier<PracticeRecordsListState> {
  StreamSubscription<List<PracticeRecord>>? _subscription;

  @override
  Stream<PracticeRecordsListState> build() {
    final PracticeRecordRepository repository =
        ref.watch(practiceRecordRepositoryProvider);
    final Stream<List<PracticeRecord>> source = repository.watchAll();

    // The intermediate controller is what lets us (a) wrap each
    // emission in a fresh [PracticeRecordsListState] instance so
    // Riverpod sees a change, (b) own the cancellation lifecycle
    // through [ref.onDispose] without leaking a listener into the
    // repository's underlying stream, and (c) translate stream
    // errors into AsyncError without leaking the [Object] /
    // [StackTrace] to the widget tree (debugPrint is fine —
    // rendering the exception string is NOT).
    final StreamController<PracticeRecordsListState> controller =
        StreamController<PracticeRecordsListState>();

    _subscription = source.listen(
      (List<PracticeRecord> records) {
        controller.add(
          PracticeRecordsListState(List<PracticeRecord>.unmodifiable(records)),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('practiceRecordsListControllerProvider stream error: '
            '$error\n$stackTrace');
        controller.addError(error, stackTrace);
      },
    );

    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
      controller.close();
    });

    return controller.stream;
  }

  /// Forces the controller to re-subscribe to the repository.
  ///
  /// `ref.invalidateSelf` is the canonical Riverpod reset
  /// primitive; the next `watch` re-runs [build], which
  /// subscribes to a fresh `repository.watchAll()` stream.
  /// (We use `invalidateSelf` rather than `invalidate(<self>)`
  /// because Riverpod asserts "a provider cannot depend on
  /// itself" — `invalidate` is meant to invalidate OTHER
  /// providers.)
  void retry() {
    ref.invalidateSelf();
  }
}

/// Provider for the practice records list controller.
///
/// The page watches this via `ref.watch` and consumes the
/// `AsyncValue` envelope with `.when(...)`.
final StreamNotifierProvider<PracticeRecordsListController,
        PracticeRecordsListState> practiceRecordsListControllerProvider =
    StreamNotifierProvider<PracticeRecordsListController,
        PracticeRecordsListState>(PracticeRecordsListController.new);
