// Riverpod controller for the single-note practice page.
//
// T009 scope:
// - Hand-written [Notifier] (no `@riverpod` codegen) per the
//   project's convention (T007, T008).
// - The note list is a compile-time constant; the controller keeps
//   a current index plus a set of "practiced" note ids in memory.
//   Per the task brief, no Drift, no SharedPreferences, no network,
//   no permissions.
// - Navigation rules (chose "wrap around"):
//     * [nextNote] from the last note wraps to the first.
//     * [previousNote] from the first note wraps to the last.
//   Wrapping keeps the practice loop friendly for beginners and
//   means the UI never has to disable the nav buttons.
// - Completion state is *local* to the controller instance. It does
//   not feed back into T007's home page "today's practice" task
//   list — the brief explicitly says so. A future task can promote
//   the practiced set to a shared service if cross-page aggregation
//   is required.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/features/single_note_practice/data/built_in_single_notes.dart';
import 'package:ukulele_app/features/single_note_practice/domain/single_note.dart';

/// Provider exposing the full built-in single-note list.
///
/// The list is the same `List` instance stored in
/// `built_in_single_notes.dart`. It is declared as a top-level
/// `final` (stable final built-in list) and is initialised once at
/// startup; we deliberately do NOT wrap it in another immutable
/// layer so equality checks stay cheap — every consumer sees the
/// same canonical instance.
final Provider<List<SingleNote>> builtInSingleNotesProvider =
    Provider<List<SingleNote>>((Ref ref) => kBuiltInSingleNotes);

/// Family provider that resolves a single [SingleNote] by id.
///
/// Returns `null` for unknown ids. Currently unused by the page
/// (the controller exposes the list directly), but exposed here as
/// a future-proof lookup helper — mirrors `chordByIdProvider` from
/// the chord library.
final singleNoteByIdProvider =
    Provider.family<SingleNote?, String>((Ref ref, String id) {
  if (id.isEmpty) {
    return null;
  }
  return findBuiltInSingleNote(id);
});

/// Immutable state for the single-note practice page.
@immutable
class SingleNotePracticeState {
  const SingleNotePracticeState({
    required this.notes,
    required this.currentIndex,
    required this.practicedNoteIds,
  });

  /// The full note list, in display order. Always non-empty in
  /// practice — the built-in data ships 6 notes.
  final List<SingleNote> notes;

  /// 0-based index into [notes] pointing at the active note. Always
  /// in `0..notes.length - 1`.
  final int currentIndex;

  /// Set of note ids that the user has marked as practiced in this
  /// session. Lost when the controller is disposed (no persistence).
  final Set<String> practicedNoteIds;

  /// The currently active note, or `null` if [notes] is empty
  /// (defensive — the built-in data is never empty).
  SingleNote? get currentNote =>
      notes.isEmpty ? null : notes[currentIndex.clamp(0, notes.length - 1)];

  /// Number of notes the user has marked as practiced.
  int get practicedCount => practicedNoteIds.length;

  /// Total number of notes available.
  int get totalCount => notes.length;

  /// `true` iff the current note is in [practicedNoteIds].
  bool get isCurrentPracticed {
    final SingleNote? note = currentNote;
    if (note == null) {
      return false;
    }
    return practicedNoteIds.contains(note.id);
  }

  /// Returns a copy with the given fields replaced.
  SingleNotePracticeState copyWith({
    List<SingleNote>? notes,
    int? currentIndex,
    Set<String>? practicedNoteIds,
  }) {
    return SingleNotePracticeState(
      notes: notes ?? this.notes,
      currentIndex: currentIndex ?? this.currentIndex,
      practicedNoteIds: practicedNoteIds ?? this.practicedNoteIds,
    );
  }
}

/// Riverpod notifier that produces [SingleNotePracticeState].
class SingleNotePracticeController extends Notifier<SingleNotePracticeState> {
  @override
  SingleNotePracticeState build() {
    final List<SingleNote> notes = ref.read(builtInSingleNotesProvider);
    return SingleNotePracticeState(
      notes: notes,
      currentIndex: 0,
      practicedNoteIds: const <String>{},
    );
  }

  /// Moves to the next note. Wraps around: calling this on the
  /// last note jumps back to the first. No-op if the list is empty.
  void nextNote() {
    if (state.notes.isEmpty) {
      return;
    }
    final int next = (state.currentIndex + 1) % state.notes.length;
    state = state.copyWith(currentIndex: next);
  }

  /// Moves to the previous note. Wraps around: calling this on the
  /// first note jumps to the last. No-op if the list is empty.
  void previousNote() {
    if (state.notes.isEmpty) {
      return;
    }
    final int prev =
        (state.currentIndex - 1 + state.notes.length) % state.notes.length;
    state = state.copyWith(currentIndex: prev);
  }

  /// Toggles the "practiced" flag for the current note.
  ///
  /// No-op if there is no current note (defensive — built-in data
  /// is never empty).
  void toggleCurrentPracticed() {
    final SingleNote? note = state.currentNote;
    if (note == null) {
      return;
    }
    final Set<String> next = Set<String>.from(state.practicedNoteIds);
    if (next.contains(note.id)) {
      next.remove(note.id);
    } else {
      next.add(note.id);
    }
    state = state.copyWith(practicedNoteIds: next);
  }

  /// Selects the note with [id]. No-op if the id is not in the
  /// built-in list.
  void selectNoteById(String id) {
    final int index = state.notes.indexWhere((SingleNote n) => n.id == id);
    if (index < 0) {
      return;
    }
    state = state.copyWith(currentIndex: index);
  }
}

/// Provider for the single-note practice page controller.
final NotifierProvider<SingleNotePracticeController, SingleNotePracticeState>
    singleNotePracticeControllerProvider =
    NotifierProvider<SingleNotePracticeController, SingleNotePracticeState>(
  SingleNotePracticeController.new,
);
