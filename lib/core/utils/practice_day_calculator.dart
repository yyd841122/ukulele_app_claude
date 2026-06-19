// Pure function that maps "days since install" -> 7-day cycle index (1-7).
//
// T007 scope:
// - This is intentionally a *pure* function with no I/O and no DateTime.now()
//   calls. Tests pass explicit [installDate] / [today] arguments so the
//   behaviour is deterministic.
// - The home page wires this together with `InstallDateService` (which
//   supplies the install date) and `DateTime.now()` (which supplies
//   "today").
//
// Rules — per task spec §8 and PRD §9 / DATA_MODEL_DRAFT.md §7:
//   1. Both inputs are normalised to local-midnight (00:00:00).
//   2. daysDiff = (todayMidnight - installMidnight).inDays.
//   3. If daysDiff < 0, return 1 (clock skew / system clock change).
//   4. Otherwise return (daysDiff % 7) + 1.
//   5. The returned value is always in the closed range 1..7.

/// Returns the 1-based 7-day cycle index for the given [today] relative to
/// the user's [installDate].
///
/// Both arguments are interpreted in the device's local time zone; the
/// time-of-day component is ignored.
int calculatePracticeDayIndex({
  required DateTime installDate,
  required DateTime today,
}) {
  // Normalise to local-midnight. We use year/month/day to avoid any DST
  // surprises from `DateTime(now.year, now.month, now.day)` constructors
  // when the system clock jumps across a DST boundary.
  final DateTime installMidnight = DateTime(
    installDate.year,
    installDate.month,
    installDate.day,
  );
  final DateTime todayMidnight = DateTime(
    today.year,
    today.month,
    today.day,
  );

  final int daysDiff = todayMidnight.difference(installMidnight).inDays;
  if (daysDiff < 0) {
    return 1;
  }
  // `daysDiff % 7` is in 0..6 for non-negative ints, so the result is
  // guaranteed to be in 1..7.
  return (daysDiff % 7) + 1;
}
