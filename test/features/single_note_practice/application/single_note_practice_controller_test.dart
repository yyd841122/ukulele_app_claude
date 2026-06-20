// Tests for [SingleNotePracticeController].
//
// T009 scope:
// - Verify the initial state is sane (index 0, currentNote is the
//   first shipped note, practiced set is empty).
// - Verify nextNote / previousNote walk the list and wrap around at
//   the boundaries.
// - Verify toggleCurrentPracticed flips the flag and updates the
//   practiced count.
// - Verify selectNoteById moves to a known note and is a no-op for
//   unknown ids.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ukulele_app/features/single_note_practice/application/single_note_practice_controller.dart';
import 'package:ukulele_app/features/single_note_practice/data/built_in_single_notes.dart';
import 'package:ukulele_app/features/single_note_practice/domain/single_note.dart';

void main() {
  group('SingleNotePracticeController', () {
    test('initial state exposes all six notes and the first as current',
        () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final SingleNotePracticeState state =
          container.read(singleNotePracticeControllerProvider);

      expect(state.notes.length, kBuiltInSingleNotes.length);
      expect(state.totalCount, kBuiltInSingleNotes.length);
      expect(state.practicedCount, 0);
      expect(state.currentIndex, 0);
      expect(state.currentNote, isNotNull);
      expect(state.currentNote!.id, kBuiltInSingleNotes.first.id);
      expect(state.isCurrentPracticed, isFalse);
    });

    test('nextNote walks forward and wraps at the end', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final SingleNotePracticeController controller =
          container.read(singleNotePracticeControllerProvider.notifier);

      // Walk to the last note.
      for (int i = 0; i < kBuiltInSingleNotes.length - 1; i++) {
        controller.nextNote();
      }
      expect(
        container.read(singleNotePracticeControllerProvider).currentNote!.id,
        kBuiltInSingleNotes.last.id,
      );

      // One more step wraps to the first note.
      controller.nextNote();
      expect(
        container.read(singleNotePracticeControllerProvider).currentNote!.id,
        kBuiltInSingleNotes.first.id,
      );
    });

    test('previousNote walks backward and wraps at the start', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final SingleNotePracticeController controller =
          container.read(singleNotePracticeControllerProvider.notifier);

      // At index 0, previous wraps to the last note.
      controller.previousNote();
      expect(
        container.read(singleNotePracticeControllerProvider).currentNote!.id,
        kBuiltInSingleNotes.last.id,
      );

      // Now walk back to the first.
      for (int i = 0; i < kBuiltInSingleNotes.length - 1; i++) {
        controller.previousNote();
      }
      expect(
        container.read(singleNotePracticeControllerProvider).currentNote!.id,
        kBuiltInSingleNotes.first.id,
      );
    });

    test('nextNote / previousNote never go out of bounds', () {
      // A long walk in both directions must not throw and must
      // always land on a valid index.
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final SingleNotePracticeController controller =
          container.read(singleNotePracticeControllerProvider.notifier);

      for (int i = 0; i < kBuiltInSingleNotes.length * 3; i++) {
        controller.nextNote();
        final int idx =
            container.read(singleNotePracticeControllerProvider).currentIndex;
        expect(idx, inInclusiveRange(0, kBuiltInSingleNotes.length - 1));
      }
      for (int i = 0; i < kBuiltInSingleNotes.length * 3; i++) {
        controller.previousNote();
        final int idx =
            container.read(singleNotePracticeControllerProvider).currentIndex;
        expect(idx, inInclusiveRange(0, kBuiltInSingleNotes.length - 1));
      }
    });

    test('toggleCurrentPracticed flips the flag and updates the count',
        () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final SingleNotePracticeController controller =
          container.read(singleNotePracticeControllerProvider.notifier);
      final String firstId =
          kBuiltInSingleNotes.first.id;

      // Mark the current note (index 0) as practiced.
      controller.toggleCurrentPracticed();
      SingleNotePracticeState state =
          container.read(singleNotePracticeControllerProvider);
      expect(state.practicedCount, 1);
      expect(state.isCurrentPracticed, isTrue);
      expect(state.practicedNoteIds, contains(firstId));

      // Toggling again clears the flag.
      controller.toggleCurrentPracticed();
      state = container.read(singleNotePracticeControllerProvider);
      expect(state.practicedCount, 0);
      expect(state.isCurrentPracticed, isFalse);
      expect(state.practicedNoteIds, isNot(contains(firstId)));
    });

    test('toggleCurrentPracticed counts each note once', () {
      // Mark every note as practiced, then advance — the count
      // must equal notes.length.
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final SingleNotePracticeController controller =
          container.read(singleNotePracticeControllerProvider.notifier);

      for (int i = 0; i < kBuiltInSingleNotes.length; i++) {
        controller.toggleCurrentPracticed();
        controller.nextNote();
      }
      expect(
        container.read(singleNotePracticeControllerProvider).practicedCount,
        kBuiltInSingleNotes.length,
      );
    });

    test('selectNoteById moves to a known note', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final SingleNotePracticeController controller =
          container.read(singleNotePracticeControllerProvider.notifier);

      controller.selectNoteById('f');
      SingleNotePracticeState state =
          container.read(singleNotePracticeControllerProvider);
      expect(state.currentNote!.id, 'f');
      expect(state.currentIndex,
          kBuiltInSingleNotes.indexWhere((SingleNote n) => n.id == 'f'));
    });

    test('selectNoteById ignores unknown ids', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      final SingleNotePracticeController controller =
          container.read(singleNotePracticeControllerProvider.notifier);
      final int before =
          container.read(singleNotePracticeControllerProvider).currentIndex;

      controller.selectNoteById('not-a-real-id');

      final int after =
          container.read(singleNotePracticeControllerProvider).currentIndex;
      expect(after, before);
    });

    test('builtInSingleNotesProvider exposes the shipped list', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      final List<SingleNote> notes =
          container.read(builtInSingleNotesProvider);
      expect(notes, isNotEmpty);
      expect(notes.first.id, kBuiltInSingleNotes.first.id);
    });
  });
}
