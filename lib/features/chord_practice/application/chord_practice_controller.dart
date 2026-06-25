// Riverpod Notifier for the chord practice page.
//
// T053 scope:
// - Tracks the *currently selected* chord id for the practice UI.
//   Holds nothing more: the chord metadata itself comes from the
//   existing [chordByIdProvider] family (T008), so this controller
//   only owns the selection state.
// - State shape is intentionally minimal: a single `currentChordId`.
//   This keeps the data model trivially serializable and leaves the
//   door open for P2 to add `selectedVoicingIndex`, `lastPracticedAt`,
//   etc. without breaking existing widget code that reads
//   [currentChordId].
// - The default chord is the first one in [kBuiltInChords]. If a
//   future task ships the list empty, the page renders an empty
//   state via the [currentChord] getter returning `null`.
// - `selectChord` is a no-op if the requested id is not in the
//   shipped library (or if the user passes an empty string). The
//   page never needs to render "I picked an unknown chord", which
//   would only happen from a buggy data layer or a deep link we
//   have not wired up.
//
// This file must NOT:
//   * Import anything from `metronome/`, `recording/`, or
//     `practice_records/`. The chord practice feature has no audio
//     and no recording coupling — T053 is UI-only.
//   * Persist selection to disk. P2 may add persistence; T053
//     intentionally keeps selection in-memory so a fresh app start
//     resets to the default chord.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/features/chord_library/application/chord_library_controller.dart';
import 'package:ukulele_app/features/chord_library/data/built_in_chords.dart';
import 'package:ukulele_app/features/chord_library/domain/chord.dart';

/// Riverpod Notifier exposing the practice page's currently selected
/// chord id.
///
/// Read state via `ref.watch(chordPracticeControllerProvider)`,
/// update state via
/// `ref.read(chordPracticeControllerProvider.notifier).selectChord(id)`.
class ChordPracticeController extends Notifier<String> {
  @override
  String build() {
    // Default selection = the first shipped chord. If the library is
    // empty (defensive — should never happen at runtime), the page
    // renders an empty state via [currentChord] returning `null`.
    return kBuiltInChords.isNotEmpty ? kBuiltInChords.first.id : '';
  }

  /// Sets the current chord to the chord with the given [id].
  ///
  /// Silently ignores unknown ids and the empty string. This keeps
  /// the UI defensive against a stale deep-link / a data swap that
  /// removes a chord while a `selectChord` call is in flight.
  void selectChord(String id) {
    if (id.isEmpty) {
      return;
    }
    if (findBuiltInChord(id) == null) {
      return;
    }
    if (state == id) {
      // Same id — skip the rebuild. `state ==` is cheap string
      // comparison; Notifier would coalesce anyway, but returning
      // early keeps logs clean in widget tests.
      return;
    }
    state = id;
  }
}

/// Provider for [ChordPracticeController].
///
/// Uses a plain [NotifierProvider] (no codegen) to match the
/// hand-written style of the rest of the codebase (see
/// `metronome_controller.dart`, `chord_library_controller.dart`).
final chordPracticeControllerProvider =
    NotifierProvider<ChordPracticeController, String>(
  ChordPracticeController.new,
);

/// Read-side helper: the currently displayed [Chord] (resolved from
/// the id stored in [chordPracticeControllerProvider]), or `null`
/// when the id is empty / unknown / the library is empty.
///
/// Widgets should prefer `ref.watch(currentChordProvider)` over
/// manually reading the id and then resolving via
/// [chordByIdProvider], so the wiring stays in one place.
final currentChordProvider = Provider<Chord?>((Ref ref) {
  final String id = ref.watch(chordPracticeControllerProvider);
  if (id.isEmpty) {
    return null;
  }
  return ref.watch(chordByIdProvider(id));
});