// Riverpod controller for the practice record detail page (T013.4C + T034 + T035).
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
// - T034: post-delete audio file cleanup coordination.
// - T035: real-audio playback against [RealAudioPlaybackService]
//   for records with a non-null / non-empty [PracticeRecord.audioFilePath].
//   The controller coordinates playback state with the existing
//   delete state machine: a delete-in-flight MUST stop the
//   player first so the file is released before the row is
//   removed; a stop failure on the playback side refuses the
//   delete so we never silently race a player that still holds
//   the on-disk handle.
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
// Audio file cleanup (T034):
// - After the Repository successfully removes the row, the
//   controller coordinates an opportunistic cleanup of the
//   associated on-disk audio file through [AudioFileStorageService].
//   The Repository stays a pure persistence boundary — it never
//   touches the file system. The controller is the only place
//   that bridges "DB delete" and "audio file lifecycle".
// - The cleanup is **best-effort**: any failure (delete returned
//   `false`, `deleteIfExists` threw `ArgumentError`, filesystem
//   exception, …) is reported as
//   [DeleteResult.successWithCleanupWarning] so the DB deletion
//   is **not** silently rolled back. The page surfaces a
//   dedicated non-fatal SnackBar but the row stays gone.
// - The captured [PracticeRecord.audioFilePath] is read from the
//   state snapshot **at the entry of `deleteCurrentRecord`**,
//   never re-read mid-flight. This pins the contract that a
//   concurrent `watchAll()` stream emission cannot poison the
//   cleanup with a stale or different path.
// - Shared paths are protected: before deleting, the controller
//   re-queries the Repository with
//   [PracticeRecordRepository.hasAudioPathReference]; if any
//   OTHER row still references the same path verbatim, the file
//   is left on disk for the surviving record.
//
// T035 — real-audio playback contract:
// - This controller is the SINGLE coordinator for the detail
//   page's playback lifecycle. The UI never calls the playback
//   service directly; it only invokes [playRecordedAudio] /
//   [pausePlayback] / [resumePlayback] / [stopPlayback].
// - The path passed to [RealAudioPlaybackService.loadFile] is
//   sourced **verbatim** from the loaded record's
//   [PracticeRecord.audioFilePath]. The controller does NOT
//   reformat, normalise, or recompute the string.
// - `audioFilePath == null` / `''` → the playback methods are
//   no-ops and `playbackStatus` stays at [PracticeRecordPlaybackStatus.idle].
//   The page surfaces "此记录没有录音" rather than a button.
// - The playback state machine ([PracticeRecordPlaybackStatus])
//   is intentionally SEPARATE from [AudioPlaybackState]: the
//   service's 8 states are a private implementation detail of
//   `RealAudioPlaybackService`; the controller collapses them
//   into 6 controller-facing states (idle / loading / ready /
//   playing / paused / error) so the UI never has to know
//   about `stopping` / `disposed` / `completed` as distinct
//   states. `completed` from the gateway is mapped to
//   `idle` so the user can immediately re-tap "播放".
// - Playback errors are surfaced via
//   [PracticeRecordPlaybackStatus.error] + a SHORT friendly
//   message ([PracticeRecordDetailState.playbackErrorMessage]).
//   The full exception is `debugPrint`-ed for engineering
//   triage but NEVER rendered, so no absolute path / stack
//   trace leaks to the UI.
// - A natural playback completion is observed on
//   [RealAudioPlaybackService.playerStateStream]
//   (`processingState == completed`). The controller flips
//   `playbackStatus` back to `idle` synchronously and clears
//   any prior error. Re-entrancy is guarded via
//   `_handlingNaturalCompletion` so a duplicate stream event
//   (which the fake gateway simulates on real devices) cannot
//   double-write the state.
// - The controller deliberately does NOT call
//   [RealAudioPlaybackService.stop] / `seek(0)` from the
//   completion handler. The playback service's own
//   `playerStateStream` callback already advances its internal
//   state to `idle` on `completed` (see T030 + T031I), and the
//   next `playRecordedAudio` re-loads the file so the
//   "replay-from-zero" contract is satisfied without us racing
//   the service's state machine.
// - On Provider dispose the controller cancels its
//   `playerStateStream` subscription but does NOT call
//   [RealAudioPlaybackService.dispose]. The service is owned
//   by `realAudioPlaybackServiceProvider` and is torn down by
//   the Riverpod scope's `onDispose` hooks — calling
//   `dispose` from here would invalidate the shared service
//   for the recording page and break T031's contract.
//
// Playback ↔ delete coordination (T035):
// - `deleteCurrentRecord` MUST stop the player before the row
//   is removed, otherwise the on-disk file is still open via
//   the gateway's native decoder while the controller then
//   tries to delete it from disk.
// - `_stopPlaybackIfActive` is the helper that runs **before**
//   `repository.delete` in the delete state machine:
//   * `playbackStatus == playing | paused | ready` →
//     best-effort `service.stop()` + small
//     `playbackStatus = idle` write. If `service.stop` throws
//     the delete refuses to proceed (returns
//     [DeleteResult.failure]) and the page surfaces a friendly
//     SnackBar so the user can retry. The file is left on
//     disk; the row is left in place.
//   * `playbackStatus == idle | error | loading` → no-op
//     (nothing is holding the file; the delete proceeds
//     immediately).
// - After a successful delete, the controller state is left
//   in `notFound` / disposed (the page pops), so a stale
//   `playerStateStream` event arriving AFTER the pop is
//   discarded by both the `ref.mounted` check and the
//   subscription's `cancel` in the autoDispose teardown.
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
// - Playback requests are likewise serialised by the
//   [PracticeRecordPlaybackStatus] state machine: a second
//   `playRecordedAudio` while `playbackStatus == playing |
//   loading` is a no-op (the gateway is single-instance; a
//   parallel `loadFile` would clobber the active session).
// - The controller deliberately does NOT navigate. Navigation
//   (pop / SnackBar) is the page's responsibility — keeping the
//   controller framework-free of `BuildContext` makes it
//   trivially testable.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/features/practice_records/data/practice_record_repository.dart';
import 'package:ukulele_app/features/practice_records/data/practice_record_repository_provider.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_record.dart';
import 'package:ukulele_app/shared/providers/audio_file_storage_service_provider.dart';
import 'package:ukulele_app/shared/providers/real_audio_playback_service_provider.dart';
import 'package:ukulele_app/shared/services/audio_file_storage_paths.dart';
import 'package:ukulele_app/shared/services/audio_file_storage_service.dart';
import 'package:ukulele_app/shared/services/audio_playback_exception.dart';
import 'package:ukulele_app/shared/services/audio_playback_gateway.dart';
import 'package:ukulele_app/shared/services/real_audio_playback_service.dart';

