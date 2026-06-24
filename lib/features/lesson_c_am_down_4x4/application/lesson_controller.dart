// Riverpod providers for the beginner learning phase 2 lessons.
//
// T044 scope:
// - Pure-Dart lookup against the `kBuiltInLessons` constant list.
//   No I/O, no async, no mutability, no DB. The provider is shaped
//   like `chordByIdProvider` (T008) so the LessonPage can render a
//   friendly not-found placeholder for unknown ids without try/catch
//   noise at the widget boundary.
// - Lessons are code-resident constants per T041 §4.2; the
//   `lessonByIdProvider` family is the only seam between data and
//   UI. Tests override it to swap the data source.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/core/constants/lesson_constants.dart';

/// Provider exposing the full built-in lesson list.
///
/// Mirrors `chordLibraryProvider` (T008) — the same `List` instance
/// stored in `lesson_constants.dart` is exposed so equality checks
/// stay cheap and consumers see the canonical list.
final lessonLibraryProvider =
    Provider<List<Lesson>>((Ref ref) => kBuiltInLessons);

/// Family provider that resolves a single [Lesson] by id.
///
/// Returns `null` for empty or unknown ids — the page treats this
/// as a "not found" case and renders a friendly placeholder.
final lessonByIdProvider =
    Provider.family<Lesson?, String>((Ref ref, String id) {
  if (id.isEmpty) {
    return null;
  }
  for (final Lesson lesson in kBuiltInLessons) {
    if (lesson.id == id) {
      return lesson;
    }
  }
  return null;
});
