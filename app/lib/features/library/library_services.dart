import 'package:flutter/foundation.dart';
import 'package:storize_model/storize_model.dart';

/// One saved file handed to the system share sheet.
@immutable
class ShareFile {
  /// Creates a file reference.
  const ShareFile({required this.contentUri, required this.mediaType});

  /// The saved file's reference: a MediaStore URI for a gallery file, or a
  /// `file://` path for a private file (FR-79).
  final String contentUri;

  /// Whether the file is in Storize's private storage. Another app cannot read
  /// it by path: the share seam must hand it over through the app's
  /// `FileProvider` ([privateShareAuthoritySuffix]) with a temporary read
  /// grant.
  bool get isPrivate => contentUri.startsWith('file://');

  /// The local path of a private file, or null for a gallery file.
  String? get privatePath =>
      isPrivate ? Uri.parse(contentUri).toFilePath() : null;

  /// The `FileProvider` authority is the application id plus this suffix
  /// (declared in `AndroidManifest.xml`, paths in `res/xml/file_paths.xml`).
  static const String privateShareAuthoritySuffix = '.storize.files';

  /// Photo or video (decides the MIME type).
  final MediaType mediaType;
}

/// Shares saved files with other apps. A seam for the platform share sheet
/// (T-027, T-028, T-029). The default does nothing.
// ignore: one_member_abstracts, a port that tests and main() replace.
abstract interface class ShareService {
  /// Opens the share sheet for [files].
  Future<void> share(List<ShareFile> files);
}

/// The default [ShareService]: does nothing until a share package is wired.
final class NoOpShareService implements ShareService {
  /// Creates the service.
  const NoOpShareService();

  @override
  Future<void> share(List<ShareFile> files) async {}
}

/// The result of a "check now" run.
@immutable
class CheckNowResult {
  /// Creates a result. [failed] is true when the check could not run.
  const CheckNowResult({this.newItems = 0, this.failed = false});

  /// How many new items the check found.
  final int newItems;

  /// The check could not run (no session, offline, rate limited).
  final bool failed;

  @override
  bool operator ==(Object other) =>
      other is CheckNowResult &&
      other.newItems == newItems &&
      other.failed == failed;

  @override
  int get hashCode => Object.hash(newItems, failed);
}

/// Runs a check of all targets now (FR-21). T-017/T-021 wire the real
/// `RunCheck`; the default is a stub.
// ignore: one_member_abstracts, a port that tests and main() replace.
abstract interface class CheckNowAction {
  /// Runs the check and completes with its outcome. Never throws for expected
  /// failures; report them with [CheckNowResult.failed].
  ///
  /// With [targetId], only that target is checked (S-09); otherwise all active
  /// targets.
  Future<CheckNowResult> call({int? targetId});
}

/// The default [CheckNowAction]: completes at once with nothing new.
final class StubCheckNowAction implements CheckNowAction {
  /// Creates the stub.
  const StubCheckNowAction();

  @override
  Future<CheckNowResult> call({int? targetId}) async => const CheckNowResult();
}
