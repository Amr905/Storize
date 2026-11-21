import 'package:storize_app/l10n/app_localizations.dart';

/// Largest "Keep downloads" window in days (FR-54).
const int retentionMaxDays = 3650;

const int _kb = 1024;
const int _mb = 1024 * _kb;
const int _gb = 1024 * _mb;

/// Formats a byte count for S-12: GB, MB or KB with one decimal, else bytes.
String formatBytes(AppLocalizations l10n, int bytes) {
  if (bytes >= _gb) return l10n.setSizeGb(_oneDecimal(bytes / _gb));
  if (bytes >= _mb) return l10n.setSizeMb(_oneDecimal(bytes / _mb));
  if (bytes >= _kb) return l10n.setSizeKb(_oneDecimal(bytes / _kb));
  return l10n.setSizeBytes('$bytes');
}

String _oneDecimal(double value) => value.toStringAsFixed(1);

/// An interval as shown on S-12: "30 min" below an hour, "3 h" otherwise.
String intervalLabel(AppLocalizations l10n, int minutes) => minutes < 60
    ? l10n.setIntervalMinutes(minutes)
    : l10n.setIntervalHours(minutes ~/ 60);

/// Parses the "After N days" field. Returns null unless the text is a whole
/// number from 1 to [retentionMaxDays].
int? parseRetentionDays(String text) {
  final n = int.tryParse(text.trim());
  if (n == null || n < 1 || n > retentionMaxDays) return null;
  return n;
}
