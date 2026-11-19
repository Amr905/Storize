import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_data/db/db.dart';
import 'package:storize_model/storize_model.dart';

/// A fresh in-memory database.
StorizeDatabase newDb() => StorizeDatabase.forTesting(NativeDatabase.memory());

final DateTime t0 = DateTime.utc(2026, 11, 19, 10);

DateTime minutesAfter(int minutes) => t0.add(Duration(minutes: minutes));

Future<int> addAccount(
  StorizeDatabase db, {
  String remoteUserId = 'acct-1',
  AccountStatus status = AccountStatus.active,
}) => db.accountDao
    .upsert(
      LoginAccountsCompanion.insert(
        platform: PlatformId.instagram,
        remoteUserId: remoteUserId,
        username: 'tester_$remoteUserId',
        status: status,
        connectedAt: t0,
      ),
    )
    .then((row) => row.id);

TargetsCompanion targetCompanion({
  String remoteUserId = 'u-1',
  String username = 'user_one',
  int? loginAccountId,
  bool trackStories = true,
  bool trackPosts = true,
  bool trackReels = true,
  TargetStatus status = TargetStatus.active,
}) => TargetsCompanion.insert(
  platform: PlatformId.instagram,
  remoteUserId: remoteUserId,
  username: username,
  category: TargetCategory.public,
  status: status,
  postsWatermarkAt: t0,
  addedAt: t0,
  loginAccountId: Value(loginAccountId),
  trackStories: Value(trackStories),
  trackPosts: Value(trackPosts),
  trackReels: Value(trackReels),
);

Future<int> addTarget(
  StorizeDatabase db, {
  String remoteUserId = 'u-1',
  String username = 'user_one',
  int? loginAccountId,
  TargetStatus status = TargetStatus.active,
}) => db.targetsDao.insert(
  targetCompanion(
    remoteUserId: remoteUserId,
    username: username,
    loginAccountId: loginAccountId,
    status: status,
  ),
);

ContentsCompanion contentCompanion({
  required int targetId,
  String remoteId = 'r-1',
  ContentKind kind = ContentKind.story,
  DateTime? postedAt,
  DateTime? detectedAt,
  ContentStatus status = ContentStatus.pending,
}) => ContentsCompanion.insert(
  targetId: targetId,
  kind: kind,
  remoteId: remoteId,
  postedAt: postedAt ?? t0,
  detectedAt: detectedAt ?? t0,
  status: status,
);

MediaFilesCompanion mediaCompanion({
  int slideIndex = 0,
  MediaType type = MediaType.photo,
  MediaFileStatus status = MediaFileStatus.pending,
  int? sizeBytes,
}) => MediaFilesCompanion.insert(
  // Overwritten by ContentDao.insertIfNew.
  contentId: 0,
  slideIndex: Value(slideIndex),
  mediaType: type,
  sourceUrl: 'https://cdn.example.invalid/file-$slideIndex',
  status: status,
  sizeBytes: Value(sizeBytes),
);

/// Inserts one content row with media and returns its id.
Future<int> addContent(
  StorizeDatabase db, {
  required int targetId,
  String remoteId = 'r-1',
  ContentKind kind = ContentKind.story,
  DateTime? postedAt,
  DateTime? detectedAt,
  ContentStatus status = ContentStatus.pending,
  List<MediaFilesCompanion>? media,
}) async {
  final result = await db.contentDao.insertIfNew(
    contentCompanion(
      targetId: targetId,
      remoteId: remoteId,
      kind: kind,
      postedAt: postedAt,
      detectedAt: detectedAt,
      status: status,
    ),
    media ?? [mediaCompanion()],
  );
  return result.contentId;
}

Future<int> count(StorizeDatabase db, String table) async {
  final row = await db
      .customSelect('SELECT COUNT(*) AS c FROM $table')
      .getSingle();
  return row.read<int>('c');
}

/// Matches an error whose message contains [text].
Matcher failsWith(String text) => throwsA(
  predicate<Object>(
    (e) => e.toString().contains(text),
    'error containing "$text"',
  ),
);
