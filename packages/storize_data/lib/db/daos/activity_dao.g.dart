// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_dao.dart';

// ignore_for_file: type=lint
mixin _$ActivityDaoMixin on DatabaseAccessor<StorizeDatabase> {
  $LoginAccountsTable get loginAccounts => attachedDatabase.loginAccounts;
  $TargetsTable get targets => attachedDatabase.targets;
  $CheckRunsTable get checkRuns => attachedDatabase.checkRuns;
  $ActivityEventsTable get activityEvents => attachedDatabase.activityEvents;
  ActivityDaoManager get managers => ActivityDaoManager(this);
}

class ActivityDaoManager {
  final _$ActivityDaoMixin _db;
  ActivityDaoManager(this._db);
  $$LoginAccountsTableTableManager get loginAccounts =>
      $$LoginAccountsTableTableManager(_db.attachedDatabase, _db.loginAccounts);
  $$TargetsTableTableManager get targets =>
      $$TargetsTableTableManager(_db.attachedDatabase, _db.targets);
  $$CheckRunsTableTableManager get checkRuns =>
      $$CheckRunsTableTableManager(_db.attachedDatabase, _db.checkRuns);
  $$ActivityEventsTableTableManager get activityEvents =>
      $$ActivityEventsTableTableManager(
        _db.attachedDatabase,
        _db.activityEvents,
      );
}
