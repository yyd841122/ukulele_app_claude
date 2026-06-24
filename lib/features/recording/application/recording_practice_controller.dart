// Riverpod controller for the recording practice flow (T012 + T013.4A + T031 + T031C + T033 + T037B + T037B1 + T037B2 + T038B).
//
// Design notes (T031 - real audio state machine integration):
//
// - Hand-written [Notifier] (no `@riverpod` codegen) per the
//   project convention (T007 / T008 / T009 / T010 / T011).
// - T031 wires the previously-simulated recording / playback flow
//   to the real [RealAudioRecorderService] (T029) and
//   [RealAudioPlaybackService] (T030) plus
//   [MicrophonePermissionService] (T027). The save flow, the
//   rating / note metadata, and the [PracticeRecord] write path
//   remain UNCHANGED for the engine swap.
//
// - T033 connects the real audio path to the persisted
//   [PracticeRecord]: the in-memory take's
//   [AudioRecorderTakeResult.resolvedPath] is now written
//   verbatim into [PracticeRecord.audioFilePath] by
//   [saveCurrentTake]. The path is taken straight from the
//   recorder service's successful `stop()` result (which is
//   already cross-checked against the requested path inside
//   [RealAudioRecorderService] via `_pathsEqual`); the
//   controller does NOT normalise, reformat, or recompute the
//   string. When the recorder did not produce a usable
//   resolved path (no take yet, or the in-flight take was
//   discarded / failed) the field is `null` — the same
//   pre-T033 contract. The repository layer
//   ([DriftPracticeRecordRepository.insert]) already persists
//   `audioFilePath` verbatim; no schema / migration change is
//   required (schemaVersion is still 2 from T032).
//
// - The simulated [Timer.periodic] clock has been REMOVED. Position
//   during recording is derived from [AudioRecorderTakeResult] only
//   after [stopRecording] (the recorder service does not expose a
//   live position stream). Position during playback is driven by
//   the [RealAudioPlaybackService.positionStream] subscription set
//   up the first time a file is loaded.
//
// - Permission flow follows T025 §3.1 / T031 contract: the
//   controller must NOT touch the microphone before the user taps
//   "开始录音". [startRecording] first reads
//   [MicrophonePermissionService.checkStatus]; if the status is not
//   `granted` it issues a single [MicrophonePermissionService
//   .requestPermission] call (no polling / no retry). On denied /
//   permanentlyDenied / restricted the state moves to the matching
//   terminal permission status and the recorder service is NOT
//   invoked. On `granted` (initial or after request) the controller
//   calls [RealAudioRecorderService.start] with a freshly minted
//   `takeId` and flips into the recording state.
//
// - Recording ↔ Playback mutual exclusion (T025 §8.3 + T031C):
//   - `isPlaying == true` => `startRecording()` is a no-op
//     (recording button is disabled by the UI; controller is the
//         belt-and-braces guard). T031C pins this guard with a
//         dedicated controller test + page test so the user can
//         never start a recording while playback is running;
//   - `isRecording == true` => `play()` is a no-op
//     (play button is disabled by the UI);
//   - `disposed` => every public mutator is a no-op
//     (recording / playback / save / rating / note / reset).
//
// - Natural completion handling (T031C + T031I):
//   When `playback.playerStateStream` emits
//   `processingState == completed`:
//     1. `isPlaying` flips to `false` **synchronously** so the UI
//        immediately auto-disables "停止回放" and re-enables
//        "回放" + "开始录音" (T031C). The page no longer requires
//        the user to tap "停止回放" after the file ends;
//     2. `currentPlaybackPosition` is reset to `Duration.zero`;
//     3. `playback.stop()` is called (best-effort, T031I) — this
//        is what actually breaks the real-device loop on Android.
//        just_audio's `seek(0)` from a completed state can re-arm
//        playback on some real devices, so we MUST drive the
//        underlying player to `stop()` before the next `play()`.
//        The playback service's `stop()` resets `_activePosition`
//        to `Duration.zero` (via `_clearActiveSession()`) so the
//        "next play() starts from 0" contract is satisfied without
//        an extra seek(0) call (which would be rejected at the
//        service layer once state has transitioned to `idle`);
//     4. `lastError` is cleared.
//   The handler is idempotent (T031I): duplicate `completed`
//   events from `just_audio` are short-circuited by an internal
//   `_handlingNaturalCompletion` flag so we never drive
//   `playback.stop()` twice for the same take.
//
// - dispose: cancels the playback stream subscriptions, calls
//   [RealAudioPlaybackService.dispose] (best-effort, idempotent) and
//   [RealAudioRecorderService.dispose] (best-effort, idempotent) so
//   the underlying platform channels are released even if the user
//   leaves the page mid-recording. The save flow is also short-
//   circuited after dispose via `ref.mounted`.
//
// State machine (documented; tests pin every transition):
//
//   startRecording (granted)  ->  isRecording = true, hasRecording =
//                                 false, hasRecordedTake = false,
//                                 recordedTakeResult = null,
//                                 elapsedSeconds = 0, takeId =
//                                 <fresh UUID v4>, savedRecordId =
//                                 null, isSaving = false
//   startRecording (denied)   ->  isPermissionDenied = true (no
//                                 recorder call)
//   startRecording (permDenied)->  isPermissionPermanentlyDenied =
//                                 true (no recorder call)
//   startRecording (restricted)->  isPermissionDenied = true (no
//                                 recorder call)
//   startRecording (isPlaying)->  no-op
//   stopRecording             ->  isRecording = false,
//                                 hasRecording = true,
//                                 hasRecordedTake = true,
//                                 recordedTakeResult = <result>,
//                                 recordedDurationSeconds =
//                                 computed from file duration via
//                                 `RealAudioPlaybackService.duration`
//                                 after a one-shot probe; falls back
//                                 to elapsedSeconds if duration is
//                                 null.
//   play                      ->  hasRecordedTake && !isRecording:
//                                   RealAudioPlaybackService
//                                     .loadFile(resolvedPath) then
//                                     .play();
//                                   isPlaying = true
//                                 otherwise: no-op
//   stopPlayback              ->  isPlaying = false (service.stop())
//   playerStateStream.completed (T031C + T031I)
//                              ->  state.isPlaying flips to false
//                                  synchronously, position reset to 0,
//                                  lastError cleared;
//                                  then best-effort playback.stop()
//                                  (T031I core fix — breaks the
//                                  real-device loop). No explicit
//                                  seek(0) — stop() resets the
//                                  service-side position to 0 via
//                                  _clearActiveSession().
//                                  Repeated completed events are
//                                  idempotent (no double stop).
//                                  UI auto-disables "停止回放" and
//                                  re-enables "回放" + "开始录音".
//   reset                     ->  back to initial state, clears
//                                 takeId + recordedTakeResult +
//                                 savedRecordId + recordedDurationSeconds
//   setSelfRating / setNote   ->  no-op while isRecording / isPlaying
//                                 / isSaving / isCheckingPermission
//                                 or after isSaved == true
//   saveCurrentTake           ->  T033: writes a PracticeRecord
//                                 with audioFilePath sourced
//                                 verbatim from
//                                 recordedTakeResult.resolvedPath
//                                 (null when no usable take is
//                                 held) and durationSeconds =
//                                 recordedDurationSeconds. Repository
//                                 persists the value verbatim.
//
//   dispose                   ->  cancels stream subscriptions,
//                                 calls recorder / playback
//                                 dispose (idempotent).
//
// UI copy contract (T031):
//   - "本页使用本机麦克风录制练习片段"
//   - "录音暂存在本机，保存到练习记录将在后续步骤接入"
//   - "当前录音仅保存在本次会话中"
// The page must NOT display "模拟录音" / "不调用麦克风" /
// "不保存真实音频" — those phrases belong to the
// pre-T031 controller contract and are no longer accurate.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/features/practice_records/application/practice_record_id_generator.dart';
import 'package:ukulele_app/features/practice_records/data/practice_record_repository.dart';
import 'package:ukulele_app/features/practice_records/data/practice_record_repository_provider.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_record.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_tag.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_type.dart';
import 'package:ukulele_app/features/recording/application/recording_page_exit_stop_result.dart';
import 'package:ukulele_app/features/recording/application/self_rating_mapper.dart';
import 'package:ukulele_app/features/recording/domain/self_rating.dart';
import 'package:ukulele_app/shared/providers/app_clock_provider.dart';
import 'package:ukulele_app/shared/providers/microphone_permission_service_provider.dart';
import 'package:ukulele_app/shared/providers/real_audio_playback_service_provider.dart';
import 'package:ukulele_app/shared/providers/real_audio_recorder_service_provider.dart';
import 'package:ukulele_app/shared/services/audio_playback_gateway.dart';
import 'package:ukulele_app/shared/services/audio_playback_state.dart';
import 'package:ukulele_app/shared/services/audio_recorder_state.dart';
import 'package:ukulele_app/shared/services/microphone_permission_service.dart';
import 'package:ukulele_app/shared/services/microphone_permission_status.dart';
import 'package:ukulele_app/shared/services/practice_day_context.dart';
import 'package:ukulele_app/shared/services/real_audio_playback_service.dart';
import 'package:ukulele_app/shared/services/real_audio_recorder_service.dart';

