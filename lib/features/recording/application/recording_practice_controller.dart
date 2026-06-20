// Riverpod controller for the recording practice flow (T012).
//
// Design notes:
// - Hand-written [Notifier] (no `@riverpod` codegen) per the
//   project convention (T007 / T008 / T009 / T010 / T011).
// - This is a *simulated* recording / playback controller. It
//   does NOT touch the microphone, does NOT read or write audio
//   bytes, does NOT request any platform permission. See the task
//   brief §边界限制 — real audio is explicitly out of scope and
//   deferred to later tasks.
// - The simulated elapsed-seconds clock uses a `Timer.periodic`
//   similar to [MetronomeController]. To keep tests independent of
//   the real clock, [tickForTesting] exposes the same one-second
//   advance publicly; tests never `sleep` and never rely on the
//   timer firing on its own.
// - The timer is created lazily on [startRecording] and reused on
//   subsequent calls — calling start twice is a no-op while a
//   timer is alive, matching the metronome's "start 不应重复创建
//   多个 timer" rule.
// - [reset] restores the initial state AND clears the self-rating
//   + note. This is the user-visible "重新录一遍" semantics.
// - [dispose] cancels the timer. `ref.onDispose` is wired so the
//   timer is released even if the consumer forgets to call
//   [dispose] explicitly.
//
// T013.4A_SAVE_RECORDING_TAKE (save flow) adds:
// - `takeId` — UUID v4 minted by [PracticeRecordIdGenerator] the
//   first time [startRecording] is called for a given take. The
//   id is preserved across the entire save flow so a failed save
//   can be retried with the SAME id (and the Repository therefore
//   treats the retry as the same logical record).
// - `recordedDurationSeconds` — the elapsed-seconds value frozen
//   at [stopRecording] time. T012 left [elapsedSeconds] free to
//   keep advancing during simulated playback; that behaviour is
//   preserved verbatim (the original timer is reused) so the
//   frozen value is the canonical recording duration.
// - `isSaving` / `savedRecordId` / `canSave` / `isSaved` — the
//   save state machine. `isSaving == true` short-circuits ALL
//   state mutators except the save method itself, so an in-flight
//   save cannot see its take mutated out from under it.
//
// State machine (documented; tests pin every transition):
//
//   startRecording    -> isRecording = true,  isPlaying = false,
//                        hasRecording = false, elapsedSeconds = 0,
//                        recordedDurationSeconds = 0,
//                        selfRating = null, note = '',
//                        takeId = <fresh UUID v4>,
//                        savedRecordId = null, isSaving = false
//                        (start while playing keeps the same rules:
//                         it stops playback AND mints a new UUID.)
//   stopRecording     -> isRecording = false, hasRecording = true,
//                        recordedDurationSeconds = elapsedSeconds
//                        (playback that follows continues to
//                         advance elapsedSeconds; the frozen
//                         recordedDurationSeconds is the one used
//                         when the user hits 保存.)
//   play              -> hasRecording && !isRecording:
//                          isPlaying = true, isRecording = false
//                        otherwise: no-op
//                        (playback continues to advance
//                         elapsedSeconds; recordedDurationSeconds
//                         is NOT touched.)
//   stopPlayback      -> isPlaying = false
//   reset             -> back to initial state (clears rating +
//                        note + takeId + savedRecordId +
//                        recordedDurationSeconds).
//   setSelfRating / setNote
//                     -> no-op while isRecording or isSaving.
//                     -> no-op after isSaved == true (the saved
//                        record is the source of truth).
//   saveCurrentTake   -> canSave: sets isSaving, awaits
//                        PracticeDayResolver + Repository,
//                        writes savedRecordId on success. While
//                        isSaving == true, every other mutator
//                        is a no-op (see "保存期间状态保护" in the
//                        task brief).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/features/practice_records/application/practice_record_id_generator.dart';
import 'package:ukulele_app/features/practice_records/data/practice_record_repository.dart';
import 'package:ukulele_app/features/practice_records/data/practice_record_repository_provider.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_record.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_tag.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_type.dart';
import 'package:ukulele_app/features/recording/application/self_rating_mapper.dart';
import 'package:ukulele_app/features/recording/domain/self_rating.dart';
import 'package:ukulele_app/shared/providers/app_clock_provider.dart';
import 'package:ukulele_app/shared/services/practice_day_context.dart';

