// Riverpod controller for the recording practice flow (T012 + T013.4A + T031 + T031C).
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
//   remain UNCHANGED — T031 only swaps the recording + playback
//   engines and the duration / position source. The save flow
//   still hard-codes `audioFilePath: null` because T032 (Drift
//   schema migration) is out of scope here.
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
// - Natural completion handling (T031C):
//   When `playback.playerStateStream` emits
//   `processingState == completed`:
//     1. `isPlaying` flips to `false` (auto-recovery — the page
//        no longer requires the user to tap "停止回放" after the
//        file ends);
//     2. `currentPlaybackPosition` is reset to `Duration.zero`;
//     3. `playback.seek(Duration.zero)` is called so the next
//        `play()` replays from the start (matches the user's
//        expected "回放 from the start" behaviour);
//     4. `lastError` is cleared.
//   This makes the post-completion UX deterministic: "停止回放"
//   auto-disables, "回放" + "开始录音" re-enable, and re-tapping
//   "回放" restarts the take from 0. The seek is best-effort
//   (the state-machine recovery still runs even if the seek
//   throws, e.g. completed → dispose race).
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
//   playerStateStream.completed (T031C)
//                              ->  playback.seek(Duration.zero)
//                                  (best-effort), then isPlaying =
//                                  false, currentPlaybackPosition =
//                                  Duration.zero, lastError cleared.
//                                  State transitions to recorded
//                                  (hasRecordedTake stays true,
//                                  isPlaying flips to false). UI
//                                  auto-disables "停止回放" and
//                                  re-enables "回放" + "开始录音".
//   reset                     ->  back to initial state, clears
//                                 takeId + recordedTakeResult +
//                                 savedRecordId + recordedDurationSeconds
//   setSelfRating / setNote   ->  no-op while isRecording / isPlaying
//                                 / isSaving / isCheckingPermission
//                                 or after isSaved == true
//   saveCurrentTake           ->  unchanged: writes a
//                                 PracticeRecord with
//                                 audioFilePath = null and
//                                 durationSeconds =
//                                 recordedDurationSeconds
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
import 'package:ukulele_app/features/recording/application/self_rating_mapper.dart';
import 'package:ukulele_app/features/recording/domain/self_rating.dart';
import 'package:ukulele_app/shared/providers/app_clock_provider.dart';
import 'package:ukulele_app/shared/providers/microphone_permission_service_provider.dart';
import 'package:ukulele_app/shared/providers/real_audio_playback_service_provider.dart';
import 'package:ukulele_app/shared/providers/real_audio_recorder_service_provider.dart';
import 'package:ukulele_app/shared/services/audio_playback_gateway.dart';
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
  String get statusLabel {
    if (permission == RecordingPermissionStatus.checking) {
      return '正在检查麦克风权限…';
    }
    if (permission == RecordingPermissionStatus.denied) {
      return '麦克风权限被拒绝';
    }
    if (permission == RecordingPermissionStatus.permanentDenied) {
      return '麦克风权限已永久拒绝';
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
  /// Behaviour:
  /// - **No-op** unless [state.hasRecordedTake] is `true` AND
  ///   [state.isRecording] is `false` AND [state.isSaving] is
  ///   `false` AND [state.isPlaying] is `false`.
  /// - Calls `RealAudioPlaybackService.loadFile` with the recorded
  ///   take's `resolvedPath` (T031 contract — playback only
  ///   targets the in-memory take, never historical records).
  /// - On `loadFile` success calls `play()` and flips
  ///   [state.isPlaying] to `true`. On failure surfaces
  ///   `lastError` and leaves `isPlaying = false`.
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
      await _playback.loadFile(result.resolvedPath);
      if (_disposed || !ref.mounted) {
        return;
      }
      _ensurePlaybackSubscriptions();
      await _playback.play();
      if (_disposed || !ref.mounted) {
        return;
      }
      state = state.copyWith(
        isPlaying: true,
        currentPlaybackPosition: Duration.zero,
      );
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
  // Save flow — UNCHANGED from T013.4A
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
  /// the user must tap the save button explicitly. The persisted
  /// `audioFilePath` is `null` because T032 (Drift schema
  /// migration) has not landed; T031 explicitly does NOT
  /// promote the in-memory take to the `PracticeRecord`.
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
    try {
      await repository.insert(record);
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
        // T031C: natural completion must auto-recover the
        // controller state. The user no longer has to tap
        // "停止回放" after the file ends — the controller
        // flips isPlaying back to false and asks the playback
        // service to seek to 0 so the next `play()` replays
        // from the start (matches the user's expected UX).
        // The seek is best-effort: if the playback service
        // already tore the source down (e.g. completed →
        // dispose race) the seek will throw and we still keep
        // the state-machine recovery that the user depends on.
        unawaited(_seekToZeroOnCompletion());
      }
    });
  }

  /// Best-effort `seek(0)` invoked from the playback
  /// `playerStateStream` `completed` handler (T031C).
  ///
  /// - If the seek succeeds, `currentPlaybackPosition` is
  ///   updated by the underlying service + position stream;
  ///   the controller state is then refreshed to
  ///   `isPlaying = false` / `currentPlaybackPosition = 0` /
  ///   `lastError = null` so the UI immediately re-enables
  ///   "回放" + "开始录音" and disables "停止回放".
  /// - If the seek throws (e.g. service in a state that no
  ///   longer accepts seek), the state-machine recovery
  ///   (`isPlaying = false` / position reset / `lastError`
  ///   clear) still runs so the user is never left staring
  ///   at a "停止回放" button that does nothing.
  Future<void> _seekToZeroOnCompletion() async {
    try {
      await _playback.seek(Duration.zero);
    } on Object {
      // Best-effort: state machine still recovers below.
    }
    if (_disposed || !ref.mounted) {
      return;
    }
    state = state.copyWith(
      isPlaying: false,
      currentPlaybackPosition: Duration.zero,
      clearLastError: true,
    );
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