/// Outcome of a single call to
/// [RecordingPracticeController.saveCurrentTake].
///
/// Unchanged from T013.4A — the save flow itself is out of scope
/// for T031; only the recording / playback engines were swapped.
enum SaveRecordingResult {
  success,
  ignored,
  failure,
}

/// Permission outcome surfaced by [RecordingPracticeController].
///
/// `idle`     — no permission check has been performed yet.
/// `checking` — a permission check / request is currently in flight.
/// `granted`  — the user has granted microphone access and a
///              recording may proceed.
/// `denied`   — the user has denied microphone access once. The
///              page exposes a "重新申请权限" affordance.
/// `permanentDenied` — the user has permanently denied microphone
///              access. The page exposes a "前往系统设置" affordance.
/// `restricted` — system-level restriction (e.g. parental controls
///              or MDM). Surfaces a "麦克风不可用" affordance.
enum RecordingPermissionStatus {
  idle,
  checking,
  granted,
  denied,
  permanentDenied,
  restricted,
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
    required this.permission,
    required this.recordedTakeResult,
    required this.currentPlaybackPosition,
    required this.currentPlaybackDuration,
    required this.lastError,
  });

  /// `true` while a real recording is in progress.
  final bool isRecording;

  /// `true` iff at least one take is currently held in memory.
  final bool hasRecording;

  /// `true` while the user is listening back to the current take.
  final bool isPlaying;

  /// Whole seconds elapsed in the current recording session.
  ///
  /// The T031 contract does NOT auto-advance this counter via a
  /// `Timer.periodic` — `recorder service` does not expose a live
  /// position stream. The value is best-effort: 0 at start, then
  /// `recordedDurationSeconds` after stopRecording. During
  /// playback it is overwritten by the last `positionStream` tick
  /// the UI happened to observe (so the same MM:SS readout remains
  /// responsive without an extra timer).
  final int elapsedSeconds;

  /// Seconds that were elapsed at the moment [stopRecording]
  /// fired. This is the value persisted as
  /// [PracticeRecord.durationSeconds].
  final int recordedDurationSeconds;

  /// UUID v4 string minted by [PracticeRecordIdGenerator] at
  /// [RecordingPracticeController.startRecording] time. Stable
  /// across a failed save.
  final String? takeId;

  /// User's self-rating for the current take.
  final SelfRating? selfRating;

  /// Free-form note attached to the current take.
  final String note;

  /// `true` while a save is currently in flight.
  final bool isSaving;

  /// id of the persisted [PracticeRecord] for the current take.
  final String? savedRecordId;

  /// Permission status mirrored from [MicrophonePermissionService].
  final RecordingPermissionStatus permission;

  /// The [AudioRecorderTakeResult] returned by the most recent
  /// successful [RealAudioRecorderService.stop]. `null` until the
  /// first take completes. Used by `play()` to derive
  /// `resolvedPath` (T031 contract — playback only loads the take
  /// currently held in memory, not historical saved records).
  final AudioRecorderTakeResult? recordedTakeResult;

  /// Most recent position reported by
  /// [RealAudioPlaybackService.positionStream]. `Duration.zero`
  /// before the first load.
  final Duration currentPlaybackPosition;

  /// Most recent duration reported by
  /// [RealAudioPlaybackService.durationStream] / `duration`
  /// getter. `null` until a file is loaded.
  final Duration? currentPlaybackDuration;

  /// Last error message from the recorder / playback service, or
  /// `null` when the most recent operation succeeded. Cleared on
  /// the next successful state transition.
  final String? lastError;

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
    permission: RecordingPermissionStatus.idle,
    recordedTakeResult: null,
    currentPlaybackPosition: Duration.zero,
    currentPlaybackDuration: null,
    lastError: null,
  );

  /// `true` iff a save has completed successfully.
  bool get isSaved => savedRecordId != null;

  /// `true` iff the page should expose a tappable "保存到练习记录"
  /// button right now.
  bool get canSave =>
      hasRecording &&
      recordedDurationSeconds > 0 &&
      !isRecording &&
      !isPlaying &&
      !isSaving &&
      !isSaved &&
      takeId != null;

  /// `true` iff a real take result is held in memory (== the
  /// recorder service has returned a successful `stop()` since the
  /// last `reset`).
  bool get hasRecordedTake => recordedTakeResult != null;

  /// MM:SS formatter for [elapsedSeconds]. Returns e.g. "00:42".
  String get formattedElapsed {
    final int minutes = elapsedSeconds ~/ 60;
    final int seconds = elapsedSeconds % 60;
    final String mm = minutes.toString().padLeft(2, '0');
    final String ss = seconds.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  /// MM:SS formatter for the live playback position. Returns
  /// e.g. "00:00" when no position has been observed yet.
  String get formattedPlaybackPosition {
    final int totalSeconds = currentPlaybackPosition.inSeconds;
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    final String mm = minutes.toString().padLeft(2, '0');
    final String ss = seconds.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  /// Human-readable status string used by the page's status card.
  ///
  /// T038B: the user-visible copy is intentionally "麦克风权限已拒绝"
  /// for both `denied` and `permanentDenied` so the page never
  /// shows the wording "永久拒绝" to the user. The internal
  /// permission state machine (the [RecordingPermissionStatus]
  /// enum value) is unchanged — both states still map to
  /// distinct semantics inside the controller (the `denied`
  /// state allows `startRecording` to call
  /// `MicrophonePermissionService.requestPermission()`; the
  /// `permanentDenied` state shows the system-settings entry
  /// point via [openAppSettings]). The page reads
  /// [statusLabel] for the status card and [permission] for
  /// the affordance decision; both reads are independent.
  String get statusLabel {
    if (permission == RecordingPermissionStatus.checking) {
      return '正在检查麦克风权限…';
    }
    if (permission == RecordingPermissionStatus.denied) {
      return '麦克风权限已拒绝';
    }
    if (permission == RecordingPermissionStatus.permanentDenied) {
      // T038B: user-visible copy is identical to `denied` —
      // we DO NOT surface "永久拒绝" to the user. The
      // affordance layer (system-settings entry point) is
      // driven by [permission] (the enum), not by this label.
      return '麦克风权限已拒绝';
    }
    if (permission == RecordingPermissionStatus.restricted) {
      return '麦克风被系统限制';
    }
    if (isRecording) {
      return '正在录音';
    }
    if (isPlaying) {
      return '正在回放';
    }
    if (hasRecording) {
      return '录音完成（可回放 / 自评）';
    }
    if (lastError != null) {
      return '音频操作失败：$lastError';
    }
    return '准备录音';
  }

  /// Returns a copy with the given fields replaced.
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
    RecordingPermissionStatus? permission,
    AudioRecorderTakeResult? recordedTakeResult,
    bool clearRecordedTakeResult = false,
    Duration? currentPlaybackPosition,
    Duration? currentPlaybackDuration,
    bool clearCurrentPlaybackDuration = false,
    String? lastError,
    bool clearLastError = false,
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
      permission: permission ?? this.permission,
      recordedTakeResult: clearRecordedTakeResult
          ? null
          : (recordedTakeResult ?? this.recordedTakeResult),
      currentPlaybackPosition:
          currentPlaybackPosition ?? this.currentPlaybackPosition,
      currentPlaybackDuration: clearCurrentPlaybackDuration
          ? null
          : (currentPlaybackDuration ?? this.currentPlaybackDuration),
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }
}

/// Riverpod controller for the recording practice page.
///
/// T031 constructor takes the live providers for
/// [RealAudioRecorderService] / [RealAudioPlaybackService] /
/// [MicrophonePermissionService]. Tests inject fakes via
/// `ProviderScope.overrides`.
class RecordingPracticeController extends Notifier<RecordingPracticeState> {
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlaybackPlayerState>? _playbackStateSubscription;
  Timer? _ticker;
  int _tickerSeconds = 0;
  bool _disposed = false;

