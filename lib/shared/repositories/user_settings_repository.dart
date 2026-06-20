// Repository contract for the generic key/value settings store.
//
// T013.2 scope:
// - Backed by the `user_settings` Drift table. The Repository is
//   the SINGLE place that converts between concrete Dart types
//   (`int`, `double`, `DateTime`, `String`, ...) and the table's
//   TEXT `value` column.
// - For T013.2 we persist values verbatim as `String`. Type-aware
//   helpers (e.g. `getInt` / `setInt`) will be added in the task
//   that actually wires each setting (T013.4 metronome, etc.).
//   This keeps the contract minimal until the first real consumer
//   needs it.

/// Persistence boundary for app-wide key/value settings.
abstract class UserSettingsRepository {
  /// Returns the raw stored value for [key], or `null` if missing.
  Future<String?> getValue(String key);

  /// Writes [value] for [key], stamping [updatedAt] as the last
  /// write time. Overwrites any existing value.
  Future<void> setValue({
    required String key,
    required String value,
    required DateTime updatedAt,
  });

  /// Removes the row with [key]. Returns `true` if a row was
  /// actually deleted.
  Future<bool> deleteValue(String key);
}
