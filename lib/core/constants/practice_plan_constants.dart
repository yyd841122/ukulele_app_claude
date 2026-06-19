// 7-day practice plan constants.
//
// T007 scope:
// - 7-day built-in practice plan (Day 1-7) lives in code, NOT in the database.
// - This is per PRD §9 / DATA_MODEL_DRAFT.md §3.1: the plan is intended to be
//   easy to adjust in code without a schema migration.
// - Each day is broken into multiple [PracticeTask] entries with explicit
//   id / title / description / estimatedMinutes / routePath / iconName.
//
// IMPORTANT: This file is referenced by [TodayPracticeController]. It must
// not import anything from the `features/home` layer (constants live in
// `core/`, domain types live in `features/home/domain/`).

import 'package:ukulele_app/features/home/domain/built_in_practice_plan.dart';
import 'package:ukulele_app/features/home/domain/practice_task.dart';
import 'package:ukulele_app/features/home/domain/practice_task_icon.dart';
import 'package:ukulele_app/features/home/domain/practice_task_status.dart';

/// The 7-day practice plan, indexed by [BuiltInPracticePlan.dayIndex]
/// (1-based, 1-7).
///
/// The order in this list is significant: index 0 corresponds to Day 1.
const List<BuiltInPracticePlan> kBuiltInPracticePlan = <BuiltInPracticePlan>[
  // ---- Day 1: 认识琴弦 ----
  BuiltInPracticePlan(
    dayIndex: 1,
    title: '认识琴弦',
    estimatedMinutes: 15,
    tasks: <PracticeTask>[
      PracticeTask(
        id: 'day1_tuner',
        title: '调音 G / C / E / A',
        description: '逐弦手动调音，确保 G/C/E/A 四根弦音准。',
        estimatedMinutes: 5,
        routePath: '/tuner',
        iconName: PracticeTaskIcon.tuner,
        status: PracticeTaskStatus.todo,
      ),
      PracticeTask(
        id: 'day1_single_note',
        title: '单音 C / E 练习',
        description: '练习按出 C 弦与 E 弦的基础单音。',
        estimatedMinutes: 5,
        routePath: '/single-note',
        iconName: PracticeTaskIcon.singleNote,
        status: PracticeTaskStatus.todo,
      ),
      PracticeTask(
        id: 'day1_metronome',
        title: '节拍器 80 BPM 跟拍',
        description: '用节拍器 80 BPM 跟拍单音练习。',
        estimatedMinutes: 5,
        routePath: '/metronome',
        iconName: PracticeTaskIcon.metronome,
        status: PracticeTaskStatus.todo,
      ),
    ],
  ),

  // ---- Day 2: 单音进阶 ----
  BuiltInPracticePlan(
    dayIndex: 2,
    title: '单音进阶',
    estimatedMinutes: 15,
    tasks: <PracticeTask>[
      PracticeTask(
        id: 'day2_tuner',
        title: '调音 G / C / E / A',
        description: '逐弦手动调音，确保四根弦音准。',
        estimatedMinutes: 5,
        routePath: '/tuner',
        iconName: PracticeTaskIcon.tuner,
        status: PracticeTaskStatus.todo,
      ),
      PracticeTask(
        id: 'day2_single_note',
        title: '单音 C / D / E / F / G 练习',
        description: '练习 C / D / E / F / G 五个基础单音的按弦。',
        estimatedMinutes: 5,
        routePath: '/single-note',
        iconName: PracticeTaskIcon.singleNote,
        status: PracticeTaskStatus.todo,
      ),
      PracticeTask(
        id: 'day2_metronome',
        title: '节拍器 80 BPM',
        description: '用节拍器 80 BPM 跟拍单音练习。',
        estimatedMinutes: 5,
        routePath: '/metronome',
        iconName: PracticeTaskIcon.metronome,
        status: PracticeTaskStatus.todo,
      ),
    ],
  ),

  // ---- Day 3: 第一个和弦 ----
  BuiltInPracticePlan(
    dayIndex: 3,
    title: '第一个和弦',
    estimatedMinutes: 18,
    tasks: <PracticeTask>[
      PracticeTask(
        id: 'day3_tuner',
        title: '调音 G / C / E / A',
        description: '逐弦手动调音。',
        estimatedMinutes: 3,
        routePath: '/tuner',
        iconName: PracticeTaskIcon.tuner,
        status: PracticeTaskStatus.todo,
      ),
      PracticeTask(
        id: 'day3_chord_c',
        title: '学习 C 和弦',
        description: '在和弦库中查看 C 和弦的指法并练习按出。',
        estimatedMinutes: 5,
        routePath: '/chords/c',
        iconName: PracticeTaskIcon.chord,
        status: PracticeTaskStatus.todo,
      ),
      PracticeTask(
        id: 'day3_metronome',
        title: '节拍器 80 BPM',
        description: '用节拍器 80 BPM 跟拍 C 和弦分解。',
        estimatedMinutes: 4,
        routePath: '/metronome',
        iconName: PracticeTaskIcon.metronome,
        status: PracticeTaskStatus.todo,
      ),
      PracticeTask(
        id: 'day3_recording',
        title: '录音 1 段',
        description: '录下一段 C 和弦的练习回放。',
        estimatedMinutes: 4,
        routePath: '/recording',
        iconName: PracticeTaskIcon.recording,
        status: PracticeTaskStatus.todo,
      ),
      PracticeTask(
        id: 'day3_self_assessment',
        title: '回放并自评',
        description: '回放录音并给出"好 / 一般 / 需改进"自评。',
        estimatedMinutes: 2,
        routePath: '/records',
        iconName: PracticeTaskIcon.selfAssessment,
        status: PracticeTaskStatus.todo,
      ),
    ],
  ),

  // ---- Day 4: 和弦转换 ----
  BuiltInPracticePlan(
    dayIndex: 4,
    title: '和弦转换',
    estimatedMinutes: 18,
    tasks: <PracticeTask>[
      PracticeTask(
        id: 'day4_tuner',
        title: '调音 G / C / E / A',
        description: '逐弦手动调音。',
        estimatedMinutes: 3,
        routePath: '/tuner',
        iconName: PracticeTaskIcon.tuner,
        status: PracticeTaskStatus.todo,
      ),
      PracticeTask(
        id: 'day4_chord_switch',
        title: 'C ↔ Am 转换',
        description: '练习在 C 和弦与 Am 和弦之间反复切换。',
        estimatedMinutes: 5,
        routePath: '/chords/c',
        iconName: PracticeTaskIcon.chord,
        status: PracticeTaskStatus.todo,
      ),
      PracticeTask(
        id: 'day4_metronome',
        title: '节拍器 80 BPM',
        description: '用节拍器 80 BPM 跟拍和弦转换。',
        estimatedMinutes: 4,
        routePath: '/metronome',
        iconName: PracticeTaskIcon.metronome,
        status: PracticeTaskStatus.todo,
      ),
      PracticeTask(
        id: 'day4_recording',
        title: '录音 1 段',
        description: '录下一段和弦转换的练习。',
        estimatedMinutes: 4,
        routePath: '/recording',
        iconName: PracticeTaskIcon.recording,
        status: PracticeTaskStatus.todo,
      ),
      PracticeTask(
        id: 'day4_self_assessment',
        title: '回放并自评',
        description: '回放录音并给出"好 / 一般 / 需改进"自评。',
        estimatedMinutes: 2,
        routePath: '/records',
        iconName: PracticeTaskIcon.selfAssessment,
        status: PracticeTaskStatus.todo,
      ),
    ],
  ),

  // ---- Day 5: 更多和弦 ----
  BuiltInPracticePlan(
    dayIndex: 5,
    title: '更多和弦',
    estimatedMinutes: 20,
    tasks: <PracticeTask>[
      PracticeTask(
        id: 'day5_tuner',
        title: '调音 G / C / E / A',
        description: '逐弦手动调音。',
        estimatedMinutes: 3,
        routePath: '/tuner',
        iconName: PracticeTaskIcon.tuner,
        status: PracticeTaskStatus.todo,
      ),
      PracticeTask(
        id: 'day5_chord_f',
        title: 'F 和弦指法',
        description: '学习 F 和弦的指法并练习按出。',
        estimatedMinutes: 4,
        routePath: '/chords/f',
        iconName: PracticeTaskIcon.chord,
        status: PracticeTaskStatus.todo,
      ),
      PracticeTask(
        id: 'day5_chord_g',
        title: 'G 和弦指法',
        description: '学习 G 和弦的指法并练习按出。',
        estimatedMinutes: 4,
        routePath: '/chords/g',
        iconName: PracticeTaskIcon.chord,
        status: PracticeTaskStatus.todo,
      ),
      PracticeTask(
        id: 'day5_metronome',
        title: '节拍器 90 BPM',
        description: '用节拍器 90 BPM 跟拍和弦切换。',
        estimatedMinutes: 4,
        routePath: '/metronome',
        iconName: PracticeTaskIcon.metronome,
        status: PracticeTaskStatus.todo,
      ),
      PracticeTask(
        id: 'day5_recording',
        title: '录音 1 段',
        description: '录下一段 F / G 和弦的练习。',
        estimatedMinutes: 3,
        routePath: '/recording',
        iconName: PracticeTaskIcon.recording,
        status: PracticeTaskStatus.todo,
      ),
      PracticeTask(
        id: 'day5_self_assessment',
        title: '回放并自评',
        description: '回放录音并给出"好 / 一般 / 需改进"自评。',
        estimatedMinutes: 2,
        routePath: '/records',
        iconName: PracticeTaskIcon.selfAssessment,
        status: PracticeTaskStatus.todo,
      ),
    ],
  ),

  // ---- Day 6: 综合练习 ----
  BuiltInPracticePlan(
    dayIndex: 6,
    title: '综合练习',
    estimatedMinutes: 20,
    tasks: <PracticeTask>[
      PracticeTask(
        id: 'day6_tuner',
        title: '调音 G / C / E / A',
        description: '逐弦手动调音。',
        estimatedMinutes: 3,
        routePath: '/tuner',
        iconName: PracticeTaskIcon.tuner,
        status: PracticeTaskStatus.todo,
      ),
      PracticeTask(
        id: 'day6_chord_progression',
        title: 'C - Am - F - G 循环',
        description: '练习 C / Am / F / G 四个和弦的循环切换。',
        estimatedMinutes: 5,
        routePath: '/chords/c',
        iconName: PracticeTaskIcon.chord,
        status: PracticeTaskStatus.todo,
      ),
      PracticeTask(
        id: 'day6_metronome',
        title: '节拍器 100 BPM',
        description: '用节拍器 100 BPM 跟拍循环进行。',
        estimatedMinutes: 4,
        routePath: '/metronome',
        iconName: PracticeTaskIcon.metronome,
        status: PracticeTaskStatus.todo,
      ),
      PracticeTask(
        id: 'day6_recording',
        title: '录音 1 段',
        description: '录下一段 C-Am-F-G 循环的练习。',
        estimatedMinutes: 5,
        routePath: '/recording',
        iconName: PracticeTaskIcon.recording,
        status: PracticeTaskStatus.todo,
      ),
      PracticeTask(
        id: 'day6_self_assessment',
        title: '回放并自评',
        description: '回放录音并给出"好 / 一般 / 需改进"自评。',
        estimatedMinutes: 3,
        routePath: '/records',
        iconName: PracticeTaskIcon.selfAssessment,
        status: PracticeTaskStatus.todo,
      ),
    ],
  ),

  // ---- Day 7: 复习巩固 ----
  BuiltInPracticePlan(
    dayIndex: 7,
    title: '复习巩固',
    estimatedMinutes: 20,
    tasks: <PracticeTask>[
      PracticeTask(
        id: 'day7_tuner',
        title: '调音 G / C / E / A',
        description: '逐弦手动调音。',
        estimatedMinutes: 3,
        routePath: '/tuner',
        iconName: PracticeTaskIcon.tuner,
        status: PracticeTaskStatus.todo,
      ),
      PracticeTask(
        id: 'day7_free_practice',
        title: '任选和弦 / 单音组合',
        description: '在和弦库中任选 1-2 个和弦 + 单音组合自由练习。',
        estimatedMinutes: 6,
        routePath: '/chords',
        iconName: PracticeTaskIcon.chord,
        status: PracticeTaskStatus.todo,
      ),
      PracticeTask(
        id: 'day7_metronome',
        title: '节拍器 90 BPM',
        description: '用节拍器 90 BPM 跟拍自由练习。',
        estimatedMinutes: 4,
        routePath: '/metronome',
        iconName: PracticeTaskIcon.metronome,
        status: PracticeTaskStatus.todo,
      ),
      PracticeTask(
        id: 'day7_recording',
        title: '录音 1 段',
        description: '录下一段自由组合的练习。',
        estimatedMinutes: 5,
        routePath: '/recording',
        iconName: PracticeTaskIcon.recording,
        status: PracticeTaskStatus.todo,
      ),
      PracticeTask(
        id: 'day7_self_assessment',
        title: '回放并自评',
        description: '回放录音并给出"好 / 一般 / 需改进"自评。',
        estimatedMinutes: 2,
        routePath: '/records',
        iconName: PracticeTaskIcon.selfAssessment,
        status: PracticeTaskStatus.todo,
      ),
    ],
  ),
];