  /// T031I: re-entrancy guard for the natural-completion handler.
  ///
  /// `just_audio` may emit `processingState == completed` more
  /// than once in some real-device scenarios (e.g. when the
  /// underlying decoder re-broadcasts the end-of-stream signal
  /// after a `seek(0)`). The guard short-circuits duplicate
  /// events so we never drive `playback.stop()` / `playback.seek()`
  /// twice for the same take — the second call would race with
  /// the first and could re-introduce the real-device
  /// "playback loops forever" regression T031I is fixing.
  bool _handlingNaturalCompletion = false;

  /// T037B1 — page-exit stop in-flight coordination.
  ///
  /// The first call to [requestStopForPageExit] creates the
  /// `Future`; concurrent callers (a same-frame AppBar double-
  /// tap, an AppBar back + immediate Android system back, etc.)
  /// `await` the same Future instead of firing their own.
  /// Cleared in the `finally` block so the next genuine exit
  /// request (after the user retries a failed stop) can start
  /// a fresh in-flight Future.
  Future<PageExitStopResult>? _pageExitStopFuture;

  /// T038B — `openAppSettings` re-entrancy guard. Mirrors the
  /// `_pageExitStopFuture` pattern but uses a plain `bool` (the
  /// page is single-threaded on the UI isolate). Prevents a
  /// rapid double-tap on the page's "前往系统设置" button from
  /// queueing two `permission_handler.openAppSettings()` calls
  /// (the OS would launch the system settings page twice and
  /// the second one would land on top of the first).
  bool _openingAppSettings = false;

  @override
  RecordingPracticeState build() {
    // Make sure all the resources are released when the provider
    // is torn down — e.g. when the page pops. Mirrors the
    // metronome + pre-T031 recording controller.
    ref.onDispose(_onDispose);
    return RecordingPracticeState.initial;
  }

  /// Reads the live [RealAudioRecorderService] from the
  /// `ref` scope. Tests override the provider with a fake.
  RealAudioRecorderService get _recorder =>
      ref.read(realAudioRecorderServiceProvider);

  /// Reads the live [RealAudioPlaybackService] from the
  /// `ref` scope. Tests override the provider with a fake.
  RealAudioPlaybackService get _playback =>
      ref.read(realAudioPlaybackServiceProvider);

  /// Reads the live [MicrophonePermissionService] from the
  /// `ref` scope. Tests override the provider with a fake.
  MicrophonePermissionService get _permission =>
      ref.read(microphonePermissionServiceProvider);

  // ---------------------------------------------------------------------------
  // Recording
  // ---------------------------------------------------------------------------

  /// Starts a real recording session.
  ///
  /// Behaviour:
  /// - **No-op** if [state.isRecording] is already true.
  /// - **No-op** if [state.isSaving] is true.
  /// - **No-op** if [state.isPlaying] is true (recording ↔
  ///   playback mutual exclusion; the page also disables the
  ///   start button while playing, this is the belt-and-braces
  ///   guard).
  /// - **No-op** if [state.permission] is `checking`.
  /// - Otherwise:
  ///   1. flip permission to `checking`;
  ///   2. read `MicrophonePermissionService.checkStatus()`;
  ///   3. if `granted` proceed; if not, call
  ///      `requestPermission()` exactly once;
  ///   4. on `granted` mint a fresh `takeId`, mark `isRecording`,
  ///      reset metadata, call `RealAudioRecorderService.start`;
  ///   5. on `denied` / `restricted` / `permanentDenied` flip
  ///      permission status and DO NOT touch the recorder.
  ///
  /// On any thrown error (permission service throws / recorder
  /// service throws), the state moves back to
  /// `permission = granted` (best-effort recovery) and
  /// `lastError` is set so the UI can surface a SnackBar.
  Future<void> startRecording() async {
    if (_disposed) {
      return;
    }
    if (state.isRecording) {
      return;
    }
    if (state.isSaving) {
      return;
    }
    if (state.isPlaying) {
      return;
    }
    if (state.permission == RecordingPermissionStatus.checking) {
      return;
    }

    state = state.copyWith(
      permission: RecordingPermissionStatus.checking,
      clearLastError: true,
    );

    MicrophonePermissionStatus permissionStatus;
    try {
      permissionStatus = await _permission.checkStatus();
      if (permissionStatus != MicrophonePermissionStatus.granted) {
        permissionStatus = await _permission.requestPermission();
      }
    } on Object catch (e) {
      if (_disposed || !ref.mounted) {
        return;
      }
      state = state.copyWith(
        permission: RecordingPermissionStatus.idle,
        lastError: '权限服务异常：$e',
      );
      return;
    }

    if (_disposed || !ref.mounted) {
      return;
    }

    final RecordingPermissionStatus nextPermission =
        _mapPermissionStatus(permissionStatus);
    if (nextPermission != RecordingPermissionStatus.granted) {
      state = state.copyWith(permission: nextPermission);
      return;
    }

    // Permission is granted. Mint a fresh takeId, reset metadata,
    // call the recorder service. Errors from `recorder.start` are
    // surfaced via `lastError` so the UI can show a SnackBar.
    final PracticeRecordIdGenerator generator =
        ref.read(practiceRecordIdGeneratorProvider);
    final String freshTakeId = generator.generate();
    state = state.copyWith(
      isRecording: true,
      isPlaying: false,
      hasRecording: false,
      clearRecordedTakeResult: true,
      elapsedSeconds: 0,
      recordedDurationSeconds: 0,
      takeId: freshTakeId,
      clearSelfRating: true,
      note: '',
      isSaving: false,
      clearSavedRecordId: true,
      permission: RecordingPermissionStatus.granted,
      clearLastError: true,
    );
    _startTicker();
    try {
      await _recorder.start(takeId: freshTakeId);
    } on Object catch (e) {
      _stopTicker();
      if (_disposed || !ref.mounted) {
        return;
      }
      state = state.copyWith(
        isRecording: false,
        permission: RecordingPermissionStatus.granted,
        clearTakeId: true,
        elapsedSeconds: 0,
        recordedDurationSeconds: 0,
        lastError: '录音启动失败：$e',
      );
    }
  }

  /// Stops the current real recording session and freezes the
  /// recorded duration.
  ///
  /// Behaviour:
  /// - **No-op** if [state.isRecording] is `false` or [state.isSaving]
  ///   is `true`.
  /// - Calls `RealAudioRecorderService.stop()`; on success
  ///   stores the returned [AudioRecorderTakeResult] in
  ///   `recordedTakeResult` and `hasRecording = true`.
  /// - The recorded duration is derived from the playback
  ///   service's `duration` getter when available, falling back
  ///   to the local elapsed-second ticker. This is best-effort:
  ///   T030 explicitly notes that some encoders report `null`
  ///   for the duration until the first `loadFile` returns; the
  ///   fallback guarantees `canSave` can flip true after at
  ///   least one tick of the local ticker.
  Future<void> stopRecording() async {
    if (_disposed) {
      return;
    }
    if (!state.isRecording) {
      return;
    }
    if (state.isSaving) {
      return;
    }
    _stopTicker();
    final int localElapsed = _tickerSeconds;
    try {
      final AudioRecorderTakeResult result = await _recorder.stop();
      if (_disposed || !ref.mounted) {
        return;
      }
      Duration? resolvedDuration;
      try {
        resolvedDuration = await _probeRecordingDuration(result.resolvedPath);
      } on Object {
        resolvedDuration = null;
      }
      final int resolvedSeconds = resolvedDuration != null
          ? resolvedDuration.inSeconds
          : (localElapsed > 0 ? localElapsed : 1);
      state = state.copyWith(
        isRecording: false,
        hasRecording: true,
        recordedTakeResult: result,
        recordedDurationSeconds: resolvedSeconds,
        elapsedSeconds: resolvedSeconds,
        currentPlaybackDuration: resolvedDuration,
        currentPlaybackPosition: Duration.zero,
        clearLastError: true,
      );
      _tickerSeconds = 0;
    } on Object catch (e) {
      if (_disposed || !ref.mounted) {
        return;
      }
      state = state.copyWith(
        isRecording: false,
        lastError: '录音停止失败：$e',
      );
      _tickerSeconds = 0;
    }
  }

  // ---------------------------------------------------------------------------
  // Playback
  // ---------------------------------------------------------------------------

