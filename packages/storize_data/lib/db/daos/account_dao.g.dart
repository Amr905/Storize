// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_dao.dart';

// ignore_for_file: type=lint
mixin _$AccountDaoMixin on DatabaseAccessor<StorizeDatabase> {
  $LoginAccountsTable get loginAccounts => attachedDatabase.loginAccounts;
  AccountDaoManager get managers => AccountDaoManager(this);
}

class AccountDaoManager {
  final _$AccountDaoMixin _db;
  AccountDaoManager(this._db);
  $$LoginAccountsTableTableManager get loginAccounts =>
      $$LoginAccountsTableTableManager(_db.attachedDatabase, _db.loginAccounts);
}
