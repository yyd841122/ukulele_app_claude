// Drift-backed implementation of [PracticeRecordRepository].
//
// T013.2 scope:
// - Owns the ONLY conversion between `PracticeRecordData` (Drift
//   row) and `PracticeRecord` (domain). No other layer is allowed
//   to touch the JSON tag column or to read the enum string
//   columns.
// - Validates user-supplied invariants up front (id / content
//   non-empty, dayIndex in 1..7, durationSeconds >= 0) so the
//   database can never see malformed data even if Drift would
//   otherwise accept it.
// - Stamps `createdAt` / `updatedAt` to the supplied UTC clock and
//   normalises `practiceDate` to local-midnight. Callers that pass
//   a `DateTime` with a non-zero time-of-day will see it silently
//   truncated to midnight — this matches the DATA_MODEL_DRAFT
//   §2.1 / §7 invariant.

import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:ukulele_app/data/database/app_database.dart';
import 'package:ukulele_app/features/practice_records/data/practice_record_repository.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_record.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_tag.dart';
import 'package:ukulele_app/features/practice_records/domain/practice_type.dart';
import 'package:ukulele_app/features/practice_records/domain/self_assessment.dart';

/// Concrete [PracticeRecordRepository] that writes to / reads from
/// the `practice_records` table of an [AppDatabase].
class DriftPracticeRecordRepository implements PracticeRecordRepository {
  DriftPracticeRecordRepository({
    required AppDatabase database,
    DateTime Function()? clock,
  })  : _db = database,
        _clock = clock ?? DateTime.now;

  final AppDatabase _db;

  /// UTC clock for stamping `createdAt` / `updatedAt`. Overridable
  /// in tests so they can pin the timestamp deterministically.
  final DateTime Function() _clock;

  // --- Public API ---

  @override
  Future<PracticeRecord> insert(PracticeRecord record) async {
    _validateRecord(record);

    final DateTime normalisedPracticeDate = _toLocalMidnight(
      record.practiceDate,
    );
    final DateTime nowUtc = _clock().toUtc();

    final PracticeRecordsCompanion companion = PracticeRecordsCompanion(
      id: Value(record.id),
      practiceDate: Value(normalisedPracticeDate),
      dayIndex: Value(record.dayIndex),
      primaryPracticeType: Value(record.primaryPracticeType.name),
      practiceTagsJson: Value(_encodeTags(record.practiceTags)),
      practiceContent: Value(record.practiceContent),
      durationSeconds: Value(record.durationSeconds),
      isCompleted: Value(record.isCompleted),
      selfAssessment: Value(record.selfAssessment?.name),
      audioFilePath: Value(record.audioFilePath),
      createdAt: Value(nowUtc),
      updatedAt: Value(nowUtc),
    );

    await _db.into(_db.practiceRecords).insert(companion);

    // The persisted copy is byte-equivalent to the validated
    // input — `createdAt` / `updatedAt` are now stamped. Return a
    // new instance rather than mutating the caller's.
    return PracticeRecord(
      id: record.id,
      practiceDate: normalisedPracticeDate,
      dayIndex: record.dayIndex,
      primaryPracticeType: record.primaryPracticeType,
      practiceTags: List<PracticeTag>.unmodifiable(record.practiceTags),
      practiceContent: record.practiceContent,
      durationSeconds: record.durationSeconds,
      isCompleted: record.isCompleted,
      selfAssessment: record.selfAssessment,
      audioFilePath: record.audioFilePath,
      createdAt: nowUtc,
      updatedAt: nowUtc,
    );
  }