/// Interval between two ticks of the simulated recording clock.
const Duration kRecordingTickInterval = Duration(seconds: 1);

/// Outcome of a single call to
/// [RecordingPracticeController.saveCurrentTake].
///
/// `success`  — the [PracticeRecord] was persisted. State now has
///              `savedRecordId` set and `isSaving == false`.
/// `ignored`  — the call was deliberately dropped: the state
///              could not save (e.g. `isSaving`, `isSaved`,
///              `takeId == null`, Provider already disposed, or
///              the take changed while awaiting). The UI MUST
///              NOT show a failure SnackBar for this outcome.
/// `failure`  — the Resolver or the Repository threw. The take,
///              self-rating, note, recordedDurationSeconds, and
///              takeId are all preserved. The user can retry
///              with the same takeId. The UI MAY show a failure
///              SnackBar.
enum SaveRecordingResult {
  success,
  ignored,
  failure,
}

/// Immutable state of the recording practice flow.
@immutable
class RecordingPracticeState {
  const RecordingPracticeState({
    required this.isRecording,
    required this.hasRecording,
    required this.isPlaying,
    required this.elapsedSeconds,
    required this.recordedDurationSeconds,
    required this.takeId,
    required this.selfRating,
    required this.note,
    required this.isSaving,
    required this.savedRecordId,
  });

  /// `true` while a simulated recording is in progress.
  final bool isRecording;

  /// `true` iff at least one simulated take is currently held in
  /// memory. Cleared by [reset] and by starting a new take.
  final bool hasRecording;

  /// `true` while the user is listening back to the (simulated)
  /// take. Mutually exclusive with [isRecording] — see the file
  /// doc comment.
  final bool isPlaying;

  /// Whole seconds elapsed in the current simulated recording /
  /// playback. Reset to 0 whenever a fresh recording begins and
  /// NOT reset by playback (T012's original behaviour).
  final int elapsedSeconds;

  /// Seconds that were elapsed at the moment [stopRecording]
  /// fired. This is the value persisted as
  /// [PracticeRecord.durationSeconds] and is NOT updated by
  /// subsequent playback ticks — see the T013.4A "冻结录音时长"
  /// contract.
  final int recordedDurationSeconds;

  /// UUID v4 string minted by [PracticeRecordIdGenerator] at
  /// [RecordingPracticeController.startRecording] time. `null`
  /// until the user has started at least one take in this
  /// Provider's lifetime. Stays stable across a failed save so
  /// the user can retry with the same id.
  final String? takeId;

  /// User's self-rating for the current take. `null` until the user
  /// picks one.
  final SelfRating? selfRating;

  /// Free-form note attached to the current take. In-memory only
  /// for T012; persistence is deferred to T013.
  final String note;

  /// `true` while a save is currently in flight. All other
  /// mutators are no-ops while this is true.
  final bool isSaving;

  /// id of the persisted [PracticeRecord] for the current take
  /// — `null` until a save succeeds. Equals [takeId] on success
  /// by construction (the Repository never generates ids).
  final String? savedRecordId;

  /// Returns the initial / "ready to record" state. Static factory
  /// so tests and the controller can share the same baseline.
  static const RecordingPracticeState initial = RecordingPracticeState(
    isRecording: false,
    hasRecording: false,
    isPlaying: false,
    elapsedSeconds: 0,
    recordedDurationSeconds: 0,
    takeId: null,
    selfRating: null,
    note: '',
    isSaving: false,
    savedRecordId: null,
  );

  /// `true` iff a save has completed successfully. Driven by
  /// [savedRecordId] so the only way to flip it is to actually
  /// persist a record.
  bool get isSaved => savedRecordId != null;

  /// `true` iff the page should expose a tappable "保存到练习记录"
  /// button right now. The full precondition is documented in
  /// the task brief §"保存状态" — kept here so the UI and the
  /// Controller agree on a single source of truth.
  bool get canSave =>
      hasRecording &&
      recordedDurationSeconds > 0 &&
      !isRecording &&
      !isPlaying &&
      !isSaving &&
      !isSaved &&
      takeId != null;

