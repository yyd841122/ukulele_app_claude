// Lesson Engine — Adaptive Decision (T057_ADAPTIVE_LEARNING_SYSTEM).
//
// What this file is:
// - The OUTPUT value type the adaptive policy returns. The
//   decision tells the caller: "given the current skill model
//   and history, you should drive this task, with these
//   parameters, and here is the reasoning that got us here".
//
// Why a sealed family instead of one big struct:
// - T057 has three distinct "shapes" the policy can emit:
//   1. `ProceedTaskDecision` — go do a specific task with
//      specific tool parameters (the normal happy path).
//   2. `RepeatTaskDecision` — repeat the SAME task again with
//      tweaked (easier) parameters (error-driven downgrade).
//   3. `InjectSkillDecision` — inject a *different* task
//      aimed at the user's weak axis (skill-routing).
//   Sealing the family means downstream pattern matches
//   exhaustively — adding a new decision shape without
//   handling it in the consumer is a compile error.
//
// Each decision carries a `reason` string so the home UI can
// surface WHY the system chose this task ("你最近和弦较弱 →
// 注入 C 和弦单音练习") without re-running the policy.

import 'package:flutter/foundation.dart';

import 'package:ukulele_app/features/lesson_engine/domain/lesson.dart';
import 'package:ukulele_app/features/lesson_engine/domain/task_tool_binding.dart';

/// The T057 policy's output envelope.
///
/// T057 contract:
/// - Exactly one subtype is returned per call. The policy
///   is NOT allowed to return "no decision" — even an empty
///   lesson is answered with a `ProceedTaskDecision` whose
///   task is the first one in the plan.
@immutable
sealed class AdaptiveDecision {
  const AdaptiveDecision({required this.reason});

  /// Human-readable explanation of WHY this decision was
  /// made. The home UI can surface it in a small line under
  /// the task card. Not localised in T057 (matches the
  /// T055/T056 telemetry convention of "engine strings are
  /// not user-facing"); T058+ can layer a lookup on top.
  final String reason;
}

/// "Go do this exact task, with these exact tool parameters."
///
/// This is the policy's NORMAL output. The presenter should
/// push the user to [task] (which already carries a
/// `routePath`) and feed [parameters] to the tool executor.
@immutable
class ProceedTaskDecision extends AdaptiveDecision {
  const ProceedTaskDecision({
    required this.task,
    required this.parameters,
    required this.difficulty,
    super.reason = '',
  });

  /// The next task the user should do. Always a member of
  /// today's `Lesson.tasks`.
  final LessonTask task;

  /// The tool parameters the executor should hand the tool.
  /// The policy MAY override the resolver's defaults to
  /// scale BPM / chord / note targets based on the user's
  /// current skill level.
  final ToolParams parameters;

  /// The policy-chosen difficulty (a normalised 0.0..1.0
  /// signal). The presenter can use this to drive a UI
  /// indicator ("Easy" / "Medium" / "Hard") without
  /// re-computing it. The policy DOES NOT use this field
  /// internally — it is a derived output for telemetry.
  final double difficulty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProceedTaskDecision &&
          other.task == task &&
          other.parameters == parameters &&
          other.difficulty == difficulty &&
          other.reason == reason);

  @override
  int get hashCode => Object.hash(task, parameters, difficulty, reason);
}

/// "Repeat the same task again, but with easier parameters."
///
/// The policy emits this when the user has just produced
/// [AdaptivePolicy.kEscalateDownThreshold] or more consecutive
/// wrongs on the candidate task. The presenter should push
/// the SAME [task] (so the user re-engages the same surface)
/// but with the easier [parameters].
@immutable
class RepeatTaskDecision extends AdaptiveDecision {
  const RepeatTaskDecision({
    required this.task,
    required this.parameters,
    required this.difficulty,
    required this.recentWrongs,
    super.reason = '',
  }) : assert(recentWrongs >= 0,
            'RepeatTaskDecision.recentWrongs must be >= 0');

  /// The task to repeat. Always equal to the task the user
  /// just failed on (the policy finds it from the history).
  final LessonTask task;

  /// Easier tool parameters. The policy scales BPM / chord
  /// count / note count DOWN relative to the default.
  final ToolParams parameters;

  /// The down-scaled difficulty level (always <= the
  /// pre-escalation level).
  final double difficulty;

  /// The number of trailing wrong attempts that triggered
  /// the repeat. Surfaced for the UI ("已错过 2 次 → 降级
  /// 重练") and for the regression test.
  final int recentWrongs;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RepeatTaskDecision &&
          other.task == task &&
          other.parameters == parameters &&
          other.difficulty == difficulty &&
          other.recentWrongs == recentWrongs &&
          other.reason == reason);

  @override
  int get hashCode =>
      Object.hash(task, parameters, difficulty, recentWrongs, reason);
}

/// "Inject a different task to drill a weak skill axis."
///
/// The policy emits this when the user's per-axis skill
/// score has fallen below the threshold for one of the
/// three axes (rhythm / chord / note). The injected task is
/// a task from the same lesson that targets the weak axis.
@immutable
class InjectSkillDecision extends AdaptiveDecision {
  const InjectSkillDecision({
    required this.task,
    required this.parameters,
    required this.difficulty,
    required this.weakAxis,
    required this.weakScore,
    super.reason = '',
  })  : assert(weakScore >= 0.0 && weakScore <= 1.0,
            'InjectSkillDecision.weakScore must be in 0.0..1.0');

  /// The injected task. Picked from the same lesson so the
  /// user does not jump to a different day's content.
  final LessonTask task;

  /// Tool parameters tuned to the weak axis.
  final ToolParams parameters;

  /// The policy-chosen difficulty for the injected task.
  final double difficulty;

  /// The axis the policy is trying to drill. Drives the
  /// `reason` copy and the UI badge.
  final SkillAxis weakAxis;

  /// The user's current score on the weak axis. Surfaced
  /// for the UI ("和弦熟练度 0.18 → 注入 C 和弦单音练习").
  final double weakScore;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InjectSkillDecision &&
          other.task == task &&
          other.parameters == parameters &&
          other.difficulty == difficulty &&
          other.weakAxis == weakAxis &&
          other.weakScore == weakScore &&
          other.reason == reason);

  @override
  int get hashCode => Object.hash(
        task,
        parameters,
        difficulty,
        weakAxis,
        weakScore,
        reason,
      );
}

/// The three skill axes the policy reasons about.
///
/// T057 surface:
/// - Mirrors the three axes of [SkillState]. The enum is
///   kept tiny so the policy can switch on it exhaustively
///   without a default arm.
enum SkillAxis { rhythm, chord, note }
