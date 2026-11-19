import 'dart:convert';
import 'dart:io';

import 'package:storize_data/log/redactor.dart';
import 'package:storize_domain/storize_domain.dart';
import 'package:storize_model/storize_model.dart';

/// What the crash marker holds: no secrets, no stack trace.
final class CrashInfo {
  /// Creates the info.
  const CrashInfo({required this.type, required this.summary, this.at});

  /// The error's runtime type, for example `StateError`.
  final String type;

  /// The redacted first line of the error message.
  final String summary;

  /// When it happened (UTC), if known.
  final DateTime? at;
}

/// A tiny file (`crash_marker.json`) written when the app crashes, so the next
/// start can add an `APP_CRASH` activity (TECH_SPEC §4.3 error table).
///
/// All methods are synchronous on purpose: they run inside crash handlers,
/// where the process may die at any moment.
final class CrashMarker {
  /// Creates a marker stored as [fileName] inside [directory].
  CrashMarker(this.directory, {this.fileName = 'crash_marker.json'});

  /// The directory holding the marker.
  final Directory directory;

  /// The marker file name.
  final String fileName;

  /// The marker file.
  File get file => File('${directory.path}/$fileName');

  /// Records a crash of [error] at [at]. Keeps the first marker when one is
  /// already pending (the first error is the likeliest root cause). Stores
  /// only the type and a redacted first line. Never throws.
  void write(Object error, DateTime at) {
    try {
      if (file.existsSync()) return;
      if (!directory.existsSync()) directory.createSync(recursive: true);
      String text;
      try {
        text = error.toString();
      } on Object {
        text = '';
      }
      final type = error.runtimeType.toString().replaceAll(
        RegExp('[^A-Za-z0-9_<>?, ]'),
        '',
      );
      file.writeAsStringSync(
        jsonEncode({
          'type': type.length > 80 ? type.substring(0, 80) : type,
          'summary': Redactor.redactFirstLine(text),
          'at': at.toUtc().toIso8601String(),
        }),
        flush: true,
      );
    } on Object {
      // Never throw from a crash handler.
    }
  }

  /// The pending crash, or null when there is none. A marker that exists but
  /// cannot be read still counts as a crash, with type `Unknown`.
  CrashInfo? read() {
    try {
      if (!file.existsSync()) return null;
    } on Object {
      return null;
    }
    try {
      final json = jsonDecode(file.readAsStringSync());
      if (json is Map) {
        final at = json['at'];
        return CrashInfo(
          type: json['type'] is String ? json['type'] as String : 'Unknown',
          summary: json['summary'] is String
              ? Redactor.redactFirstLine(json['summary'] as String)
              : '',
          at: at is String ? DateTime.tryParse(at)?.toUtc() : null,
        );
      }
    } on Object {
      // Fall through to the unreadable case.
    }
    return const CrashInfo(type: 'Unknown', summary: '');
  }

  /// Deletes the marker. Returns true only for the caller that actually
  /// deleted it, so two racing callers cannot both claim it.
  bool clear() {
    try {
      file.deleteSync();
      return true;
    } on Object {
      return false;
    }
  }

  /// Puts a [CrashInfo] back after a failed report.
  void restore(CrashInfo info) {
    try {
      if (!directory.existsSync()) directory.createSync(recursive: true);
      file.writeAsStringSync(
        jsonEncode({
          'type': info.type,
          'summary': info.summary,
          'at': info.at?.toIso8601String(),
        }),
        flush: true,
      );
    } on Object {
      // Best effort.
    }
  }
}

/// Records one `APP_CRASH` activity if [marker] holds a pending crash, then
/// clears the marker. Call it once on each start, after the database is open.
///
/// Returns true if an activity was added. Idempotent: a second call (or a
/// racing call from another isolate) finds no marker and returns false. If
/// adding fails the marker is restored and the error is rethrown, so the
/// report is retried on the next start.
Future<bool> reportPendingCrash(
  ActivityRepo activities,
  Clock clock, {
  required CrashMarker marker,
}) async {
  final info = marker.read();
  if (info == null) return false;
  if (!marker.clear()) return false;
  try {
    await activities.add(
      ActivityEvent(
        id: ActivityEvent.unsavedId,
        at: clock.now(),
        type: ActivityType.appCrash,
        severity: Severity.error,
        payload: {
          'errorType': info.type,
          'summary': info.summary,
          if (info.at != null) 'crashedAt': info.at!.toIso8601String(),
        },
      ),
    );
  } on Object {
    marker.restore(info);
    rethrow;
  }
  return true;
}