/// Outcome of [PracticeRecordDetailController.deleteCurrentRecord].
enum DeleteResult {
  /// The Repository removed the row AND the audio file
  /// lifecycle ended cleanly (file existed and was deleted,
  /// OR the record had no audio, OR the audio file was still
  /// referenced by another row and was therefore preserved).
  /// The page pops back to the list.
  success,

  /// The Repository removed the row BUT the post-delete audio
  /// cleanup did NOT complete successfully. The row stays gone
  /// — we do NOT roll back the DB deletion — but the on-disk
  /// audio file may still be present. The page shows a non-fatal
  /// warning SnackBar and then pops back to the list. This is a
  /// deliberate design choice: reverting the row would create a
  /// "ghost row that no longer reflects what the user asked for"
  /// (worse than a leftover file). Cleanup failure is observable
  /// but non-blocking.
  successWithCleanupWarning,

  /// The call was deliberately dropped. Reasons include:
  /// - the controller is still loading,
  /// - the loaded record is in [DetailLoadStatus.notFound] state,
  /// - a delete for this controller instance is already in
  ///   flight (the page must not fire a second click),
  /// - the Provider was disposed mid-flight,
  /// - the pre-delete stop-playback helper refused to
  ///   guarantee the player has released the on-disk file.
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

/// T035 — controller-facing playback state.
///
/// The 6-value enum is intentionally **separate** from
/// [AudioPlaybackState] (8 values) so the UI does not have to
/// know about the service's internal `stopping` / `disposed` /
/// `completed` distinctions. The mapping is:
///
/// | Controller state | Source / transition                                 |
/// | ---------------- | --------------------------------------------------- |
/// | `idle`           | initial; `stop` succeeded; natural completion        |
/// | `loading`        | `playRecordedAudio` → `loadFile` in flight          |
/// | `ready`          | `loadFile` succeeded, `play` not yet called          |
/// | `playing`        | service is in `playing`                             |
/// | `paused`         | `pausePlayback` succeeded                           |
/// | `error`          | any [AudioPlaybackException]                         |
enum PracticeRecordPlaybackStatus {
  /// No active session. The user can tap "播放录音" to start one.
  idle,

  /// `loadFile` is in flight. UI must show a spinner and
  /// disable duplicate taps.
  loading,

  /// `loadFile` succeeded but `play` has not yet been driven.
  /// This is a transient state — `playRecordedAudio` calls
  /// `play` immediately after `loadFile` resolves, so the
  /// controller usually jumps `loading → playing`. `ready` is
  /// retained for any future "load but don't auto-play" flow.
  ready,

  /// The service is currently driving the underlying player.
  /// UI shows the pause / stop buttons.
  playing,

  /// The user has paused; the file remains loaded and can be
  /// resumed. UI shows the resume / stop buttons.
  paused,

