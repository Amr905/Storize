// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'storize_database.dart';

// ignore_for_file: type=lint
class $LoginAccountsTable extends LoginAccounts
    with TableInfo<$LoginAccountsTable, LoginAccountRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LoginAccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<PlatformId, String> platform =
      GeneratedColumn<String>(
        'platform',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<PlatformId>($LoginAccountsTable.$converterplatform);
  static const VerificationMeta _remoteUserIdMeta = const VerificationMeta(
    'remoteUserId',
  );
  @override
  late final GeneratedColumn<String> remoteUserId = GeneratedColumn<String>(
    'remote_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AccountStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<AccountStatus>($LoginAccountsTable.$converterstatus);
  static const VerificationMeta _statusReasonMeta = const VerificationMeta(
    'statusReason',
  );
  @override
  late final GeneratedColumn<String> statusReason = GeneratedColumn<String>(
    'status_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> connectedAt =
      GeneratedColumn<int>(
        'connected_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($LoginAccountsTable.$converterconnectedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> lastSuccessAt =
      GeneratedColumn<int>(
        'last_success_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($LoginAccountsTable.$converterlastSuccessAtn);
  static const VerificationMeta _userAgentMeta = const VerificationMeta(
    'userAgent',
  );
  @override
  late final GeneratedColumn<String> userAgent = GeneratedColumn<String>(
    'user_agent',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    platform,
    remoteUserId,
    username,
    status,
    statusReason,
    connectedAt,
    lastSuccessAt,
    userAgent,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'login_account';
  @override
  VerificationContext validateIntegrity(
    Insertable<LoginAccountRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('remote_user_id')) {
      context.handle(
        _remoteUserIdMeta,
        remoteUserId.isAcceptableOrUnknown(
          data['remote_user_id']!,
          _remoteUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remoteUserIdMeta);
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('status_reason')) {
      context.handle(
        _statusReasonMeta,
        statusReason.isAcceptableOrUnknown(
          data['status_reason']!,
          _statusReasonMeta,
        ),
      );
    }
    if (data.containsKey('user_agent')) {
      context.handle(
        _userAgentMeta,
        userAgent.isAcceptableOrUnknown(data['user_agent']!, _userAgentMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LoginAccountRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LoginAccountRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      platform: $LoginAccountsTable.$converterplatform.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}platform'],
        )!,
      ),
      remoteUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_user_id'],
      )!,
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      )!,
      status: $LoginAccountsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      statusReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status_reason'],
      ),
      connectedAt: $LoginAccountsTable.$converterconnectedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}connected_at'],
        )!,
      ),
      lastSuccessAt: $LoginAccountsTable.$converterlastSuccessAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}last_success_at'],
        ),
      ),
      userAgent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_agent'],
      ),
    );
  }

  @override
  $LoginAccountsTable createAlias(String alias) {
    return $LoginAccountsTable(attachedDatabase, alias);
  }

  static TypeConverter<PlatformId, String> $converterplatform =
      const PlatformIdConverter();
  static TypeConverter<AccountStatus, String> $converterstatus =
      const AccountStatusConverter();
  static TypeConverter<DateTime, int> $converterconnectedAt =
      const EpochMsConverter();
  static TypeConverter<DateTime, int> $converterlastSuccessAt =
      const EpochMsConverter();
  static TypeConverter<DateTime?, int?> $converterlastSuccessAtn =
      NullAwareTypeConverter.wrap($converterlastSuccessAt);
}

class LoginAccountRow extends DataClass implements Insertable<LoginAccountRow> {
  final int id;
  final PlatformId platform;
  final String remoteUserId;
  final String username;
  final AccountStatus status;
  final String? statusReason;
  final DateTime connectedAt;
  final DateTime? lastSuccessAt;
  final String? userAgent;
  const LoginAccountRow({
    required this.id,
    required this.platform,
    required this.remoteUserId,
    required this.username,
    required this.status,
    this.statusReason,
    required this.connectedAt,
    this.lastSuccessAt,
    this.userAgent,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['platform'] = Variable<String>(
        $LoginAccountsTable.$converterplatform.toSql(platform),
      );
    }
    map['remote_user_id'] = Variable<String>(remoteUserId);
    map['username'] = Variable<String>(username);
    {
      map['status'] = Variable<String>(
        $LoginAccountsTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || statusReason != null) {
      map['status_reason'] = Variable<String>(statusReason);
    }
    {
      map['connected_at'] = Variable<int>(
        $LoginAccountsTable.$converterconnectedAt.toSql(connectedAt),
      );
    }
    if (!nullToAbsent || lastSuccessAt != null) {
      map['last_success_at'] = Variable<int>(
        $LoginAccountsTable.$converterlastSuccessAtn.toSql(lastSuccessAt),
      );
    }
    if (!nullToAbsent || userAgent != null) {
      map['user_agent'] = Variable<String>(userAgent);
    }
    return map;
  }

  LoginAccountsCompanion toCompanion(bool nullToAbsent) {
    return LoginAccountsCompanion(
      id: Value(id),
      platform: Value(platform),
      remoteUserId: Value(remoteUserId),
      username: Value(username),
      status: Value(status),
      statusReason: statusReason == null && nullToAbsent
          ? const Value.absent()
          : Value(statusReason),
      connectedAt: Value(connectedAt),
      lastSuccessAt: lastSuccessAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSuccessAt),
      userAgent: userAgent == null && nullToAbsent
          ? const Value.absent()
          : Value(userAgent),
    );
  }

  factory LoginAccountRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LoginAccountRow(
      id: serializer.fromJson<int>(json['id']),
      platform: serializer.fromJson<PlatformId>(json['platform']),
      remoteUserId: serializer.fromJson<String>(json['remoteUserId']),
      username: serializer.fromJson<String>(json['username']),
      status: serializer.fromJson<AccountStatus>(json['status']),
      statusReason: serializer.fromJson<String?>(json['statusReason']),
      connectedAt: serializer.fromJson<DateTime>(json['connectedAt']),
      lastSuccessAt: serializer.fromJson<DateTime?>(json['lastSuccessAt']),
      userAgent: serializer.fromJson<String?>(json['userAgent']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'platform': serializer.toJson<PlatformId>(platform),
      'remoteUserId': serializer.toJson<String>(remoteUserId),
      'username': serializer.toJson<String>(username),
      'status': serializer.toJson<AccountStatus>(status),
      'statusReason': serializer.toJson<String?>(statusReason),
      'connectedAt': serializer.toJson<DateTime>(connectedAt),
      'lastSuccessAt': serializer.toJson<DateTime?>(lastSuccessAt),
      'userAgent': serializer.toJson<String?>(userAgent),
    };
  }

  LoginAccountRow copyWith({
    int? id,
    PlatformId? platform,
    String? remoteUserId,
    String? username,
    AccountStatus? status,
    Value<String?> statusReason = const Value.absent(),
    DateTime? connectedAt,
    Value<DateTime?> lastSuccessAt = const Value.absent(),
    Value<String?> userAgent = const Value.absent(),
  }) => LoginAccountRow(
    id: id ?? this.id,
    platform: platform ?? this.platform,
    remoteUserId: remoteUserId ?? this.remoteUserId,
    username: username ?? this.username,
    status: status ?? this.status,
    statusReason: statusReason.present ? statusReason.value : this.statusReason,
    connectedAt: connectedAt ?? this.connectedAt,
    lastSuccessAt: lastSuccessAt.present
        ? lastSuccessAt.value
        : this.lastSuccessAt,
    userAgent: userAgent.present ? userAgent.value : this.userAgent,
  );
  LoginAccountRow copyWithCompanion(LoginAccountsCompanion data) {
    return LoginAccountRow(
      id: data.id.present ? data.id.value : this.id,
      platform: data.platform.present ? data.platform.value : this.platform,
      remoteUserId: data.remoteUserId.present
          ? data.remoteUserId.value
          : this.remoteUserId,
      username: data.username.present ? data.username.value : this.username,
      status: data.status.present ? data.status.value : this.status,
      statusReason: data.statusReason.present
          ? data.statusReason.value
          : this.statusReason,
      connectedAt: data.connectedAt.present
          ? data.connectedAt.value
          : this.connectedAt,
      lastSuccessAt: data.lastSuccessAt.present
          ? data.lastSuccessAt.value
          : this.lastSuccessAt,
      userAgent: data.userAgent.present ? data.userAgent.value : this.userAgent,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LoginAccountRow(')
          ..write('id: $id, ')
          ..write('platform: $platform, ')
          ..write('remoteUserId: $remoteUserId, ')
          ..write('username: $username, ')
          ..write('status: $status, ')
          ..write('statusReason: $statusReason, ')
          ..write('connectedAt: $connectedAt, ')
          ..write('lastSuccessAt: $lastSuccessAt, ')
          ..write('userAgent: $userAgent')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    platform,
    remoteUserId,
    username,
    status,
    statusReason,
    connectedAt,
    lastSuccessAt,
    userAgent,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LoginAccountRow &&
          other.id == this.id &&
          other.platform == this.platform &&
          other.remoteUserId == this.remoteUserId &&
          other.username == this.username &&
          other.status == this.status &&
          other.statusReason == this.statusReason &&
          other.connectedAt == this.connectedAt &&
          other.lastSuccessAt == this.lastSuccessAt &&
          other.userAgent == this.userAgent);
}

class LoginAccountsCompanion extends UpdateCompanion<LoginAccountRow> {
  final Value<int> id;
  final Value<PlatformId> platform;
  final Value<String> remoteUserId;
  final Value<String> username;
  final Value<AccountStatus> status;
  final Value<String?> statusReason;
  final Value<DateTime> connectedAt;
  final Value<DateTime?> lastSuccessAt;
  final Value<String?> userAgent;
  const LoginAccountsCompanion({
    this.id = const Value.absent(),
    this.platform = const Value.absent(),
    this.remoteUserId = const Value.absent(),
    this.username = const Value.absent(),
    this.status = const Value.absent(),
    this.statusReason = const Value.absent(),
    this.connectedAt = const Value.absent(),
    this.lastSuccessAt = const Value.absent(),
    this.userAgent = const Value.absent(),
  });
  LoginAccountsCompanion.insert({
    this.id = const Value.absent(),
    required PlatformId platform,
    required String remoteUserId,
    required String username,
    required AccountStatus status,
    this.statusReason = const Value.absent(),
    required DateTime connectedAt,
    this.lastSuccessAt = const Value.absent(),
    this.userAgent = const Value.absent(),
  }) : platform = Value(platform),
       remoteUserId = Value(remoteUserId),
       username = Value(username),
       status = Value(status),
       connectedAt = Value(connectedAt);
  static Insertable<LoginAccountRow> custom({
    Expression<int>? id,
    Expression<String>? platform,
    Expression<String>? remoteUserId,
    Expression<String>? username,
    Expression<String>? status,
    Expression<String>? statusReason,
    Expression<int>? connectedAt,
    Expression<int>? lastSuccessAt,
    Expression<String>? userAgent,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (platform != null) 'platform': platform,
      if (remoteUserId != null) 'remote_user_id': remoteUserId,
      if (username != null) 'username': username,
      if (status != null) 'status': status,
      if (statusReason != null) 'status_reason': statusReason,
      if (connectedAt != null) 'connected_at': connectedAt,
      if (lastSuccessAt != null) 'last_success_at': lastSuccessAt,
      if (userAgent != null) 'user_agent': userAgent,
    });
  }

  LoginAccountsCompanion copyWith({
    Value<int>? id,
    Value<PlatformId>? platform,
    Value<String>? remoteUserId,
    Value<String>? username,
    Value<AccountStatus>? status,
    Value<String?>? statusReason,
    Value<DateTime>? connectedAt,
    Value<DateTime?>? lastSuccessAt,
    Value<String?>? userAgent,
  }) {
    return LoginAccountsCompanion(
      id: id ?? this.id,
      platform: platform ?? this.platform,
      remoteUserId: remoteUserId ?? this.remoteUserId,
      username: username ?? this.username,
      status: status ?? this.status,
      statusReason: statusReason ?? this.statusReason,
      connectedAt: connectedAt ?? this.connectedAt,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      userAgent: userAgent ?? this.userAgent,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (platform.present) {
      map['platform'] = Variable<String>(
        $LoginAccountsTable.$converterplatform.toSql(platform.value),
      );
    }
    if (remoteUserId.present) {
      map['remote_user_id'] = Variable<String>(remoteUserId.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $LoginAccountsTable.$converterstatus.toSql(status.value),
      );
    }
    if (statusReason.present) {
      map['status_reason'] = Variable<String>(statusReason.value);
    }
    if (connectedAt.present) {
      map['connected_at'] = Variable<int>(
        $LoginAccountsTable.$converterconnectedAt.toSql(connectedAt.value),
      );
    }
    if (lastSuccessAt.present) {
      map['last_success_at'] = Variable<int>(
        $LoginAccountsTable.$converterlastSuccessAtn.toSql(lastSuccessAt.value),
      );
    }
    if (userAgent.present) {
      map['user_agent'] = Variable<String>(userAgent.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LoginAccountsCompanion(')
          ..write('id: $id, ')
          ..write('platform: $platform, ')
          ..write('remoteUserId: $remoteUserId, ')
          ..write('username: $username, ')
          ..write('status: $status, ')
          ..write('statusReason: $statusReason, ')
          ..write('connectedAt: $connectedAt, ')
          ..write('lastSuccessAt: $lastSuccessAt, ')
          ..write('userAgent: $userAgent')
          ..write(')'))
        .toString();
  }
}

class $TargetsTable extends Targets with TableInfo<$TargetsTable, TargetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TargetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<PlatformId, String> platform =
      GeneratedColumn<String>(
        'platform',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<PlatformId>($TargetsTable.$converterplatform);
  static const VerificationMeta _remoteUserIdMeta = const VerificationMeta(
    'remoteUserId',
  );
  @override
  late final GeneratedColumn<String> remoteUserId = GeneratedColumn<String>(
    'remote_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _avatarPathMeta = const VerificationMeta(
    'avatarPath',
  );
  @override
  late final GeneratedColumn<String> avatarPath = GeneratedColumn<String>(
    'avatar_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TargetCategory, String> category =
      GeneratedColumn<String>(
        'category',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TargetCategory>($TargetsTable.$convertercategory);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TargetStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TargetStatus>($TargetsTable.$converterstatus);
  static const VerificationMeta _statusReasonMeta = const VerificationMeta(
    'statusReason',
  );
  @override
  late final GeneratedColumn<String> statusReason = GeneratedColumn<String>(
    'status_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPrivateMeta = const VerificationMeta(
    'isPrivate',
  );
  @override
  late final GeneratedColumn<bool> isPrivate = GeneratedColumn<bool>(
    'is_private',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_private" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _trackStoriesMeta = const VerificationMeta(
    'trackStories',
  );
  @override
  late final GeneratedColumn<bool> trackStories = GeneratedColumn<bool>(
    'track_stories',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("track_stories" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _trackPostsMeta = const VerificationMeta(
    'trackPosts',
  );
  @override
  late final GeneratedColumn<bool> trackPosts = GeneratedColumn<bool>(
    'track_posts',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("track_posts" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _trackReelsMeta = const VerificationMeta(
    'trackReels',
  );
  @override
  late final GeneratedColumn<bool> trackReels = GeneratedColumn<bool>(
    'track_reels',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("track_reels" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> postsWatermarkAt =
      GeneratedColumn<int>(
        'posts_watermark_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($TargetsTable.$converterpostsWatermarkAt);
  static const VerificationMeta _loginAccountIdMeta = const VerificationMeta(
    'loginAccountId',
  );
  @override
  late final GeneratedColumn<int> loginAccountId = GeneratedColumn<int>(
    'login_account_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES login_account (id) ON DELETE SET NULL',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> addedAt =
      GeneratedColumn<int>(
        'added_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($TargetsTable.$converteraddedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int>
  lastStoriesCheckAt = GeneratedColumn<int>(
    'last_stories_check_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  ).withConverter<DateTime?>($TargetsTable.$converterlastStoriesCheckAtn);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> lastPostsCheckAt =
      GeneratedColumn<int>(
        'last_posts_check_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($TargetsTable.$converterlastPostsCheckAtn);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> lastNewStoryAt =
      GeneratedColumn<int>(
        'last_new_story_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($TargetsTable.$converterlastNewStoryAtn);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> lastNewPostAt =
      GeneratedColumn<int>(
        'last_new_post_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($TargetsTable.$converterlastNewPostAtn);
  @override
  late final GeneratedColumnWithTypeConverter<HistoryRange, String>
  historyRange = GeneratedColumn<String>(
    'history_range',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('NONE'),
  ).withConverter<HistoryRange>($TargetsTable.$converterhistoryRange);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> historySince =
      GeneratedColumn<int>(
        'history_since',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($TargetsTable.$converterhistorySincen);
  @override
  late final GeneratedColumnWithTypeConverter<HistoryState, String>
  historyState = GeneratedColumn<String>(
    'history_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('IDLE'),
  ).withConverter<HistoryState>($TargetsTable.$converterhistoryState);
  static const VerificationMeta _historyCursorMeta = const VerificationMeta(
    'historyCursor',
  );
  @override
  late final GeneratedColumn<String> historyCursor = GeneratedColumn<String>(
    'history_cursor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _historyFetchedMeta = const VerificationMeta(
    'historyFetched',
  );
  @override
  late final GeneratedColumn<int> historyFetched = GeneratedColumn<int>(
    'history_fetched',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int>
  historyOldestSeenAt = GeneratedColumn<int>(
    'history_oldest_seen_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  ).withConverter<DateTime?>($TargetsTable.$converterhistoryOldestSeenAtn);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> historyUpdatedAt =
      GeneratedColumn<int>(
        'history_updated_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($TargetsTable.$converterhistoryUpdatedAtn);
  static const VerificationMeta _highlightsEnabledMeta = const VerificationMeta(
    'highlightsEnabled',
  );
  @override
  late final GeneratedColumn<bool> highlightsEnabled = GeneratedColumn<bool>(
    'highlights_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("highlights_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> lastSuccessAt =
      GeneratedColumn<int>(
        'last_success_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($TargetsTable.$converterlastSuccessAtn);
  @override
  late final GeneratedColumnWithTypeConverter<TargetCheckOutcome?, String>
  lastCheckOutcome =
      GeneratedColumn<String>(
        'last_check_outcome',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<TargetCheckOutcome?>(
        $TargetsTable.$converterlastCheckOutcomen,
      );
  static const VerificationMeta _lastCheckCodeMeta = const VerificationMeta(
    'lastCheckCode',
  );
  @override
  late final GeneratedColumn<String> lastCheckCode = GeneratedColumn<String>(
    'last_check_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    platform,
    remoteUserId,
    username,
    displayName,
    avatarPath,
    category,
    note,
    status,
    statusReason,
    isPrivate,
    trackStories,
    trackPosts,
    trackReels,
    postsWatermarkAt,
    loginAccountId,
    addedAt,
    lastStoriesCheckAt,
    lastPostsCheckAt,
    lastNewStoryAt,
    lastNewPostAt,
    historyRange,
    historySince,
    historyState,
    historyCursor,
    historyFetched,
    historyOldestSeenAt,
    historyUpdatedAt,
    highlightsEnabled,
    lastSuccessAt,
    lastCheckOutcome,
    lastCheckCode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'target';
  @override
  VerificationContext validateIntegrity(
    Insertable<TargetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('remote_user_id')) {
      context.handle(
        _remoteUserIdMeta,
        remoteUserId.isAcceptableOrUnknown(
          data['remote_user_id']!,
          _remoteUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remoteUserIdMeta);
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('avatar_path')) {
      context.handle(
        _avatarPathMeta,
        avatarPath.isAcceptableOrUnknown(data['avatar_path']!, _avatarPathMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('status_reason')) {
      context.handle(
        _statusReasonMeta,
        statusReason.isAcceptableOrUnknown(
          data['status_reason']!,
          _statusReasonMeta,
        ),
      );
    }
    if (data.containsKey('is_private')) {
      context.handle(
        _isPrivateMeta,
        isPrivate.isAcceptableOrUnknown(data['is_private']!, _isPrivateMeta),
      );
    }
    if (data.containsKey('track_stories')) {
      context.handle(
        _trackStoriesMeta,
        trackStories.isAcceptableOrUnknown(
          data['track_stories']!,
          _trackStoriesMeta,
        ),
      );
    }
    if (data.containsKey('track_posts')) {
      context.handle(
        _trackPostsMeta,
        trackPosts.isAcceptableOrUnknown(data['track_posts']!, _trackPostsMeta),
      );
    }
    if (data.containsKey('track_reels')) {
      context.handle(
        _trackReelsMeta,
        trackReels.isAcceptableOrUnknown(data['track_reels']!, _trackReelsMeta),
      );
    }
    if (data.containsKey('login_account_id')) {
      context.handle(
        _loginAccountIdMeta,
        loginAccountId.isAcceptableOrUnknown(
          data['login_account_id']!,
          _loginAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('history_cursor')) {
      context.handle(
        _historyCursorMeta,
        historyCursor.isAcceptableOrUnknown(
          data['history_cursor']!,
          _historyCursorMeta,
        ),
      );
    }
    if (data.containsKey('history_fetched')) {
      context.handle(
        _historyFetchedMeta,
        historyFetched.isAcceptableOrUnknown(
          data['history_fetched']!,
          _historyFetchedMeta,
        ),
      );
    }
    if (data.containsKey('highlights_enabled')) {
      context.handle(
        _highlightsEnabledMeta,
        highlightsEnabled.isAcceptableOrUnknown(
          data['highlights_enabled']!,
          _highlightsEnabledMeta,
        ),
      );
    }
    if (data.containsKey('last_check_code')) {
      context.handle(
        _lastCheckCodeMeta,
        lastCheckCode.isAcceptableOrUnknown(
          data['last_check_code']!,
          _lastCheckCodeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {platform, remoteUserId},
  ];
  @override
  TargetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TargetRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      platform: $TargetsTable.$converterplatform.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}platform'],
        )!,
      ),
      remoteUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_user_id'],
      )!,
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      avatarPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_path'],
      ),
      category: $TargetsTable.$convertercategory.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}category'],
        )!,
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      status: $TargetsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      statusReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status_reason'],
      ),
      isPrivate: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_private'],
      )!,
      trackStories: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}track_stories'],
      )!,
      trackPosts: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}track_posts'],
      )!,
      trackReels: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}track_reels'],
      )!,
      postsWatermarkAt: $TargetsTable.$converterpostsWatermarkAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}posts_watermark_at'],
        )!,
      ),
      loginAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}login_account_id'],
      ),
      addedAt: $TargetsTable.$converteraddedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}added_at'],
        )!,
      ),
      lastStoriesCheckAt: $TargetsTable.$converterlastStoriesCheckAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}last_stories_check_at'],
        ),
      ),
      lastPostsCheckAt: $TargetsTable.$converterlastPostsCheckAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}last_posts_check_at'],
        ),
      ),
      lastNewStoryAt: $TargetsTable.$converterlastNewStoryAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}last_new_story_at'],
        ),
      ),
      lastNewPostAt: $TargetsTable.$converterlastNewPostAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}last_new_post_at'],
        ),
      ),
      historyRange: $TargetsTable.$converterhistoryRange.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}history_range'],
        )!,
      ),
      historySince: $TargetsTable.$converterhistorySincen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}history_since'],
        ),
      ),
      historyState: $TargetsTable.$converterhistoryState.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}history_state'],
        )!,
      ),
      historyCursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}history_cursor'],
      ),
      historyFetched: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}history_fetched'],
      )!,
      historyOldestSeenAt: $TargetsTable.$converterhistoryOldestSeenAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}history_oldest_seen_at'],
        ),
      ),
      historyUpdatedAt: $TargetsTable.$converterhistoryUpdatedAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}history_updated_at'],
        ),
      ),
      highlightsEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}highlights_enabled'],
      )!,
      lastSuccessAt: $TargetsTable.$converterlastSuccessAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}last_success_at'],
        ),
      ),
      lastCheckOutcome: $TargetsTable.$converterlastCheckOutcomen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}last_check_outcome'],
        ),
      ),
      lastCheckCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_check_code'],
      ),
    );
  }

  @override
  $TargetsTable createAlias(String alias) {
    return $TargetsTable(attachedDatabase, alias);
  }

  static TypeConverter<PlatformId, String> $converterplatform =
      const PlatformIdConverter();
  static TypeConverter<TargetCategory, String> $convertercategory =
      const TargetCategoryConverter();
  static TypeConverter<TargetStatus, String> $converterstatus =
      const TargetStatusConverter();
  static TypeConverter<DateTime, int> $converterpostsWatermarkAt =
      const EpochMsConverter();
  static TypeConverter<DateTime, int> $converteraddedAt =
      const EpochMsConverter();
  static TypeConverter<DateTime, int> $converterlastStoriesCheckAt =
      const EpochMsConverter();
  static TypeConverter<DateTime?, int?> $converterlastStoriesCheckAtn =
      NullAwareTypeConverter.wrap($converterlastStoriesCheckAt);
  static TypeConverter<DateTime, int> $converterlastPostsCheckAt =
      const EpochMsConverter();
  static TypeConverter<DateTime?, int?> $converterlastPostsCheckAtn =
      NullAwareTypeConverter.wrap($converterlastPostsCheckAt);
  static TypeConverter<DateTime, int> $converterlastNewStoryAt =
      const EpochMsConverter();
  static TypeConverter<DateTime?, int?> $converterlastNewStoryAtn =
      NullAwareTypeConverter.wrap($converterlastNewStoryAt);
  static TypeConverter<DateTime, int> $converterlastNewPostAt =
      const EpochMsConverter();
  static TypeConverter<DateTime?, int?> $converterlastNewPostAtn =
      NullAwareTypeConverter.wrap($converterlastNewPostAt);
  static TypeConverter<HistoryRange, String> $converterhistoryRange =
      const HistoryRangeConverter();
  static TypeConverter<DateTime, int> $converterhistorySince =
      const EpochMsConverter();
  static TypeConverter<DateTime?, int?> $converterhistorySincen =
      NullAwareTypeConverter.wrap($converterhistorySince);
  static TypeConverter<HistoryState, String> $converterhistoryState =
      const HistoryStateConverter();
  static TypeConverter<DateTime, int> $converterhistoryOldestSeenAt =
      const EpochMsConverter();
  static TypeConverter<DateTime?, int?> $converterhistoryOldestSeenAtn =
      NullAwareTypeConverter.wrap($converterhistoryOldestSeenAt);
  static TypeConverter<DateTime, int> $converterhistoryUpdatedAt =
      const EpochMsConverter();
  static TypeConverter<DateTime?, int?> $converterhistoryUpdatedAtn =
      NullAwareTypeConverter.wrap($converterhistoryUpdatedAt);
  static TypeConverter<DateTime, int> $converterlastSuccessAt =
      const EpochMsConverter();
  static TypeConverter<DateTime?, int?> $converterlastSuccessAtn =
      NullAwareTypeConverter.wrap($converterlastSuccessAt);
  static TypeConverter<TargetCheckOutcome, String> $converterlastCheckOutcome =
      const TargetCheckOutcomeConverter();
  static TypeConverter<TargetCheckOutcome?, String?>
  $converterlastCheckOutcomen = NullAwareTypeConverter.wrap(
    $converterlastCheckOutcome,
  );
}

