// Riverpod controller for the manual tuning guide page.
//
// T011 scope:
// - Hand-written [Notifier] (no `@riverpod` codegen) per the
//   project convention (T007, T008, T009, T010).
// - The string list itself is a compile-time constant (see
//   `data/standard_ukulele_tuning.dart`); the controller only
//   holds the in-memory "confirmed" set.
// - Confirmation state is *local* and ephemeral:
//     * It is never written to a database (no Drift).
//     * It is never written to SharedPreferences.
//     * It is lost whenever the application process is killed
//       (cold restart, OS reclaim, etc.).
//   Completion state does NOT feed back into T007's home page
//   "today's practice" task list — the brief explicitly forbids
//   that. A future task can promote this to a shared service if
//   cross-page aggregation is required.
// - Behaviors:
//     * [toggleConfirmed]: add / remove a stringNumber from the
//       confirmed set. Unknown stringNumbers (anything outside
//       1..4 or not in the built-in library) are a no-op.
//     * [resetAll]: clears the confirmed set.
//     * [confirmAll]: marks every built-in string as confirmed.
//       Optional in the brief; provided so the page can offer a
//       one-tap "全部标记已调好" affordance.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukulele_app/features/tuner/data/standard_ukulele_tuning.dart';
import 'package:ukulele_app/features/tuner/domain/tuning_string.dart';

/// Provider exposing the full built-in tuning string list.
final Provider<List<TuningString>> builtInTuningStringsProvider =
    Provider<List<TuningString>>(
        (Ref ref) => kBuiltInTuningStrings);

/// Provider exposing the four strings in display order
/// (G, C, E, A). The page reads from this rather than re-sorting.
final Provider<List<TuningString>> tuningStringsDisplayOrderProvider =
    Provider<List<TuningString>>(
        (Ref ref) => tuningStringsInDisplayOrder());

/// Immutable state for the tuner guide page.
@immutable
class TunerState {
  const TunerState({
    required this.strings,
    required this.confirmedStringNumbers,
  });

  /// All four strings in *storage* order (1..4).
  final List<TuningString> strings;

  /// Set of `stringNumber`s the user has marked as confirmed in
  /// this session. Always a subset of `{1, 2, 3, 4}` in practice.
  final Set<int> confirmedStringNumbers;

  /// All four strings in *display* order (G, C, E, A).
  List<TuningString> get stringsInDisplayOrder {
    final List<TuningString> out = <TuningString>[];
    for (final int n in kTuningStringDisplayOrder) {
      for (final TuningString s in strings) {
        if (s.stringNumber == n) {
          out.add(s);
        }
      }
    }
    return out;
  }

  /// `true` iff the string with [stringNumber] is in the
  /// confirmed set. Unknown stringNumbers are always `false`.
  bool isConfirmed(int stringNumber) =>
      confirmedStringNumbers.contains(stringNumber);

  /// Number of strings the user has marked as confirmed.
  int get confirmedCount => confirmedStringNumbers.length;

  /// Total number of strings available (always 4 in the MVP).
  int get totalCount => strings.length;

  /// `true` iff the user has confirmed every shipped string.
  bool get allConfirmed =>
      confirmedStringNumbers.length == strings.length &&
      strings.isNotEmpty;

  /// Returns a copy with the given fields replaced.
  TunerState copyWith({
    List<TuningString>? strings,
    Set<int>? confirmedStringNumbers,
  }) {
    return TunerState(
      strings: strings ?? this.strings,
      confirmedStringNumbers:
          confirmedStringNumbers ?? this.confirmedStringNumbers,
    );
  }
}

/// Riverpod notifier for the tuner guide page.
class TunerController extends Notifier<TunerState> {
  @override
  TunerState build() {
    final List<TuningString> strings =
        ref.read(builtInTuningStringsProvider);
    return TunerState(
      strings: strings,
      confirmedStringNumbers: const <int>{},
    );
  }

  /// Toggles the confirmed flag for [stringNumber].
  ///
  /// Unknown stringNumbers (anything outside the built-in
  /// library, including values like 0, 5, -1) are a no-op.
  /// Repeated calls with the same value flip the flag, so
  /// `confirmedCount` never double-counts a single string.
  void toggleConfirmed(int stringNumber) {
    if (!_isKnownStringNumber(stringNumber)) {
      return;
    }
    final Set<int> next = Set<int>.from(state.confirmedStringNumbers);
    if (next.contains(stringNumber)) {
      next.remove(stringNumber);
    } else {
      next.add(stringNumber);
    }
    state = state.copyWith(confirmedStringNumbers: next);
  }

  /// Clears every confirmed string. No-op if the set is already
  /// empty (still emits a fresh empty set so any UI rebound off
  /// `state ==` equality repaints cleanly).
  void resetAll() {
    if (state.confirmedStringNumbers.isEmpty) {
      // Still emit a fresh set so listeners using `==` can react.
      state = state.copyWith(
        confirmedStringNumbers: const <int>{},
      );
      return;
    }
    state = state.copyWith(
      confirmedStringNumbers: const <int>{},
    );
  }

  /// Marks every built-in string as confirmed. Useful for the
  /// optional "全部标记已调好" affordance. No-op if the library
  /// is empty (defensive — the MVP ships 4 strings).
  void confirmAll() {
    if (state.strings.isEmpty) {
      return;
    }
    state = state.copyWith(
      confirmedStringNumbers: <int>{
        for (final TuningString s in state.strings) s.stringNumber,
      },
    );
  }

  /// `true` iff [stringNumber] is a known built-in string.
  /// Internal helper; exposed at file scope for tests.
  bool _isKnownStringNumber(int stringNumber) {
    for (final TuningString s in state.strings) {
      if (s.stringNumber == stringNumber) {
        return true;
      }
    }
    return false;
  }
}

/// Provider for the tuner guide page controller.
final NotifierProvider<TunerController, TunerState>
    tunerControllerProvider =
    NotifierProvider<TunerController, TunerState>(
  TunerController.new,
);