  /// The latest playback command raised an
  /// [AudioPlaybackException]. UI shows the friendly
  /// [PracticeRecordDetailState.playbackErrorMessage] and a
  /// retry button. The record is still loaded; the path on
  /// disk is still available.
  error,
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
    required this.playbackStatus,
    required this.playbackErrorMessage,
  });

  /// "Not found" — nothing to render. The page uses the
  /// AsyncValue envelope for Loading/Error; this object only
  /// describes the Data branch.
  factory PracticeRecordDetailState.notFound() =>
      const PracticeRecordDetailState._(
        loadStatus: DetailLoadStatus.notFound,
        record: null,
        isDeleting: false,
        playbackStatus: PracticeRecordPlaybackStatus.idle,
        playbackErrorMessage: null,
      );

  factory PracticeRecordDetailState.loaded(PracticeRecord record) =>
      PracticeRecordDetailState._(
        loadStatus: DetailLoadStatus.loaded,
        record: record,
        isDeleting: false,
        playbackStatus: PracticeRecordPlaybackStatus.idle,
        playbackErrorMessage: null,
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

  /// T035 — current playback status of the detail page's audio
  /// session. The page reads this from the watched [AsyncValue]
  /// so a state change rebuilds the playback control row. The
  /// default is [PracticeRecordPlaybackStatus.idle]; it is
  /// independent of [isDeleting] / [loadStatus] so the two
  /// state machines can be observed / reasoned about in
  /// isolation.
  final PracticeRecordPlaybackStatus playbackStatus;

  /// T035 — short, UI-safe error message for the most recent
  /// playback failure. `null` whenever [playbackStatus] is not
  /// [PracticeRecordPlaybackStatus.error]. The full exception
  /// string (which may include the on-disk path) is NEVER
  /// surfaced here — see [PracticeRecordDetailController]
  /// for the error-message mapping.
  final String? playbackErrorMessage;

  /// Convenience: `true` iff a record is currently held.
  bool get isLoaded => loadStatus == DetailLoadStatus.loaded;

  /// Convenience: `true` iff the controller's last successful
  /// `getById` returned `null`.
  bool get isNotFound => loadStatus == DetailLoadStatus.notFound;

  /// T035 — `true` iff a `playRecordedAudio` call should be
  /// accepted. We refuse concurrent play attempts while the
  /// service is mid-load or already playing — see the
  /// controller's `playRecordedAudio` for the rationale.
  bool get canStartPlayback =>
      playbackStatus == PracticeRecordPlaybackStatus.idle ||
      playbackStatus == PracticeRecordPlaybackStatus.ready ||
      playbackStatus == PracticeRecordPlaybackStatus.error;

  /// T035 — `true` iff a `pausePlayback` call should be
  /// accepted. Only valid in [PracticeRecordPlaybackStatus.playing].
  bool get canPause => playbackStatus == PracticeRecordPlaybackStatus.playing;

  /// T035 — `true` iff a `resumePlayback` call should be
  /// accepted. Only valid in [PracticeRecordPlaybackStatus.paused].
  bool get canResume => playbackStatus == PracticeRecordPlaybackStatus.paused;

  /// T035 — `true` iff a `stopPlayback` call should be accepted.
  /// Refused in [PracticeRecordPlaybackStatus.idle] and `.error`
  /// because there is nothing to stop.
  bool get canStop =>
      playbackStatus == PracticeRecordPlaybackStatus.playing ||
      playbackStatus == PracticeRecordPlaybackStatus.paused ||
      playbackStatus == PracticeRecordPlaybackStatus.ready ||
      playbackStatus == PracticeRecordPlaybackStatus.loading;

  /// Returns a copy of this state with the given fields replaced.
  /// [isDeleting] / [playbackStatus] / [playbackErrorMessage] are
  /// the fields that vary during a delete or a playback session;
  /// the other fields stay constant across the lifecycle of a
  /// single detail page.
  PracticeRecordDetailState copyWith({
    DetailLoadStatus? loadStatus,
    PracticeRecord? record,
    bool? isDeleting,
    PracticeRecordPlaybackStatus? playbackStatus,
    String? playbackErrorMessage,
    bool clearPlaybackErrorMessage = false,
  }) {
    return PracticeRecordDetailState._(
      loadStatus: loadStatus ?? this.loadStatus,
      record: record ?? this.record,
      isDeleting: isDeleting ?? this.isDeleting,
      playbackStatus: playbackStatus ?? this.playbackStatus,
      playbackErrorMessage: clearPlaybackErrorMessage
          ? null
          : (playbackErrorMessage ?? this.playbackErrorMessage),
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

  /// T035 — synchronous guard against concurrent play attempts.
  /// Prevents a second `playRecordedAudio` call from racing
  /// past the `playbackStatus == loading | playing` check before
  /// the published state has propagated. Mirrors the `_isDeleting`
  /// pattern.
  bool _isStartingPlayback = false;

  /// T035 — re-entrancy guard for the natural-completion handler.
  /// `just_audio` may emit `processingState == completed` more
  /// than once in a session; the second event must be a no-op
  /// so the controller's state machine does not double-write.
  bool _handlingNaturalCompletion = false;

  /// T035 — `true` after the controller's `ref.onDispose` hook
  /// has fired. Subsequent `state` writes are skipped so the
  /// autoDispose teardown is race-free.
  bool _disposed = false;

  /// T035 — the `playerStateStream` subscription set up on the
  /// first successful `loadFile`. Cancelled in `ref.onDispose`.
  StreamSubscription<PlaybackPlayerState>? _playbackStateSubscription;

  @override
  Future<PracticeRecordDetailState> build() async {
    // Reset the per-instance guards whenever the controller is
    // rebuilt — this includes the initial build AND any retry-
    // driven invalidation. A stale `_isDeleting` /
    // `_isStartingPlayback` from a previous lifetime must not
    // carry over.
    _isDeleting = false;
    _isStartingPlayback = false;
    _handlingNaturalCompletion = false;
    _disposed = false;
    await _playbackStateSubscription?.cancel();
    _playbackStateSubscription = null;

    // T035 — cancel any in-flight playback subscriptions /
    // timers when the controller is rebuilt (e.g. after
    // `ref.invalidate` from the error-retry button). The
    // Riverpod scope guarantees the previous `build` future
    // resolves before `onDispose` runs, so this is the right
    // place to drop the old subscription.
    ref.onDispose(_onDispose);

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

  // ---------------------------------------------------------------------------
  // Delete flow (T013.4C + T013.4C_FIX + T034 + T035 coordination)
  // ---------------------------------------------------------------------------

  /// Deletes the record currently held by this controller.
  ///
  /// Contract:
  /// - Returns [DeleteResult.success] only when the Repository
  ///   actually removed a row AND the audio file lifecycle
  ///   ended cleanly.
  /// - Returns [DeleteResult.ignored] if the controller is still
  ///   loading, the record is in [DetailLoadStatus.notFound], a
  ///   delete is already in flight, the Provider was disposed
  ///   mid-flight, or the pre-delete stop-playback helper
  ///   refused to guarantee the player has released the
  ///   on-disk file. NEVER throws.
  /// - Returns [DeleteResult.failure] when the Repository threw
  ///   OR when the pre-delete stop-playback helper could not
  ///   release the on-disk file. The previously-loaded record
  ///   is preserved — `state.value` remains valid so the user
  ///   can retry.
  ///
  /// Reactive state publication:
  /// - Before the await, the controller publishes a state with
  ///   `isDeleting = true` so the page can disable the button,
  ///   block a second confirmation, and show a "正在删除…"
  ///   affordance. The loaded record is preserved.
  /// - After the Repository call resolves, the controller
  ///   publishes another state with `isDeleting = false` so the
  ///   page restores the button (and pops on success).
  ///
  /// T035 — playback coordination:
  /// - Between the `isDeleting` publish and the `repository.delete`
  ///   call, the controller invokes [_stopPlaybackIfActive] so
  ///   the on-disk file is released before the row is removed.
  ///   If that helper throws, the delete refuses to proceed and
  ///   the result is [DeleteResult.failure] (NOT
  ///   [DeleteResult.ignored] — the user should be able to retry
  ///   once the player is in a sane state).
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

    // T034 — capture the id and the audio-path snapshot at the
    // entry of this method. We intentionally do NOT re-read
    // `state` after the Repository call: a concurrent
    // `watchAll()` emission could have flipped the loaded record
    // and we must not let that change either the id or the file
    // we are about to delete.
    final String idToDelete = current.record!.id;
    final String? capturedAudioPath = current.record!.audioFilePath;

    // T035 — stop the player BEFORE the row is removed so the
    // on-disk file is released while we still have a row that
    // documents its existence. If the player refuses to stop
    // (rare on real devices — typically a `PlaybackOperationFailedException`
    // raised by the gateway), the delete refuses to proceed
    // and we surface [DeleteResult.failure]. The page's failure
    // SnackBar lets the user retry; the file stays on disk and
    // the row stays in place.
    final PreDeleteStopOutcome stopResult =
        await _stopPlaybackIfActive(capturedAudioPath);
    if (stopResult == PreDeleteStopOutcome.refused) {
      _isDeleting = false;
      if (!ref.mounted) {
        return DeleteResult.ignored;
      }
      // Re-read the latest state (which still carries
      // `isDeleting = true`) and restore the button. The
      // loaded record is preserved — the brief forbids
      // clearing it to signal progress.
      final PracticeRecordDetailState? afterRefusal = state.value;
      if (afterRefusal != null) {
        state = AsyncData<PracticeRecordDetailState>(
          afterRefusal.copyWith(isDeleting: false),
        );
      }
      return DeleteResult.failure;
    }

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

    // T034 — opportunistic, best-effort audio file cleanup.
    // The DB row is already gone at this point; cleanup is
    // fire-and-forget and its result is mapped to
    // `successWithCleanupWarning` on any failure so the page
    // can show a non-fatal warning. The DB deletion is NOT
    // rolled back — that would create a "ghost row that no
    // longer reflects the user's intent" which is worse than
    // a leftover file.
    final bool cleanupSucceeded =
        await _cleanupAudioFileIfOrphaned(capturedAudioPath);

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
    return cleanupSucceeded
        ? DeleteResult.success
        : DeleteResult.successWithCleanupWarning;
  }

  /// T034 — best-effort post-delete audio file cleanup.
  ///
  /// Returns `true` when the audio file lifecycle ended cleanly
  /// (no file to clean, file already missing, or `deleteIfExists`
  /// returned `true`). Returns `false` when the file is still
  /// on disk after this call — either because the cleanup path
  /// refused the path (root self / outside root / traversal),
  /// because `deleteIfExists` itself threw, or because another
  /// row still references the same path verbatim and was left
  /// on disk for the survivor (treated as `true` since we
  /// deliberately skipped the call).
  ///
  /// Contract:
  /// - **Never throws.** Any failure inside the storage service
  ///   or filesystem is swallowed and surfaced as `false` so
  ///   the caller can map it to [DeleteResult.successWithCleanupWarning].
  /// - **Never touches the DB.** The Repository stays a pure
  ///   persistence boundary; the only DB call here is the
  ///   read-only [PracticeRecordRepository.hasAudioPathReference].
  /// - **Never rewrites the path.** The verbatim string from
  ///   the entry-of-method snapshot is wrapped in `File(...)`
  ///   and handed to `deleteIfExists`, which is the single
  ///   source of truth for path safety (`AudioFileStorageService`
  ///   rejects `..`, root, outside-root, etc.).
  /// - `null` and empty-string paths skip the call entirely —
  ///   no `File('')` is ever constructed.
  Future<bool> _cleanupAudioFileIfOrphaned(String? audioFilePath) async {
    if (audioFilePath == null || audioFilePath.isEmpty) {
      // No audio to clean — short-circuit, no File, no service
      // call. Equivalent to "cleanup succeeded because there
      // was nothing to do".
      return true;
    }

    try {
      final PracticeRecordRepository repository =
          ref.read(practiceRecordRepositoryProvider);
      // Shared-path protection: another row may still point at
      // this file. We compare verbatim (the Repository's
      // `hasAudioPathReference` is `=` SQL) so two records
      // whose paths differ only by trailing slash / case are
      // NOT treated as the same file.
      final bool stillReferenced =
          await repository.hasAudioPathReference(audioFilePath);
      if (stillReferenced) {
        return true;
      }

      final AudioFileStorageService storage =
          ref.read(audioFileStorageServiceProvider);
      // `ensureDirectories()` is the documented way to obtain
      // the root Directory. The service idempotently creates
      // root / temp / saved on each call.
      final AudioFileStoragePaths paths = await storage.ensureDirectories();
      // The path is wrapped verbatim. The service is the ONLY
      // authority on root containment, traversal, and root-self
      // deletion — the controller intentionally does NOT
      // re-validate or rewrite the path.
      //
      // `deleteIfExists` returns `false` for two clean cases:
      //  1. The file does not exist (T028 contract — short-
      //     circuit on `!await file.exists()`).
      //  2. The path is the audio root itself, which the
      //     service refuses to delete by treating the directory
      //     as "does not exist" (T028 / T028A contract — same
      //     `File.exists()` short-circuit).
      // Both are treated as clean outcomes. The only "warning"
      // cases are exceptions (root-outside, traversal), which
      // are caught below.
      await storage.deleteIfExists(
        File(audioFilePath),
        rootDirectory: paths.rootDirectory,
      );
      return true;
    } catch (e, st) {
      // Best-effort: log for engineering triage but never
      // throw to the caller. The DB deletion has already
      // succeeded; surfacing a warning rather than crashing is
      // the documented T034 contract.
      debugPrint(
        'PracticeRecordDetailController cleanup warning: '
        '$e\n$st',
      );
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // T035 — playback control surface
  // ---------------------------------------------------------------------------

  /// Starts (or restarts) playback of the loaded record's
  /// audio. Reads the path verbatim from
  /// [PracticeRecordDetailState.record] and hands it to
  /// [RealAudioPlaybackService.loadFile] followed by `play`.
  ///
  /// State machine:
  /// - `audioFilePath == null | ''` → no-op (the page surfaces
  ///   "此记录没有录音" instead of a button).
  /// - `playbackStatus == playing | loading` → no-op (a
  ///   previous `playRecordedAudio` is still in flight; the
  ///   concurrent guard `_isStartingPlayback` backs this up
  ///   at the synchronous layer).
  /// - Otherwise: publish `loading` → `service.loadFile` →
  ///   publish `playing` → `service.play` (fire-and-forget —
  ///   the service's `play` future hangs for the whole
  ///   playback duration on real devices, mirroring T031G /
  ///   T031I). The natural-completion event drives the
  ///   post-playback state machine.
  ///
  /// Errors:
  /// - `service.loadFile` throws
  ///   [AudioFileNotFoundException] / [PlaybackLoadFailedException]
  ///   / [PlaybackIOFailedException] → publish `error` with a
  ///   short friendly message; the record and the
  ///   `audioFilePath` are preserved.
  /// - `service.play` throws [PlaybackOperationFailedException]
  ///   → publish `error`. The `play` future is fired
  ///   asynchronously so the catch here covers both sync
  ///   and post-async failures (the unawaited `play` future
  ///   reports its own error to the controller in the
  ///   onError callback).
  ///
  /// **NEVER** throws to the caller. Errors are surfaced
  /// through the published [PracticeRecordDetailState].
  Future<void> playRecordedAudio() async {
    if (_disposed || !ref.mounted) {
      return;
    }
    if (_isStartingPlayback) {
      // A previous tap is still in flight; refuse the
      // duplicate so the service is never asked to start a
      // parallel `loadFile` for the same controller.
      return;
    }
    final PracticeRecordDetailState? current = state.value;
    if (current == null) {
      return;
    }
    final PracticeRecord? record = current.record;
    if (record == null) {
      return;
    }
    final String? path = record.audioFilePath;
    if (path == null || path.isEmpty) {
      // No audio to play. The page must not even surface a
      // button in this case, but the controller is the source
      // of truth and MUST refuse the call.
      return;
    }
    if (current.playbackStatus == PracticeRecordPlaybackStatus.playing ||
        current.playbackStatus == PracticeRecordPlaybackStatus.loading) {
      return;
    }

    _isStartingPlayback = true;
    final RealAudioPlaybackService playback =
        ref.read(realAudioPlaybackServiceProvider);

    // Publish `loading` so the page can show a spinner and
    // disable duplicate taps. We do NOT clear
    // `playbackErrorMessage` here — the `loading` status
    // itself signals "the previous error is being retried";
    // the `loading → playing` transition will clear it.
    state = AsyncData<PracticeRecordDetailState>(current.copyWith(
      playbackStatus: PracticeRecordPlaybackStatus.loading,
    ));

    // Snapshot the load-time state for error recovery: if the
    // controller is disposed mid-load, we must NOT write a
    // post-dispose state. The `ref.mounted` check before every
    // `state =` write covers this.
    try {
      await playback.loadFile(path);
    } on AudioPlaybackException catch (e, st) {
      debugPrint(
        'PracticeRecordDetailController playRecordedAudio loadFile '
        'failed: $e\n$st',
      );
      _isStartingPlayback = false;
      if (_disposed || !ref.mounted) {
        return;
      }
      state = AsyncData<PracticeRecordDetailState>(
        _currentOrLoaded().copyWith(
          playbackStatus: PracticeRecordPlaybackStatus.error,
          playbackErrorMessage: _friendlyLoadError(e),
        ),
      );
      return;
    } catch (e, st) {
      debugPrint(
        'PracticeRecordDetailController playRecordedAudio loadFile '
        'unexpected error: $e\n$st',
      );
      _isStartingPlayback = false;
      if (_disposed || !ref.mounted) {
        return;
      }
      state = AsyncData<PracticeRecordDetailState>(
        _currentOrLoaded().copyWith(
          playbackStatus: PracticeRecordPlaybackStatus.error,
          playbackErrorMessage: '录音加载失败，请重试',
        ),
      );
      return;
    }
    if (_disposed || !ref.mounted) {
      _isStartingPlayback = false;
      return;
    }

    // Subscribe to the natural-completion stream. Idempotent:
    // the service guards against double-subscription, and the
    // controller also null-checks before assigning. The
    // subscription is cancelled in `ref.onDispose`.
    _ensurePlaybackSubscription();

    // Synchronous transition to `playing` BEFORE the fire-
    // and-forget `play()` call so the UI updates in the same
    // microtask as the user's tap. This mirrors the T031G
    // pattern for the recording page; without it, the page
    // would render "playing" only after the service's `play`
    // future settles (which can be seconds in on real
    // devices).
    state = AsyncData<PracticeRecordDetailState>(
      _currentOrLoaded().copyWith(
        playbackStatus: PracticeRecordPlaybackStatus.playing,
        clearPlaybackErrorMessage: true,
      ),
    );
    _isStartingPlayback = false;

    // Fire-and-forget. The service's `play()` future hangs
    // for the whole playback duration on real devices; the
    // controller observes natural completion via
    // `playerStateStream` instead. Errors from the
    // unawaited future are surfaced via the `onError`
    // callback so a real-device failure mode is also covered.
    // We deliberately do NOT `await` here — see T031G for the
    // rationale.
    // ignore: unawaited_futures
    playback.play().then(
      (_) {},
      onError: (Object e, StackTrace st) {
        debugPrint(
          'PracticeRecordDetailController playRecordedAudio play '
          'failed: $e\n$st',
        );
        if (_disposed || !ref.mounted) {
          return;
        }
        // Only surface the error if the controller is still
        // trying to play. A natural-completion event between
        // the play call and this callback would already have
        // flipped us to `idle`; we must not clobber that.
        final PracticeRecordDetailState? latest = state.value;
        if (latest == null) {
          return;
        }
        if (latest.playbackStatus != PracticeRecordPlaybackStatus.playing) {
          return;
        }
        state = AsyncData<PracticeRecordDetailState>(
          latest.copyWith(
            playbackStatus: PracticeRecordPlaybackStatus.error,
            playbackErrorMessage: '播放操作失败，请重试',
          ),
        );
      },
    );
  }

  /// Pauses a currently-playing session. No-op unless the
  /// current state is [PracticeRecordPlaybackStatus.playing].
  /// The `service.pause` call is awaited so the synchronous
  /// state write only lands after the gateway confirms the
  /// pause — pausing is a fast operation on real devices
  /// (no future hangs) so the `await` is safe.
  Future<void> pausePlayback() async {
    if (_disposed || !ref.mounted) {
      return;
    }
    final PracticeRecordDetailState? current = state.value;
    if (current == null) {
      return;
    }
    if (current.playbackStatus != PracticeRecordPlaybackStatus.playing) {
      return;
    }
    final RealAudioPlaybackService playback =
        ref.read(realAudioPlaybackServiceProvider);
    try {
      await playback.pause();
    } on Object catch (e, st) {
      debugPrint(
        'PracticeRecordDetailController pausePlayback failed: $e\n$st',
      );
      if (_disposed || !ref.mounted) {
        return;
      }
      state = AsyncData<PracticeRecordDetailState>(
        _currentOrLoaded().copyWith(
          playbackStatus: PracticeRecordPlaybackStatus.error,
          playbackErrorMessage: '播放操作失败，请重试',
        ),
      );
      return;
    }
    if (_disposed || !ref.mounted) {
      return;
    }
    state = AsyncData<PracticeRecordDetailState>(
      _currentOrLoaded().copyWith(
        playbackStatus: PracticeRecordPlaybackStatus.paused,
      ),
    );
  }

  /// Resumes a paused session. No-op unless the current state
  /// is [PracticeRecordPlaybackStatus.paused]. Internally
  /// delegates to [RealAudioPlaybackService.resume] which is
  /// semantically equivalent to `play` from the `paused` state.
  Future<void> resumePlayback() async {
    if (_disposed || !ref.mounted) {
      return;
    }
    final PracticeRecordDetailState? current = state.value;
    if (current == null) {
      return;
    }
    if (current.playbackStatus != PracticeRecordPlaybackStatus.paused) {
      return;
    }
    final RealAudioPlaybackService playback =
        ref.read(realAudioPlaybackServiceProvider);
    try {
      await playback.resume();
    } on Object catch (e, st) {
      debugPrint(
        'PracticeRecordDetailController resumePlayback failed: $e\n$st',
      );
      if (_disposed || !ref.mounted) {
        return;
      }
      state = AsyncData<PracticeRecordDetailState>(
        _currentOrLoaded().copyWith(
          playbackStatus: PracticeRecordPlaybackStatus.error,
          playbackErrorMessage: '播放操作失败，请重试',
        ),
      );
      return;
    }
    if (_disposed || !ref.mounted) {
      return;
    }
    state = AsyncData<PracticeRecordDetailState>(
      _currentOrLoaded().copyWith(
        playbackStatus: PracticeRecordPlaybackStatus.playing,
        clearPlaybackErrorMessage: true,
      ),
    );
  }

  /// Stops the current session, releasing the player's
  /// on-disk handle. No-op in [PracticeRecordPlaybackStatus.idle]
  /// or `.error`. After a successful stop, the state returns
  /// to `idle` and a subsequent `playRecordedAudio` will
  /// re-load the file from scratch (the service's `stop`
  /// clears the active source).
  Future<void> stopPlayback() async {
    if (_disposed || !ref.mounted) {
      return;
    }
    final PracticeRecordDetailState? current = state.value;
    if (current == null) {
      return;
    }
    if (current.playbackStatus == PracticeRecordPlaybackStatus.idle ||
        current.playbackStatus == PracticeRecordPlaybackStatus.error) {
      return;
    }
    final RealAudioPlaybackService playback =
        ref.read(realAudioPlaybackServiceProvider);
    try {
      await playback.stop();
    } on Object catch (e, st) {
      debugPrint(
        'PracticeRecordDetailController stopPlayback failed: $e\n$st',
      );
      if (_disposed || !ref.mounted) {
        return;
      }
      state = AsyncData<PracticeRecordDetailState>(
        _currentOrLoaded().copyWith(
          playbackStatus: PracticeRecordPlaybackStatus.error,
          playbackErrorMessage: '播放操作失败，请重试',
        ),
      );
      return;
    }
    if (_disposed || !ref.mounted) {
      return;
    }
    state = AsyncData<PracticeRecordDetailState>(
      _currentOrLoaded().copyWith(
        playbackStatus: PracticeRecordPlaybackStatus.idle,
        clearPlaybackErrorMessage: true,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // T035 — delete ↔ playback coordination
  // ---------------------------------------------------------------------------

  /// Best-effort pre-delete stop. Called from
  /// [deleteCurrentRecord] BEFORE the row is removed so the
  /// on-disk file is no longer held by the player.
  ///
  /// The audio path argument is the path captured at the
  /// entry of the delete call (T034's contract). The helper
  /// uses it only to decide whether a "stop" is required —
  /// the service's `stop()` does NOT require a path argument.
  ///
  /// Decision table:
  /// - `playbackStatus == idle | error` → returns
  ///   [PreDeleteStopOutcome.proceed] (nothing to stop; the
  ///   delete proceeds).
  /// - `playbackStatus == ready | playing | paused | loading`
  ///   → best-effort `service.stop()`. On success,
  ///   [PreDeleteStopOutcome.proceed]. On any thrown
  ///   [AudioPlaybackException] or other error,
  ///   [PreDeleteStopOutcome.refused] so the delete returns
  ///   [DeleteResult.failure].
  /// - Provider disposed mid-stop → [PreDeleteStopOutcome.proceed]
  ///   (delete will then also be `ignored` via the existing
  ///   `ref.mounted` guard at the top of `deleteCurrentRecord`).
  Future<PreDeleteStopOutcome> _stopPlaybackIfActive(
    String? capturedPath,
  ) async {
    if (_disposed || !ref.mounted) {
      return PreDeleteStopOutcome.proceed;
    }
    if (capturedPath == null || capturedPath.isEmpty) {
      // No audio path → no player is holding the file. Skip
      // the stop attempt entirely; the delete proceeds.
      return PreDeleteStopOutcome.proceed;
    }
    final PracticeRecordDetailState? current = state.value;
    if (current == null) {
      return PreDeleteStopOutcome.proceed;
    }
    switch (current.playbackStatus) {
      case PracticeRecordPlaybackStatus.idle:
      case PracticeRecordPlaybackStatus.error:
        return PreDeleteStopOutcome.proceed;
      case PracticeRecordPlaybackStatus.loading:
      case PracticeRecordPlaybackStatus.ready:
      case PracticeRecordPlaybackStatus.playing:
      case PracticeRecordPlaybackStatus.paused:
        // Active session — try to stop.
        break;
    }
    final RealAudioPlaybackService playback =
        ref.read(realAudioPlaybackServiceProvider);
    try {
      await playback.stop();
    } on Object catch (e, st) {
      debugPrint(
        'PracticeRecordDetailController pre-delete stop failed: '
        '$e\n$st',
      );
      return PreDeleteStopOutcome.refused;
    }
    if (_disposed || !ref.mounted) {
      return PreDeleteStopOutcome.proceed;
    }
    // Best-effort: flip the state to `idle` so the UI is
    // not left with a stale "playing" badge while the
    // delete is in flight. The page does not observe this
    // transition for long because the success branch pops
    // the route immediately after.
    final PracticeRecordDetailState? afterStop = state.value;
    if (afterStop != null &&
        afterStop.playbackStatus != PracticeRecordPlaybackStatus.idle) {
      state = AsyncData<PracticeRecordDetailState>(
        afterStop.copyWith(
          playbackStatus: PracticeRecordPlaybackStatus.idle,
          clearPlaybackErrorMessage: true,
        ),
      );
    }
    return PreDeleteStopOutcome.proceed;
  }

  // ---------------------------------------------------------------------------
  // T035 — natural-completion subscription
  // ---------------------------------------------------------------------------

  /// Idempotently attaches the natural-completion listener to
  /// the playback service's `playerStateStream`. Called from
  /// [playRecordedAudio] after a successful `loadFile`; the
  /// subscription is cancelled in `_onDispose`. Mirrors the
  /// T031I pattern in [RecordingPracticeController].
  void _ensurePlaybackSubscription() {
    if (_playbackStateSubscription != null) {
      return;
    }
    final RealAudioPlaybackService playback =
        ref.read(realAudioPlaybackServiceProvider);
    _playbackStateSubscription =
        playback.playerStateStream.listen(_onPlayerState);
  }

  /// `playerStateStream` callback. Translates the gateway's
  /// `completed` event into a controller-side transition back
  /// to [PracticeRecordPlaybackStatus.idle].
  ///
  /// Design notes (T035):
  /// - We deliberately do NOT call
  ///   [RealAudioPlaybackService.stop] / `seek(0)` from the
  ///   completion handler. The playback service's own
  ///   internal `_onPlayerState` callback (T030) already
  ///   drives the service to `completed`; the next
  ///   `playRecordedAudio` re-loads the file from scratch
  ///   so the "replay-from-zero" contract is satisfied
  ///   without us racing the service's state machine.
  /// - `_handlingNaturalCompletion` guards against duplicate
  ///   `completed` events (which the fake gateway simulates
  ///   on real devices via `simulateRealDeviceLoopAfterCompleted`).
  /// - `_disposed` and `!ref.mounted` checks run BEFORE any
  ///   state write so a post-dispose event cannot push
  ///   into a torn-down Provider.
  void _onPlayerState(PlaybackPlayerState ps) {
    if (_disposed || !ref.mounted) {
      return;
    }
    if (ps.processingState != PlaybackProcessingState.completed) {
      return;
    }
    if (_handlingNaturalCompletion) {
      // Duplicate `completed` event from the gateway. The
      // first event has already driven the state back to
      // `idle`; the second one is a no-op.
      return;
    }
    final PracticeRecordDetailState? current = state.value;
    if (current == null) {
      return;
    }
    // If the controller has already moved on (e.g. the user
    // tapped stop before the gateway's `completed` event
    // arrived, or a previous `playRecordedAudio` has
    // already started a new session), do not clobber the
    // new state.
    if (current.playbackStatus != PracticeRecordPlaybackStatus.playing &&
        current.playbackStatus != PracticeRecordPlaybackStatus.paused &&
        current.playbackStatus != PracticeRecordPlaybackStatus.ready &&
        current.playbackStatus != PracticeRecordPlaybackStatus.loading) {
      return;
    }
    _handlingNaturalCompletion = true;
    try {
      state = AsyncData<PracticeRecordDetailState>(
        current.copyWith(
          playbackStatus: PracticeRecordPlaybackStatus.idle,
          clearPlaybackErrorMessage: true,
        ),
      );
    } finally {
      _handlingNaturalCompletion = false;
    }
  }

  /// T035 — Riverpod teardown hook. Cancels the playback
  /// stream subscription and flips the disposed flag so any
  /// post-dispose stream event is a no-op. **Does NOT** call
  /// [RealAudioPlaybackService.dispose] — the service is
  /// shared via `realAudioPlaybackServiceProvider` and is
  /// torn down by the Riverpod scope's own lifecycle.
  void _onDispose() {
    _disposed = true;
    final Future<void> cancel =
        _playbackStateSubscription?.cancel() ?? Future<void>.value();
    _playbackStateSubscription = null;
    // ignore: unawaited_futures
    cancel;
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Returns the most recent published state, or a fresh
  /// "notFound" placeholder if the controller has no
  /// published state yet. The placeholder is only reachable
  /// in race conditions where a state write happens before
  /// `build` has published; in normal operation
  /// [state.value] is always non-null after the first
  /// microtask. We return a defensive placeholder rather
  /// than throwing because the helpers in this file are
  /// called from a defensive `if (current == null) return;`
  /// upstream — the helpers should never receive a `null`
  /// snapshot.
  PracticeRecordDetailState _currentOrLoaded() {
    final PracticeRecordDetailState? latest = state.value;
    if (latest != null) {
      return latest;
    }
    return PracticeRecordDetailState.notFound();
  }

  /// T035 — maps a load-time [AudioPlaybackException] to a
  /// short, user-visible message. The full exception
  /// (including the on-disk path) is `debugPrint`-ed by the
  /// caller and NEVER rendered.
  static String _friendlyLoadError(AudioPlaybackException e) {
    if (e is AudioFileNotFoundException) {
      return '录音文件不存在或已被移动';
    }
    if (e is PlaybackIOFailedException) {
      return '录音加载失败，请重试';
    }
    // PlaybackLoadFailedException + PlaybackConfigException +
    // InvalidPlaybackStateException → generic "load failed" copy.
    return '录音加载失败，请重试';
  }
}

/// T035 — outcome of the pre-delete `_stopPlaybackIfActive`
/// helper. Two values:
/// - [proceed] — the delete can run (player was inactive OR
///   `service.stop()` succeeded).
/// - [refused] — the player was active and `service.stop()`
///   threw. The delete refuses to proceed so we never
///   silently race a player that still holds the file handle.
enum PreDeleteStopOutcome {
  proceed,
  refused,
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