class TargetRow extends DataClass implements Insertable<TargetRow> {
  final int id;
  final PlatformId platform;
  final String remoteUserId;
  final String username;
  final String? displayName;
  final String? avatarPath;
  final TargetCategory category;
  final String? note;
  final TargetStatus status;
  final String? statusReason;
  final bool isPrivate;
  final bool trackStories;
  final bool trackPosts;
  final bool trackReels;
  final DateTime postsWatermarkAt;
  final int? loginAccountId;
  final DateTime addedAt;
  final DateTime? lastStoriesCheckAt;
  final DateTime? lastPostsCheckAt;
  final DateTime? lastNewStoryAt;
  final DateTime? lastNewPostAt;
  final HistoryRange historyRange;
  final DateTime? historySince;
  final HistoryState historyState;
  final String? historyCursor;
  final int historyFetched;
  final DateTime? historyOldestSeenAt;
  final DateTime? historyUpdatedAt;
  final bool highlightsEnabled;
  final DateTime? lastSuccessAt;
  final TargetCheckOutcome? lastCheckOutcome;
  final String? lastCheckCode;
  const TargetRow({
    required this.id,
    required this.platform,
    required this.remoteUserId,
    required this.username,
    this.displayName,
    this.avatarPath,
    required this.category,
    this.note,
    required this.status,
    this.statusReason,
    required this.isPrivate,
    required this.trackStories,
    required this.trackPosts,
    required this.trackReels,
    required this.postsWatermarkAt,
    this.loginAccountId,
    required this.addedAt,
    this.lastStoriesCheckAt,
    this.lastPostsCheckAt,
    this.lastNewStoryAt,
    this.lastNewPostAt,
    required this.historyRange,
    this.historySince,
    required this.historyState,
    this.historyCursor,
    required this.historyFetched,
    this.historyOldestSeenAt,
    this.historyUpdatedAt,
    required this.highlightsEnabled,
    this.lastSuccessAt,
    this.lastCheckOutcome,
    this.lastCheckCode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['platform'] = Variable<String>(
        $TargetsTable.$converterplatform.toSql(platform),
      );
    }
    map['remote_user_id'] = Variable<String>(remoteUserId);
    map['username'] = Variable<String>(username);
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || avatarPath != null) {
      map['avatar_path'] = Variable<String>(avatarPath);
    }
    {
      map['category'] = Variable<String>(
        $TargetsTable.$convertercategory.toSql(category),
      );
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    {
      map['status'] = Variable<String>(
        $TargetsTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || statusReason != null) {
      map['status_reason'] = Variable<String>(statusReason);
    }
    map['is_private'] = Variable<bool>(isPrivate);
    map['track_stories'] = Variable<bool>(trackStories);
    map['track_posts'] = Variable<bool>(trackPosts);
    map['track_reels'] = Variable<bool>(trackReels);
    {
      map['posts_watermark_at'] = Variable<int>(
        $TargetsTable.$converterpostsWatermarkAt.toSql(postsWatermarkAt),
      );
    }
    if (!nullToAbsent || loginAccountId != null) {
      map['login_account_id'] = Variable<int>(loginAccountId);
    }
    {
      map['added_at'] = Variable<int>(
        $TargetsTable.$converteraddedAt.toSql(addedAt),
      );
    }
    if (!nullToAbsent || lastStoriesCheckAt != null) {
      map['last_stories_check_at'] = Variable<int>(
        $TargetsTable.$converterlastStoriesCheckAtn.toSql(lastStoriesCheckAt),
      );
    }
    if (!nullToAbsent || lastPostsCheckAt != null) {
      map['last_posts_check_at'] = Variable<int>(
        $TargetsTable.$converterlastPostsCheckAtn.toSql(lastPostsCheckAt),
      );
    }
    if (!nullToAbsent || lastNewStoryAt != null) {
      map['last_new_story_at'] = Variable<int>(
        $TargetsTable.$converterlastNewStoryAtn.toSql(lastNewStoryAt),
      );
    }
    if (!nullToAbsent || lastNewPostAt != null) {
      map['last_new_post_at'] = Variable<int>(
        $TargetsTable.$converterlastNewPostAtn.toSql(lastNewPostAt),
      );
    }
    {
      map['history_range'] = Variable<String>(
        $TargetsTable.$converterhistoryRange.toSql(historyRange),
      );
    }
    if (!nullToAbsent || historySince != null) {
      map['history_since'] = Variable<int>(
        $TargetsTable.$converterhistorySincen.toSql(historySince),
      );
    }
    {
      map['history_state'] = Variable<String>(
        $TargetsTable.$converterhistoryState.toSql(historyState),
      );
    }
    if (!nullToAbsent || historyCursor != null) {
      map['history_cursor'] = Variable<String>(historyCursor);
    }
    map['history_fetched'] = Variable<int>(historyFetched);
    if (!nullToAbsent || historyOldestSeenAt != null) {
      map['history_oldest_seen_at'] = Variable<int>(
        $TargetsTable.$converterhistoryOldestSeenAtn.toSql(historyOldestSeenAt),
      );
    }
    if (!nullToAbsent || historyUpdatedAt != null) {
      map['history_updated_at'] = Variable<int>(
        $TargetsTable.$converterhistoryUpdatedAtn.toSql(historyUpdatedAt),
      );
    }
    map['highlights_enabled'] = Variable<bool>(highlightsEnabled);
    if (!nullToAbsent || lastSuccessAt != null) {
      map['last_success_at'] = Variable<int>(
        $TargetsTable.$converterlastSuccessAtn.toSql(lastSuccessAt),
      );
    }
    if (!nullToAbsent || lastCheckOutcome != null) {
      map['last_check_outcome'] = Variable<String>(
        $TargetsTable.$converterlastCheckOutcomen.toSql(lastCheckOutcome),
      );
    }
    if (!nullToAbsent || lastCheckCode != null) {
      map['last_check_code'] = Variable<String>(lastCheckCode);
    }
    return map;
  }

  TargetsCompanion toCompanion(bool nullToAbsent) {
    return TargetsCompanion(
      id: Value(id),
      platform: Value(platform),
      remoteUserId: Value(remoteUserId),
      username: Value(username),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      avatarPath: avatarPath == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarPath),
      category: Value(category),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      status: Value(status),
      statusReason: statusReason == null && nullToAbsent
          ? const Value.absent()
          : Value(statusReason),
      isPrivate: Value(isPrivate),
      trackStories: Value(trackStories),
      trackPosts: Value(trackPosts),
      trackReels: Value(trackReels),
      postsWatermarkAt: Value(postsWatermarkAt),
      loginAccountId: loginAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(loginAccountId),
      addedAt: Value(addedAt),
      lastStoriesCheckAt: lastStoriesCheckAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastStoriesCheckAt),
      lastPostsCheckAt: lastPostsCheckAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPostsCheckAt),
      lastNewStoryAt: lastNewStoryAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastNewStoryAt),
      lastNewPostAt: lastNewPostAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastNewPostAt),
      historyRange: Value(historyRange),
      historySince: historySince == null && nullToAbsent
          ? const Value.absent()
          : Value(historySince),
      historyState: Value(historyState),
      historyCursor: historyCursor == null && nullToAbsent
          ? const Value.absent()
          : Value(historyCursor),
      historyFetched: Value(historyFetched),
      historyOldestSeenAt: historyOldestSeenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(historyOldestSeenAt),
      historyUpdatedAt: historyUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(historyUpdatedAt),
      highlightsEnabled: Value(highlightsEnabled),
      lastSuccessAt: lastSuccessAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSuccessAt),
      lastCheckOutcome: lastCheckOutcome == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCheckOutcome),
      lastCheckCode: lastCheckCode == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCheckCode),
    );
  }

  factory TargetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TargetRow(
      id: serializer.fromJson<int>(json['id']),
      platform: serializer.fromJson<PlatformId>(json['platform']),
      remoteUserId: serializer.fromJson<String>(json['remoteUserId']),
      username: serializer.fromJson<String>(json['username']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      avatarPath: serializer.fromJson<String?>(json['avatarPath']),
      category: serializer.fromJson<TargetCategory>(json['category']),
      note: serializer.fromJson<String?>(json['note']),
      status: serializer.fromJson<TargetStatus>(json['status']),
      statusReason: serializer.fromJson<String?>(json['statusReason']),
      isPrivate: serializer.fromJson<bool>(json['isPrivate']),
      trackStories: serializer.fromJson<bool>(json['trackStories']),
      trackPosts: serializer.fromJson<bool>(json['trackPosts']),
      trackReels: serializer.fromJson<bool>(json['trackReels']),
      postsWatermarkAt: serializer.fromJson<DateTime>(json['postsWatermarkAt']),
      loginAccountId: serializer.fromJson<int?>(json['loginAccountId']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      lastStoriesCheckAt: serializer.fromJson<DateTime?>(
        json['lastStoriesCheckAt'],
      ),
      lastPostsCheckAt: serializer.fromJson<DateTime?>(
        json['lastPostsCheckAt'],
      ),
      lastNewStoryAt: serializer.fromJson<DateTime?>(json['lastNewStoryAt']),
      lastNewPostAt: serializer.fromJson<DateTime?>(json['lastNewPostAt']),
      historyRange: serializer.fromJson<HistoryRange>(json['historyRange']),
      historySince: serializer.fromJson<DateTime?>(json['historySince']),
      historyState: serializer.fromJson<HistoryState>(json['historyState']),
      historyCursor: serializer.fromJson<String?>(json['historyCursor']),
      historyFetched: serializer.fromJson<int>(json['historyFetched']),
      historyOldestSeenAt: serializer.fromJson<DateTime?>(
        json['historyOldestSeenAt'],
      ),
      historyUpdatedAt: serializer.fromJson<DateTime?>(
        json['historyUpdatedAt'],
      ),
      highlightsEnabled: serializer.fromJson<bool>(json['highlightsEnabled']),
      lastSuccessAt: serializer.fromJson<DateTime?>(json['lastSuccessAt']),
      lastCheckOutcome: serializer.fromJson<TargetCheckOutcome?>(
        json['lastCheckOutcome'],
      ),
      lastCheckCode: serializer.fromJson<String?>(json['lastCheckCode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'platform': serializer.toJson<PlatformId>(platform),
      'remoteUserId': serializer.toJson<String>(remoteUserId),
      'username': serializer.toJson<String>(username),
      'displayName': serializer.toJson<String?>(displayName),
      'avatarPath': serializer.toJson<String?>(avatarPath),
      'category': serializer.toJson<TargetCategory>(category),
      'note': serializer.toJson<String?>(note),
      'status': serializer.toJson<TargetStatus>(status),
      'statusReason': serializer.toJson<String?>(statusReason),
      'isPrivate': serializer.toJson<bool>(isPrivate),
      'trackStories': serializer.toJson<bool>(trackStories),
      'trackPosts': serializer.toJson<bool>(trackPosts),
      'trackReels': serializer.toJson<bool>(trackReels),
      'postsWatermarkAt': serializer.toJson<DateTime>(postsWatermarkAt),
      'loginAccountId': serializer.toJson<int?>(loginAccountId),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'lastStoriesCheckAt': serializer.toJson<DateTime?>(lastStoriesCheckAt),
      'lastPostsCheckAt': serializer.toJson<DateTime?>(lastPostsCheckAt),
      'lastNewStoryAt': serializer.toJson<DateTime?>(lastNewStoryAt),
      'lastNewPostAt': serializer.toJson<DateTime?>(lastNewPostAt),
      'historyRange': serializer.toJson<HistoryRange>(historyRange),
      'historySince': serializer.toJson<DateTime?>(historySince),
      'historyState': serializer.toJson<HistoryState>(historyState),
      'historyCursor': serializer.toJson<String?>(historyCursor),
      'historyFetched': serializer.toJson<int>(historyFetched),
      'historyOldestSeenAt': serializer.toJson<DateTime?>(historyOldestSeenAt),
      'historyUpdatedAt': serializer.toJson<DateTime?>(historyUpdatedAt),
      'highlightsEnabled': serializer.toJson<bool>(highlightsEnabled),
      'lastSuccessAt': serializer.toJson<DateTime?>(lastSuccessAt),
      'lastCheckOutcome': serializer.toJson<TargetCheckOutcome?>(
        lastCheckOutcome,
      ),
      'lastCheckCode': serializer.toJson<String?>(lastCheckCode),
    };
  }

  TargetRow copyWith({
    int? id,
    PlatformId? platform,
    String? remoteUserId,
    String? username,
    Value<String?> displayName = const Value.absent(),
    Value<String?> avatarPath = const Value.absent(),
    TargetCategory? category,
    Value<String?> note = const Value.absent(),
    TargetStatus? status,
    Value<String?> statusReason = const Value.absent(),
    bool? isPrivate,
    bool? trackStories,
    bool? trackPosts,
    bool? trackReels,
    DateTime? postsWatermarkAt,
    Value<int?> loginAccountId = const Value.absent(),
    DateTime? addedAt,
    Value<DateTime?> lastStoriesCheckAt = const Value.absent(),
    Value<DateTime?> lastPostsCheckAt = const Value.absent(),
    Value<DateTime?> lastNewStoryAt = const Value.absent(),
    Value<DateTime?> lastNewPostAt = const Value.absent(),
    HistoryRange? historyRange,
    Value<DateTime?> historySince = const Value.absent(),
    HistoryState? historyState,
    Value<String?> historyCursor = const Value.absent(),
    int? historyFetched,
    Value<DateTime?> historyOldestSeenAt = const Value.absent(),
    Value<DateTime?> historyUpdatedAt = const Value.absent(),
    bool? highlightsEnabled,
    Value<DateTime?> lastSuccessAt = const Value.absent(),
    Value<TargetCheckOutcome?> lastCheckOutcome = const Value.absent(),
    Value<String?> lastCheckCode = const Value.absent(),
  }) => TargetRow(
    id: id ?? this.id,
    platform: platform ?? this.platform,
    remoteUserId: remoteUserId ?? this.remoteUserId,
    username: username ?? this.username,
    displayName: displayName.present ? displayName.value : this.displayName,
    avatarPath: avatarPath.present ? avatarPath.value : this.avatarPath,
    category: category ?? this.category,
    note: note.present ? note.value : this.note,
    status: status ?? this.status,
    statusReason: statusReason.present ? statusReason.value : this.statusReason,
    isPrivate: isPrivate ?? this.isPrivate,
    trackStories: trackStories ?? this.trackStories,
    trackPosts: trackPosts ?? this.trackPosts,
    trackReels: trackReels ?? this.trackReels,
    postsWatermarkAt: postsWatermarkAt ?? this.postsWatermarkAt,
    loginAccountId: loginAccountId.present
        ? loginAccountId.value
        : this.loginAccountId,
    addedAt: addedAt ?? this.addedAt,
    lastStoriesCheckAt: lastStoriesCheckAt.present
        ? lastStoriesCheckAt.value
        : this.lastStoriesCheckAt,
    lastPostsCheckAt: lastPostsCheckAt.present
        ? lastPostsCheckAt.value
        : this.lastPostsCheckAt,
    lastNewStoryAt: lastNewStoryAt.present
        ? lastNewStoryAt.value
        : this.lastNewStoryAt,
    lastNewPostAt: lastNewPostAt.present
        ? lastNewPostAt.value
        : this.lastNewPostAt,
    historyRange: historyRange ?? this.historyRange,
    historySince: historySince.present ? historySince.value : this.historySince,
    historyState: historyState ?? this.historyState,
    historyCursor: historyCursor.present
        ? historyCursor.value
        : this.historyCursor,
    historyFetched: historyFetched ?? this.historyFetched,
    historyOldestSeenAt: historyOldestSeenAt.present
        ? historyOldestSeenAt.value
        : this.historyOldestSeenAt,
    historyUpdatedAt: historyUpdatedAt.present
        ? historyUpdatedAt.value
        : this.historyUpdatedAt,
    highlightsEnabled: highlightsEnabled ?? this.highlightsEnabled,
    lastSuccessAt: lastSuccessAt.present
        ? lastSuccessAt.value
        : this.lastSuccessAt,
    lastCheckOutcome: lastCheckOutcome.present
        ? lastCheckOutcome.value
        : this.lastCheckOutcome,
    lastCheckCode: lastCheckCode.present
        ? lastCheckCode.value
        : this.lastCheckCode,
  );
  TargetRow copyWithCompanion(TargetsCompanion data) {
    return TargetRow(
      id: data.id.present ? data.id.value : this.id,
      platform: data.platform.present ? data.platform.value : this.platform,
      remoteUserId: data.remoteUserId.present
          ? data.remoteUserId.value
          : this.remoteUserId,
      username: data.username.present ? data.username.value : this.username,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      avatarPath: data.avatarPath.present
          ? data.avatarPath.value
          : this.avatarPath,
      category: data.category.present ? data.category.value : this.category,
      note: data.note.present ? data.note.value : this.note,
      status: data.status.present ? data.status.value : this.status,
      statusReason: data.statusReason.present
          ? data.statusReason.value
          : this.statusReason,
      isPrivate: data.isPrivate.present ? data.isPrivate.value : this.isPrivate,
      trackStories: data.trackStories.present
          ? data.trackStories.value
          : this.trackStories,
      trackPosts: data.trackPosts.present
          ? data.trackPosts.value
          : this.trackPosts,
      trackReels: data.trackReels.present
          ? data.trackReels.value
          : this.trackReels,
      postsWatermarkAt: data.postsWatermarkAt.present
          ? data.postsWatermarkAt.value
          : this.postsWatermarkAt,
      loginAccountId: data.loginAccountId.present
          ? data.loginAccountId.value
          : this.loginAccountId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      lastStoriesCheckAt: data.lastStoriesCheckAt.present
          ? data.lastStoriesCheckAt.value
          : this.lastStoriesCheckAt,
      lastPostsCheckAt: data.lastPostsCheckAt.present
          ? data.lastPostsCheckAt.value
          : this.lastPostsCheckAt,
      lastNewStoryAt: data.lastNewStoryAt.present
          ? data.lastNewStoryAt.value
          : this.lastNewStoryAt,
      lastNewPostAt: data.lastNewPostAt.present
          ? data.lastNewPostAt.value
          : this.lastNewPostAt,
      historyRange: data.historyRange.present
          ? data.historyRange.value
          : this.historyRange,
      historySince: data.historySince.present
          ? data.historySince.value
          : this.historySince,
      historyState: data.historyState.present
          ? data.historyState.value
          : this.historyState,
      historyCursor: data.historyCursor.present
          ? data.historyCursor.value
          : this.historyCursor,
      historyFetched: data.historyFetched.present
          ? data.historyFetched.value
          : this.historyFetched,
      historyOldestSeenAt: data.historyOldestSeenAt.present
          ? data.historyOldestSeenAt.value
          : this.historyOldestSeenAt,
      historyUpdatedAt: data.historyUpdatedAt.present
          ? data.historyUpdatedAt.value
          : this.historyUpdatedAt,
      highlightsEnabled: data.highlightsEnabled.present
          ? data.highlightsEnabled.value
          : this.highlightsEnabled,
      lastSuccessAt: data.lastSuccessAt.present
          ? data.lastSuccessAt.value
          : this.lastSuccessAt,
      lastCheckOutcome: data.lastCheckOutcome.present
          ? data.lastCheckOutcome.value
          : this.lastCheckOutcome,
      lastCheckCode: data.lastCheckCode.present
          ? data.lastCheckCode.value
          : this.lastCheckCode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TargetRow(')
          ..write('id: $id, ')
          ..write('platform: $platform, ')
          ..write('remoteUserId: $remoteUserId, ')
          ..write('username: $username, ')
          ..write('displayName: $displayName, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('category: $category, ')
          ..write('note: $note, ')
          ..write('status: $status, ')
          ..write('statusReason: $statusReason, ')
          ..write('isPrivate: $isPrivate, ')
          ..write('trackStories: $trackStories, ')
          ..write('trackPosts: $trackPosts, ')
          ..write('trackReels: $trackReels, ')
          ..write('postsWatermarkAt: $postsWatermarkAt, ')
          ..write('loginAccountId: $loginAccountId, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastStoriesCheckAt: $lastStoriesCheckAt, ')
          ..write('lastPostsCheckAt: $lastPostsCheckAt, ')
          ..write('lastNewStoryAt: $lastNewStoryAt, ')
          ..write('lastNewPostAt: $lastNewPostAt, ')
          ..write('historyRange: $historyRange, ')
          ..write('historySince: $historySince, ')
          ..write('historyState: $historyState, ')
          ..write('historyCursor: $historyCursor, ')
          ..write('historyFetched: $historyFetched, ')
          ..write('historyOldestSeenAt: $historyOldestSeenAt, ')
          ..write('historyUpdatedAt: $historyUpdatedAt, ')
          ..write('highlightsEnabled: $highlightsEnabled, ')
          ..write('lastSuccessAt: $lastSuccessAt, ')
          ..write('lastCheckOutcome: $lastCheckOutcome, ')
          ..write('lastCheckCode: $lastCheckCode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    platform,
    remoteUserId,
    username,
    displayName,
    avatarPath,
    category,
    note,
    status,
    statusReason,
    isPrivate,
    trackStories,
    trackPosts,
    trackReels,
    postsWatermarkAt,
    loginAccountId,
    addedAt,
    lastStoriesCheckAt,
    lastPostsCheckAt,
    lastNewStoryAt,
    lastNewPostAt,
    historyRange,
    historySince,
    historyState,
    historyCursor,
    historyFetched,
    historyOldestSeenAt,
    historyUpdatedAt,
    highlightsEnabled,
    lastSuccessAt,
    lastCheckOutcome,
    lastCheckCode,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TargetRow &&
          other.id == this.id &&
          other.platform == this.platform &&
          other.remoteUserId == this.remoteUserId &&
          other.username == this.username &&
          other.displayName == this.displayName &&
          other.avatarPath == this.avatarPath &&
          other.category == this.category &&
          other.note == this.note &&
          other.status == this.status &&
          other.statusReason == this.statusReason &&
          other.isPrivate == this.isPrivate &&
          other.trackStories == this.trackStories &&
          other.trackPosts == this.trackPosts &&
          other.trackReels == this.trackReels &&
          other.postsWatermarkAt == this.postsWatermarkAt &&
          other.loginAccountId == this.loginAccountId &&
          other.addedAt == this.addedAt &&
          other.lastStoriesCheckAt == this.lastStoriesCheckAt &&
          other.lastPostsCheckAt == this.lastPostsCheckAt &&
          other.lastNewStoryAt == this.lastNewStoryAt &&
          other.lastNewPostAt == this.lastNewPostAt &&
          other.historyRange == this.historyRange &&
          other.historySince == this.historySince &&
          other.historyState == this.historyState &&
          other.historyCursor == this.historyCursor &&
          other.historyFetched == this.historyFetched &&
          other.historyOldestSeenAt == this.historyOldestSeenAt &&
          other.historyUpdatedAt == this.historyUpdatedAt &&
          other.highlightsEnabled == this.highlightsEnabled &&
          other.lastSuccessAt == this.lastSuccessAt &&
          other.lastCheckOutcome == this.lastCheckOutcome &&
          other.lastCheckCode == this.lastCheckCode);
}

class TargetsCompanion extends UpdateCompanion<TargetRow> {
  final Value<int> id;
  final Value<PlatformId> platform;
  final Value<String> remoteUserId;
  final Value<String> username;
  final Value<String?> displayName;
  final Value<String?> avatarPath;
  final Value<TargetCategory> category;
  final Value<String?> note;
  final Value<TargetStatus> status;
  final Value<String?> statusReason;
  final Value<bool> isPrivate;
  final Value<bool> trackStories;
  final Value<bool> trackPosts;
  final Value<bool> trackReels;
  final Value<DateTime> postsWatermarkAt;
  final Value<int?> loginAccountId;
  final Value<DateTime> addedAt;
  final Value<DateTime?> lastStoriesCheckAt;
  final Value<DateTime?> lastPostsCheckAt;
  final Value<DateTime?> lastNewStoryAt;
  final Value<DateTime?> lastNewPostAt;
  final Value<HistoryRange> historyRange;
  final Value<DateTime?> historySince;
  final Value<HistoryState> historyState;
  final Value<String?> historyCursor;
  final Value<int> historyFetched;
  final Value<DateTime?> historyOldestSeenAt;
  final Value<DateTime?> historyUpdatedAt;
  final Value<bool> highlightsEnabled;
  final Value<DateTime?> lastSuccessAt;
  final Value<TargetCheckOutcome?> lastCheckOutcome;
  final Value<String?> lastCheckCode;
  const TargetsCompanion({
    this.id = const Value.absent(),
    this.platform = const Value.absent(),
    this.remoteUserId = const Value.absent(),
    this.username = const Value.absent(),
    this.displayName = const Value.absent(),
    this.avatarPath = const Value.absent(),
    this.category = const Value.absent(),
    this.note = const Value.absent(),
    this.status = const Value.absent(),
    this.statusReason = const Value.absent(),
    this.isPrivate = const Value.absent(),
    this.trackStories = const Value.absent(),
    this.trackPosts = const Value.absent(),
    this.trackReels = const Value.absent(),
    this.postsWatermarkAt = const Value.absent(),
    this.loginAccountId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.lastStoriesCheckAt = const Value.absent(),
    this.lastPostsCheckAt = const Value.absent(),
    this.lastNewStoryAt = const Value.absent(),
    this.lastNewPostAt = const Value.absent(),
    this.historyRange = const Value.absent(),
    this.historySince = const Value.absent(),
    this.historyState = const Value.absent(),
    this.historyCursor = const Value.absent(),
    this.historyFetched = const Value.absent(),
    this.historyOldestSeenAt = const Value.absent(),
    this.historyUpdatedAt = const Value.absent(),
    this.highlightsEnabled = const Value.absent(),
    this.lastSuccessAt = const Value.absent(),
    this.lastCheckOutcome = const Value.absent(),
    this.lastCheckCode = const Value.absent(),
  });
  TargetsCompanion.insert({
    this.id = const Value.absent(),
    required PlatformId platform,
    required String remoteUserId,
    required String username,
    this.displayName = const Value.absent(),
    this.avatarPath = const Value.absent(),
    required TargetCategory category,
    this.note = const Value.absent(),
    required TargetStatus status,
    this.statusReason = const Value.absent(),
    this.isPrivate = const Value.absent(),
    this.trackStories = const Value.absent(),
    this.trackPosts = const Value.absent(),
    this.trackReels = const Value.absent(),
    required DateTime postsWatermarkAt,
    this.loginAccountId = const Value.absent(),
    required DateTime addedAt,
    this.lastStoriesCheckAt = const Value.absent(),
    this.lastPostsCheckAt = const Value.absent(),
    this.lastNewStoryAt = const Value.absent(),
    this.lastNewPostAt = const Value.absent(),
    this.historyRange = const Value.absent(),
    this.historySince = const Value.absent(),
    this.historyState = const Value.absent(),
    this.historyCursor = const Value.absent(),
    this.historyFetched = const Value.absent(),
    this.historyOldestSeenAt = const Value.absent(),
    this.historyUpdatedAt = const Value.absent(),
    this.highlightsEnabled = const Value.absent(),
    this.lastSuccessAt = const Value.absent(),
    this.lastCheckOutcome = const Value.absent(),
    this.lastCheckCode = const Value.absent(),
  }) : platform = Value(platform),
       remoteUserId = Value(remoteUserId),
       username = Value(username),
       category = Value(category),
       status = Value(status),
       postsWatermarkAt = Value(postsWatermarkAt),
       addedAt = Value(addedAt);
  static Insertable<TargetRow> custom({
    Expression<int>? id,
    Expression<String>? platform,
    Expression<String>? remoteUserId,
    Expression<String>? username,
    Expression<String>? displayName,
    Expression<String>? avatarPath,
    Expression<String>? category,
    Expression<String>? note,
    Expression<String>? status,
    Expression<String>? statusReason,
    Expression<bool>? isPrivate,
    Expression<bool>? trackStories,
    Expression<bool>? trackPosts,
    Expression<bool>? trackReels,
    Expression<int>? postsWatermarkAt,
    Expression<int>? loginAccountId,
    Expression<int>? addedAt,
    Expression<int>? lastStoriesCheckAt,
    Expression<int>? lastPostsCheckAt,
    Expression<int>? lastNewStoryAt,
    Expression<int>? lastNewPostAt,
    Expression<String>? historyRange,
    Expression<int>? historySince,
    Expression<String>? historyState,
    Expression<String>? historyCursor,
    Expression<int>? historyFetched,
    Expression<int>? historyOldestSeenAt,
    Expression<int>? historyUpdatedAt,
    Expression<bool>? highlightsEnabled,
    Expression<int>? lastSuccessAt,
    Expression<String>? lastCheckOutcome,
    Expression<String>? lastCheckCode,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (platform != null) 'platform': platform,
      if (remoteUserId != null) 'remote_user_id': remoteUserId,
      if (username != null) 'username': username,
      if (displayName != null) 'display_name': displayName,
      if (avatarPath != null) 'avatar_path': avatarPath,
      if (category != null) 'category': category,
      if (note != null) 'note': note,
      if (status != null) 'status': status,
      if (statusReason != null) 'status_reason': statusReason,
      if (isPrivate != null) 'is_private': isPrivate,
      if (trackStories != null) 'track_stories': trackStories,
      if (trackPosts != null) 'track_posts': trackPosts,
      if (trackReels != null) 'track_reels': trackReels,
      if (postsWatermarkAt != null) 'posts_watermark_at': postsWatermarkAt,
      if (loginAccountId != null) 'login_account_id': loginAccountId,
      if (addedAt != null) 'added_at': addedAt,
      if (lastStoriesCheckAt != null)
        'last_stories_check_at': lastStoriesCheckAt,
      if (lastPostsCheckAt != null) 'last_posts_check_at': lastPostsCheckAt,
      if (lastNewStoryAt != null) 'last_new_story_at': lastNewStoryAt,
      if (lastNewPostAt != null) 'last_new_post_at': lastNewPostAt,
      if (historyRange != null) 'history_range': historyRange,
      if (historySince != null) 'history_since': historySince,
      if (historyState != null) 'history_state': historyState,
      if (historyCursor != null) 'history_cursor': historyCursor,
      if (historyFetched != null) 'history_fetched': historyFetched,
      if (historyOldestSeenAt != null)
        'history_oldest_seen_at': historyOldestSeenAt,
      if (historyUpdatedAt != null) 'history_updated_at': historyUpdatedAt,
      if (highlightsEnabled != null) 'highlights_enabled': highlightsEnabled,
      if (lastSuccessAt != null) 'last_success_at': lastSuccessAt,
      if (lastCheckOutcome != null) 'last_check_outcome': lastCheckOutcome,
      if (lastCheckCode != null) 'last_check_code': lastCheckCode,
    });
  }

  TargetsCompanion copyWith({
    Value<int>? id,
    Value<PlatformId>? platform,
    Value<String>? remoteUserId,
    Value<String>? username,
    Value<String?>? displayName,
    Value<String?>? avatarPath,
    Value<TargetCategory>? category,
    Value<String?>? note,
    Value<TargetStatus>? status,
    Value<String?>? statusReason,
    Value<bool>? isPrivate,
    Value<bool>? trackStories,
    Value<bool>? trackPosts,
    Value<bool>? trackReels,
    Value<DateTime>? postsWatermarkAt,
    Value<int?>? loginAccountId,
    Value<DateTime>? addedAt,
    Value<DateTime?>? lastStoriesCheckAt,
    Value<DateTime?>? lastPostsCheckAt,
    Value<DateTime?>? lastNewStoryAt,
    Value<DateTime?>? lastNewPostAt,
    Value<HistoryRange>? historyRange,
    Value<DateTime?>? historySince,
    Value<HistoryState>? historyState,
    Value<String?>? historyCursor,
    Value<int>? historyFetched,
    Value<DateTime?>? historyOldestSeenAt,
    Value<DateTime?>? historyUpdatedAt,
    Value<bool>? highlightsEnabled,
    Value<DateTime?>? lastSuccessAt,
    Value<TargetCheckOutcome?>? lastCheckOutcome,
    Value<String?>? lastCheckCode,
  }) {
    return TargetsCompanion(
      id: id ?? this.id,
      platform: platform ?? this.platform,
      remoteUserId: remoteUserId ?? this.remoteUserId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarPath: avatarPath ?? this.avatarPath,
      category: category ?? this.category,
      note: note ?? this.note,
      status: status ?? this.status,
      statusReason: statusReason ?? this.statusReason,
      isPrivate: isPrivate ?? this.isPrivate,
      trackStories: trackStories ?? this.trackStories,
      trackPosts: trackPosts ?? this.trackPosts,
      trackReels: trackReels ?? this.trackReels,
      postsWatermarkAt: postsWatermarkAt ?? this.postsWatermarkAt,
      loginAccountId: loginAccountId ?? this.loginAccountId,
      addedAt: addedAt ?? this.addedAt,
      lastStoriesCheckAt: lastStoriesCheckAt ?? this.lastStoriesCheckAt,
      lastPostsCheckAt: lastPostsCheckAt ?? this.lastPostsCheckAt,
      lastNewStoryAt: lastNewStoryAt ?? this.lastNewStoryAt,
      lastNewPostAt: lastNewPostAt ?? this.lastNewPostAt,
      historyRange: historyRange ?? this.historyRange,
      historySince: historySince ?? this.historySince,
      historyState: historyState ?? this.historyState,
      historyCursor: historyCursor ?? this.historyCursor,
      historyFetched: historyFetched ?? this.historyFetched,
      historyOldestSeenAt: historyOldestSeenAt ?? this.historyOldestSeenAt,
      historyUpdatedAt: historyUpdatedAt ?? this.historyUpdatedAt,
      highlightsEnabled: highlightsEnabled ?? this.highlightsEnabled,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      lastCheckOutcome: lastCheckOutcome ?? this.lastCheckOutcome,
      lastCheckCode: lastCheckCode ?? this.lastCheckCode,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (platform.present) {
      map['platform'] = Variable<String>(
        $TargetsTable.$converterplatform.toSql(platform.value),
      );
    }
    if (remoteUserId.present) {
      map['remote_user_id'] = Variable<String>(remoteUserId.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (avatarPath.present) {
      map['avatar_path'] = Variable<String>(avatarPath.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(
        $TargetsTable.$convertercategory.toSql(category.value),
      );
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $TargetsTable.$converterstatus.toSql(status.value),
      );
    }
    if (statusReason.present) {
      map['status_reason'] = Variable<String>(statusReason.value);
    }
    if (isPrivate.present) {
      map['is_private'] = Variable<bool>(isPrivate.value);
    }
    if (trackStories.present) {
      map['track_stories'] = Variable<bool>(trackStories.value);
    }
    if (trackPosts.present) {
      map['track_posts'] = Variable<bool>(trackPosts.value);
    }
    if (trackReels.present) {
      map['track_reels'] = Variable<bool>(trackReels.value);
    }
    if (postsWatermarkAt.present) {
      map['posts_watermark_at'] = Variable<int>(
        $TargetsTable.$converterpostsWatermarkAt.toSql(postsWatermarkAt.value),
      );
    }
    if (loginAccountId.present) {
      map['login_account_id'] = Variable<int>(loginAccountId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(
        $TargetsTable.$converteraddedAt.toSql(addedAt.value),
      );
    }
    if (lastStoriesCheckAt.present) {
      map['last_stories_check_at'] = Variable<int>(
        $TargetsTable.$converterlastStoriesCheckAtn.toSql(
          lastStoriesCheckAt.value,
        ),
      );
    }
    if (lastPostsCheckAt.present) {
      map['last_posts_check_at'] = Variable<int>(
        $TargetsTable.$converterlastPostsCheckAtn.toSql(lastPostsCheckAt.value),
      );
    }
    if (lastNewStoryAt.present) {
      map['last_new_story_at'] = Variable<int>(
        $TargetsTable.$converterlastNewStoryAtn.toSql(lastNewStoryAt.value),
      );
    }
    if (lastNewPostAt.present) {
      map['last_new_post_at'] = Variable<int>(
        $TargetsTable.$converterlastNewPostAtn.toSql(lastNewPostAt.value),
      );
    }
    if (historyRange.present) {
      map['history_range'] = Variable<String>(
        $TargetsTable.$converterhistoryRange.toSql(historyRange.value),
      );
    }
    if (historySince.present) {
      map['history_since'] = Variable<int>(
        $TargetsTable.$converterhistorySincen.toSql(historySince.value),
      );
    }
    if (historyState.present) {
      map['history_state'] = Variable<String>(
        $TargetsTable.$converterhistoryState.toSql(historyState.value),
      );
    }
    if (historyCursor.present) {
      map['history_cursor'] = Variable<String>(historyCursor.value);
    }
    if (historyFetched.present) {
      map['history_fetched'] = Variable<int>(historyFetched.value);
    }
    if (historyOldestSeenAt.present) {
      map['history_oldest_seen_at'] = Variable<int>(
        $TargetsTable.$converterhistoryOldestSeenAtn.toSql(
          historyOldestSeenAt.value,
        ),
      );
    }
    if (historyUpdatedAt.present) {
      map['history_updated_at'] = Variable<int>(
        $TargetsTable.$converterhistoryUpdatedAtn.toSql(historyUpdatedAt.value),
      );
    }
    if (highlightsEnabled.present) {
      map['highlights_enabled'] = Variable<bool>(highlightsEnabled.value);
    }
    if (lastSuccessAt.present) {
      map['last_success_at'] = Variable<int>(
        $TargetsTable.$converterlastSuccessAtn.toSql(lastSuccessAt.value),
      );
    }
    if (lastCheckOutcome.present) {
      map['last_check_outcome'] = Variable<String>(
        $TargetsTable.$converterlastCheckOutcomen.toSql(lastCheckOutcome.value),
      );
    }
    if (lastCheckCode.present) {
      map['last_check_code'] = Variable<String>(lastCheckCode.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TargetsCompanion(')
          ..write('id: $id, ')
          ..write('platform: $platform, ')
          ..write('remoteUserId: $remoteUserId, ')
          ..write('username: $username, ')
          ..write('displayName: $displayName, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('category: $category, ')
          ..write('note: $note, ')
          ..write('status: $status, ')
          ..write('statusReason: $statusReason, ')
          ..write('isPrivate: $isPrivate, ')
          ..write('trackStories: $trackStories, ')
          ..write('trackPosts: $trackPosts, ')
          ..write('trackReels: $trackReels, ')
          ..write('postsWatermarkAt: $postsWatermarkAt, ')
          ..write('loginAccountId: $loginAccountId, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastStoriesCheckAt: $lastStoriesCheckAt, ')
          ..write('lastPostsCheckAt: $lastPostsCheckAt, ')
          ..write('lastNewStoryAt: $lastNewStoryAt, ')
          ..write('lastNewPostAt: $lastNewPostAt, ')
          ..write('historyRange: $historyRange, ')
          ..write('historySince: $historySince, ')
          ..write('historyState: $historyState, ')
          ..write('historyCursor: $historyCursor, ')
          ..write('historyFetched: $historyFetched, ')
          ..write('historyOldestSeenAt: $historyOldestSeenAt, ')
          ..write('historyUpdatedAt: $historyUpdatedAt, ')
          ..write('highlightsEnabled: $highlightsEnabled, ')
          ..write('lastSuccessAt: $lastSuccessAt, ')
          ..write('lastCheckOutcome: $lastCheckOutcome, ')
          ..write('lastCheckCode: $lastCheckCode')
          ..write(')'))
        .toString();
  }
}

class $ContentsTable extends Contents
    with TableInfo<$ContentsTable, ContentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  @override
  late final GeneratedColumn<int> targetId = GeneratedColumn<int>(
    'target_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES target (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<ContentKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ContentKind>($ContentsTable.$converterkind);
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
    'remote_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _shortcodeMeta = const VerificationMeta(
    'shortcode',
  );
  @override
  late final GeneratedColumn<String> shortcode = GeneratedColumn<String>(
    'shortcode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<PostType?, String> postType =
      GeneratedColumn<String>(
        'post_type',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<PostType?>($ContentsTable.$converterpostTypen);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> postedAt =
      GeneratedColumn<int>(
        'posted_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ContentsTable.$converterpostedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> expiresAt =
      GeneratedColumn<int>(
        'expires_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($ContentsTable.$converterexpiresAtn);
  static const VerificationMeta _captionMeta = const VerificationMeta(
    'caption',
  );
  @override
  late final GeneratedColumn<String> caption = GeneratedColumn<String>(
    'caption',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationNameMeta = const VerificationMeta(
    'locationName',
  );
  @override
  late final GeneratedColumn<String> locationName = GeneratedColumn<String>(
    'location_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _taggedUsernamesMeta = const VerificationMeta(
    'taggedUsernames',
  );
  @override
  late final GeneratedColumn<String> taggedUsernames = GeneratedColumn<String>(
    'tagged_usernames',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _slideCountMeta = const VerificationMeta(
    'slideCount',
  );
  @override
  late final GeneratedColumn<int> slideCount = GeneratedColumn<int>(
    'slide_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _isCloseFriendsMeta = const VerificationMeta(
    'isCloseFriends',
  );
  @override
  late final GeneratedColumn<bool> isCloseFriends = GeneratedColumn<bool>(
    'is_close_friends',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_close_friends" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _extrasJsonMeta = const VerificationMeta(
    'extrasJson',
  );
  @override
  late final GeneratedColumn<String> extrasJson = GeneratedColumn<String>(
    'extras_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> detectedAt =
      GeneratedColumn<int>(
        'detected_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ContentsTable.$converterdetectedAt);
  @override
  late final GeneratedColumnWithTypeConverter<ContentStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ContentStatus>($ContentsTable.$converterstatus);
  static const VerificationMeta _viewedMeta = const VerificationMeta('viewed');
  @override
  late final GeneratedColumn<bool> viewed = GeneratedColumn<bool>(
    'viewed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("viewed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    targetId,
    kind,
    remoteId,
    shortcode,
    postType,
    postedAt,
    expiresAt,
    caption,
    locationName,
    taggedUsernames,
    slideCount,
    isCloseFriends,
    extrasJson,
    detectedAt,
    status,
    viewed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_targetIdMeta);
    }
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteIdMeta);
    }
    if (data.containsKey('shortcode')) {
      context.handle(
        _shortcodeMeta,
        shortcode.isAcceptableOrUnknown(data['shortcode']!, _shortcodeMeta),
      );
    }
    if (data.containsKey('caption')) {
      context.handle(
        _captionMeta,
        caption.isAcceptableOrUnknown(data['caption']!, _captionMeta),
      );
    }
    if (data.containsKey('location_name')) {
      context.handle(
        _locationNameMeta,
        locationName.isAcceptableOrUnknown(
          data['location_name']!,
          _locationNameMeta,
        ),
      );
    }
    if (data.containsKey('tagged_usernames')) {
      context.handle(
        _taggedUsernamesMeta,
        taggedUsernames.isAcceptableOrUnknown(
          data['tagged_usernames']!,
          _taggedUsernamesMeta,
        ),
      );
    }
    if (data.containsKey('slide_count')) {
      context.handle(
        _slideCountMeta,
        slideCount.isAcceptableOrUnknown(data['slide_count']!, _slideCountMeta),
      );
    }
    if (data.containsKey('is_close_friends')) {
      context.handle(
        _isCloseFriendsMeta,
        isCloseFriends.isAcceptableOrUnknown(
          data['is_close_friends']!,
          _isCloseFriendsMeta,
        ),
      );
    }
    if (data.containsKey('extras_json')) {
      context.handle(
        _extrasJsonMeta,
        extrasJson.isAcceptableOrUnknown(data['extras_json']!, _extrasJsonMeta),
      );
    }
    if (data.containsKey('viewed')) {
      context.handle(
        _viewedMeta,
        viewed.isAcceptableOrUnknown(data['viewed']!, _viewedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {targetId, kind, remoteId},
  ];
  @override
  ContentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_id'],
      )!,
      kind: $ContentsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_id'],
      )!,
      shortcode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shortcode'],
      ),
      postType: $ContentsTable.$converterpostTypen.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}post_type'],
        ),
      ),
      postedAt: $ContentsTable.$converterpostedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}posted_at'],
        )!,
      ),
      expiresAt: $ContentsTable.$converterexpiresAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}expires_at'],
        ),
      ),
      caption: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}caption'],
      ),
      locationName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location_name'],
      ),
      taggedUsernames: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tagged_usernames'],
      ),
      slideCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}slide_count'],
      )!,
      isCloseFriends: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_close_friends'],
      )!,
      extrasJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extras_json'],
      ),
      detectedAt: $ContentsTable.$converterdetectedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}detected_at'],
        )!,
      ),
      status: $ContentsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      viewed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}viewed'],
      )!,
    );
  }

  @override
  $ContentsTable createAlias(String alias) {
    return $ContentsTable(attachedDatabase, alias);
  }

  static TypeConverter<ContentKind, String> $converterkind =
      const ContentKindConverter();
  static TypeConverter<PostType, String> $converterpostType =
      const PostTypeConverter();
  static TypeConverter<PostType?, String?> $converterpostTypen =
      NullAwareTypeConverter.wrap($converterpostType);
  static TypeConverter<DateTime, int> $converterpostedAt =
      const EpochMsConverter();
  static TypeConverter<DateTime, int> $converterexpiresAt =
      const EpochMsConverter();
  static TypeConverter<DateTime?, int?> $converterexpiresAtn =
      NullAwareTypeConverter.wrap($converterexpiresAt);
  static TypeConverter<DateTime, int> $converterdetectedAt =
      const EpochMsConverter();
  static TypeConverter<ContentStatus, String> $converterstatus =
      const ContentStatusConverter();
}

