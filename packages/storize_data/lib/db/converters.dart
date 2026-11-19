import 'package:drift/drift.dart';
import 'package:storize_model/storize_model.dart';

/// Stores a [DateTime] as INTEGER epoch milliseconds (UTC), as TECH_SPEC §3
/// requires. Reads come back as UTC [DateTime]s.
class EpochMsConverter extends TypeConverter<DateTime, int> {
  const EpochMsConverter();

  @override
  DateTime fromSql(int fromDb) =>
      DateTime.fromMillisecondsSinceEpoch(fromDb, isUtc: true);

  @override
  int toSql(DateTime value) => value.millisecondsSinceEpoch;
}

/// Maps a `storize_model` enum to the TEXT `dbValue` the schema stores.
///
/// An unknown stored value throws [ArgumentError] (from the enum's `fromDb`).

class PlatformIdConverter extends TypeConverter<PlatformId, String> {
  const PlatformIdConverter();

  @override
  PlatformId fromSql(String fromDb) => PlatformId.fromDb(fromDb);

  @override
  String toSql(PlatformId value) => value.dbValue;
}

class ContentKindConverter extends TypeConverter<ContentKind, String> {
  const ContentKindConverter();

  @override
  ContentKind fromSql(String fromDb) => ContentKind.fromDb(fromDb);

  @override
  String toSql(ContentKind value) => value.dbValue;
}

class PostTypeConverter extends TypeConverter<PostType, String> {
  const PostTypeConverter();

  @override
  PostType fromSql(String fromDb) => PostType.fromDb(fromDb);

  @override
  String toSql(PostType value) => value.dbValue;
}

class MediaTypeConverter extends TypeConverter<MediaType, String> {
  const MediaTypeConverter();

  @override
  MediaType fromSql(String fromDb) => MediaType.fromDb(fromDb);

  @override
  String toSql(MediaType value) => value.dbValue;
}

class TargetCategoryConverter extends TypeConverter<TargetCategory, String> {
  const TargetCategoryConverter();

  @override
  TargetCategory fromSql(String fromDb) => TargetCategory.fromDb(fromDb);

  @override
  String toSql(TargetCategory value) => value.dbValue;
}

class TargetStatusConverter extends TypeConverter<TargetStatus, String> {
  const TargetStatusConverter();

  @override
  TargetStatus fromSql(String fromDb) => TargetStatus.fromDb(fromDb);

  @override
  String toSql(TargetStatus value) => value.dbValue;
}

class AccountStatusConverter extends TypeConverter<AccountStatus, String> {
  const AccountStatusConverter();

  @override
  AccountStatus fromSql(String fromDb) => AccountStatus.fromDb(fromDb);

  @override
  String toSql(AccountStatus value) => value.dbValue;
}

class ContentStatusConverter extends TypeConverter<ContentStatus, String> {
  const ContentStatusConverter();

  @override
  ContentStatus fromSql(String fromDb) => ContentStatus.fromDb(fromDb);

  @override
  String toSql(ContentStatus value) => value.dbValue;
}

class MediaFileStatusConverter extends TypeConverter<MediaFileStatus, String> {
  const MediaFileStatusConverter();

  @override
  MediaFileStatus fromSql(String fromDb) => MediaFileStatus.fromDb(fromDb);

  @override
  String toSql(MediaFileStatus value) => value.dbValue;
}

class CheckTriggerConverter extends TypeConverter<CheckTrigger, String> {
  const CheckTriggerConverter();

  @override
  CheckTrigger fromSql(String fromDb) => CheckTrigger.fromDb(fromDb);

  @override
  String toSql(CheckTrigger value) => value.dbValue;
}

class CheckResultConverter extends TypeConverter<CheckResult, String> {
  const CheckResultConverter();

  @override
  CheckResult fromSql(String fromDb) => CheckResult.fromDb(fromDb);

  @override
  String toSql(CheckResult value) => value.dbValue;
}

class ExtractionModeConverter extends TypeConverter<ExtractionMode, String> {
  const ExtractionModeConverter();

  @override
  ExtractionMode fromSql(String fromDb) => ExtractionMode.fromDb(fromDb);

  @override
  String toSql(ExtractionMode value) => value.dbValue;
}

class ActivityTypeConverter extends TypeConverter<ActivityType, String> {
  const ActivityTypeConverter();

  @override
  ActivityType fromSql(String fromDb) => ActivityType.fromDb(fromDb);

  @override
  String toSql(ActivityType value) => value.dbValue;
}

class SeverityConverter extends TypeConverter<Severity, String> {
  const SeverityConverter();

  @override
  Severity fromSql(String fromDb) => Severity.fromDb(fromDb);

  @override
  String toSql(Severity value) => value.dbValue;
}

/// `check_run.scope` only holds STORIES or POSTS. [CheckScope.all] is a Dart
/// only value, so writing it throws before SQL runs (the CHECK constraint is
/// the second line of defence).
class CheckRunScopeConverter extends TypeConverter<CheckScope, String> {
  const CheckRunScopeConverter();

  @override
  CheckScope fromSql(String fromDb) => CheckScope.fromDb(fromDb);

  @override
  String toSql(CheckScope value) {
    if (value == CheckScope.all) {
      throw ArgumentError.value(
        value,
        'value',
        'check_run.scope must be STORIES or POSTS, never ALL',
      );
    }
    return value.dbValue;
  }
}