  @override
  Future<PracticeRecord?> getById(String id) async {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'id must not be empty');
    }
    final PracticeRecordData? row = await (_db.select(_db.practiceRecords)
          ..where(($PracticeRecordsTable t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) {
      return null;
    }
    return _decode(row);
  }

  @override
  Future<List<PracticeRecord>> listRecent({int limit = 50}) async {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'limit must be > 0');
    }
    final List<PracticeRecordData> rows = await (_db.select(
      _db.practiceRecords,
    )
          ..orderBy(<OrderClauseGenerator<$PracticeRecordsTable>>[
            ($PracticeRecordsTable t) => OrderingTerm(
                expression: t.practiceDate, mode: OrderingMode.desc),
            ($PracticeRecordsTable t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .get();
    return rows.map(_decode).toList(growable: false);
  }

  @override
  Stream<List<PracticeRecord>> watchAll() {
    final Stream<List<PracticeRecordData>> source = (_db.select(
      _db.practiceRecords,
    )..orderBy(<OrderClauseGenerator<$PracticeRecordsTable>>[
            ($PracticeRecordsTable t) => OrderingTerm(
                expression: t.practiceDate, mode: OrderingMode.desc),
            ($PracticeRecordsTable t) =>
                OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .watch();
    return source.map(
      (List<PracticeRecordData> rows) =>
          rows.map(_decode).toList(growable: false),
    );
  }

  @override
  Future<bool> delete(String id) async {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'id must not be empty');
    }
    final int affected = await (_db.delete(_db.practiceRecords)
          ..where(($PracticeRecordsTable t) => t.id.equals(id)))
        .go();
    return affected > 0;
  }

  // --- Internal helpers ---

  /// Throws [ArgumentError] when the record violates a documented
  /// invariant. The error message is intentionally explicit so
  /// upstream code can surface a useful message to the user.
  void _validateRecord(PracticeRecord r) {
    if (r.id.isEmpty) {
      throw ArgumentError.value(r.id, 'id', 'id must not be empty');
    }
    if (r.practiceContent.isEmpty) {
      throw ArgumentError.value(
        r.practiceContent,
        'practiceContent',
        'practiceContent must not be empty',
      );
    }
    if (r.dayIndex < 1 || r.dayIndex > 7) {
      throw ArgumentError.value(
        r.dayIndex,
        'dayIndex',
        'dayIndex must be in 1..7',
      );
    }
    if (r.durationSeconds < 0) {
      throw ArgumentError.value(
        r.durationSeconds,
        'durationSeconds',
        'durationSeconds must be >= 0',
      );
    }
  }

  /// Truncates [d] to local-midnight. The Repository treats
  /// `practiceDate` as a "calendar day" — any time-of-day component
  /// is discarded.
  ///
  /// Drift stores DateTimes as unix-seconds; on read the returned
  /// value may be flagged `isUtc=true` even though the caller
  /// originally passed a local DateTime. We always project to the
  /// *local* wall clock before extracting y/m/d so that a value
  /// originally written as `DateTime(2026, 6, 20)` (local) comes
  /// back as `DateTime(2026, 6, 20)` (local).
  DateTime _toLocalMidnight(DateTime d) {
    final DateTime localD = d.isUtc ? d.toLocal() : d;
    return DateTime(localD.year, localD.month, localD.day);
  }

  /// JSON-encodes [tags] as an array of enum-case names. Empty
  /// list encodes to `[]`, never `null`.
  String _encodeTags(List<PracticeTag> tags) {
    return jsonEncode(<String>[for (final PracticeTag t in tags) t.name]);
  }

  /// Reverse of [_encodeTags]. Also parses the enum columns and
  /// the `PracticeType` name. Throws [FormatException] on any
  /// structural or unknown-enum error so the upstream layer sees
  /// an unambiguous "data is corrupt" signal rather than a silent
  /// fallback.
  PracticeRecord _decode(PracticeRecordData row) {
    return PracticeRecord(
      id: row.id,
      practiceDate: _toLocalMidnight(row.practiceDate),
      dayIndex: row.dayIndex,
      primaryPracticeType: _decodePracticeType(row.primaryPracticeType),
      practiceTags: _decodeTags(row.practiceTagsJson),
      practiceContent: row.practiceContent,
      durationSeconds: row.durationSeconds,
      isCompleted: row.isCompleted,
      selfAssessment: _decodeSelfAssessment(row.selfAssessment),
      audioFilePath: row.audioFilePath,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  PracticeType _decodePracticeType(String raw) {
    for (final PracticeType t in PracticeType.values) {
      if (t.name == raw) {
        return t;
      }
    }
    throw FormatException(
      'Unknown PracticeType in practice_records.primary_practice_type: "$raw"',
    );
  }

  SelfAssessment? _decodeSelfAssessment(String? raw) {
    if (raw == null) {
      return null;
    }
    for (final SelfAssessment v in SelfAssessment.values) {
      if (v.name == raw) {
        return v;
      }
    }
    throw FormatException(
      'Unknown SelfAssessment in practice_records.self_assessment: "$raw"',
    );
  }

  List<PracticeTag> _decodeTags(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException catch (e) {
      throw FormatException(
        'Corrupt practice_records.practice_tags_json: ${e.message}',
      );
    }
    if (decoded is! List<Object?>) {
      throw FormatException(
        'practice_records.practice_tags_json is not a JSON array: $json',
      );
    }
    final List<PracticeTag> out = <PracticeTag>[];
    for (final Object? element in decoded) {
      if (element is! String) {
        throw FormatException(
          'practice_records.practice_tags_json contains a non-string: $element',
        );
      }
      bool matched = false;
      for (final PracticeTag t in PracticeTag.values) {
        if (t.name == element) {
          out.add(t);
          matched = true;
          break;
        }
      }
      if (!matched) {
        throw FormatException(
          'Unknown PracticeTag in practice_records.practice_tags_json: "$element"',
        );
      }
    }
    return List<PracticeTag>.unmodifiable(out);
  }
}
