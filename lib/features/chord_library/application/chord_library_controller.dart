// Riverpod providers for the chord library feature.
//
// T008 scope:
// - Hand-written providers (no `@riverpod` codegen) to match the
//   pattern established by T007 (`today_practice_controller.dart`).
// - The chord list itself is a compile-time constant — there is no
//   I/O, no async, no mutability. We still expose a controller-shaped
//   provider so the UI stays decoupled from the data source; a later
//   task can swap the data source (database / network) without
//   touching widgets.
// - We expose two separate providers:
//     * `chordLibraryProvider`     -> list of all chords.
//     * `chordByIdProvider`        -> family of "single chord by id"
//                                    lookups, including a `null` case
//                                    for unknown ids.
//   The family keeps the "id may not exist" concern at the provider
//   boundary so the detail page can render a friendly not-found
//   state without try/catch noise.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/features/chord_library/data/built_in_chords.dart';
import 'package:ukulele_app/features/chord_library/domain/chord.dart';

/// Provider exposing the full built-in chord list.
///
/// The list is the same `List` instance stored in
/// `built_in_chords.dart`. We deliberately do NOT wrap it in another
/// immutable layer so equality checks stay cheap (the list is already
/// `const`).
final chordLibraryProvider = Provider<List<Chord>>((Ref ref) => kBuiltInChords);

/// Family provider that resolves a single [Chord] by id.
///
/// Returns `null` for unknown ids — the detail page treats this as a
/// "not found" case and renders a friendly placeholder.
final chordByIdProvider =
    Provider.family<Chord?, String>((Ref ref, String id) {
  if (id.isEmpty) {
    return null;
  }
  return findBuiltInChord(id);
});