  /// Starts playback of the most recently recorded take.
  ///
  /// Behaviour (T031G):
  /// - **No-op** unless [state.hasRecordedTake] is `true` AND
  ///   [state.isRecording] is `false` AND [state.isSaving] is
  ///   `false` AND [state.isPlaying] is `false`.
  /// - Calls `RealAudioPlaybackService.loadFile` with the recorded
  ///   take's `resolvedPath` (T031 contract — playback only
  ///   targets the in-memory take, never historical records).
  /// - **Immediately** flips [state.isPlaying] to `true` on a
  ///   successful `loadFile`, BEFORE the underlying
  ///   `playback.play()` Future is awaited. This is required
  ///   because `just_audio`'s `AudioPlayer.play()` returns a
  ///   `Future<void>` that stays pending for the entire
  ///   playback duration on real Android devices; awaiting it
  ///   in the controller would block the synchronous
  ///   `state.isPlaying = true` write and leave the page
  ///   buttons ("停止回放" disabled / "开始录音" enabled) in
  ///   the wrong state for the whole duration of the take.
  ///   On real devices this caused the user to be able to
  ///   start a recording while the previous playback was
  ///   still in progress. We therefore fire the play
  ///   request via `unawaited` and rely on the playback
  ///   service's `playerStateStream` `completed` event to
  ///   drive the post-playback state machine.
  /// - The `playback.play()` call itself is fire-and-forget.
  ///   Any error from it surfaces via `lastError` AND flips
  ///   `isPlaying` back to `false` (the unawaited future
  ///   returns to the controller on its own microtask).
  /// - Subscribes to the playback service's position / duration /
  ///   state streams on first success so the UI's elapsed
  ///   readout tracks the live file.
  Future<void> play() async {
    if (_disposed) {
      return;
    }
    final AudioRecorderTakeResult? result = state.recordedTakeResult;
    if (result == null) {
      return;
    }
    if (state.isRecording || state.isSaving || state.isPlaying) {
      return;
    }
    state = state.copyWith(clearLastError: true);
    try {
      // T031E: loadFile is responsible for pinning LoopMode.off
      // at the gateway layer (see AudioPlaybackGateway.loadFile
      // contract). The defensive setLoopModeOff call in
      // RealAudioPlaybackService.loadFile covers any future
      // gateway swap.
      await _playback.loadFile(result.resolvedPath);
      if (_disposed || !ref.mounted) {
        return;
      }
      _ensurePlaybackSubscriptions();

      // T031G: flip isPlaying synchronously BEFORE the
      // fire-and-forget play() call so the UI state machine
      // (停止回放 enabled / 开始录音 disabled) updates in
      // the same microtask as the user tap. just_audio's
      // play() Future stays pending for the whole playback
      // duration on real Android; awaiting it here would
      // block the state write and let the user start a
      // recording while the previous playback is still
      // running.
      state = state.copyWith(
        isPlaying: true,
        currentPlaybackPosition: Duration.zero,
      );

      // T031G: fire-and-forget the actual play() request.
      // The state machine recovery is driven by the
      // `playerStateStream` `completed` event (subscribed
      // above), which is the canonical just_audio signal
      // for "natural end of playback". Errors from the
      // play() Future are surfaced via lastError and
      // flip isPlaying back to false.
      unawaited(_playback.play().then(
        (_) {},
        onError: (Object e) {
          if (_disposed || !ref.mounted) {
            return;
          }
          state = state.copyWith(
            isPlaying: false,
            currentPlaybackPosition: Duration.zero,
            lastError: '播放失败：$e',
          );
        },
      ));
    } on Object catch (e) {
      if (_disposed || !ref.mounted) {
        return;
      }
      state = state.copyWith(
        isPlaying: false,
        lastError: '播放失败：$e',
      );
    }
  }

  /// Stops playback. **No-op** unless [state.isPlaying] is `true`.
  Future<void> stopPlayback() async {
    if (_disposed) {
      return;
    }
    if (!state.isPlaying) {
      return;
    }
    try {
      await _playback.stop();
    } on Object catch (e) {
      if (_disposed || !ref.mounted) {
        return;
      }
      state = state.copyWith(lastError: '停止播放失败：$e');
      return;
    }
    if (_disposed || !ref.mounted) {
      return;
    }
    state = state.copyWith(
      isPlaying: false,
      currentPlaybackPosition: Duration.zero,
    );
  }

  // ---------------------------------------------------------------------------
  // Permission recovery (T038B)
  // ---------------------------------------------------------------------------

  /// T038B — opens the system settings page for this app so the
  /// user can re-enable the microphone permission after a
  /// `permanentDenied` / `USER_FIXED` outcome.
  ///
  /// Internally:
  /// 1. Guards against re-entrancy — a rapid double-tap on
  ///    the page's "前往系统设置" button must NOT call
  ///    `MicrophonePermissionService.openSettings()` twice
  ///    (the OS would queue two settings-page launches).
  ///    The guard is in the controller and persists until
  ///    the OS settings page returns control to the app —
  ///    see [refreshPermissionStatus] for the release path.
  /// 2. Calls `MicrophonePermissionService.openSettings()`
  ///    (which delegates to `permission_handler`'s
  ///    `openAppSettings()` — the official API for jumping
  ///    from the app to the system settings page).
  /// 3. **Never** throws — failures are surfaced via
  ///    [lastError] so the page can render a SnackBar and
  ///    keep itself mounted.
  /// 4. The system settings page is OS-owned; the controller
  ///    does NOT receive a callback when the user returns.
  ///    The page wires a `WidgetsBindingObserver.didChangeAppLifecycleState`
  ///    resume observer that calls [refreshPermissionStatus]
  ///    to re-read the platform-side status when the app
  ///    comes back to the foreground — that resume hook is
  ///    also what releases the in-flight guard so a
  ///    follow-up tap is honoured.
  ///
  /// The method is a no-op if the controller is disposed, the
  /// widget is not mounted, or an in-flight call is already
  /// running.
  Future<void> openAppSettings() async {
    if (_disposed || !ref.mounted) {
      return;
    }
    if (_openingAppSettings) {
      return;
    }
    _openingAppSettings = true;
    try {
      final bool launched = await _permission.openSettings();
      if (_disposed || !ref.mounted) {
        return;
      }
      if (!launched) {
        state = state.copyWith(
          lastError: '无法打开系统设置，请手动前往系统设置开启麦克风权限',
        );
        // T038B: the OS refused to launch the settings
        // page. Release the guard immediately so the
        // user can try again.
        _openingAppSettings = false;
      }
      // T038B: on a successful launch the guard stays
      // set — the OS is about to bring the system
      // settings page to the foreground. The guard is
      // released by [refreshPermissionStatus] when the
      // app comes back to the foreground (i.e. the user
      // has toggled the permission and swiped / pressed
      // back into the app).
    } on Object catch (e) {
      if (_disposed || !ref.mounted) {
        return;
      }
      state = state.copyWith(
        lastError: '打开系统设置失败：$e',
      );
      _openingAppSettings = false;
    }
  }

  /// T038B — re-reads the platform-side microphone permission
  /// status and reconciles the controller's permission field
  /// with it.
  ///
  /// The page wires this call to the
  /// `WidgetsBindingObserver.didChangeAppLifecycleState`
  /// `AppLifecycleState.resumed` event so that when the user
  /// returns from the system settings page (or the system
  /// permission dialog), the controller immediately reflects
  /// the new status without waiting for the user to tap a
  /// button.
  ///
  /// Behaviour:
  /// - **No-op** if the controller is disposed or the widget
  ///   is not mounted.
  /// - **No-op** if a permission check is already in flight
  ///   (`state.permission == checking`).
  /// - Otherwise: flips `permission` to `checking`, calls
  ///   `MicrophonePermissionService.checkStatus()`, and
  ///   reconciles the result with `_mapPermissionStatus`. On
  ///   `granted` the controller does NOT auto-start a
  ///   recording — the user must tap "开始录音" again. This
  ///   preserves the "no permission auto-start" T025 / T031
  ///   contract: returning from the system settings page
  ///   only refreshes the visual state.
  /// - On error: `permission` reverts to the previous value
  ///   and `lastError` is set so the UI can surface a SnackBar.
  /// - Releases the [`_openingAppSettings`] re-entrancy
  ///   guard so the user can re-tap "前往系统设置" after
  ///   returning from the system settings page.
  Future<void> refreshPermissionStatus() async {
    if (_disposed || !ref.mounted) {
      return;
    }
    if (state.permission == RecordingPermissionStatus.checking) {
      return;
    }
    final RecordingPermissionStatus previousPermission = state.permission;
    state = state.copyWith(
      permission: RecordingPermissionStatus.checking,
      clearLastError: true,
    );
    MicrophonePermissionStatus status;
    try {
      status = await _permission.checkStatus();
    } on Object catch (e) {
      if (_disposed || !ref.mounted) {
        return;
      }
      state = state.copyWith(
        permission: previousPermission,
        lastError: '权限服务异常：$e',
      );
      return;
    }
    if (_disposed || !ref.mounted) {
      return;
    }
    // T038B: the user is back from the system settings
    // page. Release the openAppSettings re-entrancy guard
    // so a follow-up tap (e.g. the user re-denied and
    // wants to re-enter the system settings page) can
    // proceed.
    _openingAppSettings = false;
    state = state.copyWith(
      permission: _mapPermissionStatus(status),
    );
  }

