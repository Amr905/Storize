import 'package:storize_domain/src/entities/app_settings.dart';
import 'package:storize_domain/src/exceptions.dart';
import 'package:storize_domain/src/repos/settings_repo.dart';
import 'package:storize_domain/src/testing/change_feed.dart';

/// An in-memory [SettingsRepo] that validates like the real one.
final class FakeSettingsRepo implements SettingsRepo {
  /// Creates the repo with [initial] (the spec defaults when omitted).
  FakeSettingsRepo([AppSettings initial = const AppSettings()])
    : _settings = initial {
    final problems = initial.validationErrors;
    if (problems.isNotEmpty) throw SettingsValidationException(problems);
  }

  AppSettings _settings;
  final ChangeFeed _feed = ChangeFeed();

  @override
  Stream<AppSettings> watch() => _feed.watch(() => _settings);

  @override
  Future<AppSettings> get() async => _settings;

  @override
  Future<AppSettings> update(
    AppSettings Function(AppSettings current) change,
  ) async {
    final next = change(_settings);
    final problems = next.validationErrors;
    if (problems.isNotEmpty) throw SettingsValidationException(problems);
    _settings = next;
    _feed.notify();
    return next;
  }
}
