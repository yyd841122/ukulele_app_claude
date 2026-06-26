// Unit tests for the T057 Adaptive Policy
// (T057_ADAPTIVE_LEARNING_SYSTEM).
//
// Scope:
// - Rule 1 (error-driven downgrade): 2 consecutive wrongs on
//   the same task produces a RepeatTaskDecision with a
//   scaled-down MetronomeParams.
// - Rule 2 (skill-driven injection): a chord score below the
//   weak threshold on a lesson that contains a chord task
//   produces an InjectSkillDecision targeting the chord.
// - Rule 3 (default progression): a fresh user gets a
//   ProceedTaskDecision on the first uncompleted task; a
//   user with every task nailed gets the first task again.
// - Difficulty scaling: BPM step is kBpmStep at the
//   extremes; chord list shrinks when difficulty is below
//   the threshold.
//
// Together these tests demonstrate the T057 acceptance
// criterion: "same user, different performance → different
// learning path".

import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/features/lesson_engine/application/adaptive_policy.dart';
import 'package:ukulele_app/features/lesson_engine/domain/adaptive_decision.dart';
import 'package:ukulele_app/features/lesson_engine/domain/learning_metrics.dart';
import 'package:ukulele_app/features/lesson_engine/domain/lesson.dart';
import 'package:ukulele_app/features/lesson_engine/domain/lesson_task_type.dart';
import 'package:ukulele_app/features/lesson_engine/domain/lesson_tool.dart';
import 'package:ukulele_app/features/lesson_engine/domain/skill_state.dart';
import 'package:ukulele_app/features/lesson_engine/domain/task_tool_binding.dart';

