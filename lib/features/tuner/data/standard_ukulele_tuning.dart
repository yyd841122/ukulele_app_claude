// Built-in manual tuning data for the MVP.
//
// T011 scope:
// - One preset: the standard ukulele G-C-E-A tuning. This file
//   is the *only* place where the per-string tip and
//   common-mistake copy lives, so a copy edit cannot accidentally
//   drift between pages.
// - Two orderings exist in the project and they are *different*
//   things — keep them separate:
//     * [kTuningStringDisplayOrder] is the teaching / chart
//       order shown to the user: G, C, E, A. It is also the
//       left-to-right order in a chord diagram.
//     * [TuningString.stringNumber] is the internal 1-based
//       index carried by every model. It follows the T008 /
//       T009 convention:
//           1 = A string
//           2 = E string
//           3 = C string
//           4 = G string
//       A future combined view (chord diagram + tuner guide
//       overlay) can join on `stringNumber` without translation.
// - The model carries no pitch / physical / perspective
//   ordering. The stringNumber and the display-order constant
//   are sufficient to address every string unambiguously:
//     * "G" is the string with stringNumber 4.
//     * "C" is the string with stringNumber 3.
//     * "E" is the string with stringNumber 2.
//     * "A" is the string with stringNumber 1.
//   Any description that tries to rank the four strings
//   "from low to high" / "from high to low" / "thickest to
//   thinnest" / "closest to the player's face" is *out of
//   scope* for this file — see the project rules pinned in the
//   T011 test suite.
// - No frequency / cents / pitch-detection state is present in
//   any model. This page is a guide, not a tuner.
// - This file is a pure constant. It must not perform I/O, must
//   not call into Flutter, and must not be mutated. Tests
//   import it directly to assert the contents.

import 'package:ukulele_app/features/tuner/domain/tuning_string.dart';

/// The four standard-tuning strings, in *teaching / display*
/// order: G (stringNumber 4), C (stringNumber 3), E
/// (stringNumber 2), A (stringNumber 1). This is also the
/// left-to-right order in a chord diagram. The order is pinned
/// by tests.
///
/// We deliberately expose this as a separate constant rather than
/// inlining the ordering inside [kBuiltInTuningStrings]: tests
/// pin both the list contents *and* the display ordering, and a
/// future contributor should be able to swap data without losing
/// the teaching order.
const List<int> kTuningStringDisplayOrder = <int>[4, 3, 2, 1];

/// The four standard ukulele strings, keyed by their T008 / T009
/// `stringNumber` (1..4). The page renders them via
/// [kTuningStringDisplayOrder] rather than this list directly.
final List<TuningString> kBuiltInTuningStrings = <TuningString>[
  // ---- stringNumber 4 = G ----
  const TuningString(
    stringNumber: 4,
    stringName: 'G',
    displayName: '4 弦 · G',
    description: '标准调弦的第 4 弦，音名是 G。',
    beginnerTip: '从松到紧慢慢拧弦钮，每拧一点就拨一下弦听变化。',
    commonMistake: '不要一开始就拧太紧，新手最容易把 4 弦拧断。',
  ),

  // ---- stringNumber 3 = C ----
  const TuningString(
    stringNumber: 3,
    stringName: 'C',
    displayName: '3 弦 · C',
    description: '标准调弦的第 3 弦，音名是 C。',
    beginnerTip: '可以先把 3 弦对准钢琴或手机调音 App 上的 C 音，再微调。',
    commonMistake: '调完 3 弦又回头拧 4 弦，导致两弦互相拉扯走音。',
  ),

  // ---- stringNumber 2 = E ----
  const TuningString(
    stringNumber: 2,
    stringName: 'E',
    displayName: '2 弦 · E',
    description: '标准调弦的第 2 弦，音名是 E。',
    beginnerTip: '每次拧动幅度小一点，听音色比拧动距离更可靠。',
    commonMistake: '误把 2 弦当 1 弦的位置，从琴头右侧开始算弦。',
  ),

  // ---- stringNumber 1 = A ----
  const TuningString(
    stringNumber: 1,
    stringName: 'A',
    displayName: '1 弦 · A',
    description: '标准调弦的第 1 弦，音名是 A。',
    beginnerTip: '调好 1 弦后，从头到尾把 G-C-E-A 四弦再各拨一次确认。',
    commonMistake: '以为 1 弦在琴头最左侧。尤克里里 1 弦其实是琴头最右侧的那根。',
  ),
];

/// Returns the [TuningString] with the given [stringNumber],
/// or `null` if no such string is in the built-in library.
///
/// In the MVP the library has exactly four entries, so the linear
/// scan is effectively constant work. Callers in the UI may invoke
/// this on every rebuild.
TuningString? findBuiltInTuningString(int stringNumber) {
  if (stringNumber < 1 || stringNumber > 4) {
    return null;
  }
  for (final TuningString s in kBuiltInTuningStrings) {
    if (s.stringNumber == stringNumber) {
      return s;
    }
  }
  return null;
}

/// Returns the four [TuningString]s in the teaching / display
/// order G, C, E, A. Use this from the UI; do not reorder the
/// underlying [kBuiltInTuningStrings] list directly.
List<TuningString> tuningStringsInDisplayOrder() {
  final List<TuningString> out = <TuningString>[];
  for (final int n in kTuningStringDisplayOrder) {
    final TuningString? s = findBuiltInTuningString(n);
    if (s != null) {
      out.add(s);
    }
  }
  return out;
}