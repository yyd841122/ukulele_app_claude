// Lesson Engine — Adaptive Policy Engine
// (T057_ADAPTIVE_LEARNING_SYSTEM).
//
// What this class is:
// - The T057 decision layer. It is a pure function:
//     `(SkillState, TaskAttemptHistory, Lesson, lastTask) ->
//      AdaptiveDecision`
//   The decision tells the caller (the home page or a future
//   presenter) which task to push, with which tool
//   parameters, and WHY.
//
// Why "pure function" instead of an injected strategy:
// - T057 is the first pass at adaptation. The policy is small
//   enough (3 rules × 3 axes = ~9 branches) that the value
//   of an injected strategy outweighs the indirection cost.
// - Pure functions are trivially unit-testable: pass a
//   snapshot, assert the decision shape.
//
// Decision rules (T057 v1):
// 1. ERROR-DRIVEN DOWNGRADE — if the user's last
//    [AdaptivePolicy.kEscalateDownThreshold] attempts on the
//    SAME task are all `wrong`, emit a [RepeatTaskDecision]
//    with the task's parameters scaled DOWN (BPM -10, chord
//    list truncated to 1, note list truncated to 1).
// 2. SKILL-DRIVEN INJECTION — if the user's skill on any
//    single axis has fallen below
//    [AdaptivePolicy.kWeakAxisThreshold], emit an
//    [InjectSkillDecision] that picks a task from the same
//    lesson targeting the weak axis.
// 3. DEFAULT PROGRESSION — otherwise, walk the lesson in
//    declaration order and emit the first task the user has
//    not yet successfully completed. Fallback to the first
//    task if every task is already complete.
//
// The rules are intentionally ordered: rule 1 wins over
// rule 2, which wins over rule 3. The comment in
// `decide` documents the precedence so future contributors
// do not invert it by accident.

import 'package:flutter/foundation.dart';

import 'package:ukulele_app/features/lesson_engine/domain/adaptive_decision.dart';
import 'package:ukulele_app/features/lesson_engine/domain/learning_metrics.dart';
import 'package:ukulele_app/features/lesson_engine/domain/lesson.dart';
import 'package:ukulele_app/features/lesson_engine/domain/lesson_task_type.dart';
import 'package:ukulele_app/features/lesson_engine/domain/lesson_tool.dart';
import 'package:ukulele_app/features/lesson_engine/domain/skill_state.dart';
import 'package:ukulele_app/features/lesson_engine/domain/task_tool_binding.dart';

/// The T057 adaptive policy.
///
/// Stateless. Construct via `const AdaptivePolicy()` and
/// share the single canonical instance via a Riverpod
/// provider.
class AdaptivePolicy {
  const AdaptivePolicy();

  // --- Tunable thresholds (public so tests can override
  //     without subclassing) --------------------------------

  /// Number of trailing wrong attempts on the SAME task that
  /// triggers a [RepeatTaskDecision]. Defaults to 2, matching
  /// the T057 design ("错误 ≥ 2 → 降级").
  static const int kEscalateDownThreshold = 2;

  /// Per-axis skill score below which the user is considered
  /// "weak" on that axis. Defaults to 0.30 — high enough to
  /// catch early struggles, low enough to not nag the user
  /// on a fresh install (where initial = 0.0).
  static const double kWeakAxisThreshold = 0.30;

  /// Number of trailing correct attempts that the policy
  /// treats as "user has nailed this; offer a harder task".
  /// Defaults to 3 per the T057 design.
  static const int kEscalateUpThreshold = 3;

  /// BPM step the policy uses when scaling difficulty up or
  /// down on metronome tasks.
  static const int kBpmStep = 10;

  /// Default BPM used when a metronome task has no BPM in
  /// its description. Mirrors the [TaskBindingResolver]
  /// fallback.
  static const int kDefaultBpm = 80;

  /// Difficulty range the policy reports. The
  /// [ProceedTaskDecision.difficulty] field is in
  /// [0.0..1.0]; tier boundaries live in
  /// [_scaleBpm] / [_scaleList]. T057 v1 uses three tiers
  /// (easy / neutral / hard) — a continuous gradient is
  /// reserved for T058+ once the AI scorer feeds accuracy.
  static const double kDifficultyFloor = 0.0;
  static const double kDifficultyCeiling = 1.00;

  /// Computes the next [AdaptiveDecision] for [lesson].
  ///
  /// Inputs:
  /// - [state]: the user's current skill state.
  /// - [history]: the full attempt history (chronological).
  /// - [lesson]: today's lesson (the policy picks a task
  ///   from `lesson.tasks`; it does NOT invent tasks).
  /// - [lastTask]: the task the user just finished, or
  ///   `null` on the very first call. The policy uses this
  ///   to detect "same task, multiple wrongs" without
  ///   scanning the full history.
  ///
  /// Output: NEVER null. The policy always returns one of
  /// the three sealed [AdaptiveDecision] subtypes.
  AdaptiveDecision decide({
    required SkillState state,
    required TaskAttemptHistory history,
    required Lesson lesson,
    LessonTask? lastTask,
  }) {
    // ---- Rule 1: error-driven downgrade --------------------
    // If the user's trailing run of wrongs on the same task
    // hit the threshold, repeat the SAME task with easier
    // parameters.
    if (lastTask != null) {
      final int sameTaskWrongs = _trailingWrongsOnTask(history, lastTask.id);
      if (sameTaskWrongs >= kEscalateDownThreshold) {
        return _repeatTaskDecision(
          lesson: lesson,
          task: lastTask,
          recentWrongs: sameTaskWrongs,
        );
      }
    }

    // ---- Rule 2: skill-driven injection --------------------
    // If the user is weak on any axis AND has actually
    // attempted a task of that type at least once (so we
    // have evidence the axis is genuinely weak, not just
    // the "untouched" zero baseline), drill the weakest
    // such axis by picking a task from the same lesson that
    // targets it.
    final SkillAxis? weakAxis = _weakestEngagedAxis(state, history);
    if (weakAxis != null) {
      final LessonTask? injectTask = _pickTaskForAxis(lesson, weakAxis);
      if (injectTask != null) {
        return _injectSkillDecision(
          lesson: lesson,
          task: injectTask,
          weakAxis: weakAxis,
          weakScore: _scoreFor(state, weakAxis),
        );
      }
      // If the lesson has no task targeting the weak axis
      // (e.g. Day 1 has no chord task), fall through to
      // default progression — we do NOT downgrade the
      // user's rhythm score just because the lesson
      // happens to lack a chord task.
    }

    // ---- Rule 3: default progression -----------------------
    // Walk the lesson in declaration order and pick the
    // first task the user has not yet successfully completed
    // (i.e. the last attempt on the task was `correct` /
    // `partial`). Fallback to the first task when the user
    // has somehow completed everything.
    return _proceedTaskDecision(lesson: lesson, history: history);
  }

  // --- Internal helpers ---

  /// Counts the trailing run of `wrong` attempts on the task
  /// with id [taskId]. Returns 0 when the last attempt is
  /// for a different task (so the policy does not flag a
  /// chord wrong as a metronome wrong).
  int _trailingWrongsOnTask(TaskAttemptHistory history, String taskId) {
    int n = 0;
    for (int i = history.attempts.length - 1; i >= 0; i--) {
      final TaskAttemptMetric m = history.attempts[i];
      if (m.taskId != taskId) break;
      if (m.verdict != AttemptVerdict.wrong) break;
      n++;
    }
    return n;
  }

