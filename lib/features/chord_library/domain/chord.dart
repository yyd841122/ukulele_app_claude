// The [Chord] aggregate — a chord name + metadata + one or more
// voicings + practice tips.
//
// T008 scope:
// - We ship *one* voicing per chord for the MVP. The data shape
//   ([voicings] is a list, [primaryVoicing] picks the first) keeps the
//   door open for adding barre / alternate voicings later without a
//   migration.
// - [id] is the only lookup key. UI never compares by [name] because
//   "C" and "Cmaj7" both end in "C" but are different chords.

import 'package:flutter/foundation.dart';

import 'package:ukulele_app/features/chord_library/domain/chord_difficulty.dart';
import 'package:ukulele_app/features/chord_library/domain/chord_fingering.dart';

@immutable
class Chord {
  const Chord({
    required this.id,
    required this.name,
    required this.displayName,
    required this.description,
    required this.difficulty,
    required this.voicings,
    this.tips = const <String>[],
    this.relatedChordIds = const <String>[],
  });

  /// Stable lowercase id used for routing, e.g. `"c"`, `"am"`, `"f"`, `"g"`.
  final String id;

  /// Short musical name as commonly printed, e.g. `"C"`, `"Am"`, `"F"`, `"G"`.
  final String name;

  /// Chinese-friendly display name for the UI, e.g. `"C 和弦"`.
  final String displayName;

  /// One-sentence plain description aimed at absolute beginners.
  final String description;

  /// Difficulty tier used by the card chip.
  final ChordDifficulty difficulty;

  /// Available voicings. MVP ships exactly one per chord.
  final List<ChordFingering> voicings;

  /// Short practice tips shown on the detail page.
  final List<String> tips;

  /// Optional ids of related chords (e.g. `["am"]` for C). The detail
  /// page uses this to render "related" shortcuts.
  final List<String> relatedChordIds;

  /// Convenience accessor for the primary voicing. T008 always has one.
  ChordFingering get primaryVoicing => voicings.first;

  /// `true` if every voicing passes [ChordFingering.validate]. Used by
  /// the built-in data module and by tests to gate bad data.
  bool get isWellFormed =>
      voicings.every((ChordFingering f) => f.validate() == null);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Chord &&
          other.id == id &&
          other.name == name &&
          other.displayName == displayName &&
          other.description == description &&
          other.difficulty == difficulty &&
          listEquals(other.voicings, voicings) &&
          listEquals(other.tips, tips) &&
          listEquals(other.relatedChordIds, relatedChordIds));

  @override
  int get hashCode => Object.hash(
        id,
        name,
        displayName,
        description,
        difficulty,
        Object.hashAll(voicings),
        Object.hashAll(tips),
        Object.hashAll(relatedChordIds),
      );
}
