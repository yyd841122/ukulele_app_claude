// Drift-backed implementation of [UserSettingsRepository].
//
// T013.2 scope:
// - Backed by the `user_settings` key/value table. The Repository
//   keeps values as opaque `String`s — typed accessors (int /
//   DateTime / double) will land with the first consumer that
//   needs them.
// - `updatedAt` is stored as UTC.
import 'package:ukulele_app/data/database/app_database.dart';
import 'package:ukulele_app/shared/repositories/user_settings_repository.dart';

/// Concrete [UserSettingsRepository] backed by an [AppDatabase].
class DriftUserSettingsRepository implements UserSettingsRepository {
  DriftUserSettingsRepository({required AppDatabase database}) : _db = database;

  final AppDatabase _db;

  // --- Public API ---

  @override
  Future<String?> getValue(String key) async {
    if (key.isEmpty) {
      throw ArgumentError.value(key, 'key', 'key must not be empty');
    }
    final UserSettingData? row = await (_db.select(_db.userSettings)
          ..where(($UserSettingsTable t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  @override
  Future<void> setValue({
    required String key,
    required String value,
    required DateTime updatedAt,
  }) async {
    if (key.isEmpty) {
      throw ArgumentError.value(key, 'key', 'key must not be empty');
    }
    await _db.into(_db.userSettings).insertOnConflictUpdate(
          UserSettingsCompanion.insert(
            key: key,
            value: value,
            updatedAt: updatedAt.toUtc(),
          ),
        );
  }

  @override
  Future<bool> deleteValue(String key) async {
    if (key.isEmpty) {
      throw ArgumentError.value(key, 'key', 'key must not be empty');
    }
    final int affected = await (_db.delete(_db.userSettings)
          ..where(($UserSettingsTable t) => t.key.equals(key)))
        .go();
    return affected > 0;
  }
}