  // ---------------------------------------------------------------------------
  // Page-exit stop (T037B)
  // ---------------------------------------------------------------------------

  /// T037B — **page-exit stop with awaitable semantics**. Public
  /// seam for the recording page's exit coordination
  /// ([RecordingPage] wires AppBar back, Android system back /
  /// back-gesture, and route-pop through this single
  /// chokepoint).
  ///
  /// T037B1 — **in-flight coordination wrapper**. The method is
  /// split into two layers:
  /// 1. The public [requestStopForPageExit] is a thin
  ///    re-entrancy guard: a single [_pageExitStopFuture] is
  ///    shared across concurrent callers so a same-frame AppBar
  ///    double-tap (or AppBar back + immediate Android system
  ///    back) cannot double-fire the underlying
  ///    `recorder.stop()` / `playback.stop()`. The Future is
  ///    cleared in a `finally` block so the next genuine exit
  ///    request (after a failure + retry) starts fresh.
  /// 2. [_performPageExitStop] is the internal worker that owns
  ///    the per-branch stop + retry semantics. The page is
  ///    the sole caller of the public method.
  ///
  /// Contract (the page is the sole caller — no other call site
  /// is allowed):
  /// - **Skips** when the controller is in a state that does
  ///   not need a stop:
  ///   * `_disposed || !ref.mounted` →
  ///     [PageExitStopSkipped] with reason
  ///     [PageExitStopSkipReason.disposed];
  ///   * `takeId == null && !isRecording && !isPlaying` →
  ///     [PageExitStopSkipped] with reason
  ///     [PageExitStopSkipReason.idle] (the recording page is
  ///     effectively idle; nothing to stop).
  /// - **Stops** when an active session exists. The decision
  ///   table is:
  ///   * `isRecording == true` → `await _recorder.stop()`.
  ///     The ticker is stopped BEFORE the await so the MM:SS
  ///     readout does not advance while the platform-channel
  ///     stop is in flight. `isRecording` is NOT flipped to
  ///     false before the await (see T037B1 failure-retry
  ///     contract below). On success, `isRecording` is
  ///     flipped to `false` and `recordedTakeResult` is
  ///     populated so the user can resume / save after
  ///     re-entering the page (or after cancelling the back
  ///     gesture). On failure, [PageExitStopFailure] carries
  ///     the friendly `停止录音失败，请重试` message.
  ///   * `isPlaying == true` (or `isPlaying == false` but
  ///     `recordedTakeResult != null`, i.e. the page has a
  ///     loaded playback session that the user can resume) →
  ///     `await _playback.stop()`. `isPlaying` is NOT flipped
  ///     to false before the await (see T037B1 failure-retry
  ///     contract below). On success, `isPlaying` is
  ///     flipped to `false` and the active session is
  ///     released. On failure, [PageExitStopFailure] carries
  ///     the friendly `停止播放失败，请重试` message.
  /// - **Bumps the playback session id** BEFORE the playback
  ///   `await stop()` so any `completed` event delivered as a
  ///   side-effect of `stop()` is tagged as a prior-session
  ///   event and discarded by the playback service's
  ///   `_onPlayerState` callback (T035A invariant — the
  ///   recording controller subscribes to the same shared
  ///   `RealAudioPlaybackService.playerStateStream`).
  /// - **Defensive** against the controller's state machine
  ///   reporting an active session while the underlying
  ///   service is already in a terminal state
  ///   (`AudioRecorderState.idle` /
  ///   `AudioPlaybackState.idle` /
  ///   `AudioPlaybackState.disposed` / etc.). In that case
  ///   the controller short-circuits to
  ///   [PageExitStopSkipped] with reason
  ///   [PageExitStopSkipReason.serviceAlreadyTerminal] and
  ///   does NOT call `service.stop()` — calling `stop()` on
  ///   a service that is already in the wrong state throws
  ///   [InvalidRecorderStateException] /
  ///   [InvalidPlaybackStateException] and would surface a
  ///   misleading failure SnackBar to the user.
  /// - **Never** disposes the shared recorder / playback
  ///   services. Both services are owned by their respective
  ///   providers and outlive this controller.
  /// - **Throws nothing** — every failure mode returns a
  ///   [PageExitStopResult]. The page layer treats any result
  ///   as "do not crash".
  /// - **Does NOT delete the on-disk take file** when the
  ///   user exits with an unsaved take. The take file stays
  ///   on disk under the audio root's `temp/` directory; the
  ///   user can re-enter the recording page (the controller
  ///   state is preserved across pops because the
  ///   `recordingPracticeControllerProvider` is **not**
  ///   `autoDispose`) and either save it as a
  ///   [PracticeRecord] or start a new take. This matches
  ///   the T033 + T034 file-lifecycle contract: only
  ///   `AudioFileStorageService` may delete product audio
  ///   files, and only as part of a successful save-or-delete
  ///   flow on the detail page. The recording page's
  ///   `requestStopForPageExit` path is explicitly NOT
  ///   allowed to call `recorder.cancel()` (which would
  ///   delete the file via the storage service).
  ///
  /// T037B1 + T037B2 — failure-retry contract (replaces the
  /// pre-fix "flip isRecording/isPlaying to false before
  /// await" behaviour that made a second exit call observe
  /// the page as idle and skip the actual stop):
  /// - **In-flight coordination**: a single in-flight
  ///   [_pageExitStopFuture] is shared across concurrent
  ///   callers. The first caller creates the Future; the
  ///   second caller `await`s the same Future instead of
  ///   firing its own. The Future is cleared in a
  ///   `finally` block so the next genuine exit request
  ///   (after a failure + retry) can start fresh.
  /// - **Recording branch**:
  ///   * `isRecording` is NOT flipped to false before the
  ///     `await recorder.stop()`. The flag stays true so a
  ///     retry call observes the recording branch again.
  ///   * On success, `isRecording` flips to false and the
  ///     ticker stops.
  ///   * On failure (T037B2 — the previous T037B1 behaviour
  ///     mirrored the service's "clear session on throw"
  ///     contract and lost the retry path), the recorder
  ///     service has KEPT its active session (state stays
  ///     `recording`, `_activeTakeId` / `_activeTempFile` /
  ///     `_activePaths` preserved) so a retry call can
  ///     re-issue a real `recorder.stop()` against the
  ///     same path. The controller mirrors that on the
  ///     page side by keeping `isRecording = true` AND
  ///     restarting the ticker (so the MM:SS readout
  ///     honestly reflects "recording not yet confirmed
  ///     stopped"). `takeId` is preserved.
  ///   * A retry call observes `takeId != null && isRecording
  ///     == true` and re-enters the recording branch; the
  ///     recorder service is still in `recording`, so the
  ///     controller does NOT short-circuit to
  ///     `skipped(serviceAlreadyTerminal)` and the retry
  ///     drives a real second `recorder.stop()`. This is
  ///     the "second exit actually retries" path.
  /// - **Playback branch**:
  ///   * `isPlaying` is NOT flipped to false before the
  ///     `await playback.stop()`. The playback service
  ///     contract restores `state` to the pre-stop value on
  ///     failure (`_state = previousState`), so the service
  ///     is still in a stoppable state when the user
  ///     retries — the controller mirrors this by keeping
  ///     `isPlaying = true` on the page side.
  ///   * On success, `isPlaying` flips to false.
  ///   * On failure, [PageExitStopFailure] is returned and
  ///     `isPlaying` stays true so a retry call re-enters
  ///     the playback branch.
  ///   * A retry call observes `isPlaying == true && takeId
  ///     != null` and re-enters the playback branch — the
  ///     playback service is in `playing` (or `paused` /
  ///     `ready` / `loading` — the playback service's
  ///     `stop()` is safe in all of those), so a second
  ///     `playback.stop()` call is issued. This is the
  ///     "real-device retry actually retries" path.
  Future<PageExitStopResult> requestStopForPageExit() async {
    if (_disposed || !ref.mounted) {
      return const PageExitStopResult.skipped(
        reason: PageExitStopSkipReason.disposed,
      );
    }
    // T037B1 — in-flight coordination. The first caller
    // installs the Future; concurrent callers await the
    // same Future instead of firing their own
    // recorder.stop() / playback.stop(). The Future is
    // cleared in `finally` so the next genuine exit
    // request (after a failure + retry) starts fresh.
    final Future<PageExitStopResult>? existingFuture = _pageExitStopFuture;
    if (existingFuture != null) {
      return existingFuture;
    }
    final Completer<PageExitStopResult> completer =
        Completer<PageExitStopResult>();
    _pageExitStopFuture = completer.future;
    try {
      final PageExitStopResult result = await _performPageExitStop();
      if (!completer.isCompleted) {
        completer.complete(result);
      }
      return result;
    } on Object catch (e, st) {
      // The body explicitly does not throw — this branch
      // is defense-in-depth only. Map any unexpected
      // throw to the recording-failure variant so the
      // page keeps itself mounted and surfaces a SnackBar.
      debugPrint(
        'RecordingPracticeController requestStopForPageExit '
        'unexpected throw: $e\n$st',
      );
      if (!completer.isCompleted) {
        completer.complete(
          const PageExitStopResult.failure(
            message: '停止录音失败，请重试',
          ),
        );
      }
      rethrow;
    } finally {
      _pageExitStopFuture = null;
    }
  }

