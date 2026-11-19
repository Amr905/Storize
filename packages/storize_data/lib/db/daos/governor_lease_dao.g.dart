// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'governor_lease_dao.dart';

// ignore_for_file: type=lint
mixin _$GovernorLeaseDaoMixin on DatabaseAccessor<StorizeDatabase> {
  $GovernorLeasesTable get governorLeases => attachedDatabase.governorLeases;
  GovernorLeaseDaoManager get managers => GovernorLeaseDaoManager(this);
}

class GovernorLeaseDaoManager {
  final _$GovernorLeaseDaoMixin _db;
  GovernorLeaseDaoManager(this._db);
  $$GovernorLeasesTableTableManager get governorLeases =>
      $$GovernorLeasesTableTableManager(
        _db.attachedDatabase,
        _db.governorLeases,
      );
}