  /// Returns the weakest axis whose score is below
  /// [kWeakAxisThreshold] AND that the user has actively
  /// struggled with (at least one `wrong` verdict on a
  /// task of that type).
  ///
  /// "Zero baseline" axes (no history, score 0) and
  /// "fresh-correct" axes (one correct verdict, score
  /// ~0.10) are NOT candidates for injection — the user
  /// is on schedule, just early. The inject rule is a
  /// rescue for users who have hit the same surface
  /// multiple times and are still struggling.
  ///
  /// Ties are broken in declaration order (rhythm > chord >
  /// note) so the policy is deterministic.
  SkillAxis? _weakestEngagedAxis(
    SkillState state,
    TaskAttemptHistory history,
  ) {
    final Map<SkillAxis, int> wrongsByAxis = <SkillAxis, int>{
      SkillAxis.rhythm: 0,
      SkillAxis.chord: 0,
      SkillAxis.note: 0,
    };
    for (final TaskAttemptMetric m in history.attempts) {
      if (m.verdict == AttemptVerdict.wrong) {
        final SkillAxis? axis = _axisForType(m.taskType);
        if (axis != null) {
          wrongsByAxis[axis] = (wrongsByAxis[axis] ?? 0) + 1;
        }
      }
    }
    final List<_AxisScore> axes = <_AxisScore>[
      _AxisScore(SkillAxis.rhythm, state.rhythm),
      _AxisScore(SkillAxis.chord, state.chord),
      _AxisScore(SkillAxis.note, state.note),
    ];
    axes.removeWhere((_AxisScore a) {
      if (a.score >= kWeakAxisThreshold) return true;
      // Must have at least one wrong on this axis to
      // qualify as a "struggle" target.
      return (wrongsByAxis[a.axis] ?? 0) == 0;
    });
    if (axes.isEmpty) return null;
    axes.sort((_AxisScore a, _AxisScore b) => a.score.compareTo(b.score));
    return axes.first.axis;
  }

  /// Maps a [LessonTaskType] to its [SkillAxis] (or `null`
  /// for tasks that have no axis in T057 — tuner / record /
  /// review / unknown).
  SkillAxis? _axisForType(LessonTaskType type) {
    switch (type) {
      case LessonTaskType.rhythm:
        return SkillAxis.rhythm;
      case LessonTaskType.chord:
        return SkillAxis.chord;
      case LessonTaskType.note:
        return SkillAxis.note;
      case LessonTaskType.tuner:
      case LessonTaskType.record:
      case LessonTaskType.review:
      case LessonTaskType.unknown:
        return null;
    }
  }

  double _scoreFor(SkillState state, SkillAxis axis) {
    switch (axis) {
      case SkillAxis.rhythm:
        return state.rhythm;
      case SkillAxis.chord:
        return state.chord;
      case SkillAxis.note:
        return state.note;
    }
  }

  /// Picks the first task in [lesson] whose [LessonTaskType]
  /// matches the [SkillAxis]. Returns `null` when no task
  /// matches (e.g. a note-only lesson when the weak axis is
  /// `chord`).
  LessonTask? _pickTaskForAxis(Lesson lesson, SkillAxis axis) {
    final LessonTaskType targetType = _typeForAxis(axis);
    for (final LessonTask t in lesson.tasks) {
      if (t.type == targetType) return t;
    }
    return null;
  }

  LessonTaskType _typeForAxis(SkillAxis axis) {
    switch (axis) {
      case SkillAxis.rhythm:
        return LessonTaskType.rhythm;
      case SkillAxis.chord:
        return LessonTaskType.chord;
      case SkillAxis.note:
        return LessonTaskType.note;
    }
  }

  /// Default-progression decision: pick the first task whose
  /// last attempt was NOT a `correct`. Falls back to the
  /// first task when every task has been nailed (so the
  /// user always has a `next`).
  ProceedTaskDecision _proceedTaskDecision({
    required Lesson lesson,
    required TaskAttemptHistory history,
  }) {
    final LessonTask? next = _firstUncompletedTask(lesson, history);
    final LessonTask pick = next ?? lesson.tasks.first;
    return _buildProceed(task: pick, lesson: lesson, difficulty: _defaultDifficulty(lesson, history));
  }