  /// T037B1 — internal implementation of
  /// [requestStopForPageExit]. Owns the recording / playback
  /// branch decision table and the per-branch stop + retry
  /// semantics. The public method is an in-flight
  /// coordination wrapper that funnels concurrent calls
  /// through a single Future.
  Future<PageExitStopResult> _performPageExitStop() async {
    final RecordingPracticeState current = state;
    // Snapshot the activity flags + takeId so a concurrent
    // state write (e.g. a natural-completion event landing
    // while we await the stop) cannot change WHICH branch we
    // take mid-flight. The snapshot is a local — the
    // underlying `state` may move, but the decision table
    // already saw a coherent view.
    final bool wasRecording = current.isRecording;
    final bool wasPlaying = current.isPlaying;
    final String? snapshotTakeId = current.takeId;

    if (!wasRecording && !wasPlaying && snapshotTakeId == null) {
      // No active session. The page is effectively idle and
      // the user is leaving a clean state. No-op.
      return const PageExitStopResult.skipped(
        reason: PageExitStopSkipReason.idle,
      );
    }

    // T037B1 + T037B2 — recording branch. We stop the
    // ticker (so the MM:SS readout does not advance while
    // the platform-channel stop is in flight), but we DO
    // NOT flip `isRecording` to false before the await —
    // the failure-retry contract requires the controller
    // to still report an active recording session to a
    // concurrent / retry caller so it can re-enter this
    // branch and issue a real `recorder.stop()`. The
    // in-flight coordination in [requestStopForPageExit]
    // is the canonical re-entrancy guard; the flag-flip
    // was the wrong layer (it conflated "internal stop
    // attempt in progress" with "no recording").
    if (wasRecording) {
      final RealAudioRecorderService recorder = _recorder;
      // T037B2 — recorder service is the source of truth
      // for "is the native recorder still running". After
      // T037B2 the service keeps the active session
      // across a stop failure (state stays `recording`,
      // `_activeTakeId` / `_activeTempFile` /
      // `_activePaths` preserved) — the only way
      // `recorder.state == idle` is the natural one: a
      // successful stop on a previous call. The terminal
      // short-circuit is therefore still safe (it can
      // only fire after a successful stop, where retrying
      // is genuinely a no-op), but it is no longer
      // reachable on the failure path. The retry call
      // will observe `recorder.state == recording`,
      // fall through the short-circuit, and re-issue
      // a real `recorder.stop()` against the same
      // active session — this is the "second exit
      // actually retries" contract.
      if (recorder.state == AudioRecorderState.idle ||
          recorder.state == AudioRecorderState.disposed) {
        _stopTicker();
        _tickerSeconds = 0;
        if (ref.mounted) {
          state = current.copyWith(
            isRecording: false,
            elapsedSeconds: current.recordedDurationSeconds,
            clearLastError: true,
          );
        }
        return const PageExitStopResult.skipped(
          reason: PageExitStopSkipReason.serviceAlreadyTerminal,
        );
      }
      _stopTicker();
      try {
        final AudioRecorderTakeResult result = await recorder.stop();
        if (_disposed || !ref.mounted) {
          return const PageExitStopResult.skipped(
            reason: PageExitStopSkipReason.disposed,
          );
        }
        // Stop was successful — adopt the take result so
        // the user can save the take after re-entering the
        // page. We deliberately do NOT clear `takeId` (so
        // the user retains the "this is the take you just
        // recorded" identity) and we do NOT clear
        // `recordedTakeResult` (so a follow-up
        // `saveCurrentTake` call can still resolve the
        // verbatim path).
        Duration? resolvedDuration;
        try {
          resolvedDuration = await _probeRecordingDuration(result.resolvedPath);
        } on Object {
          resolvedDuration = null;
        }
        final int resolvedSeconds = resolvedDuration != null
            ? resolvedDuration.inSeconds
            : (current.elapsedSeconds > 0 ? current.elapsedSeconds : 1);
        _tickerSeconds = 0;
        state = current.copyWith(
          isRecording: false,
          hasRecording: true,
          recordedTakeResult: result,
          recordedDurationSeconds: resolvedSeconds,
          elapsedSeconds: resolvedSeconds,
          currentPlaybackDuration: resolvedDuration,
          currentPlaybackPosition: Duration.zero,
          clearLastError: true,
        );
        return const PageExitStopResult.success();
      } on Object catch (e, st) {
        // T037B2 — recorder.stop threw. Per the
        // RealAudioRecorderService contract (T037B2
        // update), the service has KEPT its active
        // session (state stays `recording`,
        // `_activeTakeId` / `_activeTempFile` /
        // `_activePaths` preserved) — the service is
        // truthfully reporting "I tried to stop but
        // cannot confirm; native state unknown, try
        // again". The controller mirrors that on the
        // page side:
        //   * `isRecording` STAYS true so a retry call
        //     re-enters the recording branch and
        //     issues a real second `recorder.stop()`
        //     against the same session (this is the
        //     T037B2 fix — the previous T037B1
        //     implementation would have flipped
        //     `isRecording=false` and lost the
        //     retry path);
        //   * the ticker is restarted (NOT kept
        //     stopped) so the MM:SS readout honestly
        //     reflects the unknown-stop state;
        //   * `takeId` is preserved;
        //   * return failure so the page keeps
        //     itself mounted.
        //
        // The retry call observes
        // `takeId != null && isRecording == true` and
        // re-enters the recording branch; the service
        // is still in `recording` so the controller
        // does NOT short-circuit to
        // `skipped(serviceAlreadyTerminal)` —
        // instead it re-issues
        // `await recorder.stop()`. This is the
        // "real-device retry actually retries" path.
        //
        // Caveat (documented in TECH_DEBT): when the
        // service throws, we still cannot tell
        // whether the native `record` package
        // actually stopped. If it did not, the audio
        // file on disk may keep growing and the
        // user's take will be lost. This is a
        // service-layer limitation, not a
        // controller-layer one; the controller
        // preserves the user's retry path and
        // surfaces the honest SnackBar.
        debugPrint(
          'RecordingPracticeController requestStopForPageExit '
          'recorder.stop failed: $e\n$st',
        );
        if (ref.mounted) {
          // T037B2 — keep `isRecording = true` so the
          // retry call re-enters the recording
          // branch. Restart the ticker (it was
          // stopped above) so the MM:SS readout
          // honestly reflects the unknown-stop
          // state. Preserve `takeId`. Reset the
          // ticker counter only if the local clock
          // has not advanced since the failure —
          // this keeps the MM:SS readout contiguous
          // across the failure window so the user
          // does not see the timer "jump back" to 0.
          if (current.elapsedSeconds > 0) {
            _tickerSeconds = current.elapsedSeconds;
          }
          _startTicker();
          state = current.copyWith(
            isRecording: true,
            clearLastError: true,
          );
        }
        return const PageExitStopResult.failure(
          message: '停止录音失败，请重试',
        );
      }
    }

    // T037B1 — playback branch. This covers BOTH
    // `isPlaying == true` (an active `play()`) AND
    // `isPlaying == false` with `recordedTakeResult != null`
    // (a `paused` / `ready` / `loading` session that the
    // user can resume). The playback service's `stop()` is
    // safe to call in any of those states (the service
    // documents that as a supported state transition).
    final RealAudioPlaybackService playback = _playback;
    // Defensive: if the service is already in a terminal
    // state, do NOT call `service.stop()` (it would throw
    // `InvalidPlaybackStateException`). Mirror the
    // service-level terminal state and let the page pop.
    if (playback.state == AudioPlaybackState.idle ||
        playback.state == AudioPlaybackState.disposed) {
      if (ref.mounted) {
        state = current.copyWith(
          isPlaying: false,
          currentPlaybackPosition: Duration.zero,
          clearLastError: true,
        );
      }
      return const PageExitStopResult.skipped(
        reason: PageExitStopSkipReason.serviceAlreadyTerminal,
      );
    }
    // T037B1 — do NOT flip `isPlaying` to false BEFORE
    // the `await playback.stop()`. The playback service
    // contract restores `state` to the pre-stop value on
    // failure (`_state = previousState`), so the service
    // is still in a stoppable state when the user
    // retries. Mirroring that by keeping `isPlaying = true`
    // on the controller side lets a retry call re-enter
    // this branch and issue a real second `playback.stop()`
    // — the failure-retry contract.
    try {
      await playback.stop();
    } on Object catch (e, st) {
      debugPrint(
        'RecordingPracticeController requestStopForPageExit '
        'playback.stop failed: $e\n$st',
      );
      if (!ref.mounted) {
        return const PageExitStopResult.skipped(
          reason: PageExitStopSkipReason.disposed,
        );
      }
      // Keep the page mounted; do NOT flip `isPlaying`
      // back to false — the service may still be in a
      // stoppable state and a retry must be able to
      // re-enter this branch and issue a fresh
      // `playback.stop()`.
      return const PageExitStopResult.failure(
        message: '停止播放失败，请重试',
      );
    }
    if (_disposed || !ref.mounted) {
      return const PageExitStopResult.skipped(
        reason: PageExitStopSkipReason.disposed,
      );
    }
    state = current.copyWith(
      isPlaying: false,
      currentPlaybackPosition: Duration.zero,
      clearLastError: true,
    );
    return const PageExitStopResult.success();
  }

