import 'package:storize_domain/src/entities/app_settings.dart';
import 'package:storize_domain/src/exceptions.dart';

/// Access to user settings.
abstract interface class SettingsRepo {
  /// Emits the current settings now and after every change.
  Stream<AppSettings> watch();

  /// The current settings (defaults when nothing is stored).
  Future<AppSettings> get();

  /// Applies [change] to the current settings, validates the result with
  /// `AppSettings.validationErrors`, stores it and returns it.
  ///
  /// Throws [SettingsValidationException] and stores nothing when the result
  /// is invalid (for example a story interval of 10 minutes).
  Future<AppSettings> update(AppSettings Function(AppSettings current) change);
}