class ContentRow extends DataClass implements Insertable<ContentRow> {
  final int id;
  final int targetId;
  final ContentKind kind;
  final String remoteId;
  final String? shortcode;
  final PostType? postType;
  final DateTime postedAt;
  final DateTime? expiresAt;
  final String? caption;
  final String? locationName;
  final String? taggedUsernames;
  final int slideCount;
  final bool isCloseFriends;
  final String? extrasJson;
  final DateTime detectedAt;
  final ContentStatus status;
  final bool viewed;
  const ContentRow({
    required this.id,
    required this.targetId,
    required this.kind,
    required this.remoteId,
    this.shortcode,
    this.postType,
    required this.postedAt,
    this.expiresAt,
    this.caption,
    this.locationName,
    this.taggedUsernames,
    required this.slideCount,
    required this.isCloseFriends,
    this.extrasJson,
    required this.detectedAt,
    required this.status,
    required this.viewed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['target_id'] = Variable<int>(targetId);
    {
      map['kind'] = Variable<String>($ContentsTable.$converterkind.toSql(kind));
    }
    map['remote_id'] = Variable<String>(remoteId);
    if (!nullToAbsent || shortcode != null) {
      map['shortcode'] = Variable<String>(shortcode);
    }
    if (!nullToAbsent || postType != null) {
      map['post_type'] = Variable<String>(
        $ContentsTable.$converterpostTypen.toSql(postType),
      );
    }
    {
      map['posted_at'] = Variable<int>(
        $ContentsTable.$converterpostedAt.toSql(postedAt),
      );
    }
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<int>(
        $ContentsTable.$converterexpiresAtn.toSql(expiresAt),
      );
    }
    if (!nullToAbsent || caption != null) {
      map['caption'] = Variable<String>(caption);
    }
    if (!nullToAbsent || locationName != null) {
      map['location_name'] = Variable<String>(locationName);
    }
    if (!nullToAbsent || taggedUsernames != null) {
      map['tagged_usernames'] = Variable<String>(taggedUsernames);
    }
    map['slide_count'] = Variable<int>(slideCount);
    map['is_close_friends'] = Variable<bool>(isCloseFriends);
    if (!nullToAbsent || extrasJson != null) {
      map['extras_json'] = Variable<String>(extrasJson);
    }
    {
      map['detected_at'] = Variable<int>(
        $ContentsTable.$converterdetectedAt.toSql(detectedAt),
      );
    }
    {
      map['status'] = Variable<String>(
        $ContentsTable.$converterstatus.toSql(status),
      );
    }
    map['viewed'] = Variable<bool>(viewed);
    return map;
  }

  ContentsCompanion toCompanion(bool nullToAbsent) {
    return ContentsCompanion(
      id: Value(id),
      targetId: Value(targetId),
      kind: Value(kind),
      remoteId: Value(remoteId),
      shortcode: shortcode == null && nullToAbsent
          ? const Value.absent()
          : Value(shortcode),
      postType: postType == null && nullToAbsent
          ? const Value.absent()
          : Value(postType),
      postedAt: Value(postedAt),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
      caption: caption == null && nullToAbsent
          ? const Value.absent()
          : Value(caption),
      locationName: locationName == null && nullToAbsent
          ? const Value.absent()
          : Value(locationName),
      taggedUsernames: taggedUsernames == null && nullToAbsent
          ? const Value.absent()
          : Value(taggedUsernames),
      slideCount: Value(slideCount),
      isCloseFriends: Value(isCloseFriends),
      extrasJson: extrasJson == null && nullToAbsent
          ? const Value.absent()
          : Value(extrasJson),
      detectedAt: Value(detectedAt),
      status: Value(status),
      viewed: Value(viewed),
    );
  }

