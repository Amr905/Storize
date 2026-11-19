// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'check_run_dao.dart';

// ignore_for_file: type=lint
mixin _$CheckRunDaoMixin on DatabaseAccessor<StorizeDatabase> {
  $CheckRunsTable get checkRuns => attachedDatabase.checkRuns;
  CheckRunDaoManager get managers => CheckRunDaoManager(this);
}

class CheckRunDaoManager {
  final _$CheckRunDaoMixin _db;
  CheckRunDaoManager(this._db);
  $$CheckRunsTableTableManager get checkRuns =>
      $$CheckRunsTableTableManager(_db.attachedDatabase, _db.checkRuns);
}
