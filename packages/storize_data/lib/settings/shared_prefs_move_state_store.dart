import 'package:shared_preferences/shared_preferences.dart';
import 'package:storize_domain/storize_domain.dart';

/// [MoveStateStore] in shared preferences (FR-79), so the background task that
/// moves the files and the Settings screen see the same progress.
///
/// It uses `SharedPreferencesAsync`, which reads the platform store on every
/// call and so crosses isolates. A value that is missing or of another type
/// reads as "no move". Only counts, names and a time are stored: never a path,
/// a username or a URI.
final class SharedPrefsMoveStateStore implements MoveStateStore {
  /// Creates the store. [prefs] is injectable for tests.
  SharedPrefsMoveStateStore({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  static const String _status = 'storize.move.status';
  static const String _target = 'storize.move.target';
  static const String _total = 'storize.move.total';
  static const String _moved = 'storize.move.moved';
  static const String _missing = 'storize.move.missing';
  static const String _failed = 'storize.move.failed';
  static const String _updatedAt = 'storize.move.updatedAt';
  static const String _cancel = 'storize.move.cancel';

  /// Every key of the move state.
  static const Set<String> keys = {
    _status,
    _target,
    _total,
    _moved,
    _missing,
    _failed,
    _updatedAt,
    _cancel,
  };

  @override
  Future<MoveProgress> read() async {
    try {
      final all = await _prefs.getAll(allowList: keys);
      final status = _enum(MoveStatus.values, all[_status]);
      if (status == null || status == MoveStatus.idle) return MoveProgress.none;
      final at = all[_updatedAt];
      return MoveProgress(
        status: status,
        target: _enum(StorageTarget.values, all[_target]),
        total: _count(all[_total]),
        moved: _count(all[_moved]),
        missing: _count(all[_missing]),
        failed: _count(all[_failed]),
        updatedAt: at is int
            ? DateTime.fromMillisecondsSinceEpoch(at, isUtc: true)
            : null,
      );
    } on Object {
      return MoveProgress.none;
    }
  }

  @override
  Future<void> write(MoveProgress progress) async {
    await _prefs.setString(_status, progress.status.name);
    final target = progress.target;
    if (target == null) {
      await _prefs.remove(_target);
    } else {
      await _prefs.setString(_target, target.name);
    }
    await _prefs.setInt(_total, progress.total);
    await _prefs.setInt(_moved, progress.moved);
    await _prefs.setInt(_missing, progress.missing);
    await _prefs.setInt(_failed, progress.failed);
    final at = progress.updatedAt;
    if (at == null) {
      await _prefs.remove(_updatedAt);
    } else {
      await _prefs.setInt(_updatedAt, at.toUtc().millisecondsSinceEpoch);
    }
  }

  @override
  Future<bool> cancelRequested() async {
    try {
      return await _prefs.getBool(_cancel) ?? false;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> setCancelRequested({required bool value}) =>
      value ? _prefs.setBool(_cancel, true) : _prefs.remove(_cancel);

  static T? _enum<T extends Enum>(List<T> values, Object? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return null;
  }

  static int _count(Object? raw) => raw is int && raw >= 0 ? raw : 0;
}