  factory ContentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentRow(
      id: serializer.fromJson<int>(json['id']),
      targetId: serializer.fromJson<int>(json['targetId']),
      kind: serializer.fromJson<ContentKind>(json['kind']),
      remoteId: serializer.fromJson<String>(json['remoteId']),
      shortcode: serializer.fromJson<String?>(json['shortcode']),
      postType: serializer.fromJson<PostType?>(json['postType']),
      postedAt: serializer.fromJson<DateTime>(json['postedAt']),
      expiresAt: serializer.fromJson<DateTime?>(json['expiresAt']),
      caption: serializer.fromJson<String?>(json['caption']),
      locationName: serializer.fromJson<String?>(json['locationName']),
      taggedUsernames: serializer.fromJson<String?>(json['taggedUsernames']),
      slideCount: serializer.fromJson<int>(json['slideCount']),
      isCloseFriends: serializer.fromJson<bool>(json['isCloseFriends']),
      extrasJson: serializer.fromJson<String?>(json['extrasJson']),
      detectedAt: serializer.fromJson<DateTime>(json['detectedAt']),
      status: serializer.fromJson<ContentStatus>(json['status']),
      viewed: serializer.fromJson<bool>(json['viewed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'targetId': serializer.toJson<int>(targetId),
      'kind': serializer.toJson<ContentKind>(kind),
      'remoteId': serializer.toJson<String>(remoteId),
      'shortcode': serializer.toJson<String?>(shortcode),
      'postType': serializer.toJson<PostType?>(postType),
      'postedAt': serializer.toJson<DateTime>(postedAt),
      'expiresAt': serializer.toJson<DateTime?>(expiresAt),
      'caption': serializer.toJson<String?>(caption),
      'locationName': serializer.toJson<String?>(locationName),
      'taggedUsernames': serializer.toJson<String?>(taggedUsernames),
      'slideCount': serializer.toJson<int>(slideCount),
      'isCloseFriends': serializer.toJson<bool>(isCloseFriends),
      'extrasJson': serializer.toJson<String?>(extrasJson),
      'detectedAt': serializer.toJson<DateTime>(detectedAt),
      'status': serializer.toJson<ContentStatus>(status),
      'viewed': serializer.toJson<bool>(viewed),
    };
  }

  ContentRow copyWith({
    int? id,
    int? targetId,
    ContentKind? kind,
    String? remoteId,
    Value<String?> shortcode = const Value.absent(),
    Value<PostType?> postType = const Value.absent(),
    DateTime? postedAt,
    Value<DateTime?> expiresAt = const Value.absent(),
    Value<String?> caption = const Value.absent(),
    Value<String?> locationName = const Value.absent(),
    Value<String?> taggedUsernames = const Value.absent(),
    int? slideCount,
    bool? isCloseFriends,
    Value<String?> extrasJson = const Value.absent(),
    DateTime? detectedAt,
    ContentStatus? status,
    bool? viewed,
  }) => ContentRow(
    id: id ?? this.id,
    targetId: targetId ?? this.targetId,
    kind: kind ?? this.kind,
    remoteId: remoteId ?? this.remoteId,
    shortcode: shortcode.present ? shortcode.value : this.shortcode,
    postType: postType.present ? postType.value : this.postType,
    postedAt: postedAt ?? this.postedAt,
    expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
    caption: caption.present ? caption.value : this.caption,
    locationName: locationName.present ? locationName.value : this.locationName,
    taggedUsernames: taggedUsernames.present
        ? taggedUsernames.value
        : this.taggedUsernames,
    slideCount: slideCount ?? this.slideCount,
    isCloseFriends: isCloseFriends ?? this.isCloseFriends,
    extrasJson: extrasJson.present ? extrasJson.value : this.extrasJson,
    detectedAt: detectedAt ?? this.detectedAt,
    status: status ?? this.status,
    viewed: viewed ?? this.viewed,
  );
  ContentRow copyWithCompanion(ContentsCompanion data) {
    return ContentRow(
      id: data.id.present ? data.id.value : this.id,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      kind: data.kind.present ? data.kind.value : this.kind,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      shortcode: data.shortcode.present ? data.shortcode.value : this.shortcode,
      postType: data.postType.present ? data.postType.value : this.postType,
      postedAt: data.postedAt.present ? data.postedAt.value : this.postedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      caption: data.caption.present ? data.caption.value : this.caption,
      locationName: data.locationName.present
          ? data.locationName.value
          : this.locationName,
      taggedUsernames: data.taggedUsernames.present
          ? data.taggedUsernames.value
          : this.taggedUsernames,
      slideCount: data.slideCount.present
          ? data.slideCount.value
          : this.slideCount,
      isCloseFriends: data.isCloseFriends.present
          ? data.isCloseFriends.value
          : this.isCloseFriends,
      extrasJson: data.extrasJson.present
          ? data.extrasJson.value
          : this.extrasJson,
      detectedAt: data.detectedAt.present
          ? data.detectedAt.value
          : this.detectedAt,
      status: data.status.present ? data.status.value : this.status,
      viewed: data.viewed.present ? data.viewed.value : this.viewed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentRow(')
          ..write('id: $id, ')
          ..write('targetId: $targetId, ')
          ..write('kind: $kind, ')
          ..write('remoteId: $remoteId, ')
          ..write('shortcode: $shortcode, ')
          ..write('postType: $postType, ')
          ..write('postedAt: $postedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('caption: $caption, ')
          ..write('locationName: $locationName, ')
          ..write('taggedUsernames: $taggedUsernames, ')
          ..write('slideCount: $slideCount, ')
          ..write('isCloseFriends: $isCloseFriends, ')
          ..write('extrasJson: $extrasJson, ')
          ..write('detectedAt: $detectedAt, ')
          ..write('status: $status, ')
          ..write('viewed: $viewed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    targetId,
    kind,
    remoteId,
    shortcode,
    postType,
    postedAt,
    expiresAt,
    caption,
    locationName,
    taggedUsernames,
    slideCount,
    isCloseFriends,
    extrasJson,
    detectedAt,
    status,
    viewed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentRow &&
          other.id == this.id &&
          other.targetId == this.targetId &&
          other.kind == this.kind &&
          other.remoteId == this.remoteId &&
          other.shortcode == this.shortcode &&
          other.postType == this.postType &&
          other.postedAt == this.postedAt &&
          other.expiresAt == this.expiresAt &&
          other.caption == this.caption &&
          other.locationName == this.locationName &&
          other.taggedUsernames == this.taggedUsernames &&
          other.slideCount == this.slideCount &&
          other.isCloseFriends == this.isCloseFriends &&
          other.extrasJson == this.extrasJson &&
          other.detectedAt == this.detectedAt &&
          other.status == this.status &&
          other.viewed == this.viewed);
}

class ContentsCompanion extends UpdateCompanion<ContentRow> {
  final Value<int> id;
  final Value<int> targetId;
  final Value<ContentKind> kind;
  final Value<String> remoteId;
  final Value<String?> shortcode;
  final Value<PostType?> postType;
  final Value<DateTime> postedAt;
  final Value<DateTime?> expiresAt;
  final Value<String?> caption;
  final Value<String?> locationName;
  final Value<String?> taggedUsernames;
  final Value<int> slideCount;
  final Value<bool> isCloseFriends;
  final Value<String?> extrasJson;
  final Value<DateTime> detectedAt;
  final Value<ContentStatus> status;
  final Value<bool> viewed;
  const ContentsCompanion({
    this.id = const Value.absent(),
    this.targetId = const Value.absent(),
    this.kind = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.shortcode = const Value.absent(),
    this.postType = const Value.absent(),
    this.postedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.caption = const Value.absent(),
    this.locationName = const Value.absent(),
    this.taggedUsernames = const Value.absent(),
    this.slideCount = const Value.absent(),
    this.isCloseFriends = const Value.absent(),
    this.extrasJson = const Value.absent(),
    this.detectedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.viewed = const Value.absent(),
  });
  ContentsCompanion.insert({
    this.id = const Value.absent(),
    required int targetId,
    required ContentKind kind,
    required String remoteId,
    this.shortcode = const Value.absent(),
    this.postType = const Value.absent(),
    required DateTime postedAt,
    this.expiresAt = const Value.absent(),
    this.caption = const Value.absent(),
    this.locationName = const Value.absent(),
    this.taggedUsernames = const Value.absent(),
    this.slideCount = const Value.absent(),
    this.isCloseFriends = const Value.absent(),
    this.extrasJson = const Value.absent(),
    required DateTime detectedAt,
    required ContentStatus status,
    this.viewed = const Value.absent(),
  }) : targetId = Value(targetId),
       kind = Value(kind),
       remoteId = Value(remoteId),
       postedAt = Value(postedAt),
       detectedAt = Value(detectedAt),
       status = Value(status);
  static Insertable<ContentRow> custom({
    Expression<int>? id,
    Expression<int>? targetId,
    Expression<String>? kind,
    Expression<String>? remoteId,
    Expression<String>? shortcode,
    Expression<String>? postType,
    Expression<int>? postedAt,
    Expression<int>? expiresAt,
    Expression<String>? caption,
    Expression<String>? locationName,
    Expression<String>? taggedUsernames,
    Expression<int>? slideCount,
    Expression<bool>? isCloseFriends,
    Expression<String>? extrasJson,
    Expression<int>? detectedAt,
    Expression<String>? status,
    Expression<bool>? viewed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (targetId != null) 'target_id': targetId,
      if (kind != null) 'kind': kind,
      if (remoteId != null) 'remote_id': remoteId,
      if (shortcode != null) 'shortcode': shortcode,
      if (postType != null) 'post_type': postType,
      if (postedAt != null) 'posted_at': postedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (caption != null) 'caption': caption,
      if (locationName != null) 'location_name': locationName,
      if (taggedUsernames != null) 'tagged_usernames': taggedUsernames,
      if (slideCount != null) 'slide_count': slideCount,
      if (isCloseFriends != null) 'is_close_friends': isCloseFriends,
      if (extrasJson != null) 'extras_json': extrasJson,
      if (detectedAt != null) 'detected_at': detectedAt,
      if (status != null) 'status': status,
      if (viewed != null) 'viewed': viewed,
    });
  }

  ContentsCompanion copyWith({
    Value<int>? id,
    Value<int>? targetId,
    Value<ContentKind>? kind,
    Value<String>? remoteId,
    Value<String?>? shortcode,
    Value<PostType?>? postType,
    Value<DateTime>? postedAt,
    Value<DateTime?>? expiresAt,
    Value<String?>? caption,
    Value<String?>? locationName,
    Value<String?>? taggedUsernames,
    Value<int>? slideCount,
    Value<bool>? isCloseFriends,
    Value<String?>? extrasJson,
    Value<DateTime>? detectedAt,
    Value<ContentStatus>? status,
    Value<bool>? viewed,
  }) {
    return ContentsCompanion(
      id: id ?? this.id,
      targetId: targetId ?? this.targetId,
      kind: kind ?? this.kind,
      remoteId: remoteId ?? this.remoteId,
      shortcode: shortcode ?? this.shortcode,
      postType: postType ?? this.postType,
      postedAt: postedAt ?? this.postedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      caption: caption ?? this.caption,
      locationName: locationName ?? this.locationName,
      taggedUsernames: taggedUsernames ?? this.taggedUsernames,
      slideCount: slideCount ?? this.slideCount,
      isCloseFriends: isCloseFriends ?? this.isCloseFriends,
      extrasJson: extrasJson ?? this.extrasJson,
      detectedAt: detectedAt ?? this.detectedAt,
      status: status ?? this.status,
      viewed: viewed ?? this.viewed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<int>(targetId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $ContentsTable.$converterkind.toSql(kind.value),
      );
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (shortcode.present) {
      map['shortcode'] = Variable<String>(shortcode.value);
    }
    if (postType.present) {
      map['post_type'] = Variable<String>(
        $ContentsTable.$converterpostTypen.toSql(postType.value),
      );
    }
    if (postedAt.present) {
      map['posted_at'] = Variable<int>(
        $ContentsTable.$converterpostedAt.toSql(postedAt.value),
      );
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<int>(
        $ContentsTable.$converterexpiresAtn.toSql(expiresAt.value),
      );
    }
    if (caption.present) {
      map['caption'] = Variable<String>(caption.value);
    }
    if (locationName.present) {
      map['location_name'] = Variable<String>(locationName.value);
    }
    if (taggedUsernames.present) {
      map['tagged_usernames'] = Variable<String>(taggedUsernames.value);
    }
    if (slideCount.present) {
      map['slide_count'] = Variable<int>(slideCount.value);
    }
    if (isCloseFriends.present) {
      map['is_close_friends'] = Variable<bool>(isCloseFriends.value);
    }
    if (extrasJson.present) {
      map['extras_json'] = Variable<String>(extrasJson.value);
    }
    if (detectedAt.present) {
      map['detected_at'] = Variable<int>(
        $ContentsTable.$converterdetectedAt.toSql(detectedAt.value),
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $ContentsTable.$converterstatus.toSql(status.value),
      );
    }
    if (viewed.present) {
      map['viewed'] = Variable<bool>(viewed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentsCompanion(')
          ..write('id: $id, ')
          ..write('targetId: $targetId, ')
          ..write('kind: $kind, ')
          ..write('remoteId: $remoteId, ')
          ..write('shortcode: $shortcode, ')
          ..write('postType: $postType, ')
          ..write('postedAt: $postedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('caption: $caption, ')
          ..write('locationName: $locationName, ')
          ..write('taggedUsernames: $taggedUsernames, ')
          ..write('slideCount: $slideCount, ')
          ..write('isCloseFriends: $isCloseFriends, ')
          ..write('extrasJson: $extrasJson, ')
          ..write('detectedAt: $detectedAt, ')
          ..write('status: $status, ')
          ..write('viewed: $viewed')
          ..write(')'))
        .toString();
  }
}

class $MediaFilesTable extends MediaFiles
    with TableInfo<$MediaFilesTable, MediaFileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _contentIdMeta = const VerificationMeta(
    'contentId',
  );
  @override
  late final GeneratedColumn<int> contentId = GeneratedColumn<int>(
    'content_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES content (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _slideIndexMeta = const VerificationMeta(
    'slideIndex',
  );
  @override
  late final GeneratedColumn<int> slideIndex = GeneratedColumn<int>(
    'slide_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  late final GeneratedColumnWithTypeConverter<MediaType, String> mediaType =
      GeneratedColumn<String>(
        'media_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<MediaType>($MediaFilesTable.$convertermediaType);
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<MediaFileStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<MediaFileStatus>($MediaFilesTable.$converterstatus);
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _contentUriMeta = const VerificationMeta(
    'contentUri',
  );
  @override
  late final GeneratedColumn<String> contentUri = GeneratedColumn<String>(
    'content_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbPathMeta = const VerificationMeta(
    'thumbPath',
  );
  @override
  late final GeneratedColumn<String> thumbPath = GeneratedColumn<String>(
    'thumb_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> downloadedAt =
      GeneratedColumn<int>(
        'downloaded_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($MediaFilesTable.$converterdownloadedAtn);
  @override
  List<GeneratedColumn> get $columns => [
    id,
    contentId,
    slideIndex,
    mediaType,
    sourceUrl,
    status,
    attempts,
    contentUri,
    relativePath,
    displayName,
    thumbPath,
    width,
    height,
    durationMs,
    sizeBytes,
    downloadedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_file';
  @override
  VerificationContext validateIntegrity(
    Insertable<MediaFileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('content_id')) {
      context.handle(
        _contentIdMeta,
        contentId.isAcceptableOrUnknown(data['content_id']!, _contentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_contentIdMeta);
    }
    if (data.containsKey('slide_index')) {
      context.handle(
        _slideIndexMeta,
        slideIndex.isAcceptableOrUnknown(data['slide_index']!, _slideIndexMeta),
      );
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceUrlMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('content_uri')) {
      context.handle(
        _contentUriMeta,
        contentUri.isAcceptableOrUnknown(data['content_uri']!, _contentUriMeta),
      );
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    }
    if (data.containsKey('thumb_path')) {
      context.handle(
        _thumbPathMeta,
        thumbPath.isAcceptableOrUnknown(data['thumb_path']!, _thumbPathMeta),
      );
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {contentId, slideIndex},
  ];
  @override
  MediaFileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaFileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      contentId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}content_id'],
      )!,
      slideIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}slide_index'],
      )!,
      mediaType: $MediaFilesTable.$convertermediaType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}media_type'],
        )!,
      ),
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      )!,
      status: $MediaFilesTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      contentUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_uri'],
      ),
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      ),
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      ),
      thumbPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumb_path'],
      ),
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      ),
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      ),
      downloadedAt: $MediaFilesTable.$converterdownloadedAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}downloaded_at'],
        ),
      ),
    );
  }

  @override
  $MediaFilesTable createAlias(String alias) {
    return $MediaFilesTable(attachedDatabase, alias);
  }

  static TypeConverter<MediaType, String> $convertermediaType =
      const MediaTypeConverter();
  static TypeConverter<MediaFileStatus, String> $converterstatus =
      const MediaFileStatusConverter();
  static TypeConverter<DateTime, int> $converterdownloadedAt =
      const EpochMsConverter();
  static TypeConverter<DateTime?, int?> $converterdownloadedAtn =
      NullAwareTypeConverter.wrap($converterdownloadedAt);
}

class MediaFileRow extends DataClass implements Insertable<MediaFileRow> {
  final int id;
  final int contentId;
  final int slideIndex;
  final MediaType mediaType;
  final String sourceUrl;
  final MediaFileStatus status;
  final int attempts;
  final String? contentUri;
  final String? relativePath;
  final String? displayName;
  final String? thumbPath;
  final int? width;
  final int? height;
  final int? durationMs;
  final int? sizeBytes;
  final DateTime? downloadedAt;
  const MediaFileRow({
    required this.id,
    required this.contentId,
    required this.slideIndex,
    required this.mediaType,
    required this.sourceUrl,
    required this.status,
    required this.attempts,
    this.contentUri,
    this.relativePath,
    this.displayName,
    this.thumbPath,
    this.width,
    this.height,
    this.durationMs,
    this.sizeBytes,
    this.downloadedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['content_id'] = Variable<int>(contentId);
    map['slide_index'] = Variable<int>(slideIndex);
    {
      map['media_type'] = Variable<String>(
        $MediaFilesTable.$convertermediaType.toSql(mediaType),
      );
    }
    map['source_url'] = Variable<String>(sourceUrl);
    {
      map['status'] = Variable<String>(
        $MediaFilesTable.$converterstatus.toSql(status),
      );
    }
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || contentUri != null) {
      map['content_uri'] = Variable<String>(contentUri);
    }
    if (!nullToAbsent || relativePath != null) {
      map['relative_path'] = Variable<String>(relativePath);
    }
    if (!nullToAbsent || displayName != null) {
      map['display_name'] = Variable<String>(displayName);
    }
    if (!nullToAbsent || thumbPath != null) {
      map['thumb_path'] = Variable<String>(thumbPath);
    }
    if (!nullToAbsent || width != null) {
      map['width'] = Variable<int>(width);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<int>(height);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || sizeBytes != null) {
      map['size_bytes'] = Variable<int>(sizeBytes);
    }
    if (!nullToAbsent || downloadedAt != null) {
      map['downloaded_at'] = Variable<int>(
        $MediaFilesTable.$converterdownloadedAtn.toSql(downloadedAt),
      );
    }
    return map;
  }

  MediaFilesCompanion toCompanion(bool nullToAbsent) {
    return MediaFilesCompanion(
      id: Value(id),
      contentId: Value(contentId),
      slideIndex: Value(slideIndex),
      mediaType: Value(mediaType),
      sourceUrl: Value(sourceUrl),
      status: Value(status),
      attempts: Value(attempts),
      contentUri: contentUri == null && nullToAbsent
          ? const Value.absent()
          : Value(contentUri),
      relativePath: relativePath == null && nullToAbsent
          ? const Value.absent()
          : Value(relativePath),
      displayName: displayName == null && nullToAbsent
          ? const Value.absent()
          : Value(displayName),
      thumbPath: thumbPath == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbPath),
      width: width == null && nullToAbsent
          ? const Value.absent()
          : Value(width),
      height: height == null && nullToAbsent
          ? const Value.absent()
          : Value(height),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      sizeBytes: sizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeBytes),
      downloadedAt: downloadedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadedAt),
    );
  }

  factory MediaFileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaFileRow(
      id: serializer.fromJson<int>(json['id']),
      contentId: serializer.fromJson<int>(json['contentId']),
      slideIndex: serializer.fromJson<int>(json['slideIndex']),
      mediaType: serializer.fromJson<MediaType>(json['mediaType']),
      sourceUrl: serializer.fromJson<String>(json['sourceUrl']),
      status: serializer.fromJson<MediaFileStatus>(json['status']),
      attempts: serializer.fromJson<int>(json['attempts']),
      contentUri: serializer.fromJson<String?>(json['contentUri']),
      relativePath: serializer.fromJson<String?>(json['relativePath']),
      displayName: serializer.fromJson<String?>(json['displayName']),
      thumbPath: serializer.fromJson<String?>(json['thumbPath']),
      width: serializer.fromJson<int?>(json['width']),
      height: serializer.fromJson<int?>(json['height']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      sizeBytes: serializer.fromJson<int?>(json['sizeBytes']),
      downloadedAt: serializer.fromJson<DateTime?>(json['downloadedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'contentId': serializer.toJson<int>(contentId),
      'slideIndex': serializer.toJson<int>(slideIndex),
      'mediaType': serializer.toJson<MediaType>(mediaType),
      'sourceUrl': serializer.toJson<String>(sourceUrl),
      'status': serializer.toJson<MediaFileStatus>(status),
      'attempts': serializer.toJson<int>(attempts),
      'contentUri': serializer.toJson<String?>(contentUri),
      'relativePath': serializer.toJson<String?>(relativePath),
      'displayName': serializer.toJson<String?>(displayName),
      'thumbPath': serializer.toJson<String?>(thumbPath),
      'width': serializer.toJson<int?>(width),
      'height': serializer.toJson<int?>(height),
      'durationMs': serializer.toJson<int?>(durationMs),
      'sizeBytes': serializer.toJson<int?>(sizeBytes),
      'downloadedAt': serializer.toJson<DateTime?>(downloadedAt),
    };
  }

  MediaFileRow copyWith({
    int? id,
    int? contentId,
    int? slideIndex,
    MediaType? mediaType,
    String? sourceUrl,
    MediaFileStatus? status,
    int? attempts,
    Value<String?> contentUri = const Value.absent(),
    Value<String?> relativePath = const Value.absent(),
    Value<String?> displayName = const Value.absent(),
    Value<String?> thumbPath = const Value.absent(),
    Value<int?> width = const Value.absent(),
    Value<int?> height = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    Value<int?> sizeBytes = const Value.absent(),
    Value<DateTime?> downloadedAt = const Value.absent(),
  }) => MediaFileRow(
    id: id ?? this.id,
    contentId: contentId ?? this.contentId,
    slideIndex: slideIndex ?? this.slideIndex,
    mediaType: mediaType ?? this.mediaType,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    status: status ?? this.status,
    attempts: attempts ?? this.attempts,
    contentUri: contentUri.present ? contentUri.value : this.contentUri,
    relativePath: relativePath.present ? relativePath.value : this.relativePath,
    displayName: displayName.present ? displayName.value : this.displayName,
    thumbPath: thumbPath.present ? thumbPath.value : this.thumbPath,
    width: width.present ? width.value : this.width,
    height: height.present ? height.value : this.height,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    sizeBytes: sizeBytes.present ? sizeBytes.value : this.sizeBytes,
    downloadedAt: downloadedAt.present ? downloadedAt.value : this.downloadedAt,
  );
  MediaFileRow copyWithCompanion(MediaFilesCompanion data) {
    return MediaFileRow(
      id: data.id.present ? data.id.value : this.id,
      contentId: data.contentId.present ? data.contentId.value : this.contentId,
      slideIndex: data.slideIndex.present
          ? data.slideIndex.value
          : this.slideIndex,
      mediaType: data.mediaType.present ? data.mediaType.value : this.mediaType,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      contentUri: data.contentUri.present
          ? data.contentUri.value
          : this.contentUri,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      thumbPath: data.thumbPath.present ? data.thumbPath.value : this.thumbPath,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      downloadedAt: data.downloadedAt.present
          ? data.downloadedAt.value
          : this.downloadedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaFileRow(')
          ..write('id: $id, ')
          ..write('contentId: $contentId, ')
          ..write('slideIndex: $slideIndex, ')
          ..write('mediaType: $mediaType, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('contentUri: $contentUri, ')
          ..write('relativePath: $relativePath, ')
          ..write('displayName: $displayName, ')
          ..write('thumbPath: $thumbPath, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('durationMs: $durationMs, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('downloadedAt: $downloadedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    contentId,
    slideIndex,
    mediaType,
    sourceUrl,
    status,
    attempts,
    contentUri,
    relativePath,
    displayName,
    thumbPath,
    width,
    height,
    durationMs,
    sizeBytes,
    downloadedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaFileRow &&
          other.id == this.id &&
          other.contentId == this.contentId &&
          other.slideIndex == this.slideIndex &&
          other.mediaType == this.mediaType &&
          other.sourceUrl == this.sourceUrl &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.contentUri == this.contentUri &&
          other.relativePath == this.relativePath &&
          other.displayName == this.displayName &&
          other.thumbPath == this.thumbPath &&
          other.width == this.width &&
          other.height == this.height &&
          other.durationMs == this.durationMs &&
          other.sizeBytes == this.sizeBytes &&
          other.downloadedAt == this.downloadedAt);
}

class MediaFilesCompanion extends UpdateCompanion<MediaFileRow> {
  final Value<int> id;
  final Value<int> contentId;
  final Value<int> slideIndex;
  final Value<MediaType> mediaType;
  final Value<String> sourceUrl;
  final Value<MediaFileStatus> status;
  final Value<int> attempts;
  final Value<String?> contentUri;
  final Value<String?> relativePath;
  final Value<String?> displayName;
  final Value<String?> thumbPath;
  final Value<int?> width;
  final Value<int?> height;
  final Value<int?> durationMs;
  final Value<int?> sizeBytes;
  final Value<DateTime?> downloadedAt;
  const MediaFilesCompanion({
    this.id = const Value.absent(),
    this.contentId = const Value.absent(),
    this.slideIndex = const Value.absent(),
    this.mediaType = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.contentUri = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.displayName = const Value.absent(),
    this.thumbPath = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.downloadedAt = const Value.absent(),
  });
  MediaFilesCompanion.insert({
    this.id = const Value.absent(),
    required int contentId,
    this.slideIndex = const Value.absent(),
    required MediaType mediaType,
    required String sourceUrl,
    required MediaFileStatus status,
    this.attempts = const Value.absent(),
    this.contentUri = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.displayName = const Value.absent(),
    this.thumbPath = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.downloadedAt = const Value.absent(),
  }) : contentId = Value(contentId),
       mediaType = Value(mediaType),
       sourceUrl = Value(sourceUrl),
       status = Value(status);
  static Insertable<MediaFileRow> custom({
    Expression<int>? id,
    Expression<int>? contentId,
    Expression<int>? slideIndex,
    Expression<String>? mediaType,
    Expression<String>? sourceUrl,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<String>? contentUri,
    Expression<String>? relativePath,
    Expression<String>? displayName,
    Expression<String>? thumbPath,
    Expression<int>? width,
    Expression<int>? height,
    Expression<int>? durationMs,
    Expression<int>? sizeBytes,
    Expression<int>? downloadedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (contentId != null) 'content_id': contentId,
      if (slideIndex != null) 'slide_index': slideIndex,
      if (mediaType != null) 'media_type': mediaType,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (contentUri != null) 'content_uri': contentUri,
      if (relativePath != null) 'relative_path': relativePath,
      if (displayName != null) 'display_name': displayName,
      if (thumbPath != null) 'thumb_path': thumbPath,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (durationMs != null) 'duration_ms': durationMs,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
    });
  }

  MediaFilesCompanion copyWith({
    Value<int>? id,
    Value<int>? contentId,
    Value<int>? slideIndex,
    Value<MediaType>? mediaType,
    Value<String>? sourceUrl,
    Value<MediaFileStatus>? status,
    Value<int>? attempts,
    Value<String?>? contentUri,
    Value<String?>? relativePath,
    Value<String?>? displayName,
    Value<String?>? thumbPath,
    Value<int?>? width,
    Value<int?>? height,
    Value<int?>? durationMs,
    Value<int?>? sizeBytes,
    Value<DateTime?>? downloadedAt,
  }) {
    return MediaFilesCompanion(
      id: id ?? this.id,
      contentId: contentId ?? this.contentId,
      slideIndex: slideIndex ?? this.slideIndex,
      mediaType: mediaType ?? this.mediaType,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      contentUri: contentUri ?? this.contentUri,
      relativePath: relativePath ?? this.relativePath,
      displayName: displayName ?? this.displayName,
      thumbPath: thumbPath ?? this.thumbPath,
      width: width ?? this.width,
      height: height ?? this.height,
      durationMs: durationMs ?? this.durationMs,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      downloadedAt: downloadedAt ?? this.downloadedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (contentId.present) {
      map['content_id'] = Variable<int>(contentId.value);
    }
    if (slideIndex.present) {
      map['slide_index'] = Variable<int>(slideIndex.value);
    }
    if (mediaType.present) {
      map['media_type'] = Variable<String>(
        $MediaFilesTable.$convertermediaType.toSql(mediaType.value),
      );
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $MediaFilesTable.$converterstatus.toSql(status.value),
      );
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (contentUri.present) {
      map['content_uri'] = Variable<String>(contentUri.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (thumbPath.present) {
      map['thumb_path'] = Variable<String>(thumbPath.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<int>(
        $MediaFilesTable.$converterdownloadedAtn.toSql(downloadedAt.value),
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaFilesCompanion(')
          ..write('id: $id, ')
          ..write('contentId: $contentId, ')
          ..write('slideIndex: $slideIndex, ')
          ..write('mediaType: $mediaType, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('contentUri: $contentUri, ')
          ..write('relativePath: $relativePath, ')
          ..write('displayName: $displayName, ')
          ..write('thumbPath: $thumbPath, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('durationMs: $durationMs, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('downloadedAt: $downloadedAt')
          ..write(')'))
        .toString();
  }
}

class $CheckRunsTable extends CheckRuns
    with TableInfo<$CheckRunsTable, CheckRunRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CheckRunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<CheckScope, String> scope =
      GeneratedColumn<String>(
        'scope',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CheckScope>($CheckRunsTable.$converterscope);
  @override
  late final GeneratedColumnWithTypeConverter<CheckTrigger, String> trigger =
      GeneratedColumn<String>(
        'trigger',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<CheckTrigger>($CheckRunsTable.$convertertrigger);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> startedAt =
      GeneratedColumn<int>(
        'started_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($CheckRunsTable.$converterstartedAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> finishedAt =
      GeneratedColumn<int>(
        'finished_at',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($CheckRunsTable.$converterfinishedAtn);
  @override
  late final GeneratedColumnWithTypeConverter<CheckResult?, String> result =
      GeneratedColumn<String>(
        'result',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<CheckResult?>($CheckRunsTable.$converterresultn);
  @override
  late final GeneratedColumnWithTypeConverter<ExtractionMode?, String> mode =
      GeneratedColumn<String>(
        'mode',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<ExtractionMode?>($CheckRunsTable.$convertermoden);
  static const VerificationMeta _targetsCheckedMeta = const VerificationMeta(
    'targetsChecked',
  );
  @override
  late final GeneratedColumn<int> targetsChecked = GeneratedColumn<int>(
    'targets_checked',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _newItemsMeta = const VerificationMeta(
    'newItems',
  );
  @override
  late final GeneratedColumn<int> newItems = GeneratedColumn<int>(
    'new_items',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    scope,
    trigger,
    startedAt,
    finishedAt,
    result,
    mode,
    targetsChecked,
    newItems,
    errorCode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'check_run';
  @override
  VerificationContext validateIntegrity(
    Insertable<CheckRunRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('targets_checked')) {
      context.handle(
        _targetsCheckedMeta,
        targetsChecked.isAcceptableOrUnknown(
          data['targets_checked']!,
          _targetsCheckedMeta,
        ),
      );
    }
    if (data.containsKey('new_items')) {
      context.handle(
        _newItemsMeta,
        newItems.isAcceptableOrUnknown(data['new_items']!, _newItemsMeta),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CheckRunRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CheckRunRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      scope: $CheckRunsTable.$converterscope.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}scope'],
        )!,
      ),
      trigger: $CheckRunsTable.$convertertrigger.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}trigger'],
        )!,
      ),
      startedAt: $CheckRunsTable.$converterstartedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}started_at'],
        )!,
      ),
      finishedAt: $CheckRunsTable.$converterfinishedAtn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}finished_at'],
        ),
      ),
      result: $CheckRunsTable.$converterresultn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}result'],
        ),
      ),
      mode: $CheckRunsTable.$convertermoden.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}mode'],
        ),
      ),
      targetsChecked: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}targets_checked'],
      )!,
      newItems: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}new_items'],
      )!,
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
    );
  }

  @override
  $CheckRunsTable createAlias(String alias) {
    return $CheckRunsTable(attachedDatabase, alias);
  }

  static TypeConverter<CheckScope, String> $converterscope =
      const CheckRunScopeConverter();
  static TypeConverter<CheckTrigger, String> $convertertrigger =
      const CheckTriggerConverter();
  static TypeConverter<DateTime, int> $converterstartedAt =
      const EpochMsConverter();
  static TypeConverter<DateTime, int> $converterfinishedAt =
      const EpochMsConverter();
  static TypeConverter<DateTime?, int?> $converterfinishedAtn =
      NullAwareTypeConverter.wrap($converterfinishedAt);
  static TypeConverter<CheckResult, String> $converterresult =
      const CheckResultConverter();
  static TypeConverter<CheckResult?, String?> $converterresultn =
      NullAwareTypeConverter.wrap($converterresult);
  static TypeConverter<ExtractionMode, String> $convertermode =
      const ExtractionModeConverter();
  static TypeConverter<ExtractionMode?, String?> $convertermoden =
      NullAwareTypeConverter.wrap($convertermode);
}