  // ---------------------------------------------------------------------------
  // Save flow — T013.4A + T033
  // ---------------------------------------------------------------------------

  /// Restores the initial state and clears the self-rating + note
  /// + takeId + savedRecordId + recordedTakeResult +
  /// recordedDurationSeconds + playback position / duration.
  ///
  /// Used by the "重新录一遍" button. Also a no-op if a save is
  /// currently in flight.
  void reset() {
    if (state.isSaving) {
      return;
    }
    _stopTicker();
    _tickerSeconds = 0;
    state = RecordingPracticeState.initial;
  }

  /// Records the user's self-assessment for the current take.
  ///
  /// No-op while recording / playing / saving / after a
  /// successful save (the saved record is the source of truth) /
  /// while a permission check is in flight.
  void setSelfRating(SelfRating? rating) {
    if (state.isRecording ||
        state.isPlaying ||
        state.isSaving ||
        state.isSaved) {
      return;
    }
    if (state.permission == RecordingPermissionStatus.checking) {
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
  /// No-op while recording / playing / saving / after a
  /// successful save.
  void setNote(String value) {
    if (state.isRecording ||
        state.isPlaying ||
        state.isSaving ||
        state.isSaved) {
      return;
    }
    if (state.permission == RecordingPermissionStatus.checking) {
      return;
    }
    state = state.copyWith(note: value);
  }

  /// Saves the current take as a [PracticeRecord].
  ///
  /// Returns the [SaveRecordingResult] for the call:
  /// - `success` — the record was persisted, `state.savedRecordId`
  ///   is now set, and the take + rating + note are preserved.
  /// - `ignored` — the call was dropped on purpose.
  /// - `failure` — the [PracticeDayResolver] or the
  ///   [PracticeRecordRepository] threw.
  ///
  /// The save is NOT executed by `startRecording` / `reset` —
  /// the user must tap the save button explicitly.
  ///
  /// T033: the persisted `audioFilePath` is sourced verbatim
  /// from [state.recordedTakeResult]'s `resolvedPath` when a
  /// usable take is held in memory. When no successful take is
  /// currently held (no recording yet, or the most recent
  /// in-flight take failed / was discarded) the field is
  /// `null` — the pre-T033 contract. The string is taken
  /// AS-IS from the recorder service: the controller does not
  /// reformat, normalise, or recompute the path.
  Future<SaveRecordingResult> saveCurrentTake() async {
    if (_disposed) {
      return SaveRecordingResult.ignored;
    }
    final RecordingPracticeState snapshot = state;
    if (!snapshot.canSave) {
      return SaveRecordingResult.ignored;
    }
    final String snapshotTakeId = snapshot.takeId!;
    state = snapshot.copyWith(isSaving: true);
    final PracticeDayResolver resolver = ref.read(practiceDayResolverProvider);
    final PracticeDayContext dayContext;
    try {
      dayContext = await resolver.resolve();
    } catch (_) {
      if (ref.mounted) {
        state = state.copyWith(isSaving: false);
      }
      return SaveRecordingResult.failure;
    }
    if (!ref.mounted) {
      return SaveRecordingResult.ignored;
    }
    if (state.takeId != snapshotTakeId) {
      if (ref.mounted && state.isSaving) {
        state = state.copyWith(isSaving: false);
      }
      return SaveRecordingResult.ignored;
    }
    final PracticeRecordRepository repository =
        ref.read(practiceRecordRepositoryProvider);
    final DateTime now = ref.read(appClockProvider)().toUtc();
    final String trimmedNote = snapshot.note.trim();
    final String practiceContent =
        trimmedNote.isEmpty ? 'Day ${dayContext.dayIndex} 练习录音' : trimmedNote;
    final List<PracticeTag> tags = <PracticeTag>[
      PracticeTag.recording,
      if (snapshot.selfRating != null) PracticeTag.selfAssessment,
    ];
    // T033: source the audio path from the in-memory take result.
    // The recorder service guarantees that `resolvedPath` is
    // byte-equivalent to the requested path (cross-checked via
    // `_pathsEqual` inside `RealAudioRecorderService.stop`).
    // Using `?.resolvedPath` is intentional — when no usable
    // take is held in memory the field stays `null`, matching
    // the pre-T033 contract for the canSave=false / no-take
    // case. The repository persists the value verbatim.
    final String? resolvedAudioPath = snapshot.recordedTakeResult?.resolvedPath;
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
      audioFilePath: resolvedAudioPath,
      createdAt: now,
      updatedAt: now,
    );
    try {
      await repository.insert(record);
    } catch (_) {
      // T033: failure path keeps the current take + path in
      // memory so the user can retry with the same resolved
      // path. We do NOT clear `recordedTakeResult`, do NOT
      // change the audio path, and do NOT touch the audio file
      // on disk. The existing `isSaving: false` reset is the
      // same T013.4A contract.
      if (ref.mounted) {
        state = state.copyWith(isSaving: false);
      }
      return SaveRecordingResult.failure;
    }
    if (!ref.mounted) {
      return SaveRecordingResult.ignored;
    }
    if (state.takeId != snapshotTakeId) {
      if (ref.mounted && state.isSaving) {
        state = state.copyWith(isSaving: false);
      }
      return SaveRecordingResult.ignored;
    }
    state = state.copyWith(
      isSaving: false,
      savedRecordId: snapshotTakeId,
    );
    return SaveRecordingResult.success;
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Maps the platform-side [MicrophonePermissionStatus] to the
  /// UI-side [RecordingPermissionStatus]. `unknown` / `limited`
  /// / `denied` all collapse to `denied` for the MVP — the
  /// "重新申请权限" affordance applies to all of them.
  static RecordingPermissionStatus _mapPermissionStatus(
    MicrophonePermissionStatus status,
  ) {
    switch (status) {
      case MicrophonePermissionStatus.granted:
        return RecordingPermissionStatus.granted;
      case MicrophonePermissionStatus.permanentlyDenied:
        return RecordingPermissionStatus.permanentDenied;
      case MicrophonePermissionStatus.restricted:
        return RecordingPermissionStatus.restricted;
      case MicrophonePermissionStatus.denied:
      case MicrophonePermissionStatus.limited:
      case MicrophonePermissionStatus.unknown:
        return RecordingPermissionStatus.denied;
    }
  }

  /// Best-effort probe for the recorded file's duration via
  /// `RealAudioPlaybackService.duration`. Catches all errors so
  /// the caller can fall back to the local elapsed-second
  /// ticker.
  Future<Duration?> _probeRecordingDuration(String path) async {
    try {
      await _playback.loadFile(path);
    } on Object {
      return null;
    }
    final Duration? duration = _playback.duration;
    return duration;
  }

  /// Starts the local elapsed-second ticker. The ticker is
  /// intentionally NOT a `Timer.periodic` per T025 / T031:
  /// the recorder service does not expose a live position
  /// stream, and T031 only needs a coarse MM:SS readout while
  /// the user is recording. The ticker is a 1-second `Timer`
  /// that increments a counter and re-publishes state.
  void _startTicker() {
    _stopTicker();
    _tickerSeconds = 0;
    state = state.copyWith(elapsedSeconds: 0);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) {
        return;
      }
      _tickerSeconds += 1;
      state = state.copyWith(elapsedSeconds: _tickerSeconds);
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  /// Subscribes to the playback service's streams so the UI can
  /// observe live position / duration updates. Idempotent — the
  /// service itself guards against double-subscription via
  /// internal null checks.
  void _ensurePlaybackSubscriptions() {
    _positionSubscription ??= _playback.positionStream.listen((Duration p) {
      if (_disposed) {
        return;
      }
      state = state.copyWith(
        currentPlaybackPosition: p,
        elapsedSeconds: p.inSeconds,
      );
    });
    _durationSubscription ??= _playback.durationStream.listen((Duration? d) {
      if (_disposed) {
        return;
      }
      if (d == null) {
        state = state.copyWith(clearCurrentPlaybackDuration: true);
      } else {
        state = state.copyWith(currentPlaybackDuration: d);
      }
    });
    _playbackStateSubscription ??=
        _playback.playerStateStream.listen((PlaybackPlayerState ps) {
      if (_disposed) {
        return;
      }
      if (ps.processingState == PlaybackProcessingState.completed) {
        // T031I: natural-completion handler is the only path that
        // flips `isPlaying` back to false after the underlying
        // just_audio player reaches end-of-stream. It does two
        // things in order:
        //   1. **synchronously** flip `isPlaying` to false so the
        //      UI immediately auto-disables 停止回放 and
        //      re-enables 回放 + 开始录音 (T031C contract — must
        //      not be blocked by stop I/O on the underlying
        //      player);
        //   2. best-effort call `playback.stop()` to actually
        //      release the native decoder and break the loop on
        //      real Android (T031I fix — without this call the
        //      `seek(0)` step alone can re-arm playback on some
        //      real devices because just_audio drops back to
        //      `ready/playing` after a seek-from-completed, and
        //      the user gets the playback-loops-forever bug).
        //      `stop()` also resets `_activePosition` to
        //      `Duration.zero` via the playback service's
        //      `_clearActiveSession()` call, so the "next
        //      `play()` starts from 0" contract is satisfied
        //      without an extra seek(0) call (which would be
        //      rejected by the service layer once state is
        //      `idle`).
        // The whole handler is idempotent — repeated `completed`
        // events from `just_audio` are short-circuited by the
        // `_handlingNaturalCompletion` flag so we never drive
        // `playback.stop()` twice for the same take.
        unawaited(_handleNaturalCompletion());
      }
    });
  }

  /// Best-effort natural-completion recovery (T031I).
  ///
  /// Order is load-bearing:
  ///   1. **synchronously** update the controller state so the UI
  ///      recovers even if the underlying `playback.stop()`
  ///      throws (this is the T031C contract — must hold
  ///      regardless of the playback service's runtime
  ///      behaviour on the real device);
  ///   2. best-effort `playback.stop()` (T031I core fix — this
  ///      is what stops the real Android loop). The playback
  ///      service's `stop()` clears `_activePosition` to
  ///      `Duration.zero` and `_activePath` to `null`, so the
  ///      "next play() starts from 0" contract is satisfied
  ///      without an extra `playback.seek(Duration.zero)`
  ///      (which would be rejected at the service layer once
  ///      state has transitioned to `idle`).
  ///
  /// The whole method is guarded against:
  /// - re-entrancy (duplicate `completed` events from just_audio
  ///   are short-circuited via [_handlingNaturalCompletion]);
  /// - already-recovered state (`isPlaying == false` → no-op);
  /// - post-dispose invocation (`_disposed` / `!ref.mounted`
  ///   checks before every `state` write).
  Future<void> _handleNaturalCompletion() async {
    if (_disposed || !ref.mounted) {
      return;
    }
    if (_handlingNaturalCompletion) {
      // Duplicate `completed` event — just_audio can re-emit
      // after a previous completed; skip the whole handler so
      // we never double-stop the underlying player.
      return;
    }
    if (!state.isPlaying) {
      // The handler already ran for the most recent take (or the
      // state was cleared by `stopPlayback` / `reset`). Do not
      // drive the playback service again — this is the cheap
      // short-circuit path for repeated `completed` events that
      // arrive AFTER the first recovery has finished.
      return;
    }
    _handlingNaturalCompletion = true;
    try {
      // Step 1: synchronous UI recovery. MUST NOT be awaited —
      // we want this state write to land before any await point
      // so the page re-enables 回放 / 开始录音 in the same
      // microtask as the `completed` event.
      state = state.copyWith(
        isPlaying: false,
        currentPlaybackPosition: Duration.zero,
        clearLastError: true,
      );
      // Step 2: best-effort stop. This is what actually breaks
      // the real-device "playback loops forever" loop — on some
      // just_audio Android builds the player re-enters
      // ready/playing after `seek(0)` if it was not stopped
      // first, and we MUST drive the underlying player to
      // `stop()` to release the native decoder and end the
      // loop. The playback service's `stop()` resets
      // `_activePosition` to `Duration.zero` and clears
      // `_activePath`, so the "next play() starts from 0"
      // contract is satisfied without an explicit seek(0).
      try {
        await _playback.stop();
      } on Object {
        // Swallow: UI state has already been recovered above.
        // The T031C contract is "isPlaying must flip to false on
        // completed" — that contract is already satisfied by
        // step 1, regardless of whether the underlying stop
        // succeeded.
      }
      // T031I note: we deliberately do NOT call
      // `_playback.seek(Duration.zero)` after `stop()`. The
      // playback service's `stop()` transitions state from
      // `playing` / `completed` / `paused` to `idle` and clears
      // `_activePosition` to `Duration.zero` via
      // `_clearActiveSession()`. A subsequent `seek(Duration.zero)`
      // would therefore be rejected at the service layer
      // (state == idle, no active path), which is correct but
      // useless: the position has already been cleared. The
      // user-facing "next replay starts from 0" contract is
      // satisfied by the next `play()` triggering a fresh
      // `loadFile()` (T031G behaviour) which re-initialises the
      // service to state == ready with position == 0.
    } finally {
      _handlingNaturalCompletion = false;
    }
  }

  /// Hooked to `ref.onDispose` so the playback subscriptions +
  /// timers + service disposes are released when the provider
  /// is torn down. Mirrors the metronome + pre-T031 recording
  /// controller.
  ///
  /// IMPORTANT: this hook runs during the Riverpod teardown
  /// sequence, when `ref.read` is no longer valid. The recorder /
  /// playback services therefore have to be captured BEFORE
  /// dispose (via the lazy `_recorder` / `_playback` getters
  /// during normal operation). For dispose itself we only need
  /// to cancel local subscriptions + timers; we deliberately
  /// skip calling `_recorder.dispose()` / `_playback.dispose()`
  /// here because the services are owned by the Riverpod
  /// Provider scope and will be torn down by their own
  /// onDispose hooks when the corresponding audio providers are
  /// disposed. T031 contract: `dispose` MUST NOT throw.
  void _onDispose() {
    _disposed = true;
    _stopTicker();
    final Future<void> positionCancel =
        _positionSubscription?.cancel() ?? Future<void>.value();
    final Future<void> durationCancel =
        _durationSubscription?.cancel() ?? Future<void>.value();
    final Future<void> playbackStateCancel =
        _playbackStateSubscription?.cancel() ?? Future<void>.value();
    _positionSubscription = null;
    _durationSubscription = null;
    _playbackStateSubscription = null;
    unawaited(positionCancel);
    unawaited(durationCancel);
    unawaited(playbackStateCancel);
  }
}

/// Provider for the recording practice page controller.
final NotifierProvider<RecordingPracticeController, RecordingPracticeState>
    recordingPracticeControllerProvider =
    NotifierProvider<RecordingPracticeController, RecordingPracticeState>(
  RecordingPracticeController.new,
);
