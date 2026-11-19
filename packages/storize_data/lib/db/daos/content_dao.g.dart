// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'content_dao.dart';

// ignore_for_file: type=lint
mixin _$ContentDaoMixin on DatabaseAccessor<StorizeDatabase> {
  $LoginAccountsTable get loginAccounts => attachedDatabase.loginAccounts;
  $TargetsTable get targets => attachedDatabase.targets;
  $ContentsTable get contents => attachedDatabase.contents;
  $MediaFilesTable get mediaFiles => attachedDatabase.mediaFiles;
  ContentDaoManager get managers => ContentDaoManager(this);
}

class ContentDaoManager {
  final _$ContentDaoMixin _db;
  ContentDaoManager(this._db);
  $$LoginAccountsTableTableManager get loginAccounts =>
      $$LoginAccountsTableTableManager(_db.attachedDatabase, _db.loginAccounts);
  $$TargetsTableTableManager get targets =>
      $$TargetsTableTableManager(_db.attachedDatabase, _db.targets);
  $$ContentsTableTableManager get contents =>
      $$ContentsTableTableManager(_db.attachedDatabase, _db.contents);
  $$MediaFilesTableTableManager get mediaFiles =>
      $$MediaFilesTableTableManager(_db.attachedDatabase, _db.mediaFiles);
}