class CheckRunRow extends DataClass implements Insertable<CheckRunRow> {
  final int id;
  final CheckScope scope;
  final CheckTrigger trigger;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final CheckResult? result;
  final ExtractionMode? mode;
  final int targetsChecked;
  final int newItems;
  final String? errorCode;
  const CheckRunRow({
    required this.id,
    required this.scope,
    required this.trigger,
    required this.startedAt,
    this.finishedAt,
    this.result,
    this.mode,
    required this.targetsChecked,
    required this.newItems,
    this.errorCode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['scope'] = Variable<String>(
        $CheckRunsTable.$converterscope.toSql(scope),
      );
    }
    {
      map['trigger'] = Variable<String>(
        $CheckRunsTable.$convertertrigger.toSql(trigger),
      );
    }
    {
      map['started_at'] = Variable<int>(
        $CheckRunsTable.$converterstartedAt.toSql(startedAt),
      );
    }
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<int>(
        $CheckRunsTable.$converterfinishedAtn.toSql(finishedAt),
      );
    }
    if (!nullToAbsent || result != null) {
      map['result'] = Variable<String>(
        $CheckRunsTable.$converterresultn.toSql(result),
      );
    }
    if (!nullToAbsent || mode != null) {
      map['mode'] = Variable<String>(
        $CheckRunsTable.$convertermoden.toSql(mode),
      );
    }
    map['targets_checked'] = Variable<int>(targetsChecked);
    map['new_items'] = Variable<int>(newItems);
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    return map;
  }

  CheckRunsCompanion toCompanion(bool nullToAbsent) {
    return CheckRunsCompanion(
      id: Value(id),
      scope: Value(scope),
      trigger: Value(trigger),
      startedAt: Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
      result: result == null && nullToAbsent
          ? const Value.absent()
          : Value(result),
      mode: mode == null && nullToAbsent ? const Value.absent() : Value(mode),
      targetsChecked: Value(targetsChecked),
      newItems: Value(newItems),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
    );
  }

  factory CheckRunRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CheckRunRow(
      id: serializer.fromJson<int>(json['id']),
      scope: serializer.fromJson<CheckScope>(json['scope']),
      trigger: serializer.fromJson<CheckTrigger>(json['trigger']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      finishedAt: serializer.fromJson<DateTime?>(json['finishedAt']),
      result: serializer.fromJson<CheckResult?>(json['result']),
      mode: serializer.fromJson<ExtractionMode?>(json['mode']),
      targetsChecked: serializer.fromJson<int>(json['targetsChecked']),
      newItems: serializer.fromJson<int>(json['newItems']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'scope': serializer.toJson<CheckScope>(scope),
      'trigger': serializer.toJson<CheckTrigger>(trigger),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
      'result': serializer.toJson<CheckResult?>(result),
      'mode': serializer.toJson<ExtractionMode?>(mode),
      'targetsChecked': serializer.toJson<int>(targetsChecked),
      'newItems': serializer.toJson<int>(newItems),
      'errorCode': serializer.toJson<String?>(errorCode),
    };
  }

  CheckRunRow copyWith({
    int? id,
    CheckScope? scope,
    CheckTrigger? trigger,
    DateTime? startedAt,
    Value<DateTime?> finishedAt = const Value.absent(),
    Value<CheckResult?> result = const Value.absent(),
    Value<ExtractionMode?> mode = const Value.absent(),
    int? targetsChecked,
    int? newItems,
    Value<String?> errorCode = const Value.absent(),
  }) => CheckRunRow(
    id: id ?? this.id,
    scope: scope ?? this.scope,
    trigger: trigger ?? this.trigger,
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
    result: result.present ? result.value : this.result,
    mode: mode.present ? mode.value : this.mode,
    targetsChecked: targetsChecked ?? this.targetsChecked,
    newItems: newItems ?? this.newItems,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
  );
  CheckRunRow copyWithCompanion(CheckRunsCompanion data) {
    return CheckRunRow(
      id: data.id.present ? data.id.value : this.id,
      scope: data.scope.present ? data.scope.value : this.scope,
      trigger: data.trigger.present ? data.trigger.value : this.trigger,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
      result: data.result.present ? data.result.value : this.result,
      mode: data.mode.present ? data.mode.value : this.mode,
      targetsChecked: data.targetsChecked.present
          ? data.targetsChecked.value
          : this.targetsChecked,
      newItems: data.newItems.present ? data.newItems.value : this.newItems,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CheckRunRow(')
          ..write('id: $id, ')
          ..write('scope: $scope, ')
          ..write('trigger: $trigger, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('result: $result, ')
          ..write('mode: $mode, ')
          ..write('targetsChecked: $targetsChecked, ')
          ..write('newItems: $newItems, ')
          ..write('errorCode: $errorCode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    scope,
    trigger,
    startedAt,
    finishedAt,
    result,
    mode,
    targetsChecked,
    newItems,
    errorCode,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CheckRunRow &&
          other.id == this.id &&
          other.scope == this.scope &&
          other.trigger == this.trigger &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt &&
          other.result == this.result &&
          other.mode == this.mode &&
          other.targetsChecked == this.targetsChecked &&
          other.newItems == this.newItems &&
          other.errorCode == this.errorCode);
}

class CheckRunsCompanion extends UpdateCompanion<CheckRunRow> {
  final Value<int> id;
  final Value<CheckScope> scope;
  final Value<CheckTrigger> trigger;
  final Value<DateTime> startedAt;
  final Value<DateTime?> finishedAt;
  final Value<CheckResult?> result;
  final Value<ExtractionMode?> mode;
  final Value<int> targetsChecked;
  final Value<int> newItems;
  final Value<String?> errorCode;
  const CheckRunsCompanion({
    this.id = const Value.absent(),
    this.scope = const Value.absent(),
    this.trigger = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.result = const Value.absent(),
    this.mode = const Value.absent(),
    this.targetsChecked = const Value.absent(),
    this.newItems = const Value.absent(),
    this.errorCode = const Value.absent(),
  });
  CheckRunsCompanion.insert({
    this.id = const Value.absent(),
    required CheckScope scope,
    required CheckTrigger trigger,
    required DateTime startedAt,
    this.finishedAt = const Value.absent(),
    this.result = const Value.absent(),
    this.mode = const Value.absent(),
    this.targetsChecked = const Value.absent(),
    this.newItems = const Value.absent(),
    this.errorCode = const Value.absent(),
  }) : scope = Value(scope),
       trigger = Value(trigger),
       startedAt = Value(startedAt);
  static Insertable<CheckRunRow> custom({
    Expression<int>? id,
    Expression<String>? scope,
    Expression<String>? trigger,
    Expression<int>? startedAt,
    Expression<int>? finishedAt,
    Expression<String>? result,
    Expression<String>? mode,
    Expression<int>? targetsChecked,
    Expression<int>? newItems,
    Expression<String>? errorCode,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scope != null) 'scope': scope,
      if (trigger != null) 'trigger': trigger,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (result != null) 'result': result,
      if (mode != null) 'mode': mode,
      if (targetsChecked != null) 'targets_checked': targetsChecked,
      if (newItems != null) 'new_items': newItems,
      if (errorCode != null) 'error_code': errorCode,
    });
  }

  CheckRunsCompanion copyWith({
    Value<int>? id,
    Value<CheckScope>? scope,
    Value<CheckTrigger>? trigger,
    Value<DateTime>? startedAt,
    Value<DateTime?>? finishedAt,
    Value<CheckResult?>? result,
    Value<ExtractionMode?>? mode,
    Value<int>? targetsChecked,
    Value<int>? newItems,
    Value<String?>? errorCode,
  }) {
    return CheckRunsCompanion(
      id: id ?? this.id,
      scope: scope ?? this.scope,
      trigger: trigger ?? this.trigger,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      result: result ?? this.result,
      mode: mode ?? this.mode,
      targetsChecked: targetsChecked ?? this.targetsChecked,
      newItems: newItems ?? this.newItems,
      errorCode: errorCode ?? this.errorCode,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(
        $CheckRunsTable.$converterscope.toSql(scope.value),
      );
    }
    if (trigger.present) {
      map['trigger'] = Variable<String>(
        $CheckRunsTable.$convertertrigger.toSql(trigger.value),
      );
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(
        $CheckRunsTable.$converterstartedAt.toSql(startedAt.value),
      );
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<int>(
        $CheckRunsTable.$converterfinishedAtn.toSql(finishedAt.value),
      );
    }
    if (result.present) {
      map['result'] = Variable<String>(
        $CheckRunsTable.$converterresultn.toSql(result.value),
      );
    }
    if (mode.present) {
      map['mode'] = Variable<String>(
        $CheckRunsTable.$convertermoden.toSql(mode.value),
      );
    }
    if (targetsChecked.present) {
      map['targets_checked'] = Variable<int>(targetsChecked.value);
    }
    if (newItems.present) {
      map['new_items'] = Variable<int>(newItems.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CheckRunsCompanion(')
          ..write('id: $id, ')
          ..write('scope: $scope, ')
          ..write('trigger: $trigger, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('result: $result, ')
          ..write('mode: $mode, ')
          ..write('targetsChecked: $targetsChecked, ')
          ..write('newItems: $newItems, ')
          ..write('errorCode: $errorCode')
          ..write(')'))
        .toString();
  }
}

class $ActivityEventsTable extends ActivityEvents
    with TableInfo<$ActivityEventsTable, ActivityEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActivityEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> at =
      GeneratedColumn<int>(
        'at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($ActivityEventsTable.$converterat);
  @override
  late final GeneratedColumnWithTypeConverter<ActivityType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ActivityType>($ActivityEventsTable.$convertertype);
  @override
  late final GeneratedColumnWithTypeConverter<Severity, String> severity =
      GeneratedColumn<String>(
        'severity',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Severity>($ActivityEventsTable.$converterseverity);
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  @override
  late final GeneratedColumn<int> targetId = GeneratedColumn<int>(
    'target_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES target (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _checkRunIdMeta = const VerificationMeta(
    'checkRunId',
  );
  @override
  late final GeneratedColumn<int> checkRunId = GeneratedColumn<int>(
    'check_run_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES check_run (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
    'count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    at,
    type,
    severity,
    targetId,
    checkRunId,
    count,
    payloadJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'activity_event';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActivityEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    }
    if (data.containsKey('check_run_id')) {
      context.handle(
        _checkRunIdMeta,
        checkRunId.isAcceptableOrUnknown(
          data['check_run_id']!,
          _checkRunIdMeta,
        ),
      );
    }
    if (data.containsKey('count')) {
      context.handle(
        _countMeta,
        count.isAcceptableOrUnknown(data['count']!, _countMeta),
      );
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ActivityEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActivityEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      at: $ActivityEventsTable.$converterat.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}at'],
        )!,
      ),
      type: $ActivityEventsTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      severity: $ActivityEventsTable.$converterseverity.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}severity'],
        )!,
      ),
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_id'],
      ),
      checkRunId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}check_run_id'],
      ),
      count: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      ),
    );
  }

  @override
  $ActivityEventsTable createAlias(String alias) {
    return $ActivityEventsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterat = const EpochMsConverter();
  static TypeConverter<ActivityType, String> $convertertype =
      const ActivityTypeConverter();
  static TypeConverter<Severity, String> $converterseverity =
      const SeverityConverter();
}

class ActivityEventRow extends DataClass
    implements Insertable<ActivityEventRow> {
  final int id;
  final DateTime at;
  final ActivityType type;
  final Severity severity;
  final int? targetId;
  final int? checkRunId;
  final int count;
  final String? payloadJson;
  const ActivityEventRow({
    required this.id,
    required this.at,
    required this.type,
    required this.severity,
    this.targetId,
    this.checkRunId,
    required this.count,
    this.payloadJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['at'] = Variable<int>($ActivityEventsTable.$converterat.toSql(at));
    }
    {
      map['type'] = Variable<String>(
        $ActivityEventsTable.$convertertype.toSql(type),
      );
    }
    {
      map['severity'] = Variable<String>(
        $ActivityEventsTable.$converterseverity.toSql(severity),
      );
    }
    if (!nullToAbsent || targetId != null) {
      map['target_id'] = Variable<int>(targetId);
    }
    if (!nullToAbsent || checkRunId != null) {
      map['check_run_id'] = Variable<int>(checkRunId);
    }
    map['count'] = Variable<int>(count);
    if (!nullToAbsent || payloadJson != null) {
      map['payload_json'] = Variable<String>(payloadJson);
    }
    return map;
  }

  ActivityEventsCompanion toCompanion(bool nullToAbsent) {
    return ActivityEventsCompanion(
      id: Value(id),
      at: Value(at),
      type: Value(type),
      severity: Value(severity),
      targetId: targetId == null && nullToAbsent
          ? const Value.absent()
          : Value(targetId),
      checkRunId: checkRunId == null && nullToAbsent
          ? const Value.absent()
          : Value(checkRunId),
      count: Value(count),
      payloadJson: payloadJson == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadJson),
    );
  }

  factory ActivityEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActivityEventRow(
      id: serializer.fromJson<int>(json['id']),
      at: serializer.fromJson<DateTime>(json['at']),
      type: serializer.fromJson<ActivityType>(json['type']),
      severity: serializer.fromJson<Severity>(json['severity']),
      targetId: serializer.fromJson<int?>(json['targetId']),
      checkRunId: serializer.fromJson<int?>(json['checkRunId']),
      count: serializer.fromJson<int>(json['count']),
      payloadJson: serializer.fromJson<String?>(json['payloadJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'at': serializer.toJson<DateTime>(at),
      'type': serializer.toJson<ActivityType>(type),
      'severity': serializer.toJson<Severity>(severity),
      'targetId': serializer.toJson<int?>(targetId),
      'checkRunId': serializer.toJson<int?>(checkRunId),
      'count': serializer.toJson<int>(count),
      'payloadJson': serializer.toJson<String?>(payloadJson),
    };
  }

  ActivityEventRow copyWith({
    int? id,
    DateTime? at,
    ActivityType? type,
    Severity? severity,
    Value<int?> targetId = const Value.absent(),
    Value<int?> checkRunId = const Value.absent(),
    int? count,
    Value<String?> payloadJson = const Value.absent(),
  }) => ActivityEventRow(
    id: id ?? this.id,
    at: at ?? this.at,
    type: type ?? this.type,
    severity: severity ?? this.severity,
    targetId: targetId.present ? targetId.value : this.targetId,
    checkRunId: checkRunId.present ? checkRunId.value : this.checkRunId,
    count: count ?? this.count,
    payloadJson: payloadJson.present ? payloadJson.value : this.payloadJson,
  );
  ActivityEventRow copyWithCompanion(ActivityEventsCompanion data) {
    return ActivityEventRow(
      id: data.id.present ? data.id.value : this.id,
      at: data.at.present ? data.at.value : this.at,
      type: data.type.present ? data.type.value : this.type,
      severity: data.severity.present ? data.severity.value : this.severity,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      checkRunId: data.checkRunId.present
          ? data.checkRunId.value
          : this.checkRunId,
      count: data.count.present ? data.count.value : this.count,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActivityEventRow(')
          ..write('id: $id, ')
          ..write('at: $at, ')
          ..write('type: $type, ')
          ..write('severity: $severity, ')
          ..write('targetId: $targetId, ')
          ..write('checkRunId: $checkRunId, ')
          ..write('count: $count, ')
          ..write('payloadJson: $payloadJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    at,
    type,
    severity,
    targetId,
    checkRunId,
    count,
    payloadJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActivityEventRow &&
          other.id == this.id &&
          other.at == this.at &&
          other.type == this.type &&
          other.severity == this.severity &&
          other.targetId == this.targetId &&
          other.checkRunId == this.checkRunId &&
          other.count == this.count &&
          other.payloadJson == this.payloadJson);
}

class ActivityEventsCompanion extends UpdateCompanion<ActivityEventRow> {
  final Value<int> id;
  final Value<DateTime> at;
  final Value<ActivityType> type;
  final Value<Severity> severity;
  final Value<int?> targetId;
  final Value<int?> checkRunId;
  final Value<int> count;
  final Value<String?> payloadJson;
  const ActivityEventsCompanion({
    this.id = const Value.absent(),
    this.at = const Value.absent(),
    this.type = const Value.absent(),
    this.severity = const Value.absent(),
    this.targetId = const Value.absent(),
    this.checkRunId = const Value.absent(),
    this.count = const Value.absent(),
    this.payloadJson = const Value.absent(),
  });
  ActivityEventsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime at,
    required ActivityType type,
    required Severity severity,
    this.targetId = const Value.absent(),
    this.checkRunId = const Value.absent(),
    this.count = const Value.absent(),
    this.payloadJson = const Value.absent(),
  }) : at = Value(at),
       type = Value(type),
       severity = Value(severity);
  static Insertable<ActivityEventRow> custom({
    Expression<int>? id,
    Expression<int>? at,
    Expression<String>? type,
    Expression<String>? severity,
    Expression<int>? targetId,
    Expression<int>? checkRunId,
    Expression<int>? count,
    Expression<String>? payloadJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (at != null) 'at': at,
      if (type != null) 'type': type,
      if (severity != null) 'severity': severity,
      if (targetId != null) 'target_id': targetId,
      if (checkRunId != null) 'check_run_id': checkRunId,
      if (count != null) 'count': count,
      if (payloadJson != null) 'payload_json': payloadJson,
    });
  }

  ActivityEventsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? at,
    Value<ActivityType>? type,
    Value<Severity>? severity,
    Value<int?>? targetId,
    Value<int?>? checkRunId,
    Value<int>? count,
    Value<String?>? payloadJson,
  }) {
    return ActivityEventsCompanion(
      id: id ?? this.id,
      at: at ?? this.at,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      targetId: targetId ?? this.targetId,
      checkRunId: checkRunId ?? this.checkRunId,
      count: count ?? this.count,
      payloadJson: payloadJson ?? this.payloadJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (at.present) {
      map['at'] = Variable<int>(
        $ActivityEventsTable.$converterat.toSql(at.value),
      );
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $ActivityEventsTable.$convertertype.toSql(type.value),
      );
    }
    if (severity.present) {
      map['severity'] = Variable<String>(
        $ActivityEventsTable.$converterseverity.toSql(severity.value),
      );
    }
    if (targetId.present) {
      map['target_id'] = Variable<int>(targetId.value);
    }
    if (checkRunId.present) {
      map['check_run_id'] = Variable<int>(checkRunId.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActivityEventsCompanion(')
          ..write('id: $id, ')
          ..write('at: $at, ')
          ..write('type: $type, ')
          ..write('severity: $severity, ')
          ..write('targetId: $targetId, ')
          ..write('checkRunId: $checkRunId, ')
          ..write('count: $count, ')
          ..write('payloadJson: $payloadJson')
          ..write(')'))
        .toString();
  }
}

class $GovernorLeasesTable extends GovernorLeases
    with TableInfo<$GovernorLeasesTable, GovernorLeaseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GovernorLeasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _loginAccountIdMeta = const VerificationMeta(
    'loginAccountId',
  );
  @override
  late final GeneratedColumn<int> loginAccountId = GeneratedColumn<int>(
    'login_account_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _holderMeta = const VerificationMeta('holder');
  @override
  late final GeneratedColumn<String> holder = GeneratedColumn<String>(
    'holder',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> expiresAt =
      GeneratedColumn<int>(
        'expires_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($GovernorLeasesTable.$converterexpiresAt);
  static const VerificationMeta _tokensMeta = const VerificationMeta('tokens');
  @override
  late final GeneratedColumn<double> tokens = GeneratedColumn<double>(
    'tokens',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> lastRefillAt =
      GeneratedColumn<int>(
        'last_refill_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($GovernorLeasesTable.$converterlastRefillAt);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime?, int> backoffUntil =
      GeneratedColumn<int>(
        'backoff_until',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      ).withConverter<DateTime?>($GovernorLeasesTable.$converterbackoffUntiln);
  static const VerificationMeta _backoffMultiplierMeta = const VerificationMeta(
    'backoffMultiplier',
  );
  @override
  late final GeneratedColumn<double> backoffMultiplier =
      GeneratedColumn<double>(
        'backoff_multiplier',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(1),
      );
  @override
  List<GeneratedColumn> get $columns => [
    loginAccountId,
    holder,
    expiresAt,
    tokens,
    lastRefillAt,
    backoffUntil,
    backoffMultiplier,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'governor_lease';
  @override
  VerificationContext validateIntegrity(
    Insertable<GovernorLeaseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('login_account_id')) {
      context.handle(
        _loginAccountIdMeta,
        loginAccountId.isAcceptableOrUnknown(
          data['login_account_id']!,
          _loginAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('holder')) {
      context.handle(
        _holderMeta,
        holder.isAcceptableOrUnknown(data['holder']!, _holderMeta),
      );
    } else if (isInserting) {
      context.missing(_holderMeta);
    }
    if (data.containsKey('tokens')) {
      context.handle(
        _tokensMeta,
        tokens.isAcceptableOrUnknown(data['tokens']!, _tokensMeta),
      );
    } else if (isInserting) {
      context.missing(_tokensMeta);
    }
    if (data.containsKey('backoff_multiplier')) {
      context.handle(
        _backoffMultiplierMeta,
        backoffMultiplier.isAcceptableOrUnknown(
          data['backoff_multiplier']!,
          _backoffMultiplierMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {loginAccountId};
  @override
  GovernorLeaseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GovernorLeaseRow(
      loginAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}login_account_id'],
      )!,
      holder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}holder'],
      )!,
      expiresAt: $GovernorLeasesTable.$converterexpiresAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}expires_at'],
        )!,
      ),
      tokens: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}tokens'],
      )!,
      lastRefillAt: $GovernorLeasesTable.$converterlastRefillAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}last_refill_at'],
        )!,
      ),
      backoffUntil: $GovernorLeasesTable.$converterbackoffUntiln.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}backoff_until'],
        ),
      ),
      backoffMultiplier: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}backoff_multiplier'],
      )!,
    );
  }

  @override
  $GovernorLeasesTable createAlias(String alias) {
    return $GovernorLeasesTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterexpiresAt =
      const EpochMsConverter();
  static TypeConverter<DateTime, int> $converterlastRefillAt =
      const EpochMsConverter();
  static TypeConverter<DateTime, int> $converterbackoffUntil =
      const EpochMsConverter();
  static TypeConverter<DateTime?, int?> $converterbackoffUntiln =
      NullAwareTypeConverter.wrap($converterbackoffUntil);
}