  LessonTask? _firstUncompletedTask(
    Lesson lesson,
    TaskAttemptHistory history,
  ) {
    final Map<String, AttemptVerdict> lastVerdict = <String, AttemptVerdict>{};
    for (final TaskAttemptMetric m in history.attempts) {
      lastVerdict[m.taskId] = m.verdict;
    }
    for (final LessonTask t in lesson.tasks) {
      final AttemptVerdict? v = lastVerdict[t.id];
      if (v == null || v != AttemptVerdict.correct) return t;
    }
    return null;
  }

  /// Builds a `ProceedTaskDecision` for [task] with
  /// difficulty-aware parameter scaling. The
  /// `difficulty` is in [0.0, 1.0] and is a *signal* used
  /// to scale tool parameters; the policy's own rules decide
  /// what the signal value should be (default progression
  /// passes 0.5; the consecutive-correct booster passes
  /// 1.0).
  ProceedTaskDecision _buildProceed({
    required LessonTask task,
    required Lesson lesson,
    required double difficulty,
  }) {
    final ToolParams params = _scaleParamsForDifficulty(task, difficulty);
    return ProceedTaskDecision(
      task: task,
      parameters: params,
      difficulty: difficulty,
      reason: _proceedReason(task, difficulty, lesson),
    );
  }

  RepeatTaskDecision _repeatTaskDecision({
    required Lesson lesson,
    required LessonTask task,
    required int recentWrongs,
  }) {
    // Repeat always uses the lowest difficulty tier so the
    // tool params get the full down-shift (BPM - kBpmStep,
    // chord / note lists truncated to 1).
    const double downDifficulty = 0.0;
    final ToolParams params = _scaleParamsForDifficulty(task, downDifficulty);
    return RepeatTaskDecision(
      task: task,
      parameters: params,
      difficulty: downDifficulty,
      recentWrongs: recentWrongs,
      reason: '已错过 $recentWrongs 次，自动降低难度再练一次',
    );
  }

  InjectSkillDecision _injectSkillDecision({
    required Lesson lesson,
    required LessonTask task,
    required SkillAxis weakAxis,
    required double weakScore,
  }) {
    // The inject path always uses the lowest difficulty
    // tier — the whole point is to make the drill easy
    // enough that the user can score a clean `correct` and
    // start moving the axis up.
    const double downDifficulty = 0.0;
    final ToolParams params = _scaleParamsForDifficulty(task, downDifficulty);
    return InjectSkillDecision(
      task: task,
      parameters: params,
      difficulty: downDifficulty,
      weakAxis: weakAxis,
      weakScore: weakScore,
      reason: '${_axisLabel(weakAxis)}较弱（${weakScore.toStringAsFixed(2)}），'
          '先练 ${task.title}',
    );
  }

  /// Returns the difficulty signal for default progression.
  /// The signal is binary in T057 v1:
  /// - 3+ consecutive corrects → "hard" tier (BPM +
  ///   kBpmStep, full chord / note lists).
  /// - otherwise               → "neutral" tier (BPM as
  ///   written, full chord / note lists).
  ///
  /// T058+ can graduate this to a gradient once the AI
  /// scorer feeds per-axis accuracy through metadata.
  double _defaultDifficulty(Lesson lesson, TaskAttemptHistory history) {
    final int cc = history.consecutiveCorrects;
    if (cc >= kEscalateUpThreshold) return 1.0; // hard
    return 0.5; // neutral
  }

  String _proceedReason(LessonTask task, double difficulty, Lesson lesson) {
    if (difficulty >= kDifficultyCeiling - 0.001) {
      return '继续：${task.title}（高难度）';
    }
    if (difficulty <= kDifficultyFloor + 0.05) {
      return '继续：${task.title}（低难度）';
    }
    return '继续：${task.title}';
  }

