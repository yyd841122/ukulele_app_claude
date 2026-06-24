// Lesson detail page — the first beginner teaching page (T044).
//
// T044 scope:
// - Resolves `lessonId` from the route (path param). Empty /
//   unknown ids render a friendly not-found state identical in
//   shape to `ChordDetailPage` (icon + Chinese copy + a single
//   "返回首页" `FilledButton`).
// - Renders four blocks inside a `ListView`:
//     1) Title + description (wrapped in `Semantics(header: true)`
//        so a screen reader announces the lesson header as a group
//        and not as separate child nodes).
//     2) `CAmDownStrumPatternDiagram` driven by `lesson.strumPattern`
//        — the widget itself is data-driven (T044 §Q1 fix).
//     3) A small "C 和弦 / Am 和弦" reference section that pulls the
//        existing `ChordDiagram` for each chord (no new finger
//        diagram code; we re-use the chord library's own widget).
//     4) A step list — one `_LessonStepTile` per `LessonStep`,
//        each with a navigation button (metronome for BPM steps,
//        recording for the record/review step). The buttons push
//        the existing routes (`/metronome`, `/recording`) and do
//        NOT touch any controller, repository, or `MetronomeSetting`.
// - T044 deliberately does NOT add a completion checkbox, progress
//   persistence, or any "mark lesson done" state. The chord task
//   `day4_chord_switch` is still the completion surface; the
//   lesson is an optional teaching overlay (T041 §7 R-04).
// - Layout uses `Wrap` for the step-card button area so a 280 px
//   narrow screen never overflows (T044 risk 7 in self-review).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ukulele_app/core/constants/lesson_constants.dart';
import 'package:ukulele_app/features/chord_library/application/chord_library_controller.dart';
import 'package:ukulele_app/features/chord_library/domain/chord.dart';
import 'package:ukulele_app/features/chord_library/presentation/widgets/chord_diagram.dart';
import 'package:ukulele_app/features/lesson_c_am_down_4x4/application/lesson_controller.dart';
import 'package:ukulele_app/features/lesson_c_am_down_4x4/presentation/widgets/strum_pattern_diagram.dart';

/// Page shown for `/lessons/:lessonId`.
///
/// Route layer passes the raw `lessonId` path param; this widget
/// owns the empty / unknown / unknown-id → not-found state. No
/// state is stored in this widget — every render reads from the
/// `lessonByIdProvider` family.
class LessonPage extends ConsumerWidget {
  const LessonPage({super.key, required this.lessonId});

  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Lesson? lesson = ref.watch(lessonByIdProvider(lessonId));
    if (lesson == null) {
      return _LessonNotFound(lessonId: lessonId);
    }
    return _LessonDataView(lesson: lesson);
  }
}

/// Friendly placeholder shown for empty / unknown lesson ids.
/// Mirrors the shape of `ChordDetailPage` not-found state for
/// visual consistency.
class _LessonNotFound extends StatelessWidget {
  const _LessonNotFound({required this.lessonId});

  final String lessonId;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('课程详情'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text(
                '未找到 “$lessonId” 课程',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '请返回首页查看可用的课程列表。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('返回首页'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonDataView extends StatelessWidget {
  const _LessonDataView({required this.lesson});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(lesson.title),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            // 1) Header — lesson title + description.
            Semantics(
              header: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    lesson.title,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lesson.description,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2) Strum pattern diagram — data-driven, no hardcoded
            //    rhythm in the widget itself (T044 §Q1 fix).
            Center(
              child: CAmDownStrumPatternDiagram(
                strumPattern: lesson.strumPattern,
                width: 320,
              ),
            ),
            const SizedBox(height: 24),

            // 3) Reference chord diagrams for C / Am — the chords
            //    the lesson teaches. Pulls from the existing chord
            //    library so we don't ship a second copy of the
            //    finger positions.
            _SectionTitle(theme: theme, text: '本课和弦'),
            const SizedBox(height: 8),
            _LessonChordRow(),
            const SizedBox(height: 24),

            // 4) Step list — one tile per LessonStep, each with a
            //    navigation button. The list reads the lesson in
            //    declaration order; the lesson module is responsible
            //    for ordering.
            _SectionTitle(theme: theme, text: '分步骤练习'),
            const SizedBox(height: 8),
            for (int i = 0; i < lesson.steps.length; i++) ...<Widget>[
              _LessonStepTile(
                step: lesson.steps[i],
                stepNumber: i + 1,
              ),
              if (i < lesson.steps.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

/// Reference row showing the C and Am chord diagrams. The C ↔ Am
/// pattern names two chords by their symbols; we surface their
/// finger positions so the user can re-check the hand shape while
/// reading the rhythm.
class _LessonChordRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.spaceEvenly,
      children: <Widget>[
        for (final String chordId in const <String>['c', 'am'])
          _LessonChordTile(chordId: chordId),
      ],
    );
  }
}

class _LessonChordTile extends ConsumerWidget {
  const _LessonChordTile({required this.chordId});

  final String chordId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Chord? chord = ref.watch(chordByIdProvider(chordId));
    final ThemeData theme = Theme.of(context);
    // If a future lesson adds a chord that has not been shipped in
    // the chord library, we still render the tile but with a
    // graceful fallback text — never crash.
    final String label = chord?.displayName ?? chordId.toUpperCase();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (chord != null)
          ChordDiagram(fingering: chord.primaryVoicing, width: 160)
        else
          SizedBox(
            width: 160,
            height: 176,
            child: Center(
              child: Text(
                '未找到 $chordId',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Text(label, style: theme.textTheme.titleSmall),
      ],
    );
  }
}

class _LessonStepTile extends StatelessWidget {
  const _LessonStepTile({required this.step, required this.stepNumber});

  final LessonStep step;
  final int stepNumber;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool hasBpm = step.bpm != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // The step number is purely decorative — ExcludeSemantics
            // keeps the screen reader from announcing it as a
            // separate node on top of the instruction text (T044
            // self-review risk 6).
            ExcludeSemantics(
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      '$stepNumber',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Step $stepNumber',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(step.instruction, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            // Wrap (not Row) so the button can drop to a new line
            // on a 280 px narrow screen (T044 self-review risk 7).
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (hasBpm)
                  OutlinedButton.icon(
                    onPressed: () => context.push('/metronome'),
                    icon: const Icon(Icons.timer_outlined),
                    label: Text('调整到 ${step.bpm} BPM 后开始'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => context.push('/recording'),
                    icon: const Icon(Icons.mic_none),
                    label: const Text('录音复盘'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.theme, required this.text});

  final ThemeData theme;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