  /// MM:SS formatter for [elapsedSeconds]. Returns e.g. "00:42".
  /// Exposed so the page does not re-implement the formatting and
  /// tests can pin it.
  String get formattedElapsed {
    final int minutes = elapsedSeconds ~/ 60;
    final int seconds = elapsedSeconds % 60;
    final String mm = minutes.toString().padLeft(2, '0');
    final String ss = seconds.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  /// Human-readable status string used by the page's status card.
  String get statusLabel {
    if (isRecording) {
      return '模拟录音中';
    }
    if (isPlaying) {
      return '模拟回放中';
    }
    if (hasRecording) {
      return '已录音（可回放 / 自评）';
    }
    return '准备录音';
  }

  /// Returns a copy with the given fields replaced. `selfRating`,
  /// `takeId`, and `savedRecordId` are explicitly nullable here, so
  /// to clear them the caller passes the matching `clear*` sentinel
  /// — see [copyWith].
  RecordingPracticeState copyWith({
    bool? isRecording,
    bool? hasRecording,
    bool? isPlaying,
    int? elapsedSeconds,
    int? recordedDurationSeconds,
    String? takeId,
    bool clearTakeId = false,
    SelfRating? selfRating,
    bool clearSelfRating = false,
    String? note,
    bool? isSaving,
    String? savedRecordId,
    bool clearSavedRecordId = false,
  }) {
    return RecordingPracticeState(
      isRecording: isRecording ?? this.isRecording,
      hasRecording: hasRecording ?? this.hasRecording,
      isPlaying: isPlaying ?? this.isPlaying,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      recordedDurationSeconds:
          recordedDurationSeconds ?? this.recordedDurationSeconds,
      takeId: clearTakeId ? null : (takeId ?? this.takeId),
      selfRating: clearSelfRating ? null : (selfRating ?? this.selfRating),
      note: note ?? this.note,
      isSaving: isSaving ?? this.isSaving,
      savedRecordId:
          clearSavedRecordId ? null : (savedRecordId ?? this.savedRecordId),
    );
  }
}

/// Riverpod controller for the recording practice page.
class RecordingPracticeController extends Notifier<RecordingPracticeState> {
  Timer? _timer;

  @override
  RecordingPracticeState build() {
    // Make sure the timer is cancelled when the provider is torn
    // down — e.g. when the page pops. Mirrors the metronome.
    ref.onDispose(_cancelTimer);
    return RecordingPracticeState.initial;
  }

  /// Starts a simulated recording.
  ///
  /// Behaviour:
  /// - If [state.isRecording] is already true, this is a no-op (the
  ///   timer is reused — see file docs). `takeId` is NOT
  ///   regenerated; the id is stable for the whole take.
  /// - If [state.isPlaying] is true, playback is stopped first so
  ///   the two states are mutually exclusive. A fresh UUID is
  ///   minted because the user is starting a new take.
  /// - `hasRecording` is reset because the user is starting a new
  ///   take; `elapsedSeconds` and `recordedDurationSeconds` reset
  ///   to 0; `selfRating` and `note` are cleared as well because
  ///   the previous take is being dropped — leaving stale metadata
  ///   would create the confusing "no recording yet but a
  ///   self-rating is still selected" state (T012_FIX).
  /// - A fresh UUID v4 is minted via
  ///   [practiceRecordIdGeneratorProvider] and stored in `takeId`
  ///   (unless one already exists, e.g. we just retook without
  ///   leaving the page — but the contract is "new take = new id").
  /// - The save envelope is cleared: any previous `savedRecordId`
  ///   is dropped and `isSaving` is reset.
  void startRecording() {
    if (state.isRecording) {
      return;
    }
    if (state.isSaving) {
      return;
    }
    _cancelTimer();
    final PracticeRecordIdGenerator generator =
        ref.read(practiceRecordIdGeneratorProvider);
    final String freshTakeId = generator.generate();
    state = state.copyWith(
      isRecording: true,
      isPlaying: false,
      hasRecording: false,
      elapsedSeconds: 0,
      recordedDurationSeconds: 0,
      takeId: freshTakeId,
      clearSelfRating: true,
      note: '',
      isSaving: false,
      clearSavedRecordId: true,
    );
    _timer = Timer.periodic(kRecordingTickInterval, (_) => _advance());
  }

  /// Stops the simulated recording.
  ///
  /// Behaviour:
  /// - If we were not recording, this is a no-op.
  /// - The current take is "kept" (`hasRecording = true`) so the
  ///   user can play it back, rate it, or re-record.
  /// - `recordedDurationSeconds` is FROZEN to the current
  ///   [elapsedSeconds] value. Subsequent simulated playback may
  ///   continue to advance `elapsedSeconds`; the frozen value is
  ///   the one that is persisted on save.
  void stopRecording() {
    if (!state.isRecording) {
      return;
    }
    if (state.isSaving) {
      return;
    }
    _cancelTimer();
    state = state.copyWith(
      isRecording: false,
      hasRecording: true,
      recordedDurationSeconds: state.elapsedSeconds,
    );
  }

  /// Simulates playback of the current take.
  ///
  /// Behaviour:
  /// - No-op unless `hasRecording && !isRecording` — i.e. there
  ///   must be a take AND we must not be recording at the same
  ///   time.
  /// - On success, sets `isPlaying = true` and starts the timer so
  ///   the elapsed-time counter advances during playback (the UI
  ///   reuses the same MM:SS display for symmetry).
  /// - Playback does NOT change `recordedDurationSeconds`; that
  ///   value is the canonical recording duration and was frozen
  ///   at [stopRecording] time.
  void play() {
    if (!state.hasRecording || state.isRecording) {
      return;
    }
    if (state.isPlaying) {
      return;
    }
    if (state.isSaving) {
      return;
    }
    state = state.copyWith(isPlaying: true);
    _timer = Timer.periodic(kRecordingTickInterval, (_) => _advance());
  }

  /// Stops playback.
  ///
  /// Behaviour:
  /// - No-op unless we are currently playing.
  /// - `hasRecording` stays true so the user can play it again.
  void stopPlayback() {
    if (!state.isPlaying) {
      return;
    }
    if (state.isSaving) {
      return;
    }
    _cancelTimer();
    state = state.copyWith(isPlaying: false);
  }

  /// Restores the initial state and clears the self-rating + note
  /// + takeId + savedRecordId.
  ///
  /// Used by the "重新录一遍" button. Also a no-op if a save is
  /// currently in flight (we never want to wipe the take while a
  /// save is awaiting the Repository).
  void reset() {
    if (state.isSaving) {
      return;
    }
    _cancelTimer();
    state = RecordingPracticeState.initial;
  }

  /// Records the user's self-assessment for the current take.
  ///
  /// No-op while recording (the user has no take to rate yet), no-op
  /// while saving (so the in-flight save cannot see its take
  /// mutated), and no-op after a successful save (the saved record
  /// is the source of truth). `null` clears the rating — useful for
  /// testing.
  void setSelfRating(SelfRating? rating) {
    if (state.isRecording || state.isSaving || state.isSaved) {
      return;
    }
    if (rating == null) {
      state = state.copyWith(clearSelfRating: true);
    } else {
      state = state.copyWith(selfRating: rating);
    }
  }

  /// Stores the free-form note for the current take.
  ///
  /// No-op while recording (no take exists yet), no-op while
  /// saving, and no-op after a successful save (the saved record
  /// is the source of truth). Empty string clears the note.
  void setNote(String value) {
    if (state.isRecording || state.isSaving || state.isSaved) {
      return;
    }
    state = state.copyWith(note: value);
  }