class GovernorLeaseRow extends DataClass
    implements Insertable<GovernorLeaseRow> {
  final int loginAccountId;
  final String holder;
  final DateTime expiresAt;
  final double tokens;
  final DateTime lastRefillAt;
  final DateTime? backoffUntil;
  final double backoffMultiplier;
  const GovernorLeaseRow({
    required this.loginAccountId,
    required this.holder,
    required this.expiresAt,
    required this.tokens,
    required this.lastRefillAt,
    this.backoffUntil,
    required this.backoffMultiplier,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['login_account_id'] = Variable<int>(loginAccountId);
    map['holder'] = Variable<String>(holder);
    {
      map['expires_at'] = Variable<int>(
        $GovernorLeasesTable.$converterexpiresAt.toSql(expiresAt),
      );
    }
    map['tokens'] = Variable<double>(tokens);
    {
      map['last_refill_at'] = Variable<int>(
        $GovernorLeasesTable.$converterlastRefillAt.toSql(lastRefillAt),
      );
    }
    if (!nullToAbsent || backoffUntil != null) {
      map['backoff_until'] = Variable<int>(
        $GovernorLeasesTable.$converterbackoffUntiln.toSql(backoffUntil),
      );
    }
    map['backoff_multiplier'] = Variable<double>(backoffMultiplier);
    return map;
  }

  GovernorLeasesCompanion toCompanion(bool nullToAbsent) {
    return GovernorLeasesCompanion(
      loginAccountId: Value(loginAccountId),
      holder: Value(holder),
      expiresAt: Value(expiresAt),
      tokens: Value(tokens),
      lastRefillAt: Value(lastRefillAt),
      backoffUntil: backoffUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(backoffUntil),
      backoffMultiplier: Value(backoffMultiplier),
    );
  }

  factory GovernorLeaseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GovernorLeaseRow(
      loginAccountId: serializer.fromJson<int>(json['loginAccountId']),
      holder: serializer.fromJson<String>(json['holder']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
      tokens: serializer.fromJson<double>(json['tokens']),
      lastRefillAt: serializer.fromJson<DateTime>(json['lastRefillAt']),
      backoffUntil: serializer.fromJson<DateTime?>(json['backoffUntil']),
      backoffMultiplier: serializer.fromJson<double>(json['backoffMultiplier']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'loginAccountId': serializer.toJson<int>(loginAccountId),
      'holder': serializer.toJson<String>(holder),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
      'tokens': serializer.toJson<double>(tokens),
      'lastRefillAt': serializer.toJson<DateTime>(lastRefillAt),
      'backoffUntil': serializer.toJson<DateTime?>(backoffUntil),
      'backoffMultiplier': serializer.toJson<double>(backoffMultiplier),
    };
  }

  GovernorLeaseRow copyWith({
    int? loginAccountId,
    String? holder,
    DateTime? expiresAt,
    double? tokens,
    DateTime? lastRefillAt,
    Value<DateTime?> backoffUntil = const Value.absent(),
    double? backoffMultiplier,
  }) => GovernorLeaseRow(
    loginAccountId: loginAccountId ?? this.loginAccountId,
    holder: holder ?? this.holder,
    expiresAt: expiresAt ?? this.expiresAt,
    tokens: tokens ?? this.tokens,
    lastRefillAt: lastRefillAt ?? this.lastRefillAt,
    backoffUntil: backoffUntil.present ? backoffUntil.value : this.backoffUntil,
    backoffMultiplier: backoffMultiplier ?? this.backoffMultiplier,
  );
  GovernorLeaseRow copyWithCompanion(GovernorLeasesCompanion data) {
    return GovernorLeaseRow(
      loginAccountId: data.loginAccountId.present
          ? data.loginAccountId.value
          : this.loginAccountId,
      holder: data.holder.present ? data.holder.value : this.holder,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      tokens: data.tokens.present ? data.tokens.value : this.tokens,
      lastRefillAt: data.lastRefillAt.present
          ? data.lastRefillAt.value
          : this.lastRefillAt,
      backoffUntil: data.backoffUntil.present
          ? data.backoffUntil.value
          : this.backoffUntil,
      backoffMultiplier: data.backoffMultiplier.present
          ? data.backoffMultiplier.value
          : this.backoffMultiplier,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GovernorLeaseRow(')
          ..write('loginAccountId: $loginAccountId, ')
          ..write('holder: $holder, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('tokens: $tokens, ')
          ..write('lastRefillAt: $lastRefillAt, ')
          ..write('backoffUntil: $backoffUntil, ')
          ..write('backoffMultiplier: $backoffMultiplier')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    loginAccountId,
    holder,
    expiresAt,
    tokens,
    lastRefillAt,
    backoffUntil,
    backoffMultiplier,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GovernorLeaseRow &&
          other.loginAccountId == this.loginAccountId &&
          other.holder == this.holder &&
          other.expiresAt == this.expiresAt &&
          other.tokens == this.tokens &&
          other.lastRefillAt == this.lastRefillAt &&
          other.backoffUntil == this.backoffUntil &&
          other.backoffMultiplier == this.backoffMultiplier);
}

class GovernorLeasesCompanion extends UpdateCompanion<GovernorLeaseRow> {
  final Value<int> loginAccountId;
  final Value<String> holder;
  final Value<DateTime> expiresAt;
  final Value<double> tokens;
  final Value<DateTime> lastRefillAt;
  final Value<DateTime?> backoffUntil;
  final Value<double> backoffMultiplier;
  const GovernorLeasesCompanion({
    this.loginAccountId = const Value.absent(),
    this.holder = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.tokens = const Value.absent(),
    this.lastRefillAt = const Value.absent(),
    this.backoffUntil = const Value.absent(),
    this.backoffMultiplier = const Value.absent(),
  });
  GovernorLeasesCompanion.insert({
    this.loginAccountId = const Value.absent(),
    required String holder,
    required DateTime expiresAt,
    required double tokens,
    required DateTime lastRefillAt,
    this.backoffUntil = const Value.absent(),
    this.backoffMultiplier = const Value.absent(),
  }) : holder = Value(holder),
       expiresAt = Value(expiresAt),
       tokens = Value(tokens),
       lastRefillAt = Value(lastRefillAt);
  static Insertable<GovernorLeaseRow> custom({
    Expression<int>? loginAccountId,
    Expression<String>? holder,
    Expression<int>? expiresAt,
    Expression<double>? tokens,
    Expression<int>? lastRefillAt,
    Expression<int>? backoffUntil,
    Expression<double>? backoffMultiplier,
  }) {
    return RawValuesInsertable({
      if (loginAccountId != null) 'login_account_id': loginAccountId,
      if (holder != null) 'holder': holder,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (tokens != null) 'tokens': tokens,
      if (lastRefillAt != null) 'last_refill_at': lastRefillAt,
      if (backoffUntil != null) 'backoff_until': backoffUntil,
      if (backoffMultiplier != null) 'backoff_multiplier': backoffMultiplier,
    });
  }

  GovernorLeasesCompanion copyWith({
    Value<int>? loginAccountId,
    Value<String>? holder,
    Value<DateTime>? expiresAt,
    Value<double>? tokens,
    Value<DateTime>? lastRefillAt,
    Value<DateTime?>? backoffUntil,
    Value<double>? backoffMultiplier,
  }) {
    return GovernorLeasesCompanion(
      loginAccountId: loginAccountId ?? this.loginAccountId,
      holder: holder ?? this.holder,
      expiresAt: expiresAt ?? this.expiresAt,
      tokens: tokens ?? this.tokens,
      lastRefillAt: lastRefillAt ?? this.lastRefillAt,
      backoffUntil: backoffUntil ?? this.backoffUntil,
      backoffMultiplier: backoffMultiplier ?? this.backoffMultiplier,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (loginAccountId.present) {
      map['login_account_id'] = Variable<int>(loginAccountId.value);
    }
    if (holder.present) {
      map['holder'] = Variable<String>(holder.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<int>(
        $GovernorLeasesTable.$converterexpiresAt.toSql(expiresAt.value),
      );
    }
    if (tokens.present) {
      map['tokens'] = Variable<double>(tokens.value);
    }
    if (lastRefillAt.present) {
      map['last_refill_at'] = Variable<int>(
        $GovernorLeasesTable.$converterlastRefillAt.toSql(lastRefillAt.value),
      );
    }
    if (backoffUntil.present) {
      map['backoff_until'] = Variable<int>(
        $GovernorLeasesTable.$converterbackoffUntiln.toSql(backoffUntil.value),
      );
    }
    if (backoffMultiplier.present) {
      map['backoff_multiplier'] = Variable<double>(backoffMultiplier.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GovernorLeasesCompanion(')
          ..write('loginAccountId: $loginAccountId, ')
          ..write('holder: $holder, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('tokens: $tokens, ')
          ..write('lastRefillAt: $lastRefillAt, ')
          ..write('backoffUntil: $backoffUntil, ')
          ..write('backoffMultiplier: $backoffMultiplier')
          ..write(')'))
        .toString();
  }
}

abstract class _$StorizeDatabase extends GeneratedDatabase {
  _$StorizeDatabase(QueryExecutor e) : super(e);
  $StorizeDatabaseManager get managers => $StorizeDatabaseManager(this);
  late final $LoginAccountsTable loginAccounts = $LoginAccountsTable(this);
  late final $TargetsTable targets = $TargetsTable(this);
  late final $ContentsTable contents = $ContentsTable(this);
  late final $MediaFilesTable mediaFiles = $MediaFilesTable(this);
  late final $CheckRunsTable checkRuns = $CheckRunsTable(this);
  late final $ActivityEventsTable activityEvents = $ActivityEventsTable(this);
  late final $GovernorLeasesTable governorLeases = $GovernorLeasesTable(this);
  late final Index idxTargetStatus = Index(
    'idx_target_status',
    'CREATE INDEX idx_target_status ON target (status)',
  );
  late final Index idxContentKindPostedAt = Index(
    'idx_content_kind_posted_at',
    'CREATE INDEX idx_content_kind_posted_at ON content (kind, posted_at DESC)',
  );
  late final Index idxContentTargetKindPostedAt = Index(
    'idx_content_target_kind_posted_at',
    'CREATE INDEX idx_content_target_kind_posted_at ON content (target_id, kind, posted_at DESC)',
  );
  late final Index idxMediaFileStatus = Index(
    'idx_media_file_status',
    'CREATE INDEX idx_media_file_status ON media_file (status)',
  );
  late final Index idxCheckRunScopeStartedAt = Index(
    'idx_check_run_scope_started_at',
    'CREATE INDEX idx_check_run_scope_started_at ON check_run (scope, started_at)',
  );
  late final Index idxActivityEventAt = Index(
    'idx_activity_event_at',
    'CREATE INDEX idx_activity_event_at ON activity_event (at DESC)',
  );
  late final AccountDao accountDao = AccountDao(this as StorizeDatabase);
  late final TargetsDao targetsDao = TargetsDao(this as StorizeDatabase);
  late final ContentDao contentDao = ContentDao(this as StorizeDatabase);
  late final CheckRunDao checkRunDao = CheckRunDao(this as StorizeDatabase);
  late final ActivityDao activityDao = ActivityDao(this as StorizeDatabase);
  late final GovernorLeaseDao governorLeaseDao = GovernorLeaseDao(
    this as StorizeDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    loginAccounts,
    targets,
    contents,
    mediaFiles,
    checkRuns,
    activityEvents,
    governorLeases,
    idxTargetStatus,
    idxContentKindPostedAt,
    idxContentTargetKindPostedAt,
    idxMediaFileStatus,
    idxCheckRunScopeStartedAt,
    idxActivityEventAt,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'login_account',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('target', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'target',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('content', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'content',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('media_file', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'target',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('activity_event', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'check_run',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('activity_event', kind: UpdateKind.update)],
    ),
  ]);
}

typedef $$LoginAccountsTableCreateCompanionBuilder =
    LoginAccountsCompanion Function({
      Value<int> id,
      required PlatformId platform,
      required String remoteUserId,
      required String username,
      required AccountStatus status,
      Value<String?> statusReason,
      required DateTime connectedAt,
      Value<DateTime?> lastSuccessAt,
      Value<String?> userAgent,
    });
typedef $$LoginAccountsTableUpdateCompanionBuilder =
    LoginAccountsCompanion Function({
      Value<int> id,
      Value<PlatformId> platform,
      Value<String> remoteUserId,
      Value<String> username,
      Value<AccountStatus> status,
      Value<String?> statusReason,
      Value<DateTime> connectedAt,
      Value<DateTime?> lastSuccessAt,
      Value<String?> userAgent,
    });

final class $$LoginAccountsTableReferences
    extends
        BaseReferences<
          _$StorizeDatabase,
          $LoginAccountsTable,
          LoginAccountRow
        > {
  $$LoginAccountsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$TargetsTable, List<TargetRow>> _targetsRefsTable(
    _$StorizeDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.targets,
    aliasName: 'login_account__id__target__login_account_id',
  );

  $$TargetsTableProcessedTableManager get targetsRefs {
    final manager = $$TargetsTableTableManager(
      $_db,
      $_db.targets,
    ).filter((f) => f.loginAccountId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_targetsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LoginAccountsTableFilterComposer
    extends Composer<_$StorizeDatabase, $LoginAccountsTable> {
  $$LoginAccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<PlatformId, PlatformId, String> get platform =>
      $composableBuilder(
        column: $table.platform,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get remoteUserId => $composableBuilder(
    column: $table.remoteUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AccountStatus, AccountStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get statusReason => $composableBuilder(
    column: $table.statusReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get connectedAt =>
      $composableBuilder(
        column: $table.connectedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get lastSuccessAt =>
      $composableBuilder(
        column: $table.lastSuccessAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get userAgent => $composableBuilder(
    column: $table.userAgent,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> targetsRefs(
    Expression<bool> Function($$TargetsTableFilterComposer f) f,
  ) {
    final $$TargetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.targets,
      getReferencedColumn: (t) => t.loginAccountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TargetsTableFilterComposer(
            $db: $db,
            $table: $db.targets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LoginAccountsTableOrderingComposer
    extends Composer<_$StorizeDatabase, $LoginAccountsTable> {
  $$LoginAccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteUserId => $composableBuilder(
    column: $table.remoteUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get statusReason => $composableBuilder(
    column: $table.statusReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get connectedAt => $composableBuilder(
    column: $table.connectedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSuccessAt => $composableBuilder(
    column: $table.lastSuccessAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userAgent => $composableBuilder(
    column: $table.userAgent,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LoginAccountsTableAnnotationComposer
    extends Composer<_$StorizeDatabase, $LoginAccountsTable> {
  $$LoginAccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PlatformId, String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumn<String> get remoteUserId => $composableBuilder(
    column: $table.remoteUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AccountStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get statusReason => $composableBuilder(
    column: $table.statusReason,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, int> get connectedAt =>
      $composableBuilder(
        column: $table.connectedAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime?, int> get lastSuccessAt =>
      $composableBuilder(
        column: $table.lastSuccessAt,
        builder: (column) => column,
      );

  GeneratedColumn<String> get userAgent =>
      $composableBuilder(column: $table.userAgent, builder: (column) => column);

  Expression<T> targetsRefs<T extends Object>(
    Expression<T> Function($$TargetsTableAnnotationComposer a) f,
  ) {
    final $$TargetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.targets,
      getReferencedColumn: (t) => t.loginAccountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TargetsTableAnnotationComposer(
            $db: $db,
            $table: $db.targets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LoginAccountsTableTableManager
    extends
        RootTableManager<
          _$StorizeDatabase,
          $LoginAccountsTable,
          LoginAccountRow,
          $$LoginAccountsTableFilterComposer,
          $$LoginAccountsTableOrderingComposer,
          $$LoginAccountsTableAnnotationComposer,
          $$LoginAccountsTableCreateCompanionBuilder,
          $$LoginAccountsTableUpdateCompanionBuilder,
          (LoginAccountRow, $$LoginAccountsTableReferences),
          LoginAccountRow,
          PrefetchHooks Function({bool targetsRefs})
        > {
  $$LoginAccountsTableTableManager(
    _$StorizeDatabase db,
    $LoginAccountsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LoginAccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LoginAccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LoginAccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<PlatformId> platform = const Value.absent(),
                Value<String> remoteUserId = const Value.absent(),
                Value<String> username = const Value.absent(),
                Value<AccountStatus> status = const Value.absent(),
                Value<String?> statusReason = const Value.absent(),
                Value<DateTime> connectedAt = const Value.absent(),
                Value<DateTime?> lastSuccessAt = const Value.absent(),
                Value<String?> userAgent = const Value.absent(),
              }) => LoginAccountsCompanion(
                id: id,
                platform: platform,
                remoteUserId: remoteUserId,
                username: username,
                status: status,
                statusReason: statusReason,
                connectedAt: connectedAt,
                lastSuccessAt: lastSuccessAt,
                userAgent: userAgent,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required PlatformId platform,
                required String remoteUserId,
                required String username,
                required AccountStatus status,
                Value<String?> statusReason = const Value.absent(),
                required DateTime connectedAt,
                Value<DateTime?> lastSuccessAt = const Value.absent(),
                Value<String?> userAgent = const Value.absent(),
              }) => LoginAccountsCompanion.insert(
                id: id,
                platform: platform,
                remoteUserId: remoteUserId,
                username: username,
                status: status,
                statusReason: statusReason,
                connectedAt: connectedAt,
                lastSuccessAt: lastSuccessAt,
                userAgent: userAgent,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LoginAccountsTable, LoginAccountRow>(table),
                  $$LoginAccountsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({targetsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (targetsRefs) db.targets],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (targetsRefs)
                    await $_getPrefetchedDataByColumns<
                      LoginAccountRow,
                      $LoginAccountsTable,
                      TargetRow,
                      $TargetsTable
                    >(
                      currentTable: table,
                      referencedTable: $$LoginAccountsTableReferences
                          ._targetsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LoginAccountsTableReferences(
                            db,
                            table,
                            p0,
                          ).targetsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'login_account_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LoginAccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$StorizeDatabase,
      $LoginAccountsTable,
      LoginAccountRow,
      $$LoginAccountsTableFilterComposer,
      $$LoginAccountsTableOrderingComposer,
      $$LoginAccountsTableAnnotationComposer,
      $$LoginAccountsTableCreateCompanionBuilder,
      $$LoginAccountsTableUpdateCompanionBuilder,
      (LoginAccountRow, $$LoginAccountsTableReferences),
      LoginAccountRow,
      PrefetchHooks Function({bool targetsRefs})
    >;
typedef $$TargetsTableCreateCompanionBuilder = TargetsCompanion Function({
  Value<int> id,
  required PlatformId platform,
  required String remoteUserId,
  required String username,
  Value<String?> displayName,
  Value<String?> avatarPath,
  required TargetCategory category,
  Value<String?> note,
  required TargetStatus status,
  Value<String?> statusReason,
  Value<bool> isPrivate,
  Value<bool> trackStories,
  Value<bool> trackPosts,
  Value<bool> trackReels,
  required DateTime postsWatermarkAt,
  Value<int?> loginAccountId,
  required DateTime addedAt,
  Value<DateTime?> lastStoriesCheckAt,
  Value<DateTime?> lastPostsCheckAt,
  Value<DateTime?> lastNewStoryAt,
  Value<DateTime?> lastNewPostAt,
  Value<HistoryRange> historyRange,
  Value<DateTime?> historySince,
  Value<HistoryState> historyState,
  Value<String?> historyCursor,
  Value<int> historyFetched,
  Value<DateTime?> historyOldestSeenAt,
  Value<DateTime?> historyUpdatedAt,
  Value<bool> highlightsEnabled,
  Value<DateTime?> lastSuccessAt,
  Value<TargetCheckOutcome?> lastCheckOutcome,
  Value<String?> lastCheckCode,
});
typedef $$TargetsTableUpdateCompanionBuilder = TargetsCompanion Function({
  Value<int> id,
  Value<PlatformId> platform,
  Value<String> remoteUserId,
  Value<String> username,
  Value<String?> displayName,
  Value<String?> avatarPath,
  Value<TargetCategory> category,
  Value<String?> note,
  Value<TargetStatus> status,
  Value<String?> statusReason,
  Value<bool> isPrivate,
  Value<bool> trackStories,
  Value<bool> trackPosts,
  Value<bool> trackReels,
  Value<DateTime> postsWatermarkAt,
  Value<int?> loginAccountId,
  Value<DateTime> addedAt,
  Value<DateTime?> lastStoriesCheckAt,
  Value<DateTime?> lastPostsCheckAt,
  Value<DateTime?> lastNewStoryAt,
  Value<DateTime?> lastNewPostAt,
  Value<HistoryRange> historyRange,
  Value<DateTime?> historySince,
  Value<HistoryState> historyState,
  Value<String?> historyCursor,
  Value<int> historyFetched,
  Value<DateTime?> historyOldestSeenAt,
  Value<DateTime?> historyUpdatedAt,
  Value<bool> highlightsEnabled,
  Value<DateTime?> lastSuccessAt,
  Value<TargetCheckOutcome?> lastCheckOutcome,
  Value<String?> lastCheckCode,
});

final class $$TargetsTableReferences
    extends BaseReferences<_$StorizeDatabase, $TargetsTable, TargetRow> {
  $$TargetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LoginAccountsTable _loginAccountIdTable(_$StorizeDatabase db) => db
      .loginAccounts
      .createAlias('target__login_account_id__login_account__id');

  $$LoginAccountsTableProcessedTableManager? get loginAccountId {
    final $_column = $_itemColumn<int>('login_account_id');
    if ($_column == null) return null;
    final manager = $$LoginAccountsTableTableManager(
      $_db,
      $_db.loginAccounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_loginAccountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ContentsTable, List<ContentRow>>
  _contentsRefsTable(_$StorizeDatabase db) => MultiTypedResultKey.fromTable(
    db.contents,
    aliasName: 'target__id__content__target_id',
  );

  $$ContentsTableProcessedTableManager get contentsRefs {
    final manager = $$ContentsTableTableManager(
      $_db,
      $_db.contents,
    ).filter((f) => f.targetId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_contentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ActivityEventsTable, List<ActivityEventRow>>
  _activityEventsRefsTable(_$StorizeDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.activityEvents,
        aliasName: 'target__id__activity_event__target_id',
      );

  $$ActivityEventsTableProcessedTableManager get activityEventsRefs {
    final manager = $$ActivityEventsTableTableManager(
      $_db,
      $_db.activityEvents,
    ).filter((f) => f.targetId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_activityEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TargetsTableFilterComposer
    extends Composer<_$StorizeDatabase, $TargetsTable> {
  $$TargetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<PlatformId, PlatformId, String> get platform =>
      $composableBuilder(
        column: $table.platform,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get remoteUserId => $composableBuilder(
    column: $table.remoteUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarPath => $composableBuilder(
    column: $table.avatarPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TargetCategory, TargetCategory, String>
  get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TargetStatus, TargetStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get statusReason => $composableBuilder(
    column: $table.statusReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPrivate => $composableBuilder(
    column: $table.isPrivate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get trackStories => $composableBuilder(
    column: $table.trackStories,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get trackPosts => $composableBuilder(
    column: $table.trackPosts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get trackReels => $composableBuilder(
    column: $table.trackReels,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int>
  get postsWatermarkAt => $composableBuilder(
    column: $table.postsWatermarkAt,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get addedAt =>
      $composableBuilder(
        column: $table.addedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int>
  get lastStoriesCheckAt => $composableBuilder(
    column: $table.lastStoriesCheckAt,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int>
  get lastPostsCheckAt => $composableBuilder(
    column: $table.lastPostsCheckAt,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get lastNewStoryAt =>
      $composableBuilder(
        column: $table.lastNewStoryAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get lastNewPostAt =>
      $composableBuilder(
        column: $table.lastNewPostAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<HistoryRange, HistoryRange, String>
  get historyRange => $composableBuilder(
    column: $table.historyRange,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get historySince =>
      $composableBuilder(
        column: $table.historySince,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<HistoryState, HistoryState, String>
  get historyState => $composableBuilder(
    column: $table.historyState,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get historyCursor => $composableBuilder(
    column: $table.historyCursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get historyFetched => $composableBuilder(
    column: $table.historyFetched,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int>
  get historyOldestSeenAt => $composableBuilder(
    column: $table.historyOldestSeenAt,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int>
  get historyUpdatedAt => $composableBuilder(
    column: $table.historyUpdatedAt,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get highlightsEnabled => $composableBuilder(
    column: $table.highlightsEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get lastSuccessAt =>
      $composableBuilder(
        column: $table.lastSuccessAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<
    TargetCheckOutcome?,
    TargetCheckOutcome,
    String
  >
  get lastCheckOutcome => $composableBuilder(
    column: $table.lastCheckOutcome,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get lastCheckCode => $composableBuilder(
    column: $table.lastCheckCode,
    builder: (column) => ColumnFilters(column),
  );

  $$LoginAccountsTableFilterComposer get loginAccountId {
    final $$LoginAccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.loginAccountId,
      referencedTable: $db.loginAccounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LoginAccountsTableFilterComposer(
            $db: $db,
            $table: $db.loginAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> contentsRefs(
    Expression<bool> Function($$ContentsTableFilterComposer f) f,
  ) {
    final $$ContentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.contents,
      getReferencedColumn: (t) => t.targetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContentsTableFilterComposer(
            $db: $db,
            $table: $db.contents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> activityEventsRefs(
    Expression<bool> Function($$ActivityEventsTableFilterComposer f) f,
  ) {
    final $$ActivityEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.activityEvents,
      getReferencedColumn: (t) => t.targetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivityEventsTableFilterComposer(
            $db: $db,
            $table: $db.activityEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TargetsTableOrderingComposer
    extends Composer<_$StorizeDatabase, $TargetsTable> {
  $$TargetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteUserId => $composableBuilder(
    column: $table.remoteUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarPath => $composableBuilder(
    column: $table.avatarPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get statusReason => $composableBuilder(
    column: $table.statusReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPrivate => $composableBuilder(
    column: $table.isPrivate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get trackStories => $composableBuilder(
    column: $table.trackStories,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get trackPosts => $composableBuilder(
    column: $table.trackPosts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get trackReels => $composableBuilder(
    column: $table.trackReels,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get postsWatermarkAt => $composableBuilder(
    column: $table.postsWatermarkAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastStoriesCheckAt => $composableBuilder(
    column: $table.lastStoriesCheckAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPostsCheckAt => $composableBuilder(
    column: $table.lastPostsCheckAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastNewStoryAt => $composableBuilder(
    column: $table.lastNewStoryAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastNewPostAt => $composableBuilder(
    column: $table.lastNewPostAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get historyRange => $composableBuilder(
    column: $table.historyRange,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get historySince => $composableBuilder(
    column: $table.historySince,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get historyState => $composableBuilder(
    column: $table.historyState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get historyCursor => $composableBuilder(
    column: $table.historyCursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get historyFetched => $composableBuilder(
    column: $table.historyFetched,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get historyOldestSeenAt => $composableBuilder(
    column: $table.historyOldestSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get historyUpdatedAt => $composableBuilder(
    column: $table.historyUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get highlightsEnabled => $composableBuilder(
    column: $table.highlightsEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSuccessAt => $composableBuilder(
    column: $table.lastSuccessAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastCheckOutcome => $composableBuilder(
    column: $table.lastCheckOutcome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastCheckCode => $composableBuilder(
    column: $table.lastCheckCode,
    builder: (column) => ColumnOrderings(column),
  );

  $$LoginAccountsTableOrderingComposer get loginAccountId {
    final $$LoginAccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.loginAccountId,
      referencedTable: $db.loginAccounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LoginAccountsTableOrderingComposer(
            $db: $db,
            $table: $db.loginAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TargetsTableAnnotationComposer
    extends Composer<_$StorizeDatabase, $TargetsTable> {
  $$TargetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PlatformId, String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumn<String> get remoteUserId => $composableBuilder(
    column: $table.remoteUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get avatarPath => $composableBuilder(
    column: $table.avatarPath,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<TargetCategory, String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TargetStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get statusReason => $composableBuilder(
    column: $table.statusReason,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPrivate =>
      $composableBuilder(column: $table.isPrivate, builder: (column) => column);

  GeneratedColumn<bool> get trackStories => $composableBuilder(
    column: $table.trackStories,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get trackPosts => $composableBuilder(
    column: $table.trackPosts,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get trackReels => $composableBuilder(
    column: $table.trackReels,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, int> get postsWatermarkAt =>
      $composableBuilder(
        column: $table.postsWatermarkAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime, int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get lastStoriesCheckAt =>
      $composableBuilder(
        column: $table.lastStoriesCheckAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime?, int> get lastPostsCheckAt =>
      $composableBuilder(
        column: $table.lastPostsCheckAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime?, int> get lastNewStoryAt =>
      $composableBuilder(
        column: $table.lastNewStoryAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime?, int> get lastNewPostAt =>
      $composableBuilder(
        column: $table.lastNewPostAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<HistoryRange, String> get historyRange =>
      $composableBuilder(
        column: $table.historyRange,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime?, int> get historySince =>
      $composableBuilder(
        column: $table.historySince,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<HistoryState, String> get historyState =>
      $composableBuilder(
        column: $table.historyState,
        builder: (column) => column,
      );

  GeneratedColumn<String> get historyCursor => $composableBuilder(
    column: $table.historyCursor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get historyFetched => $composableBuilder(
    column: $table.historyFetched,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime?, int> get historyOldestSeenAt =>
      $composableBuilder(
        column: $table.historyOldestSeenAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime?, int> get historyUpdatedAt =>
      $composableBuilder(
        column: $table.historyUpdatedAt,
        builder: (column) => column,
      );

  GeneratedColumn<bool> get highlightsEnabled => $composableBuilder(
    column: $table.highlightsEnabled,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime?, int> get lastSuccessAt =>
      $composableBuilder(
        column: $table.lastSuccessAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<TargetCheckOutcome?, String>
  get lastCheckOutcome => $composableBuilder(
    column: $table.lastCheckOutcome,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastCheckCode => $composableBuilder(
    column: $table.lastCheckCode,
    builder: (column) => column,
  );

  $$LoginAccountsTableAnnotationComposer get loginAccountId {
    final $$LoginAccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.loginAccountId,
      referencedTable: $db.loginAccounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LoginAccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.loginAccounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> contentsRefs<T extends Object>(
    Expression<T> Function($$ContentsTableAnnotationComposer a) f,
  ) {
    final $$ContentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.contents,
      getReferencedColumn: (t) => t.targetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContentsTableAnnotationComposer(
            $db: $db,
            $table: $db.contents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> activityEventsRefs<T extends Object>(
    Expression<T> Function($$ActivityEventsTableAnnotationComposer a) f,
  ) {
    final $$ActivityEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.activityEvents,
      getReferencedColumn: (t) => t.targetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivityEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.activityEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TargetsTableTableManager
    extends
        RootTableManager<
          _$StorizeDatabase,
          $TargetsTable,
          TargetRow,
          $$TargetsTableFilterComposer,
          $$TargetsTableOrderingComposer,
          $$TargetsTableAnnotationComposer,
          $$TargetsTableCreateCompanionBuilder,
          $$TargetsTableUpdateCompanionBuilder,
          (TargetRow, $$TargetsTableReferences),
          TargetRow,
          PrefetchHooks Function({
            bool loginAccountId,
            bool contentsRefs,
            bool activityEventsRefs,
          })
        > {
  $$TargetsTableTableManager(_$StorizeDatabase db, $TargetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TargetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TargetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TargetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<PlatformId> platform = const Value.absent(),
                Value<String> remoteUserId = const Value.absent(),
                Value<String> username = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String?> avatarPath = const Value.absent(),
                Value<TargetCategory> category = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<TargetStatus> status = const Value.absent(),
                Value<String?> statusReason = const Value.absent(),
                Value<bool> isPrivate = const Value.absent(),
                Value<bool> trackStories = const Value.absent(),
                Value<bool> trackPosts = const Value.absent(),
                Value<bool> trackReels = const Value.absent(),
                Value<DateTime> postsWatermarkAt = const Value.absent(),
                Value<int?> loginAccountId = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<DateTime?> lastStoriesCheckAt = const Value.absent(),
                Value<DateTime?> lastPostsCheckAt = const Value.absent(),
                Value<DateTime?> lastNewStoryAt = const Value.absent(),
                Value<DateTime?> lastNewPostAt = const Value.absent(),
                Value<HistoryRange> historyRange = const Value.absent(),
                Value<DateTime?> historySince = const Value.absent(),
                Value<HistoryState> historyState = const Value.absent(),
                Value<String?> historyCursor = const Value.absent(),
                Value<int> historyFetched = const Value.absent(),
                Value<DateTime?> historyOldestSeenAt = const Value.absent(),
                Value<DateTime?> historyUpdatedAt = const Value.absent(),
                Value<bool> highlightsEnabled = const Value.absent(),
                Value<DateTime?> lastSuccessAt = const Value.absent(),
                Value<TargetCheckOutcome?> lastCheckOutcome =
                    const Value.absent(),
                Value<String?> lastCheckCode = const Value.absent(),
              }) => TargetsCompanion(
                id: id,
                platform: platform,
                remoteUserId: remoteUserId,
                username: username,
                displayName: displayName,
                avatarPath: avatarPath,
                category: category,
                note: note,
                status: status,
                statusReason: statusReason,
                isPrivate: isPrivate,
                trackStories: trackStories,
                trackPosts: trackPosts,
                trackReels: trackReels,
                postsWatermarkAt: postsWatermarkAt,
                loginAccountId: loginAccountId,
                addedAt: addedAt,
                lastStoriesCheckAt: lastStoriesCheckAt,
                lastPostsCheckAt: lastPostsCheckAt,
                lastNewStoryAt: lastNewStoryAt,
                lastNewPostAt: lastNewPostAt,
                historyRange: historyRange,
                historySince: historySince,
                historyState: historyState,
                historyCursor: historyCursor,
                historyFetched: historyFetched,
                historyOldestSeenAt: historyOldestSeenAt,
                historyUpdatedAt: historyUpdatedAt,
                highlightsEnabled: highlightsEnabled,
                lastSuccessAt: lastSuccessAt,
                lastCheckOutcome: lastCheckOutcome,
                lastCheckCode: lastCheckCode,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required PlatformId platform,
                required String remoteUserId,
                required String username,
                Value<String?> displayName = const Value.absent(),
                Value<String?> avatarPath = const Value.absent(),
                required TargetCategory category,
                Value<String?> note = const Value.absent(),
                required TargetStatus status,
                Value<String?> statusReason = const Value.absent(),
                Value<bool> isPrivate = const Value.absent(),
                Value<bool> trackStories = const Value.absent(),
                Value<bool> trackPosts = const Value.absent(),
                Value<bool> trackReels = const Value.absent(),
                required DateTime postsWatermarkAt,
                Value<int?> loginAccountId = const Value.absent(),
                required DateTime addedAt,
                Value<DateTime?> lastStoriesCheckAt = const Value.absent(),
                Value<DateTime?> lastPostsCheckAt = const Value.absent(),
                Value<DateTime?> lastNewStoryAt = const Value.absent(),
                Value<DateTime?> lastNewPostAt = const Value.absent(),
                Value<HistoryRange> historyRange = const Value.absent(),
                Value<DateTime?> historySince = const Value.absent(),
                Value<HistoryState> historyState = const Value.absent(),
                Value<String?> historyCursor = const Value.absent(),
                Value<int> historyFetched = const Value.absent(),
                Value<DateTime?> historyOldestSeenAt = const Value.absent(),
                Value<DateTime?> historyUpdatedAt = const Value.absent(),
                Value<bool> highlightsEnabled = const Value.absent(),
                Value<DateTime?> lastSuccessAt = const Value.absent(),
                Value<TargetCheckOutcome?> lastCheckOutcome =
                    const Value.absent(),
                Value<String?> lastCheckCode = const Value.absent(),
              }) => TargetsCompanion.insert(
                id: id,
                platform: platform,
                remoteUserId: remoteUserId,
                username: username,
                displayName: displayName,
                avatarPath: avatarPath,
                category: category,
                note: note,
                status: status,
                statusReason: statusReason,
                isPrivate: isPrivate,
                trackStories: trackStories,
                trackPosts: trackPosts,
                trackReels: trackReels,
                postsWatermarkAt: postsWatermarkAt,
                loginAccountId: loginAccountId,
                addedAt: addedAt,
                lastStoriesCheckAt: lastStoriesCheckAt,
                lastPostsCheckAt: lastPostsCheckAt,
                lastNewStoryAt: lastNewStoryAt,
                lastNewPostAt: lastNewPostAt,
                historyRange: historyRange,
                historySince: historySince,
                historyState: historyState,
                historyCursor: historyCursor,
                historyFetched: historyFetched,
                historyOldestSeenAt: historyOldestSeenAt,
                historyUpdatedAt: historyUpdatedAt,
                highlightsEnabled: highlightsEnabled,
                lastSuccessAt: lastSuccessAt,
                lastCheckOutcome: lastCheckOutcome,
                lastCheckCode: lastCheckCode,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TargetsTable, TargetRow>(table),
                  $$TargetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                loginAccountId = false,
                contentsRefs = false,
                activityEventsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (contentsRefs) db.contents,
                    if (activityEventsRefs) db.activityEvents,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (loginAccountId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.loginAccountId,
                            referencedTable: $$TargetsTableReferences
                                ._loginAccountIdTable(db),
                            referencedColumn: $$TargetsTableReferences
                                ._loginAccountIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (contentsRefs)
                        await $_getPrefetchedDataByColumns<
                          TargetRow,
                          $TargetsTable,
                          ContentRow,
                          $ContentsTable
                        >(
                          currentTable: table,
                          referencedTable: $$TargetsTableReferences
                              ._contentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TargetsTableReferences(
                                db,
                                table,
                                p0,
                              ).contentsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'target_id',
                          typedResults: items,
                        ),
                      if (activityEventsRefs)
                        await $_getPrefetchedDataByColumns<
                          TargetRow,
                          $TargetsTable,
                          ActivityEventRow,
                          $ActivityEventsTable
                        >(
                          currentTable: table,
                          referencedTable: $$TargetsTableReferences
                              ._activityEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TargetsTableReferences(
                                db,
                                table,
                                p0,
                              ).activityEventsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'target_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TargetsTableProcessedTableManager =
    ProcessedTableManager<
      _$StorizeDatabase,
      $TargetsTable,
      TargetRow,
      $$TargetsTableFilterComposer,
      $$TargetsTableOrderingComposer,
      $$TargetsTableAnnotationComposer,
      $$TargetsTableCreateCompanionBuilder,
      $$TargetsTableUpdateCompanionBuilder,
      (TargetRow, $$TargetsTableReferences),
      TargetRow,
      PrefetchHooks Function({
        bool loginAccountId,
        bool contentsRefs,
        bool activityEventsRefs,
      })
    >;
typedef $$ContentsTableCreateCompanionBuilder = ContentsCompanion Function({
  Value<int> id,
  required int targetId,
  required ContentKind kind,
  required String remoteId,
  Value<String?> shortcode,
  Value<PostType?> postType,
  required DateTime postedAt,
  Value<DateTime?> expiresAt,
  Value<String?> caption,
  Value<String?> locationName,
  Value<String?> taggedUsernames,
  Value<int> slideCount,
  Value<bool> isCloseFriends,
  Value<String?> extrasJson,
  required DateTime detectedAt,
  required ContentStatus status,
  Value<bool> viewed,
});
typedef $$ContentsTableUpdateCompanionBuilder = ContentsCompanion Function({
  Value<int> id,
  Value<int> targetId,
  Value<ContentKind> kind,
  Value<String> remoteId,
  Value<String?> shortcode,
  Value<PostType?> postType,
  Value<DateTime> postedAt,
  Value<DateTime?> expiresAt,
  Value<String?> caption,
  Value<String?> locationName,
  Value<String?> taggedUsernames,
  Value<int> slideCount,
  Value<bool> isCloseFriends,
  Value<String?> extrasJson,
  Value<DateTime> detectedAt,
  Value<ContentStatus> status,
  Value<bool> viewed,
});

final class $$ContentsTableReferences
    extends BaseReferences<_$StorizeDatabase, $ContentsTable, ContentRow> {
  $$ContentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TargetsTable _targetIdTable(_$StorizeDatabase db) =>
      db.targets.createAlias('content__target_id__target__id');

  $$TargetsTableProcessedTableManager get targetId {
    final $_column = $_itemColumn<int>('target_id')!;

    final manager = $$TargetsTableTableManager(
      $_db,
      $_db.targets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_targetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$MediaFilesTable, List<MediaFileRow>>
  _mediaFilesRefsTable(_$StorizeDatabase db) => MultiTypedResultKey.fromTable(
    db.mediaFiles,
    aliasName: 'content__id__media_file__content_id',
  );

  $$MediaFilesTableProcessedTableManager get mediaFilesRefs {
    final manager = $$MediaFilesTableTableManager(
      $_db,
      $_db.mediaFiles,
    ).filter((f) => f.contentId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_mediaFilesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ContentsTableFilterComposer
    extends Composer<_$StorizeDatabase, $ContentsTable> {
  $$ContentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ContentKind, ContentKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shortcode => $composableBuilder(
    column: $table.shortcode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<PostType?, PostType, String> get postType =>
      $composableBuilder(
        column: $table.postType,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get postedAt =>
      $composableBuilder(
        column: $table.postedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get expiresAt =>
      $composableBuilder(
        column: $table.expiresAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get caption => $composableBuilder(
    column: $table.caption,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locationName => $composableBuilder(
    column: $table.locationName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get taggedUsernames => $composableBuilder(
    column: $table.taggedUsernames,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get slideCount => $composableBuilder(
    column: $table.slideCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCloseFriends => $composableBuilder(
    column: $table.isCloseFriends,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extrasJson => $composableBuilder(
    column: $table.extrasJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get detectedAt =>
      $composableBuilder(
        column: $table.detectedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<ContentStatus, ContentStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get viewed => $composableBuilder(
    column: $table.viewed,
    builder: (column) => ColumnFilters(column),
  );

  $$TargetsTableFilterComposer get targetId {
    final $$TargetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetId,
      referencedTable: $db.targets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TargetsTableFilterComposer(
            $db: $db,
            $table: $db.targets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> mediaFilesRefs(
    Expression<bool> Function($$MediaFilesTableFilterComposer f) f,
  ) {
    final $$MediaFilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mediaFiles,
      getReferencedColumn: (t) => t.contentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaFilesTableFilterComposer(
            $db: $db,
            $table: $db.mediaFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ContentsTableOrderingComposer
    extends Composer<_$StorizeDatabase, $ContentsTable> {
  $$ContentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shortcode => $composableBuilder(
    column: $table.shortcode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get postType => $composableBuilder(
    column: $table.postType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get postedAt => $composableBuilder(
    column: $table.postedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caption => $composableBuilder(
    column: $table.caption,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locationName => $composableBuilder(
    column: $table.locationName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get taggedUsernames => $composableBuilder(
    column: $table.taggedUsernames,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get slideCount => $composableBuilder(
    column: $table.slideCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCloseFriends => $composableBuilder(
    column: $table.isCloseFriends,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extrasJson => $composableBuilder(
    column: $table.extrasJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get detectedAt => $composableBuilder(
    column: $table.detectedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get viewed => $composableBuilder(
    column: $table.viewed,
    builder: (column) => ColumnOrderings(column),
  );

  $$TargetsTableOrderingComposer get targetId {
    final $$TargetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetId,
      referencedTable: $db.targets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TargetsTableOrderingComposer(
            $db: $db,
            $table: $db.targets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ContentsTableAnnotationComposer
    extends Composer<_$StorizeDatabase, $ContentsTable> {
  $$ContentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ContentKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get shortcode =>
      $composableBuilder(column: $table.shortcode, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PostType?, String> get postType =>
      $composableBuilder(column: $table.postType, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get postedAt =>
      $composableBuilder(column: $table.postedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<String> get caption =>
      $composableBuilder(column: $table.caption, builder: (column) => column);

  GeneratedColumn<String> get locationName => $composableBuilder(
    column: $table.locationName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get taggedUsernames => $composableBuilder(
    column: $table.taggedUsernames,
    builder: (column) => column,
  );

  GeneratedColumn<int> get slideCount => $composableBuilder(
    column: $table.slideCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCloseFriends => $composableBuilder(
    column: $table.isCloseFriends,
    builder: (column) => column,
  );

  GeneratedColumn<String> get extrasJson => $composableBuilder(
    column: $table.extrasJson,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DateTime, int> get detectedAt =>
      $composableBuilder(
        column: $table.detectedAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<ContentStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get viewed =>
      $composableBuilder(column: $table.viewed, builder: (column) => column);

  $$TargetsTableAnnotationComposer get targetId {
    final $$TargetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetId,
      referencedTable: $db.targets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TargetsTableAnnotationComposer(
            $db: $db,
            $table: $db.targets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> mediaFilesRefs<T extends Object>(
    Expression<T> Function($$MediaFilesTableAnnotationComposer a) f,
  ) {
    final $$MediaFilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mediaFiles,
      getReferencedColumn: (t) => t.contentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MediaFilesTableAnnotationComposer(
            $db: $db,
            $table: $db.mediaFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ContentsTableTableManager
    extends
        RootTableManager<
          _$StorizeDatabase,
          $ContentsTable,
          ContentRow,
          $$ContentsTableFilterComposer,
          $$ContentsTableOrderingComposer,
          $$ContentsTableAnnotationComposer,
          $$ContentsTableCreateCompanionBuilder,
          $$ContentsTableUpdateCompanionBuilder,
          (ContentRow, $$ContentsTableReferences),
          ContentRow,
          PrefetchHooks Function({bool targetId, bool mediaFilesRefs})
        > {
  $$ContentsTableTableManager(_$StorizeDatabase db, $ContentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> targetId = const Value.absent(),
                Value<ContentKind> kind = const Value.absent(),
                Value<String> remoteId = const Value.absent(),
                Value<String?> shortcode = const Value.absent(),
                Value<PostType?> postType = const Value.absent(),
                Value<DateTime> postedAt = const Value.absent(),
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<String?> caption = const Value.absent(),
                Value<String?> locationName = const Value.absent(),
                Value<String?> taggedUsernames = const Value.absent(),
                Value<int> slideCount = const Value.absent(),
                Value<bool> isCloseFriends = const Value.absent(),
                Value<String?> extrasJson = const Value.absent(),
                Value<DateTime> detectedAt = const Value.absent(),
                Value<ContentStatus> status = const Value.absent(),
                Value<bool> viewed = const Value.absent(),
              }) => ContentsCompanion(
                id: id,
                targetId: targetId,
                kind: kind,
                remoteId: remoteId,
                shortcode: shortcode,
                postType: postType,
                postedAt: postedAt,
                expiresAt: expiresAt,
                caption: caption,
                locationName: locationName,
                taggedUsernames: taggedUsernames,
                slideCount: slideCount,
                isCloseFriends: isCloseFriends,
                extrasJson: extrasJson,
                detectedAt: detectedAt,
                status: status,
                viewed: viewed,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int targetId,
                required ContentKind kind,
                required String remoteId,
                Value<String?> shortcode = const Value.absent(),
                Value<PostType?> postType = const Value.absent(),
                required DateTime postedAt,
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<String?> caption = const Value.absent(),
                Value<String?> locationName = const Value.absent(),
                Value<String?> taggedUsernames = const Value.absent(),
                Value<int> slideCount = const Value.absent(),
                Value<bool> isCloseFriends = const Value.absent(),
                Value<String?> extrasJson = const Value.absent(),
                required DateTime detectedAt,
                required ContentStatus status,
                Value<bool> viewed = const Value.absent(),
              }) => ContentsCompanion.insert(
                id: id,
                targetId: targetId,
                kind: kind,
                remoteId: remoteId,
                shortcode: shortcode,
                postType: postType,
                postedAt: postedAt,
                expiresAt: expiresAt,
                caption: caption,
                locationName: locationName,
                taggedUsernames: taggedUsernames,
                slideCount: slideCount,
                isCloseFriends: isCloseFriends,
                extrasJson: extrasJson,
                detectedAt: detectedAt,
                status: status,
                viewed: viewed,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ContentsTable, ContentRow>(table),
                  $$ContentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({targetId = false, mediaFilesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (mediaFilesRefs) db.mediaFiles],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (targetId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.targetId,
                        referencedTable: $$ContentsTableReferences
                            ._targetIdTable(db),
                        referencedColumn: $$ContentsTableReferences
                            ._targetIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (mediaFilesRefs)
                    await $_getPrefetchedDataByColumns<
                      ContentRow,
                      $ContentsTable,
                      MediaFileRow,
                      $MediaFilesTable
                    >(
                      currentTable: table,
                      referencedTable: $$ContentsTableReferences
                          ._mediaFilesRefsTable(db),
                      managerFromTypedResult: (p0) => $$ContentsTableReferences(
                        db,
                        table,
                        p0,
                      ).mediaFilesRefs,
                      currentColumn: 'id',
                      referencedColumn: 'content_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ContentsTableProcessedTableManager =
    ProcessedTableManager<
      _$StorizeDatabase,
      $ContentsTable,
      ContentRow,
      $$ContentsTableFilterComposer,
      $$ContentsTableOrderingComposer,
      $$ContentsTableAnnotationComposer,
      $$ContentsTableCreateCompanionBuilder,
      $$ContentsTableUpdateCompanionBuilder,
      (ContentRow, $$ContentsTableReferences),
      ContentRow,
      PrefetchHooks Function({bool targetId, bool mediaFilesRefs})
    >;
typedef $$MediaFilesTableCreateCompanionBuilder = MediaFilesCompanion Function({
  Value<int> id,
  required int contentId,
  Value<int> slideIndex,
  required MediaType mediaType,
  required String sourceUrl,
  required MediaFileStatus status,
  Value<int> attempts,
  Value<String?> contentUri,
  Value<String?> relativePath,
  Value<String?> displayName,
  Value<String?> thumbPath,
  Value<int?> width,
  Value<int?> height,
  Value<int?> durationMs,
  Value<int?> sizeBytes,
  Value<DateTime?> downloadedAt,
});
typedef $$MediaFilesTableUpdateCompanionBuilder = MediaFilesCompanion Function({
  Value<int> id,
  Value<int> contentId,
  Value<int> slideIndex,
  Value<MediaType> mediaType,
  Value<String> sourceUrl,
  Value<MediaFileStatus> status,
  Value<int> attempts,
  Value<String?> contentUri,
  Value<String?> relativePath,
  Value<String?> displayName,
  Value<String?> thumbPath,
  Value<int?> width,
  Value<int?> height,
  Value<int?> durationMs,
  Value<int?> sizeBytes,
  Value<DateTime?> downloadedAt,
});

final class $$MediaFilesTableReferences
    extends BaseReferences<_$StorizeDatabase, $MediaFilesTable, MediaFileRow> {
  $$MediaFilesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ContentsTable _contentIdTable(_$StorizeDatabase db) =>
      db.contents.createAlias('media_file__content_id__content__id');

  $$ContentsTableProcessedTableManager get contentId {
    final $_column = $_itemColumn<int>('content_id')!;

    final manager = $$ContentsTableTableManager(
      $_db,
      $_db.contents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_contentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MediaFilesTableFilterComposer
    extends Composer<_$StorizeDatabase, $MediaFilesTable> {
  $$MediaFilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get slideIndex => $composableBuilder(
    column: $table.slideIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MediaType, MediaType, String> get mediaType =>
      $composableBuilder(
        column: $table.mediaType,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<MediaFileStatus, MediaFileStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentUri => $composableBuilder(
    column: $table.contentUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbPath => $composableBuilder(
    column: $table.thumbPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get downloadedAt =>
      $composableBuilder(
        column: $table.downloadedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  $$ContentsTableFilterComposer get contentId {
    final $$ContentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.contentId,
      referencedTable: $db.contents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContentsTableFilterComposer(
            $db: $db,
            $table: $db.contents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MediaFilesTableOrderingComposer
    extends Composer<_$StorizeDatabase, $MediaFilesTable> {
  $$MediaFilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get slideIndex => $composableBuilder(
    column: $table.slideIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediaType => $composableBuilder(
    column: $table.mediaType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentUri => $composableBuilder(
    column: $table.contentUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbPath => $composableBuilder(
    column: $table.thumbPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ContentsTableOrderingComposer get contentId {
    final $$ContentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.contentId,
      referencedTable: $db.contents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContentsTableOrderingComposer(
            $db: $db,
            $table: $db.contents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MediaFilesTableAnnotationComposer
    extends Composer<_$StorizeDatabase, $MediaFilesTable> {
  $$MediaFilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get slideIndex => $composableBuilder(
    column: $table.slideIndex,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<MediaType, String> get mediaType =>
      $composableBuilder(column: $table.mediaType, builder: (column) => column);

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumnWithTypeConverter<MediaFileStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get contentUri => $composableBuilder(
    column: $table.contentUri,
    builder: (column) => column,
  );

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get thumbPath =>
      $composableBuilder(column: $table.thumbPath, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get downloadedAt =>
      $composableBuilder(
        column: $table.downloadedAt,
        builder: (column) => column,
      );

  $$ContentsTableAnnotationComposer get contentId {
    final $$ContentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.contentId,
      referencedTable: $db.contents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContentsTableAnnotationComposer(
            $db: $db,
            $table: $db.contents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MediaFilesTableTableManager
    extends
        RootTableManager<
          _$StorizeDatabase,
          $MediaFilesTable,
          MediaFileRow,
          $$MediaFilesTableFilterComposer,
          $$MediaFilesTableOrderingComposer,
          $$MediaFilesTableAnnotationComposer,
          $$MediaFilesTableCreateCompanionBuilder,
          $$MediaFilesTableUpdateCompanionBuilder,
          (MediaFileRow, $$MediaFilesTableReferences),
          MediaFileRow,
          PrefetchHooks Function({bool contentId})
        > {
  $$MediaFilesTableTableManager(_$StorizeDatabase db, $MediaFilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaFilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaFilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaFilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> contentId = const Value.absent(),
                Value<int> slideIndex = const Value.absent(),
                Value<MediaType> mediaType = const Value.absent(),
                Value<String> sourceUrl = const Value.absent(),
                Value<MediaFileStatus> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> contentUri = const Value.absent(),
                Value<String?> relativePath = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String?> thumbPath = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<DateTime?> downloadedAt = const Value.absent(),
              }) => MediaFilesCompanion(
                id: id,
                contentId: contentId,
                slideIndex: slideIndex,
                mediaType: mediaType,
                sourceUrl: sourceUrl,
                status: status,
                attempts: attempts,
                contentUri: contentUri,
                relativePath: relativePath,
                displayName: displayName,
                thumbPath: thumbPath,
                width: width,
                height: height,
                durationMs: durationMs,
                sizeBytes: sizeBytes,
                downloadedAt: downloadedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int contentId,
                Value<int> slideIndex = const Value.absent(),
                required MediaType mediaType,
                required String sourceUrl,
                required MediaFileStatus status,
                Value<int> attempts = const Value.absent(),
                Value<String?> contentUri = const Value.absent(),
                Value<String?> relativePath = const Value.absent(),
                Value<String?> displayName = const Value.absent(),
                Value<String?> thumbPath = const Value.absent(),
                Value<int?> width = const Value.absent(),
                Value<int?> height = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<DateTime?> downloadedAt = const Value.absent(),
              }) => MediaFilesCompanion.insert(
                id: id,
                contentId: contentId,
                slideIndex: slideIndex,
                mediaType: mediaType,
                sourceUrl: sourceUrl,
                status: status,
                attempts: attempts,
                contentUri: contentUri,
                relativePath: relativePath,
                displayName: displayName,
                thumbPath: thumbPath,
                width: width,
                height: height,
                durationMs: durationMs,
                sizeBytes: sizeBytes,
                downloadedAt: downloadedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MediaFilesTable, MediaFileRow>(table),
                  $$MediaFilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({contentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (contentId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.contentId,
                        referencedTable: $$MediaFilesTableReferences
                            ._contentIdTable(db),
                        referencedColumn: $$MediaFilesTableReferences
                            ._contentIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MediaFilesTableProcessedTableManager =
    ProcessedTableManager<
      _$StorizeDatabase,
      $MediaFilesTable,
      MediaFileRow,
      $$MediaFilesTableFilterComposer,
      $$MediaFilesTableOrderingComposer,
      $$MediaFilesTableAnnotationComposer,
      $$MediaFilesTableCreateCompanionBuilder,
      $$MediaFilesTableUpdateCompanionBuilder,
      (MediaFileRow, $$MediaFilesTableReferences),
      MediaFileRow,
      PrefetchHooks Function({bool contentId})
    >;
typedef $$CheckRunsTableCreateCompanionBuilder = CheckRunsCompanion Function({
  Value<int> id,
  required CheckScope scope,
  required CheckTrigger trigger,
  required DateTime startedAt,
  Value<DateTime?> finishedAt,
  Value<CheckResult?> result,
  Value<ExtractionMode?> mode,
  Value<int> targetsChecked,
  Value<int> newItems,
  Value<String?> errorCode,
});
typedef $$CheckRunsTableUpdateCompanionBuilder = CheckRunsCompanion Function({
  Value<int> id,
  Value<CheckScope> scope,
  Value<CheckTrigger> trigger,
  Value<DateTime> startedAt,
  Value<DateTime?> finishedAt,
  Value<CheckResult?> result,
  Value<ExtractionMode?> mode,
  Value<int> targetsChecked,
  Value<int> newItems,
  Value<String?> errorCode,
});

final class $$CheckRunsTableReferences
    extends BaseReferences<_$StorizeDatabase, $CheckRunsTable, CheckRunRow> {
  $$CheckRunsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ActivityEventsTable, List<ActivityEventRow>>
  _activityEventsRefsTable(_$StorizeDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.activityEvents,
        aliasName: 'check_run__id__activity_event__check_run_id',
      );

  $$ActivityEventsTableProcessedTableManager get activityEventsRefs {
    final manager = $$ActivityEventsTableTableManager(
      $_db,
      $_db.activityEvents,
    ).filter((f) => f.checkRunId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_activityEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CheckRunsTableFilterComposer
    extends Composer<_$StorizeDatabase, $CheckRunsTable> {
  $$CheckRunsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CheckScope, CheckScope, String> get scope =>
      $composableBuilder(
        column: $table.scope,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<CheckTrigger, CheckTrigger, String>
  get trigger => $composableBuilder(
    column: $table.trigger,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get startedAt =>
      $composableBuilder(
        column: $table.startedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get finishedAt =>
      $composableBuilder(
        column: $table.finishedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<CheckResult?, CheckResult, String>
  get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<ExtractionMode?, ExtractionMode, String>
  get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get targetsChecked => $composableBuilder(
    column: $table.targetsChecked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get newItems => $composableBuilder(
    column: $table.newItems,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> activityEventsRefs(
    Expression<bool> Function($$ActivityEventsTableFilterComposer f) f,
  ) {
    final $$ActivityEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.activityEvents,
      getReferencedColumn: (t) => t.checkRunId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivityEventsTableFilterComposer(
            $db: $db,
            $table: $db.activityEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CheckRunsTableOrderingComposer
    extends Composer<_$StorizeDatabase, $CheckRunsTable> {
  $$CheckRunsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trigger => $composableBuilder(
    column: $table.trigger,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetsChecked => $composableBuilder(
    column: $table.targetsChecked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get newItems => $composableBuilder(
    column: $table.newItems,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CheckRunsTableAnnotationComposer
    extends Composer<_$StorizeDatabase, $CheckRunsTable> {
  $$CheckRunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CheckScope, String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CheckTrigger, String> get trigger =>
      $composableBuilder(column: $table.trigger, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime?, int> get finishedAt =>
      $composableBuilder(
        column: $table.finishedAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<CheckResult?, String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ExtractionMode?, String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get targetsChecked => $composableBuilder(
    column: $table.targetsChecked,
    builder: (column) => column,
  );

  GeneratedColumn<int> get newItems =>
      $composableBuilder(column: $table.newItems, builder: (column) => column);

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  Expression<T> activityEventsRefs<T extends Object>(
    Expression<T> Function($$ActivityEventsTableAnnotationComposer a) f,
  ) {
    final $$ActivityEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.activityEvents,
      getReferencedColumn: (t) => t.checkRunId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ActivityEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.activityEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CheckRunsTableTableManager
    extends
        RootTableManager<
          _$StorizeDatabase,
          $CheckRunsTable,
          CheckRunRow,
          $$CheckRunsTableFilterComposer,
          $$CheckRunsTableOrderingComposer,
          $$CheckRunsTableAnnotationComposer,
          $$CheckRunsTableCreateCompanionBuilder,
          $$CheckRunsTableUpdateCompanionBuilder,
          (CheckRunRow, $$CheckRunsTableReferences),
          CheckRunRow,
          PrefetchHooks Function({bool activityEventsRefs})
        > {
  $$CheckRunsTableTableManager(_$StorizeDatabase db, $CheckRunsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CheckRunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CheckRunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CheckRunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<CheckScope> scope = const Value.absent(),
                Value<CheckTrigger> trigger = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<CheckResult?> result = const Value.absent(),
                Value<ExtractionMode?> mode = const Value.absent(),
                Value<int> targetsChecked = const Value.absent(),
                Value<int> newItems = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
              }) => CheckRunsCompanion(
                id: id,
                scope: scope,
                trigger: trigger,
                startedAt: startedAt,
                finishedAt: finishedAt,
                result: result,
                mode: mode,
                targetsChecked: targetsChecked,
                newItems: newItems,
                errorCode: errorCode,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required CheckScope scope,
                required CheckTrigger trigger,
                required DateTime startedAt,
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<CheckResult?> result = const Value.absent(),
                Value<ExtractionMode?> mode = const Value.absent(),
                Value<int> targetsChecked = const Value.absent(),
                Value<int> newItems = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
              }) => CheckRunsCompanion.insert(
                id: id,
                scope: scope,
                trigger: trigger,
                startedAt: startedAt,
                finishedAt: finishedAt,
                result: result,
                mode: mode,
                targetsChecked: targetsChecked,
                newItems: newItems,
                errorCode: errorCode,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CheckRunsTable, CheckRunRow>(table),
                  $$CheckRunsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({activityEventsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (activityEventsRefs) db.activityEvents,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (activityEventsRefs)
                    await $_getPrefetchedDataByColumns<
                      CheckRunRow,
                      $CheckRunsTable,
                      ActivityEventRow,
                      $ActivityEventsTable
                    >(
                      currentTable: table,
                      referencedTable: $$CheckRunsTableReferences
                          ._activityEventsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CheckRunsTableReferences(
                            db,
                            table,
                            p0,
                          ).activityEventsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'check_run_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CheckRunsTableProcessedTableManager =
    ProcessedTableManager<
      _$StorizeDatabase,
      $CheckRunsTable,
      CheckRunRow,
      $$CheckRunsTableFilterComposer,
      $$CheckRunsTableOrderingComposer,
      $$CheckRunsTableAnnotationComposer,
      $$CheckRunsTableCreateCompanionBuilder,
      $$CheckRunsTableUpdateCompanionBuilder,
      (CheckRunRow, $$CheckRunsTableReferences),
      CheckRunRow,
      PrefetchHooks Function({bool activityEventsRefs})
    >;
typedef $$ActivityEventsTableCreateCompanionBuilder =
    ActivityEventsCompanion Function({
      Value<int> id,
      required DateTime at,
      required ActivityType type,
      required Severity severity,
      Value<int?> targetId,
      Value<int?> checkRunId,
      Value<int> count,
      Value<String?> payloadJson,
    });
typedef $$ActivityEventsTableUpdateCompanionBuilder =
    ActivityEventsCompanion Function({
      Value<int> id,
      Value<DateTime> at,
      Value<ActivityType> type,
      Value<Severity> severity,
      Value<int?> targetId,
      Value<int?> checkRunId,
      Value<int> count,
      Value<String?> payloadJson,
    });

final class $$ActivityEventsTableReferences
    extends
        BaseReferences<
          _$StorizeDatabase,
          $ActivityEventsTable,
          ActivityEventRow
        > {
  $$ActivityEventsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TargetsTable _targetIdTable(_$StorizeDatabase db) =>
      db.targets.createAlias('activity_event__target_id__target__id');

  $$TargetsTableProcessedTableManager? get targetId {
    final $_column = $_itemColumn<int>('target_id');
    if ($_column == null) return null;
    final manager = $$TargetsTableTableManager(
      $_db,
      $_db.targets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_targetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CheckRunsTable _checkRunIdTable(_$StorizeDatabase db) =>
      db.checkRuns.createAlias('activity_event__check_run_id__check_run__id');

  $$CheckRunsTableProcessedTableManager? get checkRunId {
    final $_column = $_itemColumn<int>('check_run_id');
    if ($_column == null) return null;
    final manager = $$CheckRunsTableTableManager(
      $_db,
      $_db.checkRuns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_checkRunIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ActivityEventsTableFilterComposer
    extends Composer<_$StorizeDatabase, $ActivityEventsTable> {
  $$ActivityEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get at =>
      $composableBuilder(
        column: $table.at,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<ActivityType, ActivityType, String> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Severity, Severity, String> get severity =>
      $composableBuilder(
        column: $table.severity,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  $$TargetsTableFilterComposer get targetId {
    final $$TargetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetId,
      referencedTable: $db.targets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TargetsTableFilterComposer(
            $db: $db,
            $table: $db.targets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CheckRunsTableFilterComposer get checkRunId {
    final $$CheckRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.checkRunId,
      referencedTable: $db.checkRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CheckRunsTableFilterComposer(
            $db: $db,
            $table: $db.checkRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ActivityEventsTableOrderingComposer
    extends Composer<_$StorizeDatabase, $ActivityEventsTable> {
  $$ActivityEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  $$TargetsTableOrderingComposer get targetId {
    final $$TargetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetId,
      referencedTable: $db.targets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TargetsTableOrderingComposer(
            $db: $db,
            $table: $db.targets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CheckRunsTableOrderingComposer get checkRunId {
    final $$CheckRunsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.checkRunId,
      referencedTable: $db.checkRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CheckRunsTableOrderingComposer(
            $db: $db,
            $table: $db.checkRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ActivityEventsTableAnnotationComposer
    extends Composer<_$StorizeDatabase, $ActivityEventsTable> {
  $$ActivityEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ActivityType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Severity, String> get severity =>
      $composableBuilder(column: $table.severity, builder: (column) => column);

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  $$TargetsTableAnnotationComposer get targetId {
    final $$TargetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetId,
      referencedTable: $db.targets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TargetsTableAnnotationComposer(
            $db: $db,
            $table: $db.targets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CheckRunsTableAnnotationComposer get checkRunId {
    final $$CheckRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.checkRunId,
      referencedTable: $db.checkRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CheckRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.checkRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ActivityEventsTableTableManager
    extends
        RootTableManager<
          _$StorizeDatabase,
          $ActivityEventsTable,
          ActivityEventRow,
          $$ActivityEventsTableFilterComposer,
          $$ActivityEventsTableOrderingComposer,
          $$ActivityEventsTableAnnotationComposer,
          $$ActivityEventsTableCreateCompanionBuilder,
          $$ActivityEventsTableUpdateCompanionBuilder,
          (ActivityEventRow, $$ActivityEventsTableReferences),
          ActivityEventRow,
          PrefetchHooks Function({bool targetId, bool checkRunId})
        > {
  $$ActivityEventsTableTableManager(
    _$StorizeDatabase db,
    $ActivityEventsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActivityEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActivityEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActivityEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<ActivityType> type = const Value.absent(),
                Value<Severity> severity = const Value.absent(),
                Value<int?> targetId = const Value.absent(),
                Value<int?> checkRunId = const Value.absent(),
                Value<int> count = const Value.absent(),
                Value<String?> payloadJson = const Value.absent(),
              }) => ActivityEventsCompanion(
                id: id,
                at: at,
                type: type,
                severity: severity,
                targetId: targetId,
                checkRunId: checkRunId,
                count: count,
                payloadJson: payloadJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime at,
                required ActivityType type,
                required Severity severity,
                Value<int?> targetId = const Value.absent(),
                Value<int?> checkRunId = const Value.absent(),
                Value<int> count = const Value.absent(),
                Value<String?> payloadJson = const Value.absent(),
              }) => ActivityEventsCompanion.insert(
                id: id,
                at: at,
                type: type,
                severity: severity,
                targetId: targetId,
                checkRunId: checkRunId,
                count: count,
                payloadJson: payloadJson,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ActivityEventsTable, ActivityEventRow>(table),
                  $$ActivityEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({targetId = false, checkRunId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (targetId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.targetId,
                        referencedTable: $$ActivityEventsTableReferences
                            ._targetIdTable(db),
                        referencedColumn: $$ActivityEventsTableReferences
                            ._targetIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (checkRunId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.checkRunId,
                        referencedTable: $$ActivityEventsTableReferences
                            ._checkRunIdTable(db),
                        referencedColumn: $$ActivityEventsTableReferences
                            ._checkRunIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ActivityEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$StorizeDatabase,
      $ActivityEventsTable,
      ActivityEventRow,
      $$ActivityEventsTableFilterComposer,
      $$ActivityEventsTableOrderingComposer,
      $$ActivityEventsTableAnnotationComposer,
      $$ActivityEventsTableCreateCompanionBuilder,
      $$ActivityEventsTableUpdateCompanionBuilder,
      (ActivityEventRow, $$ActivityEventsTableReferences),
      ActivityEventRow,
      PrefetchHooks Function({bool targetId, bool checkRunId})
    >;
typedef $$GovernorLeasesTableCreateCompanionBuilder =
    GovernorLeasesCompanion Function({
      Value<int> loginAccountId,
      required String holder,
      required DateTime expiresAt,
      required double tokens,
      required DateTime lastRefillAt,
      Value<DateTime?> backoffUntil,
      Value<double> backoffMultiplier,
    });
typedef $$GovernorLeasesTableUpdateCompanionBuilder =
    GovernorLeasesCompanion Function({
      Value<int> loginAccountId,
      Value<String> holder,
      Value<DateTime> expiresAt,
      Value<double> tokens,
      Value<DateTime> lastRefillAt,
      Value<DateTime?> backoffUntil,
      Value<double> backoffMultiplier,
    });

class $$GovernorLeasesTableFilterComposer
    extends Composer<_$StorizeDatabase, $GovernorLeasesTable> {
  $$GovernorLeasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get loginAccountId => $composableBuilder(
    column: $table.loginAccountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get holder => $composableBuilder(
    column: $table.holder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get expiresAt =>
      $composableBuilder(
        column: $table.expiresAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<double> get tokens => $composableBuilder(
    column: $table.tokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get lastRefillAt =>
      $composableBuilder(
        column: $table.lastRefillAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<DateTime?, DateTime, int> get backoffUntil =>
      $composableBuilder(
        column: $table.backoffUntil,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<double> get backoffMultiplier => $composableBuilder(
    column: $table.backoffMultiplier,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GovernorLeasesTableOrderingComposer
    extends Composer<_$StorizeDatabase, $GovernorLeasesTable> {
  $$GovernorLeasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get loginAccountId => $composableBuilder(
    column: $table.loginAccountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get holder => $composableBuilder(
    column: $table.holder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get tokens => $composableBuilder(
    column: $table.tokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastRefillAt => $composableBuilder(
    column: $table.lastRefillAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get backoffUntil => $composableBuilder(
    column: $table.backoffUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get backoffMultiplier => $composableBuilder(
    column: $table.backoffMultiplier,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GovernorLeasesTableAnnotationComposer
    extends Composer<_$StorizeDatabase, $GovernorLeasesTable> {
  $$GovernorLeasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get loginAccountId => $composableBuilder(
    column: $table.loginAccountId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get holder =>
      $composableBuilder(column: $table.holder, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<double> get tokens =>
      $composableBuilder(column: $table.tokens, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get lastRefillAt =>
      $composableBuilder(
        column: $table.lastRefillAt,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<DateTime?, int> get backoffUntil =>
      $composableBuilder(
        column: $table.backoffUntil,
        builder: (column) => column,
      );

  GeneratedColumn<double> get backoffMultiplier => $composableBuilder(
    column: $table.backoffMultiplier,
    builder: (column) => column,
  );
}

class $$GovernorLeasesTableTableManager
    extends
        RootTableManager<
          _$StorizeDatabase,
          $GovernorLeasesTable,
          GovernorLeaseRow,
          $$GovernorLeasesTableFilterComposer,
          $$GovernorLeasesTableOrderingComposer,
          $$GovernorLeasesTableAnnotationComposer,
          $$GovernorLeasesTableCreateCompanionBuilder,
          $$GovernorLeasesTableUpdateCompanionBuilder,
          (
            GovernorLeaseRow,
            BaseReferences<
              _$StorizeDatabase,
              $GovernorLeasesTable,
              GovernorLeaseRow
            >,
          ),
          GovernorLeaseRow,
          PrefetchHooks Function()
        > {
  $$GovernorLeasesTableTableManager(
    _$StorizeDatabase db,
    $GovernorLeasesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GovernorLeasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GovernorLeasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GovernorLeasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> loginAccountId = const Value.absent(),
                Value<String> holder = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<double> tokens = const Value.absent(),
                Value<DateTime> lastRefillAt = const Value.absent(),
                Value<DateTime?> backoffUntil = const Value.absent(),
                Value<double> backoffMultiplier = const Value.absent(),
              }) => GovernorLeasesCompanion(
                loginAccountId: loginAccountId,
                holder: holder,
                expiresAt: expiresAt,
                tokens: tokens,
                lastRefillAt: lastRefillAt,
                backoffUntil: backoffUntil,
                backoffMultiplier: backoffMultiplier,
              ),
          createCompanionCallback:
              ({
                Value<int> loginAccountId = const Value.absent(),
                required String holder,
                required DateTime expiresAt,
                required double tokens,
                required DateTime lastRefillAt,
                Value<DateTime?> backoffUntil = const Value.absent(),
                Value<double> backoffMultiplier = const Value.absent(),
              }) => GovernorLeasesCompanion.insert(
                loginAccountId: loginAccountId,
                holder: holder,
                expiresAt: expiresAt,
                tokens: tokens,
                lastRefillAt: lastRefillAt,
                backoffUntil: backoffUntil,
                backoffMultiplier: backoffMultiplier,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GovernorLeasesTable, GovernorLeaseRow>(table),
                  BaseReferences<
                    _$StorizeDatabase,
                    $GovernorLeasesTable,
                    GovernorLeaseRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GovernorLeasesTableProcessedTableManager =
    ProcessedTableManager<
      _$StorizeDatabase,
      $GovernorLeasesTable,
      GovernorLeaseRow,
      $$GovernorLeasesTableFilterComposer,
      $$GovernorLeasesTableOrderingComposer,
      $$GovernorLeasesTableAnnotationComposer,
      $$GovernorLeasesTableCreateCompanionBuilder,
      $$GovernorLeasesTableUpdateCompanionBuilder,
      (
        GovernorLeaseRow,
        BaseReferences<
          _$StorizeDatabase,
          $GovernorLeasesTable,
          GovernorLeaseRow
        >,
      ),
      GovernorLeaseRow,
      PrefetchHooks Function()
    >;

class $StorizeDatabaseManager {
  final _$StorizeDatabase _db;
  $StorizeDatabaseManager(this._db);
  $$LoginAccountsTableTableManager get loginAccounts =>
      $$LoginAccountsTableTableManager(_db, _db.loginAccounts);
  $$TargetsTableTableManager get targets =>
      $$TargetsTableTableManager(_db, _db.targets);
  $$ContentsTableTableManager get contents =>
      $$ContentsTableTableManager(_db, _db.contents);
  $$MediaFilesTableTableManager get mediaFiles =>
      $$MediaFilesTableTableManager(_db, _db.mediaFiles);
  $$CheckRunsTableTableManager get checkRuns =>
      $$CheckRunsTableTableManager(_db, _db.checkRuns);
  $$ActivityEventsTableTableManager get activityEvents =>
      $$ActivityEventsTableTableManager(_db, _db.activityEvents);
  $$GovernorLeasesTableTableManager get governorLeases =>
      $$GovernorLeasesTableTableManager(_db, _db.governorLeases);
}
