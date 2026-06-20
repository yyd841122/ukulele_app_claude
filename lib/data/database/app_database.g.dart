// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PracticeRecordsTable extends PracticeRecords
    with TableInfo<$PracticeRecordsTable, PracticeRecordData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PracticeRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _practiceDateMeta =
      const VerificationMeta('practiceDate');
  @override
  late final GeneratedColumn<DateTime> practiceDate = GeneratedColumn<DateTime>(
      'practice_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _dayIndexMeta =
      const VerificationMeta('dayIndex');
  @override
  late final GeneratedColumn<int> dayIndex = GeneratedColumn<int>(
      'day_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _primaryPracticeTypeMeta =
      const VerificationMeta('primaryPracticeType');
  @override
  late final GeneratedColumn<String> primaryPracticeType =
      GeneratedColumn<String>('primary_practice_type', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _practiceTagsJsonMeta =
      const VerificationMeta('practiceTagsJson');
  @override
  late final GeneratedColumn<String> practiceTagsJson = GeneratedColumn<String>(
      'practice_tags_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _practiceContentMeta =
      const VerificationMeta('practiceContent');
  @override
  late final GeneratedColumn<String> practiceContent = GeneratedColumn<String>(
      'practice_content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _durationSecondsMeta =
      const VerificationMeta('durationSeconds');
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
      'duration_seconds', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _isCompletedMeta =
      const VerificationMeta('isCompleted');
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
      'is_completed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_completed" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _selfAssessmentMeta =
      const VerificationMeta('selfAssessment');
  @override
  late final GeneratedColumn<String> selfAssessment = GeneratedColumn<String>(
      'self_assessment', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _audioFilePathMeta =
      const VerificationMeta('audioFilePath');
  @override
  late final GeneratedColumn<String> audioFilePath = GeneratedColumn<String>(
      'audio_file_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        practiceDate,
        dayIndex,
        primaryPracticeType,
        practiceTagsJson,
        practiceContent,
        durationSeconds,
        isCompleted,
        selfAssessment,
        audioFilePath,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'practice_records';
  @override
  VerificationContext validateIntegrity(Insertable<PracticeRecordData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('practice_date')) {
      context.handle(
          _practiceDateMeta,
          practiceDate.isAcceptableOrUnknown(
              data['practice_date']!, _practiceDateMeta));
    } else if (isInserting) {
      context.missing(_practiceDateMeta);
    }
    if (data.containsKey('day_index')) {
      context.handle(_dayIndexMeta,
          dayIndex.isAcceptableOrUnknown(data['day_index']!, _dayIndexMeta));
    } else if (isInserting) {
      context.missing(_dayIndexMeta);
    }
    if (data.containsKey('primary_practice_type')) {
      context.handle(
          _primaryPracticeTypeMeta,
          primaryPracticeType.isAcceptableOrUnknown(
              data['primary_practice_type']!, _primaryPracticeTypeMeta));
    } else if (isInserting) {
      context.missing(_primaryPracticeTypeMeta);
    }
    if (data.containsKey('practice_tags_json')) {
      context.handle(
          _practiceTagsJsonMeta,
          practiceTagsJson.isAcceptableOrUnknown(
              data['practice_tags_json']!, _practiceTagsJsonMeta));
    } else if (isInserting) {
      context.missing(_practiceTagsJsonMeta);
    }
    if (data.containsKey('practice_content')) {
      context.handle(
          _practiceContentMeta,
          practiceContent.isAcceptableOrUnknown(
              data['practice_content']!, _practiceContentMeta));
    } else if (isInserting) {
      context.missing(_practiceContentMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
          _durationSecondsMeta,
          durationSeconds.isAcceptableOrUnknown(
              data['duration_seconds']!, _durationSecondsMeta));
    } else if (isInserting) {
      context.missing(_durationSecondsMeta);
    }
    if (data.containsKey('is_completed')) {
      context.handle(
          _isCompletedMeta,
          isCompleted.isAcceptableOrUnknown(
              data['is_completed']!, _isCompletedMeta));
    }
    if (data.containsKey('self_assessment')) {
      context.handle(
          _selfAssessmentMeta,
          selfAssessment.isAcceptableOrUnknown(
              data['self_assessment']!, _selfAssessmentMeta));
    }
    if (data.containsKey('audio_file_path')) {
      context.handle(
          _audioFilePathMeta,
          audioFilePath.isAcceptableOrUnknown(
              data['audio_file_path']!, _audioFilePathMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PracticeRecordData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PracticeRecordData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      practiceDate: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}practice_date'])!,
      dayIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}day_index'])!,
      primaryPracticeType: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}primary_practice_type'])!,
      practiceTagsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}practice_tags_json'])!,
      practiceContent: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}practice_content'])!,
      durationSeconds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_seconds'])!,
      isCompleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_completed'])!,
      selfAssessment: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}self_assessment']),
      audioFilePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}audio_file_path']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $PracticeRecordsTable createAlias(String alias) {
    return $PracticeRecordsTable(attachedDatabase, alias);
  }
}

class PracticeRecordData extends DataClass
    implements Insertable<PracticeRecordData> {
  /// UUID v4, primary key. Generated by Repository layer, not by the
  /// database, so callers can build records before insert.
  final String id;

  /// Local-date of the practice session, normalised to local midnight
  /// (see `core/utils/practice_day_calculator.dart`). Stored as
  /// `INTEGER` (unix seconds) for indexability.
  final DateTime practiceDate;

  /// 1-based day index in the 7-day cycle (1..7).
  final int dayIndex;

  /// Name of the `PracticeType` enum case. Stored as the enum name
  /// string so future enum re-orderings do not shift data.
  final String primaryPracticeType;

  /// JSON-encoded list of `PracticeTag` enum names.
  final String practiceTagsJson;

  /// Human-readable description of what the user practised.
  final String practiceContent;

  /// Total practice duration in seconds (>= 0).
  final int durationSeconds;

  /// Whether the user marked the session as completed.
  final bool isCompleted;

  /// Name of the `SelfAssessment` enum case, or `null` if the user
  /// skipped self-assessment. Stored as the enum name string.
  final String? selfAssessment;

  /// Relative path to the recording file under the app private dir, or
  /// `null` if no recording is attached. T013.1: always `null` in
  /// practice (no audio is saved yet), but the column is nullable so
  /// T013.5+ can populate it without a schema change.
  final String? audioFilePath;
  final DateTime createdAt;
  final DateTime updatedAt;
  const PracticeRecordData(
      {required this.id,
      required this.practiceDate,
      required this.dayIndex,
      required this.primaryPracticeType,
      required this.practiceTagsJson,
      required this.practiceContent,
      required this.durationSeconds,
      required this.isCompleted,
      this.selfAssessment,
      this.audioFilePath,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['practice_date'] = Variable<DateTime>(practiceDate);
    map['day_index'] = Variable<int>(dayIndex);
    map['primary_practice_type'] = Variable<String>(primaryPracticeType);
    map['practice_tags_json'] = Variable<String>(practiceTagsJson);
    map['practice_content'] = Variable<String>(practiceContent);
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['is_completed'] = Variable<bool>(isCompleted);
    if (!nullToAbsent || selfAssessment != null) {
      map['self_assessment'] = Variable<String>(selfAssessment);
    }
    if (!nullToAbsent || audioFilePath != null) {
      map['audio_file_path'] = Variable<String>(audioFilePath);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PracticeRecordsCompanion toCompanion(bool nullToAbsent) {
    return PracticeRecordsCompanion(
      id: Value(id),
      practiceDate: Value(practiceDate),
      dayIndex: Value(dayIndex),
      primaryPracticeType: Value(primaryPracticeType),
      practiceTagsJson: Value(practiceTagsJson),
      practiceContent: Value(practiceContent),
      durationSeconds: Value(durationSeconds),
      isCompleted: Value(isCompleted),
      selfAssessment: selfAssessment == null && nullToAbsent
          ? const Value.absent()
          : Value(selfAssessment),
      audioFilePath: audioFilePath == null && nullToAbsent
          ? const Value.absent()
          : Value(audioFilePath),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory PracticeRecordData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PracticeRecordData(
      id: serializer.fromJson<String>(json['id']),
      practiceDate: serializer.fromJson<DateTime>(json['practiceDate']),
      dayIndex: serializer.fromJson<int>(json['dayIndex']),
      primaryPracticeType:
          serializer.fromJson<String>(json['primaryPracticeType']),
      practiceTagsJson: serializer.fromJson<String>(json['practiceTagsJson']),
      practiceContent: serializer.fromJson<String>(json['practiceContent']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      selfAssessment: serializer.fromJson<String?>(json['selfAssessment']),
      audioFilePath: serializer.fromJson<String?>(json['audioFilePath']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'practiceDate': serializer.toJson<DateTime>(practiceDate),
      'dayIndex': serializer.toJson<int>(dayIndex),
      'primaryPracticeType': serializer.toJson<String>(primaryPracticeType),
      'practiceTagsJson': serializer.toJson<String>(practiceTagsJson),
      'practiceContent': serializer.toJson<String>(practiceContent),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'selfAssessment': serializer.toJson<String?>(selfAssessment),
      'audioFilePath': serializer.toJson<String?>(audioFilePath),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PracticeRecordData copyWith(
          {String? id,
          DateTime? practiceDate,
          int? dayIndex,
          String? primaryPracticeType,
          String? practiceTagsJson,
          String? practiceContent,
          int? durationSeconds,
          bool? isCompleted,
          Value<String?> selfAssessment = const Value.absent(),
          Value<String?> audioFilePath = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      PracticeRecordData(
        id: id ?? this.id,
        practiceDate: practiceDate ?? this.practiceDate,
        dayIndex: dayIndex ?? this.dayIndex,
        primaryPracticeType: primaryPracticeType ?? this.primaryPracticeType,
        practiceTagsJson: practiceTagsJson ?? this.practiceTagsJson,
        practiceContent: practiceContent ?? this.practiceContent,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        isCompleted: isCompleted ?? this.isCompleted,
        selfAssessment:
            selfAssessment.present ? selfAssessment.value : this.selfAssessment,
        audioFilePath:
            audioFilePath.present ? audioFilePath.value : this.audioFilePath,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  PracticeRecordData copyWithCompanion(PracticeRecordsCompanion data) {
    return PracticeRecordData(
      id: data.id.present ? data.id.value : this.id,
      practiceDate: data.practiceDate.present
          ? data.practiceDate.value
          : this.practiceDate,
      dayIndex: data.dayIndex.present ? data.dayIndex.value : this.dayIndex,
      primaryPracticeType: data.primaryPracticeType.present
          ? data.primaryPracticeType.value
          : this.primaryPracticeType,
      practiceTagsJson: data.practiceTagsJson.present
          ? data.practiceTagsJson.value
          : this.practiceTagsJson,
      practiceContent: data.practiceContent.present
          ? data.practiceContent.value
          : this.practiceContent,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      isCompleted:
          data.isCompleted.present ? data.isCompleted.value : this.isCompleted,
      selfAssessment: data.selfAssessment.present
          ? data.selfAssessment.value
          : this.selfAssessment,
      audioFilePath: data.audioFilePath.present
          ? data.audioFilePath.value
          : this.audioFilePath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PracticeRecordData(')
          ..write('id: $id, ')
          ..write('practiceDate: $practiceDate, ')
          ..write('dayIndex: $dayIndex, ')
          ..write('primaryPracticeType: $primaryPracticeType, ')
          ..write('practiceTagsJson: $practiceTagsJson, ')
          ..write('practiceContent: $practiceContent, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('selfAssessment: $selfAssessment, ')
          ..write('audioFilePath: $audioFilePath, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      practiceDate,
      dayIndex,
      primaryPracticeType,
      practiceTagsJson,
      practiceContent,
      durationSeconds,
      isCompleted,
      selfAssessment,
      audioFilePath,
      createdAt,
      updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PracticeRecordData &&
          other.id == this.id &&
          other.practiceDate == this.practiceDate &&
          other.dayIndex == this.dayIndex &&
          other.primaryPracticeType == this.primaryPracticeType &&
          other.practiceTagsJson == this.practiceTagsJson &&
          other.practiceContent == this.practiceContent &&
          other.durationSeconds == this.durationSeconds &&
          other.isCompleted == this.isCompleted &&
          other.selfAssessment == this.selfAssessment &&
          other.audioFilePath == this.audioFilePath &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class PracticeRecordsCompanion extends UpdateCompanion<PracticeRecordData> {
  final Value<String> id;
  final Value<DateTime> practiceDate;
  final Value<int> dayIndex;
  final Value<String> primaryPracticeType;
  final Value<String> practiceTagsJson;
  final Value<String> practiceContent;
  final Value<int> durationSeconds;
  final Value<bool> isCompleted;
  final Value<String?> selfAssessment;
  final Value<String?> audioFilePath;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PracticeRecordsCompanion({
    this.id = const Value.absent(),
    this.practiceDate = const Value.absent(),
    this.dayIndex = const Value.absent(),
    this.primaryPracticeType = const Value.absent(),
    this.practiceTagsJson = const Value.absent(),
    this.practiceContent = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.selfAssessment = const Value.absent(),
    this.audioFilePath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PracticeRecordsCompanion.insert({
    required String id,
    required DateTime practiceDate,
    required int dayIndex,
    required String primaryPracticeType,
    required String practiceTagsJson,
    required String practiceContent,
    required int durationSeconds,
    this.isCompleted = const Value.absent(),
    this.selfAssessment = const Value.absent(),
    this.audioFilePath = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        practiceDate = Value(practiceDate),
        dayIndex = Value(dayIndex),
        primaryPracticeType = Value(primaryPracticeType),
        practiceTagsJson = Value(practiceTagsJson),
        practiceContent = Value(practiceContent),
        durationSeconds = Value(durationSeconds),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<PracticeRecordData> custom({
    Expression<String>? id,
    Expression<DateTime>? practiceDate,
    Expression<int>? dayIndex,
    Expression<String>? primaryPracticeType,
    Expression<String>? practiceTagsJson,
    Expression<String>? practiceContent,
    Expression<int>? durationSeconds,
    Expression<bool>? isCompleted,
    Expression<String>? selfAssessment,
    Expression<String>? audioFilePath,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (practiceDate != null) 'practice_date': practiceDate,
      if (dayIndex != null) 'day_index': dayIndex,
      if (primaryPracticeType != null)
        'primary_practice_type': primaryPracticeType,
      if (practiceTagsJson != null) 'practice_tags_json': practiceTagsJson,
      if (practiceContent != null) 'practice_content': practiceContent,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (selfAssessment != null) 'self_assessment': selfAssessment,
      if (audioFilePath != null) 'audio_file_path': audioFilePath,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PracticeRecordsCompanion copyWith(
      {Value<String>? id,
      Value<DateTime>? practiceDate,
      Value<int>? dayIndex,
      Value<String>? primaryPracticeType,
      Value<String>? practiceTagsJson,
      Value<String>? practiceContent,
      Value<int>? durationSeconds,
      Value<bool>? isCompleted,
      Value<String?>? selfAssessment,
      Value<String?>? audioFilePath,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return PracticeRecordsCompanion(
      id: id ?? this.id,
      practiceDate: practiceDate ?? this.practiceDate,
      dayIndex: dayIndex ?? this.dayIndex,
      primaryPracticeType: primaryPracticeType ?? this.primaryPracticeType,
      practiceTagsJson: practiceTagsJson ?? this.practiceTagsJson,
      practiceContent: practiceContent ?? this.practiceContent,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isCompleted: isCompleted ?? this.isCompleted,
      selfAssessment: selfAssessment ?? this.selfAssessment,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (practiceDate.present) {
      map['practice_date'] = Variable<DateTime>(practiceDate.value);
    }
    if (dayIndex.present) {
      map['day_index'] = Variable<int>(dayIndex.value);
    }
    if (primaryPracticeType.present) {
      map['primary_practice_type'] =
          Variable<String>(primaryPracticeType.value);
    }
    if (practiceTagsJson.present) {
      map['practice_tags_json'] = Variable<String>(practiceTagsJson.value);
    }
    if (practiceContent.present) {
      map['practice_content'] = Variable<String>(practiceContent.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (selfAssessment.present) {
      map['self_assessment'] = Variable<String>(selfAssessment.value);
    }
    if (audioFilePath.present) {
      map['audio_file_path'] = Variable<String>(audioFilePath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PracticeRecordsCompanion(')
          ..write('id: $id, ')
          ..write('practiceDate: $practiceDate, ')
          ..write('dayIndex: $dayIndex, ')
          ..write('primaryPracticeType: $primaryPracticeType, ')
          ..write('practiceTagsJson: $practiceTagsJson, ')
          ..write('practiceContent: $practiceContent, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('selfAssessment: $selfAssessment, ')
          ..write('audioFilePath: $audioFilePath, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserSettingsTable extends UserSettings
    with TableInfo<$UserSettingsTable, UserSettingData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_settings';
  @override
  VerificationContext validateIntegrity(Insertable<UserSettingData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  UserSettingData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserSettingData(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $UserSettingsTable createAlias(String alias) {
    return $UserSettingsTable(attachedDatabase, alias);
  }
}

class UserSettingData extends DataClass implements Insertable<UserSettingData> {
  /// Stable identifier (e.g. `app.installDate`, `metronome.defaultBpm`).
  /// Primary key.
  final String key;

  /// String-serialised value. Repository layer is responsible for
  /// encoding / decoding the concrete type (int / double / ISO date).
  final String value;

  /// Last write timestamp. Useful for debugging and for future
  /// "settings changed" audit features.
  final DateTime updatedAt;
  const UserSettingData(
      {required this.key, required this.value, required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserSettingsCompanion toCompanion(bool nullToAbsent) {
    return UserSettingsCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserSettingData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserSettingData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserSettingData copyWith({String? key, String? value, DateTime? updatedAt}) =>
      UserSettingData(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  UserSettingData copyWithCompanion(UserSettingsCompanion data) {
    return UserSettingData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserSettingData(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserSettingData &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class UserSettingsCompanion extends UpdateCompanion<UserSettingData> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const UserSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserSettingsCompanion.insert({
    required String key,
    required String value,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value),
        updatedAt = Value(updatedAt);
  static Insertable<UserSettingData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserSettingsCompanion copyWith(
      {Value<String>? key,
      Value<String>? value,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return UserSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CompletedTasksTable extends CompletedTasks
    with TableInfo<$CompletedTasksTable, CompletedTaskData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CompletedTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localDateMeta =
      const VerificationMeta('localDate');
  @override
  late final GeneratedColumn<String> localDate = GeneratedColumn<String>(
      'local_date', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
      'task_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
      'completed_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [localDate, taskId, completedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'completed_tasks';
  @override
  VerificationContext validateIntegrity(Insertable<CompletedTaskData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_date')) {
      context.handle(_localDateMeta,
          localDate.isAcceptableOrUnknown(data['local_date']!, _localDateMeta));
    } else if (isInserting) {
      context.missing(_localDateMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(_taskIdMeta,
          taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta));
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
          _completedAtMeta,
          completedAt.isAcceptableOrUnknown(
              data['completed_at']!, _completedAtMeta));
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localDate, taskId};
  @override
  CompletedTaskData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CompletedTaskData(
      localDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_date'])!,
      taskId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}task_id'])!,
      completedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}completed_at'])!,
    );
  }

  @override
  $CompletedTasksTable createAlias(String alias) {
    return $CompletedTasksTable(attachedDatabase, alias);
  }
}

class CompletedTaskData extends DataClass
    implements Insertable<CompletedTaskData> {
  /// Local calendar date normalised to ISO-8601 `YYYY-MM-DD`. We use
  /// a `TEXT` column (rather than `INTEGER` epoch) because local
  /// dates do not have a timezone — comparing `"2026-06-20"` against
  /// `DateTime(2026, 6, 20)` would otherwise be a footgun. The
  /// Repository layer (T013.2+) is the single place that converts
  /// between `DateTime` ↔ ISO string.
  final String localDate;

  /// Stable task id, e.g. `day1_tuner` (see
  /// `lib/features/home/domain/practice_task.dart`).
  final String taskId;

  /// Moment the user toggled the checkbox most recently.
  final DateTime completedAt;
  const CompletedTaskData(
      {required this.localDate,
      required this.taskId,
      required this.completedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_date'] = Variable<String>(localDate);
    map['task_id'] = Variable<String>(taskId);
    map['completed_at'] = Variable<DateTime>(completedAt);
    return map;
  }

  CompletedTasksCompanion toCompanion(bool nullToAbsent) {
    return CompletedTasksCompanion(
      localDate: Value(localDate),
      taskId: Value(taskId),
      completedAt: Value(completedAt),
    );
  }

  factory CompletedTaskData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CompletedTaskData(
      localDate: serializer.fromJson<String>(json['localDate']),
      taskId: serializer.fromJson<String>(json['taskId']),
      completedAt: serializer.fromJson<DateTime>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localDate': serializer.toJson<String>(localDate),
      'taskId': serializer.toJson<String>(taskId),
      'completedAt': serializer.toJson<DateTime>(completedAt),
    };
  }

  CompletedTaskData copyWith(
          {String? localDate, String? taskId, DateTime? completedAt}) =>
      CompletedTaskData(
        localDate: localDate ?? this.localDate,
        taskId: taskId ?? this.taskId,
        completedAt: completedAt ?? this.completedAt,
      );
  CompletedTaskData copyWithCompanion(CompletedTasksCompanion data) {
    return CompletedTaskData(
      localDate: data.localDate.present ? data.localDate.value : this.localDate,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CompletedTaskData(')
          ..write('localDate: $localDate, ')
          ..write('taskId: $taskId, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(localDate, taskId, completedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CompletedTaskData &&
          other.localDate == this.localDate &&
          other.taskId == this.taskId &&
          other.completedAt == this.completedAt);
}

class CompletedTasksCompanion extends UpdateCompanion<CompletedTaskData> {
  final Value<String> localDate;
  final Value<String> taskId;
  final Value<DateTime> completedAt;
  final Value<int> rowid;
  const CompletedTasksCompanion({
    this.localDate = const Value.absent(),
    this.taskId = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CompletedTasksCompanion.insert({
    required String localDate,
    required String taskId,
    required DateTime completedAt,
    this.rowid = const Value.absent(),
  })  : localDate = Value(localDate),
        taskId = Value(taskId),
        completedAt = Value(completedAt);
  static Insertable<CompletedTaskData> custom({
    Expression<String>? localDate,
    Expression<String>? taskId,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localDate != null) 'local_date': localDate,
      if (taskId != null) 'task_id': taskId,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CompletedTasksCompanion copyWith(
      {Value<String>? localDate,
      Value<String>? taskId,
      Value<DateTime>? completedAt,
      Value<int>? rowid}) {
    return CompletedTasksCompanion(
      localDate: localDate ?? this.localDate,
      taskId: taskId ?? this.taskId,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localDate.present) {
      map['local_date'] = Variable<String>(localDate.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CompletedTasksCompanion(')
          ..write('localDate: $localDate, ')
          ..write('taskId: $taskId, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PracticeRecordsTable practiceRecords =
      $PracticeRecordsTable(this);
  late final $UserSettingsTable userSettings = $UserSettingsTable(this);
  late final $CompletedTasksTable completedTasks = $CompletedTasksTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [practiceRecords, userSettings, completedTasks];
}

typedef $$PracticeRecordsTableCreateCompanionBuilder = PracticeRecordsCompanion
    Function({
  required String id,
  required DateTime practiceDate,
  required int dayIndex,
  required String primaryPracticeType,
  required String practiceTagsJson,
  required String practiceContent,
  required int durationSeconds,
  Value<bool> isCompleted,
  Value<String?> selfAssessment,
  Value<String?> audioFilePath,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$PracticeRecordsTableUpdateCompanionBuilder = PracticeRecordsCompanion
    Function({
  Value<String> id,
  Value<DateTime> practiceDate,
  Value<int> dayIndex,
  Value<String> primaryPracticeType,
  Value<String> practiceTagsJson,
  Value<String> practiceContent,
  Value<int> durationSeconds,
  Value<bool> isCompleted,
  Value<String?> selfAssessment,
  Value<String?> audioFilePath,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$PracticeRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $PracticeRecordsTable> {
  $$PracticeRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get practiceDate => $composableBuilder(
      column: $table.practiceDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get dayIndex => $composableBuilder(
      column: $table.dayIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get primaryPracticeType => $composableBuilder(
      column: $table.primaryPracticeType,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get practiceTagsJson => $composableBuilder(
      column: $table.practiceTagsJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get practiceContent => $composableBuilder(
      column: $table.practiceContent,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isCompleted => $composableBuilder(
      column: $table.isCompleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get selfAssessment => $composableBuilder(
      column: $table.selfAssessment,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get audioFilePath => $composableBuilder(
      column: $table.audioFilePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$PracticeRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $PracticeRecordsTable> {
  $$PracticeRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get practiceDate => $composableBuilder(
      column: $table.practiceDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get dayIndex => $composableBuilder(
      column: $table.dayIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get primaryPracticeType => $composableBuilder(
      column: $table.primaryPracticeType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get practiceTagsJson => $composableBuilder(
      column: $table.practiceTagsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get practiceContent => $composableBuilder(
      column: $table.practiceContent,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
      column: $table.isCompleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get selfAssessment => $composableBuilder(
      column: $table.selfAssessment,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get audioFilePath => $composableBuilder(
      column: $table.audioFilePath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$PracticeRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PracticeRecordsTable> {
  $$PracticeRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get practiceDate => $composableBuilder(
      column: $table.practiceDate, builder: (column) => column);

  GeneratedColumn<int> get dayIndex =>
      $composableBuilder(column: $table.dayIndex, builder: (column) => column);

  GeneratedColumn<String> get primaryPracticeType => $composableBuilder(
      column: $table.primaryPracticeType, builder: (column) => column);

  GeneratedColumn<String> get practiceTagsJson => $composableBuilder(
      column: $table.practiceTagsJson, builder: (column) => column);

  GeneratedColumn<String> get practiceContent => $composableBuilder(
      column: $table.practiceContent, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds, builder: (column) => column);

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
      column: $table.isCompleted, builder: (column) => column);

  GeneratedColumn<String> get selfAssessment => $composableBuilder(
      column: $table.selfAssessment, builder: (column) => column);

  GeneratedColumn<String> get audioFilePath => $composableBuilder(
      column: $table.audioFilePath, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PracticeRecordsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PracticeRecordsTable,
    PracticeRecordData,
    $$PracticeRecordsTableFilterComposer,
    $$PracticeRecordsTableOrderingComposer,
    $$PracticeRecordsTableAnnotationComposer,
    $$PracticeRecordsTableCreateCompanionBuilder,
    $$PracticeRecordsTableUpdateCompanionBuilder,
    (
      PracticeRecordData,
      BaseReferences<_$AppDatabase, $PracticeRecordsTable, PracticeRecordData>
    ),
    PracticeRecordData,
    PrefetchHooks Function()> {
  $$PracticeRecordsTableTableManager(
      _$AppDatabase db, $PracticeRecordsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PracticeRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PracticeRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PracticeRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> practiceDate = const Value.absent(),
            Value<int> dayIndex = const Value.absent(),
            Value<String> primaryPracticeType = const Value.absent(),
            Value<String> practiceTagsJson = const Value.absent(),
            Value<String> practiceContent = const Value.absent(),
            Value<int> durationSeconds = const Value.absent(),
            Value<bool> isCompleted = const Value.absent(),
            Value<String?> selfAssessment = const Value.absent(),
            Value<String?> audioFilePath = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PracticeRecordsCompanion(
            id: id,
            practiceDate: practiceDate,
            dayIndex: dayIndex,
            primaryPracticeType: primaryPracticeType,
            practiceTagsJson: practiceTagsJson,
            practiceContent: practiceContent,
            durationSeconds: durationSeconds,
            isCompleted: isCompleted,
            selfAssessment: selfAssessment,
            audioFilePath: audioFilePath,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required DateTime practiceDate,
            required int dayIndex,
            required String primaryPracticeType,
            required String practiceTagsJson,
            required String practiceContent,
            required int durationSeconds,
            Value<bool> isCompleted = const Value.absent(),
            Value<String?> selfAssessment = const Value.absent(),
            Value<String?> audioFilePath = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              PracticeRecordsCompanion.insert(
            id: id,
            practiceDate: practiceDate,
            dayIndex: dayIndex,
            primaryPracticeType: primaryPracticeType,
            practiceTagsJson: practiceTagsJson,
            practiceContent: practiceContent,
            durationSeconds: durationSeconds,
            isCompleted: isCompleted,
            selfAssessment: selfAssessment,
            audioFilePath: audioFilePath,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PracticeRecordsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PracticeRecordsTable,
    PracticeRecordData,
    $$PracticeRecordsTableFilterComposer,
    $$PracticeRecordsTableOrderingComposer,
    $$PracticeRecordsTableAnnotationComposer,
    $$PracticeRecordsTableCreateCompanionBuilder,
    $$PracticeRecordsTableUpdateCompanionBuilder,
    (
      PracticeRecordData,
      BaseReferences<_$AppDatabase, $PracticeRecordsTable, PracticeRecordData>
    ),
    PracticeRecordData,
    PrefetchHooks Function()>;
typedef $$UserSettingsTableCreateCompanionBuilder = UserSettingsCompanion
    Function({
  required String key,
  required String value,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$UserSettingsTableUpdateCompanionBuilder = UserSettingsCompanion
    Function({
  Value<String> key,
  Value<String> value,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$UserSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $UserSettingsTable> {
  $$UserSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$UserSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $UserSettingsTable> {
  $$UserSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$UserSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserSettingsTable> {
  $$UserSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UserSettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UserSettingsTable,
    UserSettingData,
    $$UserSettingsTableFilterComposer,
    $$UserSettingsTableOrderingComposer,
    $$UserSettingsTableAnnotationComposer,
    $$UserSettingsTableCreateCompanionBuilder,
    $$UserSettingsTableUpdateCompanionBuilder,
    (
      UserSettingData,
      BaseReferences<_$AppDatabase, $UserSettingsTable, UserSettingData>
    ),
    UserSettingData,
    PrefetchHooks Function()> {
  $$UserSettingsTableTableManager(_$AppDatabase db, $UserSettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UserSettingsCompanion(
            key: key,
            value: value,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              UserSettingsCompanion.insert(
            key: key,
            value: value,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UserSettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UserSettingsTable,
    UserSettingData,
    $$UserSettingsTableFilterComposer,
    $$UserSettingsTableOrderingComposer,
    $$UserSettingsTableAnnotationComposer,
    $$UserSettingsTableCreateCompanionBuilder,
    $$UserSettingsTableUpdateCompanionBuilder,
    (
      UserSettingData,
      BaseReferences<_$AppDatabase, $UserSettingsTable, UserSettingData>
    ),
    UserSettingData,
    PrefetchHooks Function()>;
typedef $$CompletedTasksTableCreateCompanionBuilder = CompletedTasksCompanion
    Function({
  required String localDate,
  required String taskId,
  required DateTime completedAt,
  Value<int> rowid,
});
typedef $$CompletedTasksTableUpdateCompanionBuilder = CompletedTasksCompanion
    Function({
  Value<String> localDate,
  Value<String> taskId,
  Value<DateTime> completedAt,
  Value<int> rowid,
});

class $$CompletedTasksTableFilterComposer
    extends Composer<_$AppDatabase, $CompletedTasksTable> {
  $$CompletedTasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get localDate => $composableBuilder(
      column: $table.localDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get taskId => $composableBuilder(
      column: $table.taskId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnFilters(column));
}

class $$CompletedTasksTableOrderingComposer
    extends Composer<_$AppDatabase, $CompletedTasksTable> {
  $$CompletedTasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get localDate => $composableBuilder(
      column: $table.localDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get taskId => $composableBuilder(
      column: $table.taskId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnOrderings(column));
}

class $$CompletedTasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $CompletedTasksTable> {
  $$CompletedTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get localDate =>
      $composableBuilder(column: $table.localDate, builder: (column) => column);

  GeneratedColumn<String> get taskId =>
      $composableBuilder(column: $table.taskId, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => column);
}

class $$CompletedTasksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CompletedTasksTable,
    CompletedTaskData,
    $$CompletedTasksTableFilterComposer,
    $$CompletedTasksTableOrderingComposer,
    $$CompletedTasksTableAnnotationComposer,
    $$CompletedTasksTableCreateCompanionBuilder,
    $$CompletedTasksTableUpdateCompanionBuilder,
    (
      CompletedTaskData,
      BaseReferences<_$AppDatabase, $CompletedTasksTable, CompletedTaskData>
    ),
    CompletedTaskData,
    PrefetchHooks Function()> {
  $$CompletedTasksTableTableManager(
      _$AppDatabase db, $CompletedTasksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CompletedTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CompletedTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CompletedTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> localDate = const Value.absent(),
            Value<String> taskId = const Value.absent(),
            Value<DateTime> completedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CompletedTasksCompanion(
            localDate: localDate,
            taskId: taskId,
            completedAt: completedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String localDate,
            required String taskId,
            required DateTime completedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CompletedTasksCompanion.insert(
            localDate: localDate,
            taskId: taskId,
            completedAt: completedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CompletedTasksTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CompletedTasksTable,
    CompletedTaskData,
    $$CompletedTasksTableFilterComposer,
    $$CompletedTasksTableOrderingComposer,
    $$CompletedTasksTableAnnotationComposer,
    $$CompletedTasksTableCreateCompanionBuilder,
    $$CompletedTasksTableUpdateCompanionBuilder,
    (
      CompletedTaskData,
      BaseReferences<_$AppDatabase, $CompletedTasksTable, CompletedTaskData>
    ),
    CompletedTaskData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PracticeRecordsTableTableManager get practiceRecords =>
      $$PracticeRecordsTableTableManager(_db, _db.practiceRecords);
  $$UserSettingsTableTableManager get userSettings =>
      $$UserSettingsTableTableManager(_db, _db.userSettings);
  $$CompletedTasksTableTableManager get completedTasks =>
      $$CompletedTasksTableTableManager(_db, _db.completedTasks);
}
