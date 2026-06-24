// Entry-point card for the first beginner lesson.
//
// T044 scope:
// - Single entry point from the Day 4 C ↔ Am chord-detail page
//   (T042 §11.3 "入口数量：只此 1 个"). The card is hard-coded to
//   the lesson id `c_am_down_4x4` so multiple instances of the
//   chord detail (C / Am / F / G) cannot accidentally show a
//   lesson entry that does not exist for them.
// - The card is intentionally simple: no Riverpod, no I/O. It
//   pushes `/lessons/c_am_down_4x4` via go_router and lets the
//   page layer own all rendering. Tests verify the card renders
//   the lesson title and subtitle, and that tapping the action
//   triggers a push (the route spy catches it).
// - The Semantics label wraps the whole card so a screen reader
//   announces it as a single navigable node, and the button has
//   its own button semantics from the [FilledButton.icon] widget.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ukulele_app/core/constants/lesson_constants.dart';

/// Single entry point to the C ↔ Am 4/4 down-strum lesson.
///
/// The [lessonId] defaults to the shipped `kBuiltInLessons.first.id`
/// and is the only id the card pushes for. Callers should not pass
/// a different id — the chord detail page only embeds this card
/// for the C chord (Day 4 `day4_chord_switch` routePath), which
/// matches `linkedTaskIds = ['day4_chord_switch']` in the lesson
/// constant.
class LessonIntroCard extends StatelessWidget {
  const LessonIntroCard({
    super.key,
    this.lessonId = _kDefaultLessonId,
  });

  static const String _kDefaultLessonId = 'c_am_down_4x4';

  /// Lesson id pushed when the action button is tapped. The widget
  /// does NOT validate this against `kBuiltInLessons`; the
  /// `/lessons/:lessonId` page renders a friendly not-found state
  /// for unknown ids (same pattern as `ChordDetailPage`).
  final String lessonId;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Lesson? lesson = _findLesson(lessonId);
    // The card only ships with a shipped id, but if a future lesson
    // id is ever passed that has not been added to kBuiltInLessons
    // yet, we still render a sensible default copy so the entry
    // point never crashes.
    final String title = lesson?.title ?? '本节课程';
    final String subtitle = lesson?.description ?? '进入课程页面查看分步骤练习。';
    return Semantics(
      container: true,
      label: '$title · 本节可选 · 点击开始课程',
      child: Card(
        // Use a filled card with the primary container so the entry
        // point is visually distinct from the chord description
        // below it (T041 §7 R-01 mitigation: clearly mark this as
        // an optional teaching entry, not part of the chord task).
        color: theme.colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.school_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '教学课程',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  // Push (not go) so the user can navigate back to
                  // the chord detail page with the system back
                  // button — matches the existing "navigate
                  // deeper" pattern used by chord library
                  // (chord_library_page → chord_detail_page).
                  onPressed: () => context.push('/lessons/$lessonId'),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('开始课程'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Local linear lookup. The list has at most a handful of
  /// entries (T043 ships one; the design plan allows up to ~5),
  /// so an O(n) scan on every rebuild is cheap and avoids
  /// pulling a separate map into the constant module.
  static Lesson? _findLesson(String id) {
    for (final Lesson lesson in kBuiltInLessons) {
      if (lesson.id == id) {
        return lesson;
      }
    }
    return null;
  }
}