  /// Saves the current take as a [PracticeRecord].
  ///
  /// Returns the [SaveRecordingResult] for the call:
  /// - `success` — the record was persisted, `state.savedRecordId`
  ///   is now set, and the take + rating + note + takeId are
  ///   preserved so the user can still replay / re-take / retry.
  /// - `ignored` — the call was dropped on purpose (see the
  ///   [SaveRecordingResult] doc).
  /// - `failure` — the [PracticeDayResolver] or the
  ///   [PracticeRecordRepository] threw. The take, rating, note,
  ///   `recordedDurationSeconds`, and `takeId` are all preserved
  ///   so the user can retry with the SAME id.
  ///
  /// The save is NOT executed by `startRecording` / `reset` —
  /// the user must tap the save button explicitly.
  Future<SaveRecordingResult> saveCurrentTake() async {
    final RecordingPracticeState snapshot = state;

    // 1. Read the current snapshot.
    // 2. canSave check. Catches: isRecording, isPlaying, isSaving,
    //    isSaved, hasRecording == false, recordedDurationSeconds
    //    == 0, takeId == null.
    if (!snapshot.canSave) {
      return SaveRecordingResult.ignored;
    }
    final String snapshotTakeId = snapshot.takeId!;

    // 3. Set isSaving = true so the UI can show "正在保存…" and
    //    every other mutator becomes a no-op for the duration of
    //    the await.
    state = snapshot.copyWith(isSaving: true);

    // 4. Resolve the practice day + id. (Steps 4–5 in the brief.)
    final PracticeDayResolver resolver = ref.read(practiceDayResolverProvider);
    final PracticeDayContext dayContext;
    try {
      dayContext = await resolver.resolve();
    } catch (_) {
      // Provider may have been disposed while awaiting. Clear
      // isSaving if still mounted, otherwise just leave state
      // alone — dispose will fire shortly.
      if (ref.mounted) {
        state = state.copyWith(isSaving: false);
      }
      return SaveRecordingResult.failure;
    }

    // 6. Lifecycle guard.
    if (!ref.mounted) {
      return SaveRecordingResult.ignored;
    }

    // 7. Take-id consistency guard. If the user started a new take
    //    (or hit reset) while we were awaiting, the in-flight
    //    save is stale and must NOT write back.
    if (state.takeId != snapshotTakeId) {
      // Best-effort: clear isSaving if still mounted.
      if (ref.mounted && state.isSaving) {
        state = state.copyWith(isSaving: false);
      }
      return SaveRecordingResult.ignored;
    }

    // 8. Build the PracticeRecord using the FREEZEN
    //    `recordedDurationSeconds` value (NOT the live
    //    `elapsedSeconds`, which may have been advanced by
    //    playback).
    final PracticeRecordRepository repository =
        ref.read(practiceRecordRepositoryProvider);
    final DateTime now = ref.read(appClockProvider)().toUtc();
    final String trimmedNote = snapshot.note.trim();
    final String practiceContent =
        trimmedNote.isEmpty ? 'Day ${dayContext.dayIndex} 模拟录音练习' : trimmedNote;
    final List<PracticeTag> tags = <PracticeTag>[
      PracticeTag.recording,
      if (snapshot.selfRating != null) PracticeTag.selfAssessment,
    ];
    final PracticeRecord record = PracticeRecord(
      id: snapshotTakeId,
      practiceDate: dayContext.today,
      dayIndex: dayContext.dayIndex,
      primaryPracticeType: PracticeType.recording,
      practiceTags: tags,
      practiceContent: practiceContent,
      durationSeconds: snapshot.recordedDurationSeconds,
      isCompleted: true,
      selfAssessment: mapSelfRatingToSelfAssessment(snapshot.selfRating),
      audioFilePath: null,
      createdAt: now,
      updatedAt: now,
    );

    // 9. Persist. (10. await + re-check before publishing.)
    try {
      await repository.insert(record);
    } catch (_) {
      // Failure: keep take + rating + note + duration + takeId.
      // Clear isSaving so the user can retry.
      if (ref.mounted) {
        state = state.copyWith(isSaving: false);
      }
      return SaveRecordingResult.failure;
    }

    // 10. Post-await lifecycle + take-id re-check.
    if (!ref.mounted) {
      return SaveRecordingResult.ignored;
    }
    if (state.takeId != snapshotTakeId) {
      if (ref.mounted && state.isSaving) {
        state = state.copyWith(isSaving: false);
      }
      return SaveRecordingResult.ignored;
    }

    // 11. Success: write the saved id. isSaving clears as a
    //     side-effect of the `isSaved` transition.
    state = state.copyWith(
      isSaving: false,
      savedRecordId: snapshotTakeId,
    );
    return SaveRecordingResult.success;
  }

  /// Public test entry point: advance the simulated clock by one
  /// tick. Tests call this directly and never sleep or rely on the
  /// timer firing.
  ///
  /// Mirrors [MetronomeController.tickForTesting].
  @visibleForTesting
  void tickForTesting() => _advance();

  /// Internal "advance one second" logic. Increments
  /// [RecordingPracticeState.elapsedSeconds] by one. Used by both
  /// the real `Timer.periodic` callback and [tickForTesting].
  ///
  /// Note: this does NOT touch [RecordingPracticeState.recordedDurationSeconds].
  /// That value is frozen at [stopRecording] time and only used
  /// when the user saves the take.
  void _advance() {
    state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
  }

  /// Cancels the periodic timer if it exists. Idempotent.
  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Provider for the recording practice page controller.
final NotifierProvider<RecordingPracticeController, RecordingPracticeState>
    recordingPracticeControllerProvider =
    NotifierProvider<RecordingPracticeController, RecordingPracticeState>(
  RecordingPracticeController.new,
);