void main() {
  const AdaptivePolicy policy = AdaptivePolicy();

  const LessonTask tuner = LessonTask(
    id: 'day1_tuner',
    type: LessonTaskType.tuner,
    tool: LessonTool.tuner,
    title: '调音',
    description: '调音 G/C/E/A',
    estimatedMinutes: 5,
    routePath: '/tuner',
  );
  const LessonTask note = LessonTask(
    id: 'day1_single_note',
    type: LessonTaskType.note,
    tool: LessonTool.singleNote,
    title: '单音 C / E 练习',
    description: '练习 C / E 单音',
    estimatedMinutes: 5,
    routePath: '/single-note',
  );
  const LessonTask metronome80 = LessonTask(
    id: 'day1_metronome',
    type: LessonTaskType.rhythm,
    tool: LessonTool.metronome,
    title: '节拍器 80 BPM',
    description: '用节拍器 80 BPM 跟拍',
    estimatedMinutes: 5,
    routePath: '/metronome',
  );
  const Lesson day1 = Lesson(
    id: 'lesson_day_1',
    dayIndex: 1,
    title: '认识琴弦',
    description: '认识琴弦',
    estimatedMinutes: 15,
    tasks: <LessonTask>[tuner, note, metronome80],
  );

  // Day 3 has a chord task so the inject-skill rule can be
  // exercised with a chord weak axis.
  const LessonTask day3chord = LessonTask(
    id: 'day3_chord_c',
    type: LessonTaskType.chord,
    tool: LessonTool.chordLibrary,
    title: '学习 C 和弦',
    description: '在和弦库中查看 C 和弦指法',
    estimatedMinutes: 5,
    routePath: '/chords/c',
  );
  const LessonTask day3Metronome = LessonTask(
    id: 'day3_metronome',
    type: LessonTaskType.rhythm,
    tool: LessonTool.metronome,
    title: '节拍器 80 BPM',
    description: '用节拍器 80 BPM 跟拍 C 和弦分解',
    estimatedMinutes: 4,
    routePath: '/metronome',
  );
  const Lesson day3 = Lesson(
    id: 'lesson_day_3',
    dayIndex: 3,
    title: '第一个和弦',
    description: '第一个和弦',
    estimatedMinutes: 18,
    tasks: <LessonTask>[tuner, day3chord, day3Metronome],
  );

  group('AdaptivePolicy.decide — Rule 1 (error-driven downgrade)', () {
    test('two consecutive wrongs on the same task → RepeatTaskDecision',
        () {
      const SkillState state = SkillState.initial;
      final TaskAttemptHistory history = TaskAttemptHistory.initial
          .append(const TaskAttemptMetric(
            taskId: 'day1_metronome',
            taskType: LessonTaskType.rhythm,
            verdict: AttemptVerdict.wrong,
            elapsedMs: 5000,
          ))
          .append(const TaskAttemptMetric(
            taskId: 'day1_metronome',
            taskType: LessonTaskType.rhythm,
            verdict: AttemptVerdict.wrong,
            elapsedMs: 5000,
          ));
      final AdaptiveDecision d = policy.decide(
        state: state,
        history: history,
        lesson: day1,
        lastTask: metronome80,
      );
      expect(d, isA<RepeatTaskDecision>());
      final RepeatTaskDecision r = d as RepeatTaskDecision;
      expect(r.task.id, 'day1_metronome');
      expect(r.recentWrongs, 2);
      // Down-scaled BPM (80 - 10 = 70).
      expect((r.parameters as MetronomeParams).bpm, 70);
    });

    test('two wrongs on DIFFERENT tasks do NOT trigger a repeat', () {
      const SkillState state = SkillState.initial;
      final TaskAttemptHistory history = TaskAttemptHistory.initial
          .append(const TaskAttemptMetric(
            taskId: 'day1_metronome',
            taskType: LessonTaskType.rhythm,
            verdict: AttemptVerdict.wrong,
            elapsedMs: 5000,
          ))
          .append(const TaskAttemptMetric(
            taskId: 'day1_single_note',
            taskType: LessonTaskType.note,
            verdict: AttemptVerdict.wrong,
            elapsedMs: 5000,
          ));
      final AdaptiveDecision d = policy.decide(
        state: state,
        history: history,
        lesson: day1,
        lastTask: note,
      );
      expect(d, isNot(isA<RepeatTaskDecision>()));
    });
  });

  group('AdaptivePolicy.decide — Rule 2 (skill-driven injection)', () {
    test('low chord score on Day 3 → InjectSkillDecision targeting chord',
        () {
      // The user has tried the chord task twice and got it
      // wrong both times. The tracker would land chord at
      // ~0.20 in production; we hand-craft that low score
      // here to keep the test focused on the policy.
      const SkillState state = SkillState(
        rhythm: 0.9,
        chord: 0.20, // below kWeakAxisThreshold
        note: 0.9,
      );
      // The history must show the user actually attempted
      // a chord task — otherwise the inject rule's "axis
      // must be engaged" gate would prevent it from firing
      // (a fresh user with chord=0 is on schedule, not
      // struggling).
      final TaskAttemptHistory history = TaskAttemptHistory.initial
          .append(const TaskAttemptMetric(
            taskId: 'day3_chord_c',
            taskType: LessonTaskType.chord,
            verdict: AttemptVerdict.wrong,
            elapsedMs: 5000,
          ))
          .append(const TaskAttemptMetric(
            taskId: 'day3_chord_c',
            taskType: LessonTaskType.chord,
            verdict: AttemptVerdict.wrong,
            elapsedMs: 5000,
          ));
      final AdaptiveDecision d = policy.decide(
        state: state,
        history: history,
        lesson: day3,
      );
      expect(d, isA<InjectSkillDecision>());
      final InjectSkillDecision inj = d as InjectSkillDecision;
      expect(inj.weakAxis, SkillAxis.chord);
      expect(inj.task.type, LessonTaskType.chord);
      expect(inj.weakScore, closeTo(0.20, 1e-9));
    });

    test('all axes above threshold → falls through to default progression',
        () {
      const SkillState state = SkillState(
        rhythm: 0.8,
        chord: 0.8,
        note: 0.8,
      );
      // We need at least one history entry to keep the
      // inject rule from being short-circuited by the
      // "no engagement" gate; here the user has nailed the
      // first task.
      final TaskAttemptHistory history = TaskAttemptHistory.initial.append(
        const TaskAttemptMetric(
          taskId: 'day1_tuner',
          taskType: LessonTaskType.tuner,
          verdict: AttemptVerdict.correct,
          elapsedMs: 5000,
        ),
      );
      final AdaptiveDecision d = policy.decide(
        state: state,
        history: history,
        lesson: day1,
      );
      expect(d, isA<ProceedTaskDecision>());
      // The tuner has been completed → the next
      // uncompleted task in declaration order is `note`.
      expect((d as ProceedTaskDecision).task.id, note.id);
    });

    test('weak chord on a lesson with no chord task → falls through',
        () {
      const SkillState state = SkillState(
        rhythm: 0.8,
        chord: 0.1, // below threshold, but day1 has no chord task
        note: 0.8,
      );
      // History shows the user tried chord and failed (so
      // the "engaged" gate passes) — but the lesson has no
      // chord task to inject.
      final TaskAttemptHistory history = TaskAttemptHistory.initial.append(
        const TaskAttemptMetric(
          taskId: 'day3_chord_c',
          taskType: LessonTaskType.chord,
          verdict: AttemptVerdict.wrong,
          elapsedMs: 5000,
        ),
      );
      final AdaptiveDecision d = policy.decide(
        state: state,
        history: history,
        lesson: day1,
      );
      expect(d, isA<ProceedTaskDecision>());
    });

    test('low chord score with NO history does NOT trigger inject', () {
      // A fresh user with state.chord=0.1 (hand-crafted
      // zero-baseline) is NOT "struggling with chord" —
      // they haven't tried it yet. The inject rule should
      // fall through to default progression.
      const SkillState state = SkillState(
        rhythm: 0.0,
        chord: 0.1,
        note: 0.0,
      );
      final AdaptiveDecision d = policy.decide(
        state: state,
        history: TaskAttemptHistory.initial,
        lesson: day3,
      );
      expect(d, isA<ProceedTaskDecision>());
    });
  });

  group('AdaptivePolicy.decide — Rule 3 (default progression)', () {
    test('fresh user → first task', () {
      final AdaptiveDecision d = policy.decide(
        state: SkillState.initial,
        history: TaskAttemptHistory.initial,
        lesson: day1,
      );
      expect(d, isA<ProceedTaskDecision>());
      expect((d as ProceedTaskDecision).task.id, tuner.id);
    });

    test('completed-tuner user → next task (note)', () {
      final TaskAttemptHistory history = TaskAttemptHistory.initial.append(
        const TaskAttemptMetric(
          taskId: 'day1_tuner',
          taskType: LessonTaskType.tuner,
          verdict: AttemptVerdict.correct,
          elapsedMs: 5000,
        ),
      );
      final AdaptiveDecision d = policy.decide(
        state: SkillState.initial,
        history: history,
        lesson: day1,
      );
      expect(d, isA<ProceedTaskDecision>());
      expect((d as ProceedTaskDecision).task.id, note.id);
    });

    test('user who nailed every task → first task again', () {
      TaskAttemptHistory history = TaskAttemptHistory.initial;
      for (final LessonTask t in day1.tasks) {
        history = history.append(TaskAttemptMetric(
          taskId: t.id,
          taskType: t.type,
          verdict: AttemptVerdict.correct,
          elapsedMs: 5000,
        ));
      }
      final AdaptiveDecision d = policy.decide(
        state: SkillState.initial,
        history: history,
        lesson: day1,
      );
      expect(d, isA<ProceedTaskDecision>());
      expect((d as ProceedTaskDecision).task.id, tuner.id);
    });
  });

  group('AdaptivePolicy.decide — acceptance criterion', () {
    test('same lesson, different performance → different next task', () {
      // User A: clean record on the tuner, fresh on the rest.
      final TaskAttemptHistory historyA = TaskAttemptHistory.initial.append(
        const TaskAttemptMetric(
          taskId: 'day1_tuner',
          taskType: LessonTaskType.tuner,
          verdict: AttemptVerdict.correct,
          elapsedMs: 5000,
        ),
      );
      // User B: two wrongs on the metronome right at the
      // start of the day.
      final TaskAttemptHistory historyB = TaskAttemptHistory.initial
          .append(const TaskAttemptMetric(
            taskId: 'day1_metronome',
            taskType: LessonTaskType.rhythm,
            verdict: AttemptVerdict.wrong,
            elapsedMs: 5000,
          ))
          .append(const TaskAttemptMetric(
            taskId: 'day1_metronome',
            taskType: LessonTaskType.rhythm,
            verdict: AttemptVerdict.wrong,
            elapsedMs: 5000,
          ));
      final AdaptiveDecision a = policy.decide(
        state: SkillState.initial,
        history: historyA,
        lesson: day1,
      );
      final AdaptiveDecision b = policy.decide(
        state: SkillState.initial,
        history: historyB,
        lesson: day1,
        lastTask: metronome80,
      );
      expect(a, isA<ProceedTaskDecision>());
      expect(b, isA<RepeatTaskDecision>());
      expect((a as ProceedTaskDecision).task.id, note.id);
      expect((b as RepeatTaskDecision).task.id, metronome80.id);
      // The two decisions must not be equal.
      expect(a, isNot(equals(b)));
    });
  });

  group('Difficulty scaling', () {
    test('BPM scales down by kBpmStep on repeat', () {
      const SkillState state = SkillState.initial;
      final TaskAttemptHistory history = TaskAttemptHistory.initial
          .append(const TaskAttemptMetric(
            taskId: 'day1_metronome',
            taskType: LessonTaskType.rhythm,
            verdict: AttemptVerdict.wrong,
            elapsedMs: 5000,
          ))
          .append(const TaskAttemptMetric(
            taskId: 'day1_metronome',
            taskType: LessonTaskType.rhythm,
            verdict: AttemptVerdict.wrong,
            elapsedMs: 5000,
          ));
      final AdaptiveDecision d = policy.decide(
        state: state,
        history: history,
        lesson: day1,
        lastTask: metronome80,
      );
      expect(d, isA<RepeatTaskDecision>());
      expect((d as RepeatTaskDecision).parameters, isA<MetronomeParams>());
      expect((d.parameters as MetronomeParams).bpm, 70);
    });

    test('BPM scales up after 3 consecutive corrects (direct check)', () {
      // A user with 3 consecutive correct verdicts in
      // their trailing history should see a
      // ProceedTaskDecision whose metronome BPM is
      // boosted from the lesson's default 80 → 90.
      //
      // We construct a minimal lesson with a SINGLE
      // metronome task so the default-progression rule
      // picks it up (the policy does not skip a task
      // whose last verdict is correct when the user has
      // already cycled back to it once; here we just
      // hand-craft the situation where the policy sees
      // the metronome as the next task).
      const LessonTask met = LessonTask(
        id: 'm',
        type: LessonTaskType.rhythm,
        tool: LessonTool.metronome,
        title: '节拍器 80 BPM',
        description: '用节拍器 80 BPM 跟拍',
        estimatedMinutes: 5,
        routePath: '/metronome',
      );
      const Lesson single = Lesson(
        id: 'l',
        dayIndex: 1,
        title: 'x',
        description: 'x',
        estimatedMinutes: 5,
        tasks: <LessonTask>[met],
      );
      TaskAttemptHistory history = TaskAttemptHistory.initial;
      for (int i = 0; i < 3; i++) {
        history = history.append(const TaskAttemptMetric(
          taskId: 'm',
          taskType: LessonTaskType.rhythm,
          verdict: AttemptVerdict.correct,
          elapsedMs: 5000,
        ));
      }
      // Rhythm axis is high enough to not trigger inject;
      // the difficulty signal is what we are testing.
      const SkillState state = SkillState(
        rhythm: 0.50,
        chord: 0.50,
        note: 0.50,
      );
      final AdaptiveDecision d = policy.decide(
        state: state,
        history: history,
        lesson: single,
      );
      expect(d, isA<ProceedTaskDecision>());
      // 3 consecutive corrects → hard tier → BPM 80 + 10.
      expect((d as ProceedTaskDecision).parameters, isA<MetronomeParams>());
      expect((d.parameters as MetronomeParams).bpm, 90);
    });
  });
}