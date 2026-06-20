// UserSettings table.
//
// T013.1 scope:
// - Schema-only. No DAO / Repository; CRUD lives in T013.2+.
// - Key/value table. Each known setting is identified by a stable
//   string `key`. The `value` column is text — Repository layer (T013.2+)
//   parses per-key (int / double / ISO-8601 string / etc.) and the
//   table intentionally stays untyped at the SQL level so new settings
//   do not require a schema change.
// - Generated row class is `UserSettingData` to avoid name collision
//   with the future domain `UserSetting` model
//   (DATA_MODEL_DRAFT.md §13.2 命名约定).
//
// MVP-known keys (DATA_MODEL_DRAFT.md §7):
// - `app.installDate` — ISO-8601 UTC string. First-launch write only.
// - `metronome.defaultBpm` — int. Default 80. (Reserved; not written
//   in T013.1 — T013.4 wires the metronome Controller.)
//
// T013.1 deliberately does NOT reserve other keys. New keys are added
// by introducing them in the Repository layer + DATA_MODEL_DRAFT.

import 'package:drift/drift.dart';

@DataClassName('UserSettingData')
class UserSettings extends Table {
  /// Stable identifier (e.g. `app.installDate`, `metronome.defaultBpm`).
  /// Primary key.
  TextColumn get key => text()();

  /// String-serialised value. Repository layer is responsible for
  /// encoding / decoding the concrete type (int / double / ISO date).
  TextColumn get value => text()();

  /// Last write timestamp. Useful for debugging and for future
  /// "settings changed" audit features.
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