  String _axisLabel(SkillAxis axis) {
    switch (axis) {
      case SkillAxis.rhythm:
        return '节奏';
      case SkillAxis.chord:
        return '和弦';
      case SkillAxis.note:
        return '单音';
    }
  }

  /// Scales the tool parameters for [task] to the policy's
  /// chosen [difficulty]. The T057 v1 signal is binary:
  /// - difficulty in `[0.0, 0.33)` → "easy" tier (BPM - step,
  ///   chord / note list truncated to 1).
  /// - difficulty in `[0.33, 0.66)` → "neutral" tier (BPM
  ///   as written, full chord / note lists).
  /// - difficulty in `[0.66, 1.0]` → "hard" tier (BPM +
  ///   step, full chord / note lists).
  ///
  /// T058+ can graduate this to a gradient once the AI
  /// scorer feeds per-axis accuracy through metadata.
  ToolParams _scaleParamsForDifficulty(LessonTask task, double difficulty) {
    switch (task.tool) {
      case LessonTool.metronome:
        final int baseBpm = _bpmFromTask(task) ?? kDefaultBpm;
        final int scaled = _scaleBpm(baseBpm, difficulty);
        return MetronomeParams(bpm: scaled);
      case LessonTool.chordLibrary:
        final List<String> baseIds = _chordIdsFromTask(task);
        final List<String> scaled = _scaleList(baseIds, difficulty);
        return ChordParams(chordIds: scaled);
      case LessonTool.singleNote:
        final List<String> baseNotes = _noteNamesFromTask(task);
        final List<String> scaled = _scaleList(baseNotes, difficulty);
        return NoteParams(noteNames: scaled);
      case LessonTool.tuner:
        return const TunerParams();
      case LessonTool.recording:
        return const RecordParams();
      case LessonTool.records:
        return const ReviewParams();
    }
  }

  int? _bpmFromTask(LessonTask task) {
    final RegExp pattern = RegExp(r'(\d{2,3})\s*BPM');
    final RegExpMatch? m = pattern.firstMatch(task.description);
    if (m == null) return null;
    final int? parsed = int.tryParse(m.group(1)!);
    if (parsed == null) return null;
    if (parsed < 20 || parsed > 300) return null;
    return parsed;
  }

  int _scaleBpm(int baseBpm, double difficulty) {
    final int delta;
    if (difficulty < 0.33) {
      delta = -kBpmStep;
    } else if (difficulty >= 0.66) {
      delta = kBpmStep;
    } else {
      delta = 0;
    }
    final int next = baseBpm + delta;
    if (next < 20) return 20;
    if (next > 300) return 300;
    return next;
  }

  List<String> _chordIdsFromTask(LessonTask task) {
    if (task.type != LessonTaskType.chord) return const <String>[];
    if (!task.routePath.startsWith('/chords/')) return const <String>[];
    final String id = task.routePath.substring('/chords/'.length);
    if (id.isEmpty) return const <String>[];
    return <String>[id];
  }

  List<String> _noteNamesFromTask(LessonTask task) {
    if (task.type != LessonTaskType.note) return const <String>[];
    return const <String>[];
  }

  /// Truncates [base] to its first element when [difficulty]
  /// is in the "easy" tier; otherwise returns the list
  /// unchanged. We deliberately do NOT grow the list at the
  /// "hard" tier — the source plan already encodes the full
  /// list (e.g. `/chords/c` already means "C only"; the
  /// gradient matters more for metronome BPM).
  List<String> _scaleList(List<String> base, double difficulty) {
    if (base.isEmpty) return base;
    if (difficulty < 0.33) return <String>[base.first];
    return base;
  }
}

@immutable
class _AxisScore {
  const _AxisScore(this.axis, this.score);
  final SkillAxis axis;
  final double score;
}