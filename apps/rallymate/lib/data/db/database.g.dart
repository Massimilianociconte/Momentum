// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $PlayersTable extends Players with TableInfo<$PlayersTable, Player> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nicknameMeta = const VerificationMeta(
    'nickname',
  );
  @override
  late final GeneratedColumn<String> nickname = GeneratedColumn<String>(
    'nickname',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _isMeMeta = const VerificationMeta('isMe');
  @override
  late final GeneratedColumn<bool> isMe = GeneratedColumn<bool>(
    'is_me',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_me" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dominantHandMeta = const VerificationMeta(
    'dominantHand',
  );
  @override
  late final GeneratedColumn<String> dominantHand = GeneratedColumn<String>(
    'dominant_hand',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('RIGHT'),
  );
  static const VerificationMeta _preferredRoleMeta = const VerificationMeta(
    'preferredRole',
  );
  @override
  late final GeneratedColumn<String> preferredRole = GeneratedColumn<String>(
    'preferred_role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('UNDEFINED'),
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<String> level = GeneratedColumn<String>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('INTERMEDIATE'),
  );
  static const VerificationMeta _goalMeta = const VerificationMeta('goal');
  @override
  late final GeneratedColumn<String> goal = GeneratedColumn<String>(
    'goal',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _clubsMeta = const VerificationMeta('clubs');
  @override
  late final GeneratedColumn<String> clubs = GeneratedColumn<String>(
    'clubs',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _bioMeta = const VerificationMeta('bio');
  @override
  late final GeneratedColumn<String> bio = GeneratedColumn<String>(
    'bio',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _homeAreaMeta = const VerificationMeta(
    'homeArea',
  );
  @override
  late final GeneratedColumn<String> homeArea = GeneratedColumn<String>(
    'home_area',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _preferredSideMeta = const VerificationMeta(
    'preferredSide',
  );
  @override
  late final GeneratedColumn<String> preferredSide = GeneratedColumn<String>(
    'preferred_side',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('UNDEFINED'),
  );
  static const VerificationMeta _preferredTimeMeta = const VerificationMeta(
    'preferredTime',
  );
  @override
  late final GeneratedColumn<String> preferredTime = GeneratedColumn<String>(
    'preferred_time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _playFrequencyMeta = const VerificationMeta(
    'playFrequency',
  );
  @override
  late final GeneratedColumn<String> playFrequency = GeneratedColumn<String>(
    'play_frequency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _privacyMeta = const VerificationMeta(
    'privacy',
  );
  @override
  late final GeneratedColumn<String> privacy = GeneratedColumn<String>(
    'privacy',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('PRIVATE'),
  );
  static const VerificationMeta _avatarLocalPathMeta = const VerificationMeta(
    'avatarLocalPath',
  );
  @override
  late final GeneratedColumn<String> avatarLocalPath = GeneratedColumn<String>(
    'avatar_local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _avatarCloudPathMeta = const VerificationMeta(
    'avatarCloudPath',
  );
  @override
  late final GeneratedColumn<String> avatarCloudPath = GeneratedColumn<String>(
    'avatar_cloud_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _avatarVersionMeta = const VerificationMeta(
    'avatarVersion',
  );
  @override
  late final GeneratedColumn<int> avatarVersion = GeneratedColumn<int>(
    'avatar_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _avatarCloudVersionMeta =
      const VerificationMeta('avatarCloudVersion');
  @override
  late final GeneratedColumn<int> avatarCloudVersion = GeneratedColumn<int>(
    'avatar_cloud_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _availabilityMeta = const VerificationMeta(
    'availability',
  );
  @override
  late final GeneratedColumn<String> availability = GeneratedColumn<String>(
    'availability',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('FLEX'),
  );
  static const VerificationMeta _styleTagsMeta = const VerificationMeta(
    'styleTags',
  );
  @override
  late final GeneratedColumn<String> styleTags = GeneratedColumn<String>(
    'style_tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    nickname,
    isMe,
    dominantHand,
    preferredRole,
    level,
    goal,
    clubs,
    bio,
    homeArea,
    preferredSide,
    preferredTime,
    playFrequency,
    privacy,
    avatarLocalPath,
    avatarCloudPath,
    avatarVersion,
    avatarCloudVersion,
    availability,
    styleTags,
    createdAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'players';
  @override
  VerificationContext validateIntegrity(
    Insertable<Player> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('nickname')) {
      context.handle(
        _nicknameMeta,
        nickname.isAcceptableOrUnknown(data['nickname']!, _nicknameMeta),
      );
    }
    if (data.containsKey('is_me')) {
      context.handle(
        _isMeMeta,
        isMe.isAcceptableOrUnknown(data['is_me']!, _isMeMeta),
      );
    }
    if (data.containsKey('dominant_hand')) {
      context.handle(
        _dominantHandMeta,
        dominantHand.isAcceptableOrUnknown(
          data['dominant_hand']!,
          _dominantHandMeta,
        ),
      );
    }
    if (data.containsKey('preferred_role')) {
      context.handle(
        _preferredRoleMeta,
        preferredRole.isAcceptableOrUnknown(
          data['preferred_role']!,
          _preferredRoleMeta,
        ),
      );
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    }
    if (data.containsKey('goal')) {
      context.handle(
        _goalMeta,
        goal.isAcceptableOrUnknown(data['goal']!, _goalMeta),
      );
    }
    if (data.containsKey('clubs')) {
      context.handle(
        _clubsMeta,
        clubs.isAcceptableOrUnknown(data['clubs']!, _clubsMeta),
      );
    }
    if (data.containsKey('bio')) {
      context.handle(
        _bioMeta,
        bio.isAcceptableOrUnknown(data['bio']!, _bioMeta),
      );
    }
    if (data.containsKey('home_area')) {
      context.handle(
        _homeAreaMeta,
        homeArea.isAcceptableOrUnknown(data['home_area']!, _homeAreaMeta),
      );
    }
    if (data.containsKey('preferred_side')) {
      context.handle(
        _preferredSideMeta,
        preferredSide.isAcceptableOrUnknown(
          data['preferred_side']!,
          _preferredSideMeta,
        ),
      );
    }
    if (data.containsKey('preferred_time')) {
      context.handle(
        _preferredTimeMeta,
        preferredTime.isAcceptableOrUnknown(
          data['preferred_time']!,
          _preferredTimeMeta,
        ),
      );
    }
    if (data.containsKey('play_frequency')) {
      context.handle(
        _playFrequencyMeta,
        playFrequency.isAcceptableOrUnknown(
          data['play_frequency']!,
          _playFrequencyMeta,
        ),
      );
    }
    if (data.containsKey('privacy')) {
      context.handle(
        _privacyMeta,
        privacy.isAcceptableOrUnknown(data['privacy']!, _privacyMeta),
      );
    }
    if (data.containsKey('avatar_local_path')) {
      context.handle(
        _avatarLocalPathMeta,
        avatarLocalPath.isAcceptableOrUnknown(
          data['avatar_local_path']!,
          _avatarLocalPathMeta,
        ),
      );
    }
    if (data.containsKey('avatar_cloud_path')) {
      context.handle(
        _avatarCloudPathMeta,
        avatarCloudPath.isAcceptableOrUnknown(
          data['avatar_cloud_path']!,
          _avatarCloudPathMeta,
        ),
      );
    }
    if (data.containsKey('avatar_version')) {
      context.handle(
        _avatarVersionMeta,
        avatarVersion.isAcceptableOrUnknown(
          data['avatar_version']!,
          _avatarVersionMeta,
        ),
      );
    }
    if (data.containsKey('avatar_cloud_version')) {
      context.handle(
        _avatarCloudVersionMeta,
        avatarCloudVersion.isAcceptableOrUnknown(
          data['avatar_cloud_version']!,
          _avatarCloudVersionMeta,
        ),
      );
    }
    if (data.containsKey('availability')) {
      context.handle(
        _availabilityMeta,
        availability.isAcceptableOrUnknown(
          data['availability']!,
          _availabilityMeta,
        ),
      );
    }
    if (data.containsKey('style_tags')) {
      context.handle(
        _styleTagsMeta,
        styleTags.isAcceptableOrUnknown(data['style_tags']!, _styleTagsMeta),
      );
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Player map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Player(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      nickname: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nickname'],
      )!,
      isMe: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_me'],
      )!,
      dominantHand: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dominant_hand'],
      )!,
      preferredRole: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferred_role'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}level'],
      )!,
      goal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal'],
      )!,
      clubs: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}clubs'],
      )!,
      bio: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bio'],
      )!,
      homeArea: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}home_area'],
      )!,
      preferredSide: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferred_side'],
      )!,
      preferredTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferred_time'],
      )!,
      playFrequency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}play_frequency'],
      )!,
      privacy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}privacy'],
      )!,
      avatarLocalPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_local_path'],
      ),
      avatarCloudPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_cloud_path'],
      ),
      avatarVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}avatar_version'],
      )!,
      avatarCloudVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}avatar_cloud_version'],
      )!,
      availability: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}availability'],
      )!,
      styleTags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}style_tags'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
    );
  }

  @override
  $PlayersTable createAlias(String alias) {
    return $PlayersTable(attachedDatabase, alias);
  }
}

class Player extends DataClass implements Insertable<Player> {
  final String id;
  final String name;
  final String nickname;
  final bool isMe;
  final String dominantHand;
  final String preferredRole;
  final String level;
  final String goal;
  final String clubs;
  final String bio;
  final String homeArea;
  final String preferredSide;
  final String preferredTime;
  final String playFrequency;
  final String privacy;

  /// Processed square portrait inside app support. Free accounts keep this
  /// device-local; paid cloud backup can mirror it to private Storage.
  final String? avatarLocalPath;
  final String? avatarCloudPath;
  final int avatarVersion;
  final int avatarCloudVersion;

  /// Disponibilità matchmaking: TODAY | EVENING | WEEKEND | FLEX | HIDDEN.
  final String availability;

  /// Tag stile di gioco (csv): control, attack, defense, flex.
  final String styleTags;
  final int createdAtMs;
  const Player({
    required this.id,
    required this.name,
    required this.nickname,
    required this.isMe,
    required this.dominantHand,
    required this.preferredRole,
    required this.level,
    required this.goal,
    required this.clubs,
    required this.bio,
    required this.homeArea,
    required this.preferredSide,
    required this.preferredTime,
    required this.playFrequency,
    required this.privacy,
    this.avatarLocalPath,
    this.avatarCloudPath,
    required this.avatarVersion,
    required this.avatarCloudVersion,
    required this.availability,
    required this.styleTags,
    required this.createdAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['nickname'] = Variable<String>(nickname);
    map['is_me'] = Variable<bool>(isMe);
    map['dominant_hand'] = Variable<String>(dominantHand);
    map['preferred_role'] = Variable<String>(preferredRole);
    map['level'] = Variable<String>(level);
    map['goal'] = Variable<String>(goal);
    map['clubs'] = Variable<String>(clubs);
    map['bio'] = Variable<String>(bio);
    map['home_area'] = Variable<String>(homeArea);
    map['preferred_side'] = Variable<String>(preferredSide);
    map['preferred_time'] = Variable<String>(preferredTime);
    map['play_frequency'] = Variable<String>(playFrequency);
    map['privacy'] = Variable<String>(privacy);
    if (!nullToAbsent || avatarLocalPath != null) {
      map['avatar_local_path'] = Variable<String>(avatarLocalPath);
    }
    if (!nullToAbsent || avatarCloudPath != null) {
      map['avatar_cloud_path'] = Variable<String>(avatarCloudPath);
    }
    map['avatar_version'] = Variable<int>(avatarVersion);
    map['avatar_cloud_version'] = Variable<int>(avatarCloudVersion);
    map['availability'] = Variable<String>(availability);
    map['style_tags'] = Variable<String>(styleTags);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    return map;
  }

  PlayersCompanion toCompanion(bool nullToAbsent) {
    return PlayersCompanion(
      id: Value(id),
      name: Value(name),
      nickname: Value(nickname),
      isMe: Value(isMe),
      dominantHand: Value(dominantHand),
      preferredRole: Value(preferredRole),
      level: Value(level),
      goal: Value(goal),
      clubs: Value(clubs),
      bio: Value(bio),
      homeArea: Value(homeArea),
      preferredSide: Value(preferredSide),
      preferredTime: Value(preferredTime),
      playFrequency: Value(playFrequency),
      privacy: Value(privacy),
      avatarLocalPath: avatarLocalPath == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarLocalPath),
      avatarCloudPath: avatarCloudPath == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarCloudPath),
      avatarVersion: Value(avatarVersion),
      avatarCloudVersion: Value(avatarCloudVersion),
      availability: Value(availability),
      styleTags: Value(styleTags),
      createdAtMs: Value(createdAtMs),
    );
  }

  factory Player.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Player(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      nickname: serializer.fromJson<String>(json['nickname']),
      isMe: serializer.fromJson<bool>(json['isMe']),
      dominantHand: serializer.fromJson<String>(json['dominantHand']),
      preferredRole: serializer.fromJson<String>(json['preferredRole']),
      level: serializer.fromJson<String>(json['level']),
      goal: serializer.fromJson<String>(json['goal']),
      clubs: serializer.fromJson<String>(json['clubs']),
      bio: serializer.fromJson<String>(json['bio']),
      homeArea: serializer.fromJson<String>(json['homeArea']),
      preferredSide: serializer.fromJson<String>(json['preferredSide']),
      preferredTime: serializer.fromJson<String>(json['preferredTime']),
      playFrequency: serializer.fromJson<String>(json['playFrequency']),
      privacy: serializer.fromJson<String>(json['privacy']),
      avatarLocalPath: serializer.fromJson<String?>(json['avatarLocalPath']),
      avatarCloudPath: serializer.fromJson<String?>(json['avatarCloudPath']),
      avatarVersion: serializer.fromJson<int>(json['avatarVersion']),
      avatarCloudVersion: serializer.fromJson<int>(json['avatarCloudVersion']),
      availability: serializer.fromJson<String>(json['availability']),
      styleTags: serializer.fromJson<String>(json['styleTags']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'nickname': serializer.toJson<String>(nickname),
      'isMe': serializer.toJson<bool>(isMe),
      'dominantHand': serializer.toJson<String>(dominantHand),
      'preferredRole': serializer.toJson<String>(preferredRole),
      'level': serializer.toJson<String>(level),
      'goal': serializer.toJson<String>(goal),
      'clubs': serializer.toJson<String>(clubs),
      'bio': serializer.toJson<String>(bio),
      'homeArea': serializer.toJson<String>(homeArea),
      'preferredSide': serializer.toJson<String>(preferredSide),
      'preferredTime': serializer.toJson<String>(preferredTime),
      'playFrequency': serializer.toJson<String>(playFrequency),
      'privacy': serializer.toJson<String>(privacy),
      'avatarLocalPath': serializer.toJson<String?>(avatarLocalPath),
      'avatarCloudPath': serializer.toJson<String?>(avatarCloudPath),
      'avatarVersion': serializer.toJson<int>(avatarVersion),
      'avatarCloudVersion': serializer.toJson<int>(avatarCloudVersion),
      'availability': serializer.toJson<String>(availability),
      'styleTags': serializer.toJson<String>(styleTags),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
    };
  }

  Player copyWith({
    String? id,
    String? name,
    String? nickname,
    bool? isMe,
    String? dominantHand,
    String? preferredRole,
    String? level,
    String? goal,
    String? clubs,
    String? bio,
    String? homeArea,
    String? preferredSide,
    String? preferredTime,
    String? playFrequency,
    String? privacy,
    Value<String?> avatarLocalPath = const Value.absent(),
    Value<String?> avatarCloudPath = const Value.absent(),
    int? avatarVersion,
    int? avatarCloudVersion,
    String? availability,
    String? styleTags,
    int? createdAtMs,
  }) => Player(
    id: id ?? this.id,
    name: name ?? this.name,
    nickname: nickname ?? this.nickname,
    isMe: isMe ?? this.isMe,
    dominantHand: dominantHand ?? this.dominantHand,
    preferredRole: preferredRole ?? this.preferredRole,
    level: level ?? this.level,
    goal: goal ?? this.goal,
    clubs: clubs ?? this.clubs,
    bio: bio ?? this.bio,
    homeArea: homeArea ?? this.homeArea,
    preferredSide: preferredSide ?? this.preferredSide,
    preferredTime: preferredTime ?? this.preferredTime,
    playFrequency: playFrequency ?? this.playFrequency,
    privacy: privacy ?? this.privacy,
    avatarLocalPath: avatarLocalPath.present
        ? avatarLocalPath.value
        : this.avatarLocalPath,
    avatarCloudPath: avatarCloudPath.present
        ? avatarCloudPath.value
        : this.avatarCloudPath,
    avatarVersion: avatarVersion ?? this.avatarVersion,
    avatarCloudVersion: avatarCloudVersion ?? this.avatarCloudVersion,
    availability: availability ?? this.availability,
    styleTags: styleTags ?? this.styleTags,
    createdAtMs: createdAtMs ?? this.createdAtMs,
  );
  Player copyWithCompanion(PlayersCompanion data) {
    return Player(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      nickname: data.nickname.present ? data.nickname.value : this.nickname,
      isMe: data.isMe.present ? data.isMe.value : this.isMe,
      dominantHand: data.dominantHand.present
          ? data.dominantHand.value
          : this.dominantHand,
      preferredRole: data.preferredRole.present
          ? data.preferredRole.value
          : this.preferredRole,
      level: data.level.present ? data.level.value : this.level,
      goal: data.goal.present ? data.goal.value : this.goal,
      clubs: data.clubs.present ? data.clubs.value : this.clubs,
      bio: data.bio.present ? data.bio.value : this.bio,
      homeArea: data.homeArea.present ? data.homeArea.value : this.homeArea,
      preferredSide: data.preferredSide.present
          ? data.preferredSide.value
          : this.preferredSide,
      preferredTime: data.preferredTime.present
          ? data.preferredTime.value
          : this.preferredTime,
      playFrequency: data.playFrequency.present
          ? data.playFrequency.value
          : this.playFrequency,
      privacy: data.privacy.present ? data.privacy.value : this.privacy,
      avatarLocalPath: data.avatarLocalPath.present
          ? data.avatarLocalPath.value
          : this.avatarLocalPath,
      avatarCloudPath: data.avatarCloudPath.present
          ? data.avatarCloudPath.value
          : this.avatarCloudPath,
      avatarVersion: data.avatarVersion.present
          ? data.avatarVersion.value
          : this.avatarVersion,
      avatarCloudVersion: data.avatarCloudVersion.present
          ? data.avatarCloudVersion.value
          : this.avatarCloudVersion,
      availability: data.availability.present
          ? data.availability.value
          : this.availability,
      styleTags: data.styleTags.present ? data.styleTags.value : this.styleTags,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Player(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('nickname: $nickname, ')
          ..write('isMe: $isMe, ')
          ..write('dominantHand: $dominantHand, ')
          ..write('preferredRole: $preferredRole, ')
          ..write('level: $level, ')
          ..write('goal: $goal, ')
          ..write('clubs: $clubs, ')
          ..write('bio: $bio, ')
          ..write('homeArea: $homeArea, ')
          ..write('preferredSide: $preferredSide, ')
          ..write('preferredTime: $preferredTime, ')
          ..write('playFrequency: $playFrequency, ')
          ..write('privacy: $privacy, ')
          ..write('avatarLocalPath: $avatarLocalPath, ')
          ..write('avatarCloudPath: $avatarCloudPath, ')
          ..write('avatarVersion: $avatarVersion, ')
          ..write('avatarCloudVersion: $avatarCloudVersion, ')
          ..write('availability: $availability, ')
          ..write('styleTags: $styleTags, ')
          ..write('createdAtMs: $createdAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    nickname,
    isMe,
    dominantHand,
    preferredRole,
    level,
    goal,
    clubs,
    bio,
    homeArea,
    preferredSide,
    preferredTime,
    playFrequency,
    privacy,
    avatarLocalPath,
    avatarCloudPath,
    avatarVersion,
    avatarCloudVersion,
    availability,
    styleTags,
    createdAtMs,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Player &&
          other.id == this.id &&
          other.name == this.name &&
          other.nickname == this.nickname &&
          other.isMe == this.isMe &&
          other.dominantHand == this.dominantHand &&
          other.preferredRole == this.preferredRole &&
          other.level == this.level &&
          other.goal == this.goal &&
          other.clubs == this.clubs &&
          other.bio == this.bio &&
          other.homeArea == this.homeArea &&
          other.preferredSide == this.preferredSide &&
          other.preferredTime == this.preferredTime &&
          other.playFrequency == this.playFrequency &&
          other.privacy == this.privacy &&
          other.avatarLocalPath == this.avatarLocalPath &&
          other.avatarCloudPath == this.avatarCloudPath &&
          other.avatarVersion == this.avatarVersion &&
          other.avatarCloudVersion == this.avatarCloudVersion &&
          other.availability == this.availability &&
          other.styleTags == this.styleTags &&
          other.createdAtMs == this.createdAtMs);
}

class PlayersCompanion extends UpdateCompanion<Player> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> nickname;
  final Value<bool> isMe;
  final Value<String> dominantHand;
  final Value<String> preferredRole;
  final Value<String> level;
  final Value<String> goal;
  final Value<String> clubs;
  final Value<String> bio;
  final Value<String> homeArea;
  final Value<String> preferredSide;
  final Value<String> preferredTime;
  final Value<String> playFrequency;
  final Value<String> privacy;
  final Value<String?> avatarLocalPath;
  final Value<String?> avatarCloudPath;
  final Value<int> avatarVersion;
  final Value<int> avatarCloudVersion;
  final Value<String> availability;
  final Value<String> styleTags;
  final Value<int> createdAtMs;
  final Value<int> rowid;
  const PlayersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.nickname = const Value.absent(),
    this.isMe = const Value.absent(),
    this.dominantHand = const Value.absent(),
    this.preferredRole = const Value.absent(),
    this.level = const Value.absent(),
    this.goal = const Value.absent(),
    this.clubs = const Value.absent(),
    this.bio = const Value.absent(),
    this.homeArea = const Value.absent(),
    this.preferredSide = const Value.absent(),
    this.preferredTime = const Value.absent(),
    this.playFrequency = const Value.absent(),
    this.privacy = const Value.absent(),
    this.avatarLocalPath = const Value.absent(),
    this.avatarCloudPath = const Value.absent(),
    this.avatarVersion = const Value.absent(),
    this.avatarCloudVersion = const Value.absent(),
    this.availability = const Value.absent(),
    this.styleTags = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlayersCompanion.insert({
    required String id,
    required String name,
    this.nickname = const Value.absent(),
    this.isMe = const Value.absent(),
    this.dominantHand = const Value.absent(),
    this.preferredRole = const Value.absent(),
    this.level = const Value.absent(),
    this.goal = const Value.absent(),
    this.clubs = const Value.absent(),
    this.bio = const Value.absent(),
    this.homeArea = const Value.absent(),
    this.preferredSide = const Value.absent(),
    this.preferredTime = const Value.absent(),
    this.playFrequency = const Value.absent(),
    this.privacy = const Value.absent(),
    this.avatarLocalPath = const Value.absent(),
    this.avatarCloudPath = const Value.absent(),
    this.avatarVersion = const Value.absent(),
    this.avatarCloudVersion = const Value.absent(),
    this.availability = const Value.absent(),
    this.styleTags = const Value.absent(),
    required int createdAtMs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAtMs = Value(createdAtMs);
  static Insertable<Player> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? nickname,
    Expression<bool>? isMe,
    Expression<String>? dominantHand,
    Expression<String>? preferredRole,
    Expression<String>? level,
    Expression<String>? goal,
    Expression<String>? clubs,
    Expression<String>? bio,
    Expression<String>? homeArea,
    Expression<String>? preferredSide,
    Expression<String>? preferredTime,
    Expression<String>? playFrequency,
    Expression<String>? privacy,
    Expression<String>? avatarLocalPath,
    Expression<String>? avatarCloudPath,
    Expression<int>? avatarVersion,
    Expression<int>? avatarCloudVersion,
    Expression<String>? availability,
    Expression<String>? styleTags,
    Expression<int>? createdAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (nickname != null) 'nickname': nickname,
      if (isMe != null) 'is_me': isMe,
      if (dominantHand != null) 'dominant_hand': dominantHand,
      if (preferredRole != null) 'preferred_role': preferredRole,
      if (level != null) 'level': level,
      if (goal != null) 'goal': goal,
      if (clubs != null) 'clubs': clubs,
      if (bio != null) 'bio': bio,
      if (homeArea != null) 'home_area': homeArea,
      if (preferredSide != null) 'preferred_side': preferredSide,
      if (preferredTime != null) 'preferred_time': preferredTime,
      if (playFrequency != null) 'play_frequency': playFrequency,
      if (privacy != null) 'privacy': privacy,
      if (avatarLocalPath != null) 'avatar_local_path': avatarLocalPath,
      if (avatarCloudPath != null) 'avatar_cloud_path': avatarCloudPath,
      if (avatarVersion != null) 'avatar_version': avatarVersion,
      if (avatarCloudVersion != null)
        'avatar_cloud_version': avatarCloudVersion,
      if (availability != null) 'availability': availability,
      if (styleTags != null) 'style_tags': styleTags,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlayersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? nickname,
    Value<bool>? isMe,
    Value<String>? dominantHand,
    Value<String>? preferredRole,
    Value<String>? level,
    Value<String>? goal,
    Value<String>? clubs,
    Value<String>? bio,
    Value<String>? homeArea,
    Value<String>? preferredSide,
    Value<String>? preferredTime,
    Value<String>? playFrequency,
    Value<String>? privacy,
    Value<String?>? avatarLocalPath,
    Value<String?>? avatarCloudPath,
    Value<int>? avatarVersion,
    Value<int>? avatarCloudVersion,
    Value<String>? availability,
    Value<String>? styleTags,
    Value<int>? createdAtMs,
    Value<int>? rowid,
  }) {
    return PlayersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      nickname: nickname ?? this.nickname,
      isMe: isMe ?? this.isMe,
      dominantHand: dominantHand ?? this.dominantHand,
      preferredRole: preferredRole ?? this.preferredRole,
      level: level ?? this.level,
      goal: goal ?? this.goal,
      clubs: clubs ?? this.clubs,
      bio: bio ?? this.bio,
      homeArea: homeArea ?? this.homeArea,
      preferredSide: preferredSide ?? this.preferredSide,
      preferredTime: preferredTime ?? this.preferredTime,
      playFrequency: playFrequency ?? this.playFrequency,
      privacy: privacy ?? this.privacy,
      avatarLocalPath: avatarLocalPath ?? this.avatarLocalPath,
      avatarCloudPath: avatarCloudPath ?? this.avatarCloudPath,
      avatarVersion: avatarVersion ?? this.avatarVersion,
      avatarCloudVersion: avatarCloudVersion ?? this.avatarCloudVersion,
      availability: availability ?? this.availability,
      styleTags: styleTags ?? this.styleTags,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (nickname.present) {
      map['nickname'] = Variable<String>(nickname.value);
    }
    if (isMe.present) {
      map['is_me'] = Variable<bool>(isMe.value);
    }
    if (dominantHand.present) {
      map['dominant_hand'] = Variable<String>(dominantHand.value);
    }
    if (preferredRole.present) {
      map['preferred_role'] = Variable<String>(preferredRole.value);
    }
    if (level.present) {
      map['level'] = Variable<String>(level.value);
    }
    if (goal.present) {
      map['goal'] = Variable<String>(goal.value);
    }
    if (clubs.present) {
      map['clubs'] = Variable<String>(clubs.value);
    }
    if (bio.present) {
      map['bio'] = Variable<String>(bio.value);
    }
    if (homeArea.present) {
      map['home_area'] = Variable<String>(homeArea.value);
    }
    if (preferredSide.present) {
      map['preferred_side'] = Variable<String>(preferredSide.value);
    }
    if (preferredTime.present) {
      map['preferred_time'] = Variable<String>(preferredTime.value);
    }
    if (playFrequency.present) {
      map['play_frequency'] = Variable<String>(playFrequency.value);
    }
    if (privacy.present) {
      map['privacy'] = Variable<String>(privacy.value);
    }
    if (avatarLocalPath.present) {
      map['avatar_local_path'] = Variable<String>(avatarLocalPath.value);
    }
    if (avatarCloudPath.present) {
      map['avatar_cloud_path'] = Variable<String>(avatarCloudPath.value);
    }
    if (avatarVersion.present) {
      map['avatar_version'] = Variable<int>(avatarVersion.value);
    }
    if (avatarCloudVersion.present) {
      map['avatar_cloud_version'] = Variable<int>(avatarCloudVersion.value);
    }
    if (availability.present) {
      map['availability'] = Variable<String>(availability.value);
    }
    if (styleTags.present) {
      map['style_tags'] = Variable<String>(styleTags.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('nickname: $nickname, ')
          ..write('isMe: $isMe, ')
          ..write('dominantHand: $dominantHand, ')
          ..write('preferredRole: $preferredRole, ')
          ..write('level: $level, ')
          ..write('goal: $goal, ')
          ..write('clubs: $clubs, ')
          ..write('bio: $bio, ')
          ..write('homeArea: $homeArea, ')
          ..write('preferredSide: $preferredSide, ')
          ..write('preferredTime: $preferredTime, ')
          ..write('playFrequency: $playFrequency, ')
          ..write('privacy: $privacy, ')
          ..write('avatarLocalPath: $avatarLocalPath, ')
          ..write('avatarCloudPath: $avatarCloudPath, ')
          ..write('avatarVersion: $avatarVersion, ')
          ..write('avatarCloudVersion: $avatarCloudVersion, ')
          ..write('availability: $availability, ')
          ..write('styleTags: $styleTags, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TeamsTable extends Teams with TableInfo<$TeamsTable, Team> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TeamsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playerAIdMeta = const VerificationMeta(
    'playerAId',
  );
  @override
  late final GeneratedColumn<String> playerAId = GeneratedColumn<String>(
    'player_a_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES players (id)',
    ),
  );
  static const VerificationMeta _playerBIdMeta = const VerificationMeta(
    'playerBId',
  );
  @override
  late final GeneratedColumn<String> playerBId = GeneratedColumn<String>(
    'player_b_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES players (id)',
    ),
  );
  static const VerificationMeta _playerBNameMeta = const VerificationMeta(
    'playerBName',
  );
  @override
  late final GeneratedColumn<String> playerBName = GeneratedColumn<String>(
    'player_b_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _roleAMeta = const VerificationMeta('roleA');
  @override
  late final GeneratedColumn<String> roleA = GeneratedColumn<String>(
    'role_a',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('UNDEFINED'),
  );
  static const VerificationMeta _roleBMeta = const VerificationMeta('roleB');
  @override
  late final GeneratedColumn<String> roleB = GeneratedColumn<String>(
    'role_b',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('UNDEFINED'),
  );
  static const VerificationMeta _tacticalNotesMeta = const VerificationMeta(
    'tacticalNotes',
  );
  @override
  late final GeneratedColumn<String> tacticalNotes = GeneratedColumn<String>(
    'tactical_notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _goalsMeta = const VerificationMeta('goals');
  @override
  late final GeneratedColumn<String> goals = GeneratedColumn<String>(
    'goals',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _imageLocalPathMeta = const VerificationMeta(
    'imageLocalPath',
  );
  @override
  late final GeneratedColumn<String> imageLocalPath = GeneratedColumn<String>(
    'image_local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageCloudPathMeta = const VerificationMeta(
    'imageCloudPath',
  );
  @override
  late final GeneratedColumn<String> imageCloudPath = GeneratedColumn<String>(
    'image_cloud_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageVersionMeta = const VerificationMeta(
    'imageVersion',
  );
  @override
  late final GeneratedColumn<int> imageVersion = GeneratedColumn<int>(
    'image_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _imageCloudVersionMeta = const VerificationMeta(
    'imageCloudVersion',
  );
  @override
  late final GeneratedColumn<int> imageCloudVersion = GeneratedColumn<int>(
    'image_cloud_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _scoringStyleMeta = const VerificationMeta(
    'scoringStyle',
  );
  @override
  late final GeneratedColumn<String> scoringStyle = GeneratedColumn<String>(
    'scoring_style',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('AUTO'),
  );
  static const VerificationMeta _colorArgbMeta = const VerificationMeta(
    'colorArgb',
  );
  @override
  late final GeneratedColumn<int> colorArgb = GeneratedColumn<int>(
    'color_argb',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xFFC8F135),
  );
  static const VerificationMeta _cloudIdMeta = const VerificationMeta(
    'cloudId',
  );
  @override
  late final GeneratedColumn<String> cloudId = GeneratedColumn<String>(
    'cloud_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cloudRoleMeta = const VerificationMeta(
    'cloudRole',
  );
  @override
  late final GeneratedColumn<String> cloudRole = GeneratedColumn<String>(
    'cloud_role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('LOCAL'),
  );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    playerAId,
    playerBId,
    playerBName,
    roleA,
    roleB,
    tacticalNotes,
    goals,
    imageLocalPath,
    imageCloudPath,
    imageVersion,
    imageCloudVersion,
    scoringStyle,
    colorArgb,
    cloudId,
    cloudRole,
    archived,
    createdAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'teams';
  @override
  VerificationContext validateIntegrity(
    Insertable<Team> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('player_a_id')) {
      context.handle(
        _playerAIdMeta,
        playerAId.isAcceptableOrUnknown(data['player_a_id']!, _playerAIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playerAIdMeta);
    }
    if (data.containsKey('player_b_id')) {
      context.handle(
        _playerBIdMeta,
        playerBId.isAcceptableOrUnknown(data['player_b_id']!, _playerBIdMeta),
      );
    }
    if (data.containsKey('player_b_name')) {
      context.handle(
        _playerBNameMeta,
        playerBName.isAcceptableOrUnknown(
          data['player_b_name']!,
          _playerBNameMeta,
        ),
      );
    }
    if (data.containsKey('role_a')) {
      context.handle(
        _roleAMeta,
        roleA.isAcceptableOrUnknown(data['role_a']!, _roleAMeta),
      );
    }
    if (data.containsKey('role_b')) {
      context.handle(
        _roleBMeta,
        roleB.isAcceptableOrUnknown(data['role_b']!, _roleBMeta),
      );
    }
    if (data.containsKey('tactical_notes')) {
      context.handle(
        _tacticalNotesMeta,
        tacticalNotes.isAcceptableOrUnknown(
          data['tactical_notes']!,
          _tacticalNotesMeta,
        ),
      );
    }
    if (data.containsKey('goals')) {
      context.handle(
        _goalsMeta,
        goals.isAcceptableOrUnknown(data['goals']!, _goalsMeta),
      );
    }
    if (data.containsKey('image_local_path')) {
      context.handle(
        _imageLocalPathMeta,
        imageLocalPath.isAcceptableOrUnknown(
          data['image_local_path']!,
          _imageLocalPathMeta,
        ),
      );
    }
    if (data.containsKey('image_cloud_path')) {
      context.handle(
        _imageCloudPathMeta,
        imageCloudPath.isAcceptableOrUnknown(
          data['image_cloud_path']!,
          _imageCloudPathMeta,
        ),
      );
    }
    if (data.containsKey('image_version')) {
      context.handle(
        _imageVersionMeta,
        imageVersion.isAcceptableOrUnknown(
          data['image_version']!,
          _imageVersionMeta,
        ),
      );
    }
    if (data.containsKey('image_cloud_version')) {
      context.handle(
        _imageCloudVersionMeta,
        imageCloudVersion.isAcceptableOrUnknown(
          data['image_cloud_version']!,
          _imageCloudVersionMeta,
        ),
      );
    }
    if (data.containsKey('scoring_style')) {
      context.handle(
        _scoringStyleMeta,
        scoringStyle.isAcceptableOrUnknown(
          data['scoring_style']!,
          _scoringStyleMeta,
        ),
      );
    }
    if (data.containsKey('color_argb')) {
      context.handle(
        _colorArgbMeta,
        colorArgb.isAcceptableOrUnknown(data['color_argb']!, _colorArgbMeta),
      );
    }
    if (data.containsKey('cloud_id')) {
      context.handle(
        _cloudIdMeta,
        cloudId.isAcceptableOrUnknown(data['cloud_id']!, _cloudIdMeta),
      );
    }
    if (data.containsKey('cloud_role')) {
      context.handle(
        _cloudRoleMeta,
        cloudRole.isAcceptableOrUnknown(data['cloud_role']!, _cloudRoleMeta),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Team map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Team(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      playerAId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_a_id'],
      )!,
      playerBId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_b_id'],
      ),
      playerBName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_b_name'],
      )!,
      roleA: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role_a'],
      )!,
      roleB: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role_b'],
      )!,
      tacticalNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tactical_notes'],
      )!,
      goals: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goals'],
      )!,
      imageLocalPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_local_path'],
      ),
      imageCloudPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_cloud_path'],
      ),
      imageVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}image_version'],
      )!,
      imageCloudVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}image_cloud_version'],
      )!,
      scoringStyle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scoring_style'],
      )!,
      colorArgb: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color_argb'],
      )!,
      cloudId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cloud_id'],
      ),
      cloudRole: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cloud_role'],
      )!,
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
    );
  }

  @override
  $TeamsTable createAlias(String alias) {
    return $TeamsTable(attachedDatabase, alias);
  }
}

class Team extends DataClass implements Insertable<Team> {
  final String id;
  final String name;
  final String playerAId;
  final String? playerBId;
  final String playerBName;
  final String roleA;
  final String roleB;
  final String tacticalNotes;
  final String goals;

  /// Processed square image stored inside app support, never an external URI.
  final String? imageLocalPath;

  /// Private Supabase Storage object path. A signed URL is resolved on demand.
  final String? imageCloudPath;
  final int imageVersion;
  final int imageCloudVersion;
  final String scoringStyle;
  final int colorArgb;

  /// Cloud team UUID, created lazily after sign-in; local IDs remain stable.
  final String? cloudId;
  final String cloudRole;
  final bool archived;
  final int createdAtMs;
  const Team({
    required this.id,
    required this.name,
    required this.playerAId,
    this.playerBId,
    required this.playerBName,
    required this.roleA,
    required this.roleB,
    required this.tacticalNotes,
    required this.goals,
    this.imageLocalPath,
    this.imageCloudPath,
    required this.imageVersion,
    required this.imageCloudVersion,
    required this.scoringStyle,
    required this.colorArgb,
    this.cloudId,
    required this.cloudRole,
    required this.archived,
    required this.createdAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['player_a_id'] = Variable<String>(playerAId);
    if (!nullToAbsent || playerBId != null) {
      map['player_b_id'] = Variable<String>(playerBId);
    }
    map['player_b_name'] = Variable<String>(playerBName);
    map['role_a'] = Variable<String>(roleA);
    map['role_b'] = Variable<String>(roleB);
    map['tactical_notes'] = Variable<String>(tacticalNotes);
    map['goals'] = Variable<String>(goals);
    if (!nullToAbsent || imageLocalPath != null) {
      map['image_local_path'] = Variable<String>(imageLocalPath);
    }
    if (!nullToAbsent || imageCloudPath != null) {
      map['image_cloud_path'] = Variable<String>(imageCloudPath);
    }
    map['image_version'] = Variable<int>(imageVersion);
    map['image_cloud_version'] = Variable<int>(imageCloudVersion);
    map['scoring_style'] = Variable<String>(scoringStyle);
    map['color_argb'] = Variable<int>(colorArgb);
    if (!nullToAbsent || cloudId != null) {
      map['cloud_id'] = Variable<String>(cloudId);
    }
    map['cloud_role'] = Variable<String>(cloudRole);
    map['archived'] = Variable<bool>(archived);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    return map;
  }

  TeamsCompanion toCompanion(bool nullToAbsent) {
    return TeamsCompanion(
      id: Value(id),
      name: Value(name),
      playerAId: Value(playerAId),
      playerBId: playerBId == null && nullToAbsent
          ? const Value.absent()
          : Value(playerBId),
      playerBName: Value(playerBName),
      roleA: Value(roleA),
      roleB: Value(roleB),
      tacticalNotes: Value(tacticalNotes),
      goals: Value(goals),
      imageLocalPath: imageLocalPath == null && nullToAbsent
          ? const Value.absent()
          : Value(imageLocalPath),
      imageCloudPath: imageCloudPath == null && nullToAbsent
          ? const Value.absent()
          : Value(imageCloudPath),
      imageVersion: Value(imageVersion),
      imageCloudVersion: Value(imageCloudVersion),
      scoringStyle: Value(scoringStyle),
      colorArgb: Value(colorArgb),
      cloudId: cloudId == null && nullToAbsent
          ? const Value.absent()
          : Value(cloudId),
      cloudRole: Value(cloudRole),
      archived: Value(archived),
      createdAtMs: Value(createdAtMs),
    );
  }

  factory Team.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Team(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      playerAId: serializer.fromJson<String>(json['playerAId']),
      playerBId: serializer.fromJson<String?>(json['playerBId']),
      playerBName: serializer.fromJson<String>(json['playerBName']),
      roleA: serializer.fromJson<String>(json['roleA']),
      roleB: serializer.fromJson<String>(json['roleB']),
      tacticalNotes: serializer.fromJson<String>(json['tacticalNotes']),
      goals: serializer.fromJson<String>(json['goals']),
      imageLocalPath: serializer.fromJson<String?>(json['imageLocalPath']),
      imageCloudPath: serializer.fromJson<String?>(json['imageCloudPath']),
      imageVersion: serializer.fromJson<int>(json['imageVersion']),
      imageCloudVersion: serializer.fromJson<int>(json['imageCloudVersion']),
      scoringStyle: serializer.fromJson<String>(json['scoringStyle']),
      colorArgb: serializer.fromJson<int>(json['colorArgb']),
      cloudId: serializer.fromJson<String?>(json['cloudId']),
      cloudRole: serializer.fromJson<String>(json['cloudRole']),
      archived: serializer.fromJson<bool>(json['archived']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'playerAId': serializer.toJson<String>(playerAId),
      'playerBId': serializer.toJson<String?>(playerBId),
      'playerBName': serializer.toJson<String>(playerBName),
      'roleA': serializer.toJson<String>(roleA),
      'roleB': serializer.toJson<String>(roleB),
      'tacticalNotes': serializer.toJson<String>(tacticalNotes),
      'goals': serializer.toJson<String>(goals),
      'imageLocalPath': serializer.toJson<String?>(imageLocalPath),
      'imageCloudPath': serializer.toJson<String?>(imageCloudPath),
      'imageVersion': serializer.toJson<int>(imageVersion),
      'imageCloudVersion': serializer.toJson<int>(imageCloudVersion),
      'scoringStyle': serializer.toJson<String>(scoringStyle),
      'colorArgb': serializer.toJson<int>(colorArgb),
      'cloudId': serializer.toJson<String?>(cloudId),
      'cloudRole': serializer.toJson<String>(cloudRole),
      'archived': serializer.toJson<bool>(archived),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
    };
  }

  Team copyWith({
    String? id,
    String? name,
    String? playerAId,
    Value<String?> playerBId = const Value.absent(),
    String? playerBName,
    String? roleA,
    String? roleB,
    String? tacticalNotes,
    String? goals,
    Value<String?> imageLocalPath = const Value.absent(),
    Value<String?> imageCloudPath = const Value.absent(),
    int? imageVersion,
    int? imageCloudVersion,
    String? scoringStyle,
    int? colorArgb,
    Value<String?> cloudId = const Value.absent(),
    String? cloudRole,
    bool? archived,
    int? createdAtMs,
  }) => Team(
    id: id ?? this.id,
    name: name ?? this.name,
    playerAId: playerAId ?? this.playerAId,
    playerBId: playerBId.present ? playerBId.value : this.playerBId,
    playerBName: playerBName ?? this.playerBName,
    roleA: roleA ?? this.roleA,
    roleB: roleB ?? this.roleB,
    tacticalNotes: tacticalNotes ?? this.tacticalNotes,
    goals: goals ?? this.goals,
    imageLocalPath: imageLocalPath.present
        ? imageLocalPath.value
        : this.imageLocalPath,
    imageCloudPath: imageCloudPath.present
        ? imageCloudPath.value
        : this.imageCloudPath,
    imageVersion: imageVersion ?? this.imageVersion,
    imageCloudVersion: imageCloudVersion ?? this.imageCloudVersion,
    scoringStyle: scoringStyle ?? this.scoringStyle,
    colorArgb: colorArgb ?? this.colorArgb,
    cloudId: cloudId.present ? cloudId.value : this.cloudId,
    cloudRole: cloudRole ?? this.cloudRole,
    archived: archived ?? this.archived,
    createdAtMs: createdAtMs ?? this.createdAtMs,
  );
  Team copyWithCompanion(TeamsCompanion data) {
    return Team(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      playerAId: data.playerAId.present ? data.playerAId.value : this.playerAId,
      playerBId: data.playerBId.present ? data.playerBId.value : this.playerBId,
      playerBName: data.playerBName.present
          ? data.playerBName.value
          : this.playerBName,
      roleA: data.roleA.present ? data.roleA.value : this.roleA,
      roleB: data.roleB.present ? data.roleB.value : this.roleB,
      tacticalNotes: data.tacticalNotes.present
          ? data.tacticalNotes.value
          : this.tacticalNotes,
      goals: data.goals.present ? data.goals.value : this.goals,
      imageLocalPath: data.imageLocalPath.present
          ? data.imageLocalPath.value
          : this.imageLocalPath,
      imageCloudPath: data.imageCloudPath.present
          ? data.imageCloudPath.value
          : this.imageCloudPath,
      imageVersion: data.imageVersion.present
          ? data.imageVersion.value
          : this.imageVersion,
      imageCloudVersion: data.imageCloudVersion.present
          ? data.imageCloudVersion.value
          : this.imageCloudVersion,
      scoringStyle: data.scoringStyle.present
          ? data.scoringStyle.value
          : this.scoringStyle,
      colorArgb: data.colorArgb.present ? data.colorArgb.value : this.colorArgb,
      cloudId: data.cloudId.present ? data.cloudId.value : this.cloudId,
      cloudRole: data.cloudRole.present ? data.cloudRole.value : this.cloudRole,
      archived: data.archived.present ? data.archived.value : this.archived,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Team(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('playerAId: $playerAId, ')
          ..write('playerBId: $playerBId, ')
          ..write('playerBName: $playerBName, ')
          ..write('roleA: $roleA, ')
          ..write('roleB: $roleB, ')
          ..write('tacticalNotes: $tacticalNotes, ')
          ..write('goals: $goals, ')
          ..write('imageLocalPath: $imageLocalPath, ')
          ..write('imageCloudPath: $imageCloudPath, ')
          ..write('imageVersion: $imageVersion, ')
          ..write('imageCloudVersion: $imageCloudVersion, ')
          ..write('scoringStyle: $scoringStyle, ')
          ..write('colorArgb: $colorArgb, ')
          ..write('cloudId: $cloudId, ')
          ..write('cloudRole: $cloudRole, ')
          ..write('archived: $archived, ')
          ..write('createdAtMs: $createdAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    playerAId,
    playerBId,
    playerBName,
    roleA,
    roleB,
    tacticalNotes,
    goals,
    imageLocalPath,
    imageCloudPath,
    imageVersion,
    imageCloudVersion,
    scoringStyle,
    colorArgb,
    cloudId,
    cloudRole,
    archived,
    createdAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Team &&
          other.id == this.id &&
          other.name == this.name &&
          other.playerAId == this.playerAId &&
          other.playerBId == this.playerBId &&
          other.playerBName == this.playerBName &&
          other.roleA == this.roleA &&
          other.roleB == this.roleB &&
          other.tacticalNotes == this.tacticalNotes &&
          other.goals == this.goals &&
          other.imageLocalPath == this.imageLocalPath &&
          other.imageCloudPath == this.imageCloudPath &&
          other.imageVersion == this.imageVersion &&
          other.imageCloudVersion == this.imageCloudVersion &&
          other.scoringStyle == this.scoringStyle &&
          other.colorArgb == this.colorArgb &&
          other.cloudId == this.cloudId &&
          other.cloudRole == this.cloudRole &&
          other.archived == this.archived &&
          other.createdAtMs == this.createdAtMs);
}

class TeamsCompanion extends UpdateCompanion<Team> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> playerAId;
  final Value<String?> playerBId;
  final Value<String> playerBName;
  final Value<String> roleA;
  final Value<String> roleB;
  final Value<String> tacticalNotes;
  final Value<String> goals;
  final Value<String?> imageLocalPath;
  final Value<String?> imageCloudPath;
  final Value<int> imageVersion;
  final Value<int> imageCloudVersion;
  final Value<String> scoringStyle;
  final Value<int> colorArgb;
  final Value<String?> cloudId;
  final Value<String> cloudRole;
  final Value<bool> archived;
  final Value<int> createdAtMs;
  final Value<int> rowid;
  const TeamsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.playerAId = const Value.absent(),
    this.playerBId = const Value.absent(),
    this.playerBName = const Value.absent(),
    this.roleA = const Value.absent(),
    this.roleB = const Value.absent(),
    this.tacticalNotes = const Value.absent(),
    this.goals = const Value.absent(),
    this.imageLocalPath = const Value.absent(),
    this.imageCloudPath = const Value.absent(),
    this.imageVersion = const Value.absent(),
    this.imageCloudVersion = const Value.absent(),
    this.scoringStyle = const Value.absent(),
    this.colorArgb = const Value.absent(),
    this.cloudId = const Value.absent(),
    this.cloudRole = const Value.absent(),
    this.archived = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TeamsCompanion.insert({
    required String id,
    required String name,
    required String playerAId,
    this.playerBId = const Value.absent(),
    this.playerBName = const Value.absent(),
    this.roleA = const Value.absent(),
    this.roleB = const Value.absent(),
    this.tacticalNotes = const Value.absent(),
    this.goals = const Value.absent(),
    this.imageLocalPath = const Value.absent(),
    this.imageCloudPath = const Value.absent(),
    this.imageVersion = const Value.absent(),
    this.imageCloudVersion = const Value.absent(),
    this.scoringStyle = const Value.absent(),
    this.colorArgb = const Value.absent(),
    this.cloudId = const Value.absent(),
    this.cloudRole = const Value.absent(),
    this.archived = const Value.absent(),
    required int createdAtMs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       playerAId = Value(playerAId),
       createdAtMs = Value(createdAtMs);
  static Insertable<Team> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? playerAId,
    Expression<String>? playerBId,
    Expression<String>? playerBName,
    Expression<String>? roleA,
    Expression<String>? roleB,
    Expression<String>? tacticalNotes,
    Expression<String>? goals,
    Expression<String>? imageLocalPath,
    Expression<String>? imageCloudPath,
    Expression<int>? imageVersion,
    Expression<int>? imageCloudVersion,
    Expression<String>? scoringStyle,
    Expression<int>? colorArgb,
    Expression<String>? cloudId,
    Expression<String>? cloudRole,
    Expression<bool>? archived,
    Expression<int>? createdAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (playerAId != null) 'player_a_id': playerAId,
      if (playerBId != null) 'player_b_id': playerBId,
      if (playerBName != null) 'player_b_name': playerBName,
      if (roleA != null) 'role_a': roleA,
      if (roleB != null) 'role_b': roleB,
      if (tacticalNotes != null) 'tactical_notes': tacticalNotes,
      if (goals != null) 'goals': goals,
      if (imageLocalPath != null) 'image_local_path': imageLocalPath,
      if (imageCloudPath != null) 'image_cloud_path': imageCloudPath,
      if (imageVersion != null) 'image_version': imageVersion,
      if (imageCloudVersion != null) 'image_cloud_version': imageCloudVersion,
      if (scoringStyle != null) 'scoring_style': scoringStyle,
      if (colorArgb != null) 'color_argb': colorArgb,
      if (cloudId != null) 'cloud_id': cloudId,
      if (cloudRole != null) 'cloud_role': cloudRole,
      if (archived != null) 'archived': archived,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TeamsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? playerAId,
    Value<String?>? playerBId,
    Value<String>? playerBName,
    Value<String>? roleA,
    Value<String>? roleB,
    Value<String>? tacticalNotes,
    Value<String>? goals,
    Value<String?>? imageLocalPath,
    Value<String?>? imageCloudPath,
    Value<int>? imageVersion,
    Value<int>? imageCloudVersion,
    Value<String>? scoringStyle,
    Value<int>? colorArgb,
    Value<String?>? cloudId,
    Value<String>? cloudRole,
    Value<bool>? archived,
    Value<int>? createdAtMs,
    Value<int>? rowid,
  }) {
    return TeamsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      playerAId: playerAId ?? this.playerAId,
      playerBId: playerBId ?? this.playerBId,
      playerBName: playerBName ?? this.playerBName,
      roleA: roleA ?? this.roleA,
      roleB: roleB ?? this.roleB,
      tacticalNotes: tacticalNotes ?? this.tacticalNotes,
      goals: goals ?? this.goals,
      imageLocalPath: imageLocalPath ?? this.imageLocalPath,
      imageCloudPath: imageCloudPath ?? this.imageCloudPath,
      imageVersion: imageVersion ?? this.imageVersion,
      imageCloudVersion: imageCloudVersion ?? this.imageCloudVersion,
      scoringStyle: scoringStyle ?? this.scoringStyle,
      colorArgb: colorArgb ?? this.colorArgb,
      cloudId: cloudId ?? this.cloudId,
      cloudRole: cloudRole ?? this.cloudRole,
      archived: archived ?? this.archived,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (playerAId.present) {
      map['player_a_id'] = Variable<String>(playerAId.value);
    }
    if (playerBId.present) {
      map['player_b_id'] = Variable<String>(playerBId.value);
    }
    if (playerBName.present) {
      map['player_b_name'] = Variable<String>(playerBName.value);
    }
    if (roleA.present) {
      map['role_a'] = Variable<String>(roleA.value);
    }
    if (roleB.present) {
      map['role_b'] = Variable<String>(roleB.value);
    }
    if (tacticalNotes.present) {
      map['tactical_notes'] = Variable<String>(tacticalNotes.value);
    }
    if (goals.present) {
      map['goals'] = Variable<String>(goals.value);
    }
    if (imageLocalPath.present) {
      map['image_local_path'] = Variable<String>(imageLocalPath.value);
    }
    if (imageCloudPath.present) {
      map['image_cloud_path'] = Variable<String>(imageCloudPath.value);
    }
    if (imageVersion.present) {
      map['image_version'] = Variable<int>(imageVersion.value);
    }
    if (imageCloudVersion.present) {
      map['image_cloud_version'] = Variable<int>(imageCloudVersion.value);
    }
    if (scoringStyle.present) {
      map['scoring_style'] = Variable<String>(scoringStyle.value);
    }
    if (colorArgb.present) {
      map['color_argb'] = Variable<int>(colorArgb.value);
    }
    if (cloudId.present) {
      map['cloud_id'] = Variable<String>(cloudId.value);
    }
    if (cloudRole.present) {
      map['cloud_role'] = Variable<String>(cloudRole.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TeamsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('playerAId: $playerAId, ')
          ..write('playerBId: $playerBId, ')
          ..write('playerBName: $playerBName, ')
          ..write('roleA: $roleA, ')
          ..write('roleB: $roleB, ')
          ..write('tacticalNotes: $tacticalNotes, ')
          ..write('goals: $goals, ')
          ..write('imageLocalPath: $imageLocalPath, ')
          ..write('imageCloudPath: $imageCloudPath, ')
          ..write('imageVersion: $imageVersion, ')
          ..write('imageCloudVersion: $imageCloudVersion, ')
          ..write('scoringStyle: $scoringStyle, ')
          ..write('colorArgb: $colorArgb, ')
          ..write('cloudId: $cloudId, ')
          ..write('cloudRole: $cloudRole, ')
          ..write('archived: $archived, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MatchesTable extends Matches with TableInfo<$MatchesTable, MatchRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _teamIdMeta = const VerificationMeta('teamId');
  @override
  late final GeneratedColumn<String> teamId = GeneratedColumn<String>(
    'team_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES teams (id)',
    ),
  );
  static const VerificationMeta _formatJsonMeta = const VerificationMeta(
    'formatJson',
  );
  @override
  late final GeneratedColumn<String> formatJson = GeneratedColumn<String>(
    'format_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firstServerMeta = const VerificationMeta(
    'firstServer',
  );
  @override
  late final GeneratedColumn<String> firstServer = GeneratedColumn<String>(
    'first_server',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('TEAM_A'),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('CREATED'),
  );
  static const VerificationMeta _startTimeMsMeta = const VerificationMeta(
    'startTimeMs',
  );
  @override
  late final GeneratedColumn<int> startTimeMs = GeneratedColumn<int>(
    'start_time_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endTimeMsMeta = const VerificationMeta(
    'endTimeMs',
  );
  @override
  late final GeneratedColumn<int> endTimeMs = GeneratedColumn<int>(
    'end_time_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wonByUsMeta = const VerificationMeta(
    'wonByUs',
  );
  @override
  late final GeneratedColumn<bool> wonByUs = GeneratedColumn<bool>(
    'won_by_us',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("won_by_us" IN (0, 1))',
    ),
  );
  static const VerificationMeta _myRoleMeta = const VerificationMeta('myRole');
  @override
  late final GeneratedColumn<String> myRole = GeneratedColumn<String>(
    'my_role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('UNDEFINED'),
  );
  static const VerificationMeta _opponentLabelMeta = const VerificationMeta(
    'opponentLabel',
  );
  @override
  late final GeneratedColumn<String> opponentLabel = GeneratedColumn<String>(
    'opponent_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _opponentTagsMeta = const VerificationMeta(
    'opponentTags',
  );
  @override
  late final GeneratedColumn<String> opponentTags = GeneratedColumn<String>(
    'opponent_tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _opponentDifficultyMeta =
      const VerificationMeta('opponentDifficulty');
  @override
  late final GeneratedColumn<int> opponentDifficulty = GeneratedColumn<int>(
    'opponent_difficulty',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(3),
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _summaryJsonMeta = const VerificationMeta(
    'summaryJson',
  );
  @override
  late final GeneratedColumn<String> summaryJson = GeneratedColumn<String>(
    'summary_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _duoModeMeta = const VerificationMeta(
    'duoMode',
  );
  @override
  late final GeneratedColumn<bool> duoMode = GeneratedColumn<bool>(
    'duo_mode',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("duo_mode" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _duoTeamMeta = const VerificationMeta(
    'duoTeam',
  );
  @override
  late final GeneratedColumn<String> duoTeam = GeneratedColumn<String>(
    'duo_team',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _duoSessionIdMeta = const VerificationMeta(
    'duoSessionId',
  );
  @override
  late final GeneratedColumn<String> duoSessionId = GeneratedColumn<String>(
    'duo_session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _duoJoinCodeMeta = const VerificationMeta(
    'duoJoinCode',
  );
  @override
  late final GeneratedColumn<String> duoJoinCode = GeneratedColumn<String>(
    'duo_join_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _duoOwnerUserIdMeta = const VerificationMeta(
    'duoOwnerUserId',
  );
  @override
  late final GeneratedColumn<String> duoOwnerUserId = GeneratedColumn<String>(
    'duo_owner_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _duoCloudStatusMeta = const VerificationMeta(
    'duoCloudStatus',
  );
  @override
  late final GeneratedColumn<String> duoCloudStatus = GeneratedColumn<String>(
    'duo_cloud_status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _duoLastSyncAtMsMeta = const VerificationMeta(
    'duoLastSyncAtMs',
  );
  @override
  late final GeneratedColumn<int> duoLastSyncAtMs = GeneratedColumn<int>(
    'duo_last_sync_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    teamId,
    formatJson,
    firstServer,
    status,
    startTimeMs,
    endTimeMs,
    wonByUs,
    myRole,
    opponentLabel,
    opponentTags,
    opponentDifficulty,
    location,
    notes,
    summaryJson,
    duoMode,
    duoTeam,
    duoSessionId,
    duoJoinCode,
    duoOwnerUserId,
    duoCloudStatus,
    duoLastSyncAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'matches';
  @override
  VerificationContext validateIntegrity(
    Insertable<MatchRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('team_id')) {
      context.handle(
        _teamIdMeta,
        teamId.isAcceptableOrUnknown(data['team_id']!, _teamIdMeta),
      );
    }
    if (data.containsKey('format_json')) {
      context.handle(
        _formatJsonMeta,
        formatJson.isAcceptableOrUnknown(data['format_json']!, _formatJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_formatJsonMeta);
    }
    if (data.containsKey('first_server')) {
      context.handle(
        _firstServerMeta,
        firstServer.isAcceptableOrUnknown(
          data['first_server']!,
          _firstServerMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('start_time_ms')) {
      context.handle(
        _startTimeMsMeta,
        startTimeMs.isAcceptableOrUnknown(
          data['start_time_ms']!,
          _startTimeMsMeta,
        ),
      );
    }
    if (data.containsKey('end_time_ms')) {
      context.handle(
        _endTimeMsMeta,
        endTimeMs.isAcceptableOrUnknown(data['end_time_ms']!, _endTimeMsMeta),
      );
    }
    if (data.containsKey('won_by_us')) {
      context.handle(
        _wonByUsMeta,
        wonByUs.isAcceptableOrUnknown(data['won_by_us']!, _wonByUsMeta),
      );
    }
    if (data.containsKey('my_role')) {
      context.handle(
        _myRoleMeta,
        myRole.isAcceptableOrUnknown(data['my_role']!, _myRoleMeta),
      );
    }
    if (data.containsKey('opponent_label')) {
      context.handle(
        _opponentLabelMeta,
        opponentLabel.isAcceptableOrUnknown(
          data['opponent_label']!,
          _opponentLabelMeta,
        ),
      );
    }
    if (data.containsKey('opponent_tags')) {
      context.handle(
        _opponentTagsMeta,
        opponentTags.isAcceptableOrUnknown(
          data['opponent_tags']!,
          _opponentTagsMeta,
        ),
      );
    }
    if (data.containsKey('opponent_difficulty')) {
      context.handle(
        _opponentDifficultyMeta,
        opponentDifficulty.isAcceptableOrUnknown(
          data['opponent_difficulty']!,
          _opponentDifficultyMeta,
        ),
      );
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('summary_json')) {
      context.handle(
        _summaryJsonMeta,
        summaryJson.isAcceptableOrUnknown(
          data['summary_json']!,
          _summaryJsonMeta,
        ),
      );
    }
    if (data.containsKey('duo_mode')) {
      context.handle(
        _duoModeMeta,
        duoMode.isAcceptableOrUnknown(data['duo_mode']!, _duoModeMeta),
      );
    }
    if (data.containsKey('duo_team')) {
      context.handle(
        _duoTeamMeta,
        duoTeam.isAcceptableOrUnknown(data['duo_team']!, _duoTeamMeta),
      );
    }
    if (data.containsKey('duo_session_id')) {
      context.handle(
        _duoSessionIdMeta,
        duoSessionId.isAcceptableOrUnknown(
          data['duo_session_id']!,
          _duoSessionIdMeta,
        ),
      );
    }
    if (data.containsKey('duo_join_code')) {
      context.handle(
        _duoJoinCodeMeta,
        duoJoinCode.isAcceptableOrUnknown(
          data['duo_join_code']!,
          _duoJoinCodeMeta,
        ),
      );
    }
    if (data.containsKey('duo_owner_user_id')) {
      context.handle(
        _duoOwnerUserIdMeta,
        duoOwnerUserId.isAcceptableOrUnknown(
          data['duo_owner_user_id']!,
          _duoOwnerUserIdMeta,
        ),
      );
    }
    if (data.containsKey('duo_cloud_status')) {
      context.handle(
        _duoCloudStatusMeta,
        duoCloudStatus.isAcceptableOrUnknown(
          data['duo_cloud_status']!,
          _duoCloudStatusMeta,
        ),
      );
    }
    if (data.containsKey('duo_last_sync_at_ms')) {
      context.handle(
        _duoLastSyncAtMsMeta,
        duoLastSyncAtMs.isAcceptableOrUnknown(
          data['duo_last_sync_at_ms']!,
          _duoLastSyncAtMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MatchRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MatchRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      teamId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}team_id'],
      ),
      formatJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format_json'],
      )!,
      firstServer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}first_server'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      startTimeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_time_ms'],
      ),
      endTimeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_time_ms'],
      ),
      wonByUs: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}won_by_us'],
      ),
      myRole: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}my_role'],
      )!,
      opponentLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}opponent_label'],
      )!,
      opponentTags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}opponent_tags'],
      )!,
      opponentDifficulty: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}opponent_difficulty'],
      )!,
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      summaryJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_json'],
      ),
      duoMode: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}duo_mode'],
      )!,
      duoTeam: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}duo_team'],
      ),
      duoSessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}duo_session_id'],
      ),
      duoJoinCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}duo_join_code'],
      ),
      duoOwnerUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}duo_owner_user_id'],
      ),
      duoCloudStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}duo_cloud_status'],
      ),
      duoLastSyncAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duo_last_sync_at_ms'],
      ),
    );
  }

  @override
  $MatchesTable createAlias(String alias) {
    return $MatchesTable(attachedDatabase, alias);
  }
}

class MatchRow extends DataClass implements Insertable<MatchRow> {
  final String id;
  final String? teamId;
  final String formatJson;

  /// Team that served the first game (TEAM_A / TEAM_B, FIP Regola 4).
  ///
  /// Serve, return, break and hold statistics are all derived from the serving
  /// rotation, so a match where the opponents served first must persist it:
  /// replaying with the default would attribute every hold and break to the
  /// wrong pair.
  final String firstServer;
  final String status;
  final int? startTimeMs;
  final int? endTimeMs;
  final bool? wonByUs;
  final String myRole;
  final String opponentLabel;
  final String opponentTags;
  final int opponentDifficulty;
  final String location;
  final String notes;

  /// Cached rally_core MatchSummary as JSON (computed on completion).
  final String? summaryJson;

  /// Duo Mode: partita condivisa tra due team connessi (premium).
  final bool duoMode;

  /// Team assegnato a QUESTO device/account nella timeline condivisa
  /// (TEAM_A/TEAM_B). Nullo per le partite classiche.
  final String? duoTeam;

  /// Sessione cloud duo_sessions collegata + codice invito da mostrare.
  final String? duoSessionId;
  final String? duoJoinCode;

  /// Account cloud che ha collegato questa copia locale della sessione Duo.
  /// Impedisce che un logout/login attribuisca eventi pendenti al nuovo utente.
  final String? duoOwnerUserId;

  /// Ultimo stato confermato dal protocollo cloud a due fasi.
  final String? duoCloudStatus;
  final int? duoLastSyncAtMs;
  const MatchRow({
    required this.id,
    this.teamId,
    required this.formatJson,
    required this.firstServer,
    required this.status,
    this.startTimeMs,
    this.endTimeMs,
    this.wonByUs,
    required this.myRole,
    required this.opponentLabel,
    required this.opponentTags,
    required this.opponentDifficulty,
    required this.location,
    required this.notes,
    this.summaryJson,
    required this.duoMode,
    this.duoTeam,
    this.duoSessionId,
    this.duoJoinCode,
    this.duoOwnerUserId,
    this.duoCloudStatus,
    this.duoLastSyncAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || teamId != null) {
      map['team_id'] = Variable<String>(teamId);
    }
    map['format_json'] = Variable<String>(formatJson);
    map['first_server'] = Variable<String>(firstServer);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || startTimeMs != null) {
      map['start_time_ms'] = Variable<int>(startTimeMs);
    }
    if (!nullToAbsent || endTimeMs != null) {
      map['end_time_ms'] = Variable<int>(endTimeMs);
    }
    if (!nullToAbsent || wonByUs != null) {
      map['won_by_us'] = Variable<bool>(wonByUs);
    }
    map['my_role'] = Variable<String>(myRole);
    map['opponent_label'] = Variable<String>(opponentLabel);
    map['opponent_tags'] = Variable<String>(opponentTags);
    map['opponent_difficulty'] = Variable<int>(opponentDifficulty);
    map['location'] = Variable<String>(location);
    map['notes'] = Variable<String>(notes);
    if (!nullToAbsent || summaryJson != null) {
      map['summary_json'] = Variable<String>(summaryJson);
    }
    map['duo_mode'] = Variable<bool>(duoMode);
    if (!nullToAbsent || duoTeam != null) {
      map['duo_team'] = Variable<String>(duoTeam);
    }
    if (!nullToAbsent || duoSessionId != null) {
      map['duo_session_id'] = Variable<String>(duoSessionId);
    }
    if (!nullToAbsent || duoJoinCode != null) {
      map['duo_join_code'] = Variable<String>(duoJoinCode);
    }
    if (!nullToAbsent || duoOwnerUserId != null) {
      map['duo_owner_user_id'] = Variable<String>(duoOwnerUserId);
    }
    if (!nullToAbsent || duoCloudStatus != null) {
      map['duo_cloud_status'] = Variable<String>(duoCloudStatus);
    }
    if (!nullToAbsent || duoLastSyncAtMs != null) {
      map['duo_last_sync_at_ms'] = Variable<int>(duoLastSyncAtMs);
    }
    return map;
  }

  MatchesCompanion toCompanion(bool nullToAbsent) {
    return MatchesCompanion(
      id: Value(id),
      teamId: teamId == null && nullToAbsent
          ? const Value.absent()
          : Value(teamId),
      formatJson: Value(formatJson),
      firstServer: Value(firstServer),
      status: Value(status),
      startTimeMs: startTimeMs == null && nullToAbsent
          ? const Value.absent()
          : Value(startTimeMs),
      endTimeMs: endTimeMs == null && nullToAbsent
          ? const Value.absent()
          : Value(endTimeMs),
      wonByUs: wonByUs == null && nullToAbsent
          ? const Value.absent()
          : Value(wonByUs),
      myRole: Value(myRole),
      opponentLabel: Value(opponentLabel),
      opponentTags: Value(opponentTags),
      opponentDifficulty: Value(opponentDifficulty),
      location: Value(location),
      notes: Value(notes),
      summaryJson: summaryJson == null && nullToAbsent
          ? const Value.absent()
          : Value(summaryJson),
      duoMode: Value(duoMode),
      duoTeam: duoTeam == null && nullToAbsent
          ? const Value.absent()
          : Value(duoTeam),
      duoSessionId: duoSessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(duoSessionId),
      duoJoinCode: duoJoinCode == null && nullToAbsent
          ? const Value.absent()
          : Value(duoJoinCode),
      duoOwnerUserId: duoOwnerUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(duoOwnerUserId),
      duoCloudStatus: duoCloudStatus == null && nullToAbsent
          ? const Value.absent()
          : Value(duoCloudStatus),
      duoLastSyncAtMs: duoLastSyncAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(duoLastSyncAtMs),
    );
  }

  factory MatchRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MatchRow(
      id: serializer.fromJson<String>(json['id']),
      teamId: serializer.fromJson<String?>(json['teamId']),
      formatJson: serializer.fromJson<String>(json['formatJson']),
      firstServer: serializer.fromJson<String>(json['firstServer']),
      status: serializer.fromJson<String>(json['status']),
      startTimeMs: serializer.fromJson<int?>(json['startTimeMs']),
      endTimeMs: serializer.fromJson<int?>(json['endTimeMs']),
      wonByUs: serializer.fromJson<bool?>(json['wonByUs']),
      myRole: serializer.fromJson<String>(json['myRole']),
      opponentLabel: serializer.fromJson<String>(json['opponentLabel']),
      opponentTags: serializer.fromJson<String>(json['opponentTags']),
      opponentDifficulty: serializer.fromJson<int>(json['opponentDifficulty']),
      location: serializer.fromJson<String>(json['location']),
      notes: serializer.fromJson<String>(json['notes']),
      summaryJson: serializer.fromJson<String?>(json['summaryJson']),
      duoMode: serializer.fromJson<bool>(json['duoMode']),
      duoTeam: serializer.fromJson<String?>(json['duoTeam']),
      duoSessionId: serializer.fromJson<String?>(json['duoSessionId']),
      duoJoinCode: serializer.fromJson<String?>(json['duoJoinCode']),
      duoOwnerUserId: serializer.fromJson<String?>(json['duoOwnerUserId']),
      duoCloudStatus: serializer.fromJson<String?>(json['duoCloudStatus']),
      duoLastSyncAtMs: serializer.fromJson<int?>(json['duoLastSyncAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'teamId': serializer.toJson<String?>(teamId),
      'formatJson': serializer.toJson<String>(formatJson),
      'firstServer': serializer.toJson<String>(firstServer),
      'status': serializer.toJson<String>(status),
      'startTimeMs': serializer.toJson<int?>(startTimeMs),
      'endTimeMs': serializer.toJson<int?>(endTimeMs),
      'wonByUs': serializer.toJson<bool?>(wonByUs),
      'myRole': serializer.toJson<String>(myRole),
      'opponentLabel': serializer.toJson<String>(opponentLabel),
      'opponentTags': serializer.toJson<String>(opponentTags),
      'opponentDifficulty': serializer.toJson<int>(opponentDifficulty),
      'location': serializer.toJson<String>(location),
      'notes': serializer.toJson<String>(notes),
      'summaryJson': serializer.toJson<String?>(summaryJson),
      'duoMode': serializer.toJson<bool>(duoMode),
      'duoTeam': serializer.toJson<String?>(duoTeam),
      'duoSessionId': serializer.toJson<String?>(duoSessionId),
      'duoJoinCode': serializer.toJson<String?>(duoJoinCode),
      'duoOwnerUserId': serializer.toJson<String?>(duoOwnerUserId),
      'duoCloudStatus': serializer.toJson<String?>(duoCloudStatus),
      'duoLastSyncAtMs': serializer.toJson<int?>(duoLastSyncAtMs),
    };
  }

  MatchRow copyWith({
    String? id,
    Value<String?> teamId = const Value.absent(),
    String? formatJson,
    String? firstServer,
    String? status,
    Value<int?> startTimeMs = const Value.absent(),
    Value<int?> endTimeMs = const Value.absent(),
    Value<bool?> wonByUs = const Value.absent(),
    String? myRole,
    String? opponentLabel,
    String? opponentTags,
    int? opponentDifficulty,
    String? location,
    String? notes,
    Value<String?> summaryJson = const Value.absent(),
    bool? duoMode,
    Value<String?> duoTeam = const Value.absent(),
    Value<String?> duoSessionId = const Value.absent(),
    Value<String?> duoJoinCode = const Value.absent(),
    Value<String?> duoOwnerUserId = const Value.absent(),
    Value<String?> duoCloudStatus = const Value.absent(),
    Value<int?> duoLastSyncAtMs = const Value.absent(),
  }) => MatchRow(
    id: id ?? this.id,
    teamId: teamId.present ? teamId.value : this.teamId,
    formatJson: formatJson ?? this.formatJson,
    firstServer: firstServer ?? this.firstServer,
    status: status ?? this.status,
    startTimeMs: startTimeMs.present ? startTimeMs.value : this.startTimeMs,
    endTimeMs: endTimeMs.present ? endTimeMs.value : this.endTimeMs,
    wonByUs: wonByUs.present ? wonByUs.value : this.wonByUs,
    myRole: myRole ?? this.myRole,
    opponentLabel: opponentLabel ?? this.opponentLabel,
    opponentTags: opponentTags ?? this.opponentTags,
    opponentDifficulty: opponentDifficulty ?? this.opponentDifficulty,
    location: location ?? this.location,
    notes: notes ?? this.notes,
    summaryJson: summaryJson.present ? summaryJson.value : this.summaryJson,
    duoMode: duoMode ?? this.duoMode,
    duoTeam: duoTeam.present ? duoTeam.value : this.duoTeam,
    duoSessionId: duoSessionId.present ? duoSessionId.value : this.duoSessionId,
    duoJoinCode: duoJoinCode.present ? duoJoinCode.value : this.duoJoinCode,
    duoOwnerUserId: duoOwnerUserId.present
        ? duoOwnerUserId.value
        : this.duoOwnerUserId,
    duoCloudStatus: duoCloudStatus.present
        ? duoCloudStatus.value
        : this.duoCloudStatus,
    duoLastSyncAtMs: duoLastSyncAtMs.present
        ? duoLastSyncAtMs.value
        : this.duoLastSyncAtMs,
  );
  MatchRow copyWithCompanion(MatchesCompanion data) {
    return MatchRow(
      id: data.id.present ? data.id.value : this.id,
      teamId: data.teamId.present ? data.teamId.value : this.teamId,
      formatJson: data.formatJson.present
          ? data.formatJson.value
          : this.formatJson,
      firstServer: data.firstServer.present
          ? data.firstServer.value
          : this.firstServer,
      status: data.status.present ? data.status.value : this.status,
      startTimeMs: data.startTimeMs.present
          ? data.startTimeMs.value
          : this.startTimeMs,
      endTimeMs: data.endTimeMs.present ? data.endTimeMs.value : this.endTimeMs,
      wonByUs: data.wonByUs.present ? data.wonByUs.value : this.wonByUs,
      myRole: data.myRole.present ? data.myRole.value : this.myRole,
      opponentLabel: data.opponentLabel.present
          ? data.opponentLabel.value
          : this.opponentLabel,
      opponentTags: data.opponentTags.present
          ? data.opponentTags.value
          : this.opponentTags,
      opponentDifficulty: data.opponentDifficulty.present
          ? data.opponentDifficulty.value
          : this.opponentDifficulty,
      location: data.location.present ? data.location.value : this.location,
      notes: data.notes.present ? data.notes.value : this.notes,
      summaryJson: data.summaryJson.present
          ? data.summaryJson.value
          : this.summaryJson,
      duoMode: data.duoMode.present ? data.duoMode.value : this.duoMode,
      duoTeam: data.duoTeam.present ? data.duoTeam.value : this.duoTeam,
      duoSessionId: data.duoSessionId.present
          ? data.duoSessionId.value
          : this.duoSessionId,
      duoJoinCode: data.duoJoinCode.present
          ? data.duoJoinCode.value
          : this.duoJoinCode,
      duoOwnerUserId: data.duoOwnerUserId.present
          ? data.duoOwnerUserId.value
          : this.duoOwnerUserId,
      duoCloudStatus: data.duoCloudStatus.present
          ? data.duoCloudStatus.value
          : this.duoCloudStatus,
      duoLastSyncAtMs: data.duoLastSyncAtMs.present
          ? data.duoLastSyncAtMs.value
          : this.duoLastSyncAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MatchRow(')
          ..write('id: $id, ')
          ..write('teamId: $teamId, ')
          ..write('formatJson: $formatJson, ')
          ..write('firstServer: $firstServer, ')
          ..write('status: $status, ')
          ..write('startTimeMs: $startTimeMs, ')
          ..write('endTimeMs: $endTimeMs, ')
          ..write('wonByUs: $wonByUs, ')
          ..write('myRole: $myRole, ')
          ..write('opponentLabel: $opponentLabel, ')
          ..write('opponentTags: $opponentTags, ')
          ..write('opponentDifficulty: $opponentDifficulty, ')
          ..write('location: $location, ')
          ..write('notes: $notes, ')
          ..write('summaryJson: $summaryJson, ')
          ..write('duoMode: $duoMode, ')
          ..write('duoTeam: $duoTeam, ')
          ..write('duoSessionId: $duoSessionId, ')
          ..write('duoJoinCode: $duoJoinCode, ')
          ..write('duoOwnerUserId: $duoOwnerUserId, ')
          ..write('duoCloudStatus: $duoCloudStatus, ')
          ..write('duoLastSyncAtMs: $duoLastSyncAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    teamId,
    formatJson,
    firstServer,
    status,
    startTimeMs,
    endTimeMs,
    wonByUs,
    myRole,
    opponentLabel,
    opponentTags,
    opponentDifficulty,
    location,
    notes,
    summaryJson,
    duoMode,
    duoTeam,
    duoSessionId,
    duoJoinCode,
    duoOwnerUserId,
    duoCloudStatus,
    duoLastSyncAtMs,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MatchRow &&
          other.id == this.id &&
          other.teamId == this.teamId &&
          other.formatJson == this.formatJson &&
          other.firstServer == this.firstServer &&
          other.status == this.status &&
          other.startTimeMs == this.startTimeMs &&
          other.endTimeMs == this.endTimeMs &&
          other.wonByUs == this.wonByUs &&
          other.myRole == this.myRole &&
          other.opponentLabel == this.opponentLabel &&
          other.opponentTags == this.opponentTags &&
          other.opponentDifficulty == this.opponentDifficulty &&
          other.location == this.location &&
          other.notes == this.notes &&
          other.summaryJson == this.summaryJson &&
          other.duoMode == this.duoMode &&
          other.duoTeam == this.duoTeam &&
          other.duoSessionId == this.duoSessionId &&
          other.duoJoinCode == this.duoJoinCode &&
          other.duoOwnerUserId == this.duoOwnerUserId &&
          other.duoCloudStatus == this.duoCloudStatus &&
          other.duoLastSyncAtMs == this.duoLastSyncAtMs);
}

class MatchesCompanion extends UpdateCompanion<MatchRow> {
  final Value<String> id;
  final Value<String?> teamId;
  final Value<String> formatJson;
  final Value<String> firstServer;
  final Value<String> status;
  final Value<int?> startTimeMs;
  final Value<int?> endTimeMs;
  final Value<bool?> wonByUs;
  final Value<String> myRole;
  final Value<String> opponentLabel;
  final Value<String> opponentTags;
  final Value<int> opponentDifficulty;
  final Value<String> location;
  final Value<String> notes;
  final Value<String?> summaryJson;
  final Value<bool> duoMode;
  final Value<String?> duoTeam;
  final Value<String?> duoSessionId;
  final Value<String?> duoJoinCode;
  final Value<String?> duoOwnerUserId;
  final Value<String?> duoCloudStatus;
  final Value<int?> duoLastSyncAtMs;
  final Value<int> rowid;
  const MatchesCompanion({
    this.id = const Value.absent(),
    this.teamId = const Value.absent(),
    this.formatJson = const Value.absent(),
    this.firstServer = const Value.absent(),
    this.status = const Value.absent(),
    this.startTimeMs = const Value.absent(),
    this.endTimeMs = const Value.absent(),
    this.wonByUs = const Value.absent(),
    this.myRole = const Value.absent(),
    this.opponentLabel = const Value.absent(),
    this.opponentTags = const Value.absent(),
    this.opponentDifficulty = const Value.absent(),
    this.location = const Value.absent(),
    this.notes = const Value.absent(),
    this.summaryJson = const Value.absent(),
    this.duoMode = const Value.absent(),
    this.duoTeam = const Value.absent(),
    this.duoSessionId = const Value.absent(),
    this.duoJoinCode = const Value.absent(),
    this.duoOwnerUserId = const Value.absent(),
    this.duoCloudStatus = const Value.absent(),
    this.duoLastSyncAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MatchesCompanion.insert({
    required String id,
    this.teamId = const Value.absent(),
    required String formatJson,
    this.firstServer = const Value.absent(),
    this.status = const Value.absent(),
    this.startTimeMs = const Value.absent(),
    this.endTimeMs = const Value.absent(),
    this.wonByUs = const Value.absent(),
    this.myRole = const Value.absent(),
    this.opponentLabel = const Value.absent(),
    this.opponentTags = const Value.absent(),
    this.opponentDifficulty = const Value.absent(),
    this.location = const Value.absent(),
    this.notes = const Value.absent(),
    this.summaryJson = const Value.absent(),
    this.duoMode = const Value.absent(),
    this.duoTeam = const Value.absent(),
    this.duoSessionId = const Value.absent(),
    this.duoJoinCode = const Value.absent(),
    this.duoOwnerUserId = const Value.absent(),
    this.duoCloudStatus = const Value.absent(),
    this.duoLastSyncAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       formatJson = Value(formatJson);
  static Insertable<MatchRow> custom({
    Expression<String>? id,
    Expression<String>? teamId,
    Expression<String>? formatJson,
    Expression<String>? firstServer,
    Expression<String>? status,
    Expression<int>? startTimeMs,
    Expression<int>? endTimeMs,
    Expression<bool>? wonByUs,
    Expression<String>? myRole,
    Expression<String>? opponentLabel,
    Expression<String>? opponentTags,
    Expression<int>? opponentDifficulty,
    Expression<String>? location,
    Expression<String>? notes,
    Expression<String>? summaryJson,
    Expression<bool>? duoMode,
    Expression<String>? duoTeam,
    Expression<String>? duoSessionId,
    Expression<String>? duoJoinCode,
    Expression<String>? duoOwnerUserId,
    Expression<String>? duoCloudStatus,
    Expression<int>? duoLastSyncAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (teamId != null) 'team_id': teamId,
      if (formatJson != null) 'format_json': formatJson,
      if (firstServer != null) 'first_server': firstServer,
      if (status != null) 'status': status,
      if (startTimeMs != null) 'start_time_ms': startTimeMs,
      if (endTimeMs != null) 'end_time_ms': endTimeMs,
      if (wonByUs != null) 'won_by_us': wonByUs,
      if (myRole != null) 'my_role': myRole,
      if (opponentLabel != null) 'opponent_label': opponentLabel,
      if (opponentTags != null) 'opponent_tags': opponentTags,
      if (opponentDifficulty != null) 'opponent_difficulty': opponentDifficulty,
      if (location != null) 'location': location,
      if (notes != null) 'notes': notes,
      if (summaryJson != null) 'summary_json': summaryJson,
      if (duoMode != null) 'duo_mode': duoMode,
      if (duoTeam != null) 'duo_team': duoTeam,
      if (duoSessionId != null) 'duo_session_id': duoSessionId,
      if (duoJoinCode != null) 'duo_join_code': duoJoinCode,
      if (duoOwnerUserId != null) 'duo_owner_user_id': duoOwnerUserId,
      if (duoCloudStatus != null) 'duo_cloud_status': duoCloudStatus,
      if (duoLastSyncAtMs != null) 'duo_last_sync_at_ms': duoLastSyncAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MatchesCompanion copyWith({
    Value<String>? id,
    Value<String?>? teamId,
    Value<String>? formatJson,
    Value<String>? firstServer,
    Value<String>? status,
    Value<int?>? startTimeMs,
    Value<int?>? endTimeMs,
    Value<bool?>? wonByUs,
    Value<String>? myRole,
    Value<String>? opponentLabel,
    Value<String>? opponentTags,
    Value<int>? opponentDifficulty,
    Value<String>? location,
    Value<String>? notes,
    Value<String?>? summaryJson,
    Value<bool>? duoMode,
    Value<String?>? duoTeam,
    Value<String?>? duoSessionId,
    Value<String?>? duoJoinCode,
    Value<String?>? duoOwnerUserId,
    Value<String?>? duoCloudStatus,
    Value<int?>? duoLastSyncAtMs,
    Value<int>? rowid,
  }) {
    return MatchesCompanion(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      formatJson: formatJson ?? this.formatJson,
      firstServer: firstServer ?? this.firstServer,
      status: status ?? this.status,
      startTimeMs: startTimeMs ?? this.startTimeMs,
      endTimeMs: endTimeMs ?? this.endTimeMs,
      wonByUs: wonByUs ?? this.wonByUs,
      myRole: myRole ?? this.myRole,
      opponentLabel: opponentLabel ?? this.opponentLabel,
      opponentTags: opponentTags ?? this.opponentTags,
      opponentDifficulty: opponentDifficulty ?? this.opponentDifficulty,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      summaryJson: summaryJson ?? this.summaryJson,
      duoMode: duoMode ?? this.duoMode,
      duoTeam: duoTeam ?? this.duoTeam,
      duoSessionId: duoSessionId ?? this.duoSessionId,
      duoJoinCode: duoJoinCode ?? this.duoJoinCode,
      duoOwnerUserId: duoOwnerUserId ?? this.duoOwnerUserId,
      duoCloudStatus: duoCloudStatus ?? this.duoCloudStatus,
      duoLastSyncAtMs: duoLastSyncAtMs ?? this.duoLastSyncAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (teamId.present) {
      map['team_id'] = Variable<String>(teamId.value);
    }
    if (formatJson.present) {
      map['format_json'] = Variable<String>(formatJson.value);
    }
    if (firstServer.present) {
      map['first_server'] = Variable<String>(firstServer.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (startTimeMs.present) {
      map['start_time_ms'] = Variable<int>(startTimeMs.value);
    }
    if (endTimeMs.present) {
      map['end_time_ms'] = Variable<int>(endTimeMs.value);
    }
    if (wonByUs.present) {
      map['won_by_us'] = Variable<bool>(wonByUs.value);
    }
    if (myRole.present) {
      map['my_role'] = Variable<String>(myRole.value);
    }
    if (opponentLabel.present) {
      map['opponent_label'] = Variable<String>(opponentLabel.value);
    }
    if (opponentTags.present) {
      map['opponent_tags'] = Variable<String>(opponentTags.value);
    }
    if (opponentDifficulty.present) {
      map['opponent_difficulty'] = Variable<int>(opponentDifficulty.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (summaryJson.present) {
      map['summary_json'] = Variable<String>(summaryJson.value);
    }
    if (duoMode.present) {
      map['duo_mode'] = Variable<bool>(duoMode.value);
    }
    if (duoTeam.present) {
      map['duo_team'] = Variable<String>(duoTeam.value);
    }
    if (duoSessionId.present) {
      map['duo_session_id'] = Variable<String>(duoSessionId.value);
    }
    if (duoJoinCode.present) {
      map['duo_join_code'] = Variable<String>(duoJoinCode.value);
    }
    if (duoOwnerUserId.present) {
      map['duo_owner_user_id'] = Variable<String>(duoOwnerUserId.value);
    }
    if (duoCloudStatus.present) {
      map['duo_cloud_status'] = Variable<String>(duoCloudStatus.value);
    }
    if (duoLastSyncAtMs.present) {
      map['duo_last_sync_at_ms'] = Variable<int>(duoLastSyncAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MatchesCompanion(')
          ..write('id: $id, ')
          ..write('teamId: $teamId, ')
          ..write('formatJson: $formatJson, ')
          ..write('firstServer: $firstServer, ')
          ..write('status: $status, ')
          ..write('startTimeMs: $startTimeMs, ')
          ..write('endTimeMs: $endTimeMs, ')
          ..write('wonByUs: $wonByUs, ')
          ..write('myRole: $myRole, ')
          ..write('opponentLabel: $opponentLabel, ')
          ..write('opponentTags: $opponentTags, ')
          ..write('opponentDifficulty: $opponentDifficulty, ')
          ..write('location: $location, ')
          ..write('notes: $notes, ')
          ..write('summaryJson: $summaryJson, ')
          ..write('duoMode: $duoMode, ')
          ..write('duoTeam: $duoTeam, ')
          ..write('duoSessionId: $duoSessionId, ')
          ..write('duoJoinCode: $duoJoinCode, ')
          ..write('duoOwnerUserId: $duoOwnerUserId, ')
          ..write('duoCloudStatus: $duoCloudStatus, ')
          ..write('duoLastSyncAtMs: $duoLastSyncAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MatchEventRowsTable extends MatchEventRows
    with TableInfo<$MatchEventRowsTable, MatchEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MatchEventRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _matchIdMeta = const VerificationMeta(
    'matchId',
  );
  @override
  late final GeneratedColumn<String> matchId = GeneratedColumn<String>(
    'match_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES matches (id)',
    ),
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timestampMsMeta = const VerificationMeta(
    'timestampMs',
  );
  @override
  late final GeneratedColumn<int> timestampMs = GeneratedColumn<int>(
    'timestamp_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _teamIdMeta = const VerificationMeta('teamId');
  @override
  late final GeneratedColumn<String> teamId = GeneratedColumn<String>(
    'team_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scoreBeforeMeta = const VerificationMeta(
    'scoreBefore',
  );
  @override
  late final GeneratedColumn<String> scoreBefore = GeneratedColumn<String>(
    'score_before',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scoreAfterMeta = const VerificationMeta(
    'scoreAfter',
  );
  @override
  late final GeneratedColumn<String> scoreAfter = GeneratedColumn<String>(
    'score_after',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceDeviceMeta = const VerificationMeta(
    'sourceDevice',
  );
  @override
  late final GeneratedColumn<String> sourceDevice = GeneratedColumn<String>(
    'source_device',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('PHONE'),
  );
  static const VerificationMeta _sourceMethodMeta = const VerificationMeta(
    'sourceMethod',
  );
  @override
  late final GeneratedColumn<String> sourceMethod = GeneratedColumn<String>(
    'source_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('TAP'),
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
  static const VerificationMeta _sourceUserIdMeta = const VerificationMeta(
    'sourceUserId',
  );
  @override
  late final GeneratedColumn<String> sourceUserId = GeneratedColumn<String>(
    'source_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceTeamIdMeta = const VerificationMeta(
    'sourceTeamId',
  );
  @override
  late final GeneratedColumn<String> sourceTeamId = GeneratedColumn<String>(
    'source_team_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _duoModeMeta = const VerificationMeta(
    'duoMode',
  );
  @override
  late final GeneratedColumn<bool> duoMode = GeneratedColumn<bool>(
    'duo_mode',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("duo_mode" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdLocallyAtMsMeta =
      const VerificationMeta('createdLocallyAtMs');
  @override
  late final GeneratedColumn<int> createdLocallyAtMs = GeneratedColumn<int>(
    'created_locally_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cloudSyncedMeta = const VerificationMeta(
    'cloudSynced',
  );
  @override
  late final GeneratedColumn<bool> cloudSynced = GeneratedColumn<bool>(
    'cloud_synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("cloud_synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    eventId,
    matchId,
    seq,
    timestampMs,
    type,
    teamId,
    scoreBefore,
    scoreAfter,
    sourceDevice,
    sourceMethod,
    synced,
    payloadJson,
    sourceUserId,
    sourceTeamId,
    duoMode,
    createdLocallyAtMs,
    cloudSynced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'match_event_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<MatchEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('match_id')) {
      context.handle(
        _matchIdMeta,
        matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_matchIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('timestamp_ms')) {
      context.handle(
        _timestampMsMeta,
        timestampMs.isAcceptableOrUnknown(
          data['timestamp_ms']!,
          _timestampMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_timestampMsMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('team_id')) {
      context.handle(
        _teamIdMeta,
        teamId.isAcceptableOrUnknown(data['team_id']!, _teamIdMeta),
      );
    }
    if (data.containsKey('score_before')) {
      context.handle(
        _scoreBeforeMeta,
        scoreBefore.isAcceptableOrUnknown(
          data['score_before']!,
          _scoreBeforeMeta,
        ),
      );
    }
    if (data.containsKey('score_after')) {
      context.handle(
        _scoreAfterMeta,
        scoreAfter.isAcceptableOrUnknown(data['score_after']!, _scoreAfterMeta),
      );
    }
    if (data.containsKey('source_device')) {
      context.handle(
        _sourceDeviceMeta,
        sourceDevice.isAcceptableOrUnknown(
          data['source_device']!,
          _sourceDeviceMeta,
        ),
      );
    }
    if (data.containsKey('source_method')) {
      context.handle(
        _sourceMethodMeta,
        sourceMethod.isAcceptableOrUnknown(
          data['source_method']!,
          _sourceMethodMeta,
        ),
      );
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
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
    if (data.containsKey('source_user_id')) {
      context.handle(
        _sourceUserIdMeta,
        sourceUserId.isAcceptableOrUnknown(
          data['source_user_id']!,
          _sourceUserIdMeta,
        ),
      );
    }
    if (data.containsKey('source_team_id')) {
      context.handle(
        _sourceTeamIdMeta,
        sourceTeamId.isAcceptableOrUnknown(
          data['source_team_id']!,
          _sourceTeamIdMeta,
        ),
      );
    }
    if (data.containsKey('duo_mode')) {
      context.handle(
        _duoModeMeta,
        duoMode.isAcceptableOrUnknown(data['duo_mode']!, _duoModeMeta),
      );
    }
    if (data.containsKey('created_locally_at_ms')) {
      context.handle(
        _createdLocallyAtMsMeta,
        createdLocallyAtMs.isAcceptableOrUnknown(
          data['created_locally_at_ms']!,
          _createdLocallyAtMsMeta,
        ),
      );
    }
    if (data.containsKey('cloud_synced')) {
      context.handle(
        _cloudSyncedMeta,
        cloudSynced.isAcceptableOrUnknown(
          data['cloud_synced']!,
          _cloudSyncedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {eventId};
  @override
  MatchEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MatchEventRow(
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      matchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}match_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      timestampMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}timestamp_ms'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      teamId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}team_id'],
      ),
      scoreBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}score_before'],
      ),
      scoreAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}score_after'],
      ),
      sourceDevice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_device'],
      )!,
      sourceMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_method'],
      )!,
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      ),
      sourceUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_user_id'],
      ),
      sourceTeamId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_team_id'],
      ),
      duoMode: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}duo_mode'],
      )!,
      createdLocallyAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_locally_at_ms'],
      ),
      cloudSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}cloud_synced'],
      )!,
    );
  }

  @override
  $MatchEventRowsTable createAlias(String alias) {
    return $MatchEventRowsTable(attachedDatabase, alias);
  }
}

class MatchEventRow extends DataClass implements Insertable<MatchEventRow> {
  final String eventId;
  final String matchId;
  final int seq;
  final int timestampMs;
  final String type;
  final String? teamId;
  final String? scoreBefore;
  final String? scoreAfter;
  final String sourceDevice;
  final String sourceMethod;
  final bool synced;
  final String? payloadJson;

  /// Attribuzione Duo Mode (audit + push cloud selettivo).
  final String? sourceUserId;
  final String? sourceTeamId;
  final bool duoMode;
  final int? createdLocallyAtMs;

  /// True quando l'evento è già sulla timeline cloud della sessione Duo
  /// (push riuscito o evento ricevuto dal server): non va ripushato.
  final bool cloudSynced;
  const MatchEventRow({
    required this.eventId,
    required this.matchId,
    required this.seq,
    required this.timestampMs,
    required this.type,
    this.teamId,
    this.scoreBefore,
    this.scoreAfter,
    required this.sourceDevice,
    required this.sourceMethod,
    required this.synced,
    this.payloadJson,
    this.sourceUserId,
    this.sourceTeamId,
    required this.duoMode,
    this.createdLocallyAtMs,
    required this.cloudSynced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['event_id'] = Variable<String>(eventId);
    map['match_id'] = Variable<String>(matchId);
    map['seq'] = Variable<int>(seq);
    map['timestamp_ms'] = Variable<int>(timestampMs);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || teamId != null) {
      map['team_id'] = Variable<String>(teamId);
    }
    if (!nullToAbsent || scoreBefore != null) {
      map['score_before'] = Variable<String>(scoreBefore);
    }
    if (!nullToAbsent || scoreAfter != null) {
      map['score_after'] = Variable<String>(scoreAfter);
    }
    map['source_device'] = Variable<String>(sourceDevice);
    map['source_method'] = Variable<String>(sourceMethod);
    map['synced'] = Variable<bool>(synced);
    if (!nullToAbsent || payloadJson != null) {
      map['payload_json'] = Variable<String>(payloadJson);
    }
    if (!nullToAbsent || sourceUserId != null) {
      map['source_user_id'] = Variable<String>(sourceUserId);
    }
    if (!nullToAbsent || sourceTeamId != null) {
      map['source_team_id'] = Variable<String>(sourceTeamId);
    }
    map['duo_mode'] = Variable<bool>(duoMode);
    if (!nullToAbsent || createdLocallyAtMs != null) {
      map['created_locally_at_ms'] = Variable<int>(createdLocallyAtMs);
    }
    map['cloud_synced'] = Variable<bool>(cloudSynced);
    return map;
  }

  MatchEventRowsCompanion toCompanion(bool nullToAbsent) {
    return MatchEventRowsCompanion(
      eventId: Value(eventId),
      matchId: Value(matchId),
      seq: Value(seq),
      timestampMs: Value(timestampMs),
      type: Value(type),
      teamId: teamId == null && nullToAbsent
          ? const Value.absent()
          : Value(teamId),
      scoreBefore: scoreBefore == null && nullToAbsent
          ? const Value.absent()
          : Value(scoreBefore),
      scoreAfter: scoreAfter == null && nullToAbsent
          ? const Value.absent()
          : Value(scoreAfter),
      sourceDevice: Value(sourceDevice),
      sourceMethod: Value(sourceMethod),
      synced: Value(synced),
      payloadJson: payloadJson == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadJson),
      sourceUserId: sourceUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUserId),
      sourceTeamId: sourceTeamId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceTeamId),
      duoMode: Value(duoMode),
      createdLocallyAtMs: createdLocallyAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(createdLocallyAtMs),
      cloudSynced: Value(cloudSynced),
    );
  }

  factory MatchEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MatchEventRow(
      eventId: serializer.fromJson<String>(json['eventId']),
      matchId: serializer.fromJson<String>(json['matchId']),
      seq: serializer.fromJson<int>(json['seq']),
      timestampMs: serializer.fromJson<int>(json['timestampMs']),
      type: serializer.fromJson<String>(json['type']),
      teamId: serializer.fromJson<String?>(json['teamId']),
      scoreBefore: serializer.fromJson<String?>(json['scoreBefore']),
      scoreAfter: serializer.fromJson<String?>(json['scoreAfter']),
      sourceDevice: serializer.fromJson<String>(json['sourceDevice']),
      sourceMethod: serializer.fromJson<String>(json['sourceMethod']),
      synced: serializer.fromJson<bool>(json['synced']),
      payloadJson: serializer.fromJson<String?>(json['payloadJson']),
      sourceUserId: serializer.fromJson<String?>(json['sourceUserId']),
      sourceTeamId: serializer.fromJson<String?>(json['sourceTeamId']),
      duoMode: serializer.fromJson<bool>(json['duoMode']),
      createdLocallyAtMs: serializer.fromJson<int?>(json['createdLocallyAtMs']),
      cloudSynced: serializer.fromJson<bool>(json['cloudSynced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'eventId': serializer.toJson<String>(eventId),
      'matchId': serializer.toJson<String>(matchId),
      'seq': serializer.toJson<int>(seq),
      'timestampMs': serializer.toJson<int>(timestampMs),
      'type': serializer.toJson<String>(type),
      'teamId': serializer.toJson<String?>(teamId),
      'scoreBefore': serializer.toJson<String?>(scoreBefore),
      'scoreAfter': serializer.toJson<String?>(scoreAfter),
      'sourceDevice': serializer.toJson<String>(sourceDevice),
      'sourceMethod': serializer.toJson<String>(sourceMethod),
      'synced': serializer.toJson<bool>(synced),
      'payloadJson': serializer.toJson<String?>(payloadJson),
      'sourceUserId': serializer.toJson<String?>(sourceUserId),
      'sourceTeamId': serializer.toJson<String?>(sourceTeamId),
      'duoMode': serializer.toJson<bool>(duoMode),
      'createdLocallyAtMs': serializer.toJson<int?>(createdLocallyAtMs),
      'cloudSynced': serializer.toJson<bool>(cloudSynced),
    };
  }

  MatchEventRow copyWith({
    String? eventId,
    String? matchId,
    int? seq,
    int? timestampMs,
    String? type,
    Value<String?> teamId = const Value.absent(),
    Value<String?> scoreBefore = const Value.absent(),
    Value<String?> scoreAfter = const Value.absent(),
    String? sourceDevice,
    String? sourceMethod,
    bool? synced,
    Value<String?> payloadJson = const Value.absent(),
    Value<String?> sourceUserId = const Value.absent(),
    Value<String?> sourceTeamId = const Value.absent(),
    bool? duoMode,
    Value<int?> createdLocallyAtMs = const Value.absent(),
    bool? cloudSynced,
  }) => MatchEventRow(
    eventId: eventId ?? this.eventId,
    matchId: matchId ?? this.matchId,
    seq: seq ?? this.seq,
    timestampMs: timestampMs ?? this.timestampMs,
    type: type ?? this.type,
    teamId: teamId.present ? teamId.value : this.teamId,
    scoreBefore: scoreBefore.present ? scoreBefore.value : this.scoreBefore,
    scoreAfter: scoreAfter.present ? scoreAfter.value : this.scoreAfter,
    sourceDevice: sourceDevice ?? this.sourceDevice,
    sourceMethod: sourceMethod ?? this.sourceMethod,
    synced: synced ?? this.synced,
    payloadJson: payloadJson.present ? payloadJson.value : this.payloadJson,
    sourceUserId: sourceUserId.present ? sourceUserId.value : this.sourceUserId,
    sourceTeamId: sourceTeamId.present ? sourceTeamId.value : this.sourceTeamId,
    duoMode: duoMode ?? this.duoMode,
    createdLocallyAtMs: createdLocallyAtMs.present
        ? createdLocallyAtMs.value
        : this.createdLocallyAtMs,
    cloudSynced: cloudSynced ?? this.cloudSynced,
  );
  MatchEventRow copyWithCompanion(MatchEventRowsCompanion data) {
    return MatchEventRow(
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
      seq: data.seq.present ? data.seq.value : this.seq,
      timestampMs: data.timestampMs.present
          ? data.timestampMs.value
          : this.timestampMs,
      type: data.type.present ? data.type.value : this.type,
      teamId: data.teamId.present ? data.teamId.value : this.teamId,
      scoreBefore: data.scoreBefore.present
          ? data.scoreBefore.value
          : this.scoreBefore,
      scoreAfter: data.scoreAfter.present
          ? data.scoreAfter.value
          : this.scoreAfter,
      sourceDevice: data.sourceDevice.present
          ? data.sourceDevice.value
          : this.sourceDevice,
      sourceMethod: data.sourceMethod.present
          ? data.sourceMethod.value
          : this.sourceMethod,
      synced: data.synced.present ? data.synced.value : this.synced,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      sourceUserId: data.sourceUserId.present
          ? data.sourceUserId.value
          : this.sourceUserId,
      sourceTeamId: data.sourceTeamId.present
          ? data.sourceTeamId.value
          : this.sourceTeamId,
      duoMode: data.duoMode.present ? data.duoMode.value : this.duoMode,
      createdLocallyAtMs: data.createdLocallyAtMs.present
          ? data.createdLocallyAtMs.value
          : this.createdLocallyAtMs,
      cloudSynced: data.cloudSynced.present
          ? data.cloudSynced.value
          : this.cloudSynced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MatchEventRow(')
          ..write('eventId: $eventId, ')
          ..write('matchId: $matchId, ')
          ..write('seq: $seq, ')
          ..write('timestampMs: $timestampMs, ')
          ..write('type: $type, ')
          ..write('teamId: $teamId, ')
          ..write('scoreBefore: $scoreBefore, ')
          ..write('scoreAfter: $scoreAfter, ')
          ..write('sourceDevice: $sourceDevice, ')
          ..write('sourceMethod: $sourceMethod, ')
          ..write('synced: $synced, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('sourceUserId: $sourceUserId, ')
          ..write('sourceTeamId: $sourceTeamId, ')
          ..write('duoMode: $duoMode, ')
          ..write('createdLocallyAtMs: $createdLocallyAtMs, ')
          ..write('cloudSynced: $cloudSynced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    eventId,
    matchId,
    seq,
    timestampMs,
    type,
    teamId,
    scoreBefore,
    scoreAfter,
    sourceDevice,
    sourceMethod,
    synced,
    payloadJson,
    sourceUserId,
    sourceTeamId,
    duoMode,
    createdLocallyAtMs,
    cloudSynced,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MatchEventRow &&
          other.eventId == this.eventId &&
          other.matchId == this.matchId &&
          other.seq == this.seq &&
          other.timestampMs == this.timestampMs &&
          other.type == this.type &&
          other.teamId == this.teamId &&
          other.scoreBefore == this.scoreBefore &&
          other.scoreAfter == this.scoreAfter &&
          other.sourceDevice == this.sourceDevice &&
          other.sourceMethod == this.sourceMethod &&
          other.synced == this.synced &&
          other.payloadJson == this.payloadJson &&
          other.sourceUserId == this.sourceUserId &&
          other.sourceTeamId == this.sourceTeamId &&
          other.duoMode == this.duoMode &&
          other.createdLocallyAtMs == this.createdLocallyAtMs &&
          other.cloudSynced == this.cloudSynced);
}

class MatchEventRowsCompanion extends UpdateCompanion<MatchEventRow> {
  final Value<String> eventId;
  final Value<String> matchId;
  final Value<int> seq;
  final Value<int> timestampMs;
  final Value<String> type;
  final Value<String?> teamId;
  final Value<String?> scoreBefore;
  final Value<String?> scoreAfter;
  final Value<String> sourceDevice;
  final Value<String> sourceMethod;
  final Value<bool> synced;
  final Value<String?> payloadJson;
  final Value<String?> sourceUserId;
  final Value<String?> sourceTeamId;
  final Value<bool> duoMode;
  final Value<int?> createdLocallyAtMs;
  final Value<bool> cloudSynced;
  final Value<int> rowid;
  const MatchEventRowsCompanion({
    this.eventId = const Value.absent(),
    this.matchId = const Value.absent(),
    this.seq = const Value.absent(),
    this.timestampMs = const Value.absent(),
    this.type = const Value.absent(),
    this.teamId = const Value.absent(),
    this.scoreBefore = const Value.absent(),
    this.scoreAfter = const Value.absent(),
    this.sourceDevice = const Value.absent(),
    this.sourceMethod = const Value.absent(),
    this.synced = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.sourceUserId = const Value.absent(),
    this.sourceTeamId = const Value.absent(),
    this.duoMode = const Value.absent(),
    this.createdLocallyAtMs = const Value.absent(),
    this.cloudSynced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MatchEventRowsCompanion.insert({
    required String eventId,
    required String matchId,
    required int seq,
    required int timestampMs,
    required String type,
    this.teamId = const Value.absent(),
    this.scoreBefore = const Value.absent(),
    this.scoreAfter = const Value.absent(),
    this.sourceDevice = const Value.absent(),
    this.sourceMethod = const Value.absent(),
    this.synced = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.sourceUserId = const Value.absent(),
    this.sourceTeamId = const Value.absent(),
    this.duoMode = const Value.absent(),
    this.createdLocallyAtMs = const Value.absent(),
    this.cloudSynced = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : eventId = Value(eventId),
       matchId = Value(matchId),
       seq = Value(seq),
       timestampMs = Value(timestampMs),
       type = Value(type);
  static Insertable<MatchEventRow> custom({
    Expression<String>? eventId,
    Expression<String>? matchId,
    Expression<int>? seq,
    Expression<int>? timestampMs,
    Expression<String>? type,
    Expression<String>? teamId,
    Expression<String>? scoreBefore,
    Expression<String>? scoreAfter,
    Expression<String>? sourceDevice,
    Expression<String>? sourceMethod,
    Expression<bool>? synced,
    Expression<String>? payloadJson,
    Expression<String>? sourceUserId,
    Expression<String>? sourceTeamId,
    Expression<bool>? duoMode,
    Expression<int>? createdLocallyAtMs,
    Expression<bool>? cloudSynced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (eventId != null) 'event_id': eventId,
      if (matchId != null) 'match_id': matchId,
      if (seq != null) 'seq': seq,
      if (timestampMs != null) 'timestamp_ms': timestampMs,
      if (type != null) 'type': type,
      if (teamId != null) 'team_id': teamId,
      if (scoreBefore != null) 'score_before': scoreBefore,
      if (scoreAfter != null) 'score_after': scoreAfter,
      if (sourceDevice != null) 'source_device': sourceDevice,
      if (sourceMethod != null) 'source_method': sourceMethod,
      if (synced != null) 'synced': synced,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (sourceUserId != null) 'source_user_id': sourceUserId,
      if (sourceTeamId != null) 'source_team_id': sourceTeamId,
      if (duoMode != null) 'duo_mode': duoMode,
      if (createdLocallyAtMs != null)
        'created_locally_at_ms': createdLocallyAtMs,
      if (cloudSynced != null) 'cloud_synced': cloudSynced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MatchEventRowsCompanion copyWith({
    Value<String>? eventId,
    Value<String>? matchId,
    Value<int>? seq,
    Value<int>? timestampMs,
    Value<String>? type,
    Value<String?>? teamId,
    Value<String?>? scoreBefore,
    Value<String?>? scoreAfter,
    Value<String>? sourceDevice,
    Value<String>? sourceMethod,
    Value<bool>? synced,
    Value<String?>? payloadJson,
    Value<String?>? sourceUserId,
    Value<String?>? sourceTeamId,
    Value<bool>? duoMode,
    Value<int?>? createdLocallyAtMs,
    Value<bool>? cloudSynced,
    Value<int>? rowid,
  }) {
    return MatchEventRowsCompanion(
      eventId: eventId ?? this.eventId,
      matchId: matchId ?? this.matchId,
      seq: seq ?? this.seq,
      timestampMs: timestampMs ?? this.timestampMs,
      type: type ?? this.type,
      teamId: teamId ?? this.teamId,
      scoreBefore: scoreBefore ?? this.scoreBefore,
      scoreAfter: scoreAfter ?? this.scoreAfter,
      sourceDevice: sourceDevice ?? this.sourceDevice,
      sourceMethod: sourceMethod ?? this.sourceMethod,
      synced: synced ?? this.synced,
      payloadJson: payloadJson ?? this.payloadJson,
      sourceUserId: sourceUserId ?? this.sourceUserId,
      sourceTeamId: sourceTeamId ?? this.sourceTeamId,
      duoMode: duoMode ?? this.duoMode,
      createdLocallyAtMs: createdLocallyAtMs ?? this.createdLocallyAtMs,
      cloudSynced: cloudSynced ?? this.cloudSynced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (matchId.present) {
      map['match_id'] = Variable<String>(matchId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (timestampMs.present) {
      map['timestamp_ms'] = Variable<int>(timestampMs.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (teamId.present) {
      map['team_id'] = Variable<String>(teamId.value);
    }
    if (scoreBefore.present) {
      map['score_before'] = Variable<String>(scoreBefore.value);
    }
    if (scoreAfter.present) {
      map['score_after'] = Variable<String>(scoreAfter.value);
    }
    if (sourceDevice.present) {
      map['source_device'] = Variable<String>(sourceDevice.value);
    }
    if (sourceMethod.present) {
      map['source_method'] = Variable<String>(sourceMethod.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (sourceUserId.present) {
      map['source_user_id'] = Variable<String>(sourceUserId.value);
    }
    if (sourceTeamId.present) {
      map['source_team_id'] = Variable<String>(sourceTeamId.value);
    }
    if (duoMode.present) {
      map['duo_mode'] = Variable<bool>(duoMode.value);
    }
    if (createdLocallyAtMs.present) {
      map['created_locally_at_ms'] = Variable<int>(createdLocallyAtMs.value);
    }
    if (cloudSynced.present) {
      map['cloud_synced'] = Variable<bool>(cloudSynced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MatchEventRowsCompanion(')
          ..write('eventId: $eventId, ')
          ..write('matchId: $matchId, ')
          ..write('seq: $seq, ')
          ..write('timestampMs: $timestampMs, ')
          ..write('type: $type, ')
          ..write('teamId: $teamId, ')
          ..write('scoreBefore: $scoreBefore, ')
          ..write('scoreAfter: $scoreAfter, ')
          ..write('sourceDevice: $sourceDevice, ')
          ..write('sourceMethod: $sourceMethod, ')
          ..write('synced: $synced, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('sourceUserId: $sourceUserId, ')
          ..write('sourceTeamId: $sourceTeamId, ')
          ..write('duoMode: $duoMode, ')
          ..write('createdLocallyAtMs: $createdLocallyAtMs, ')
          ..write('cloudSynced: $cloudSynced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrainingsTable extends Trainings
    with TableInfo<$TrainingsTable, Training> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrainingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('UNDEFINED'),
  );
  static const VerificationMeta _premiumMeta = const VerificationMeta(
    'premium',
  );
  @override
  late final GeneratedColumn<bool> premium = GeneratedColumn<bool>(
    'premium',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("premium" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _durationMinutesMeta = const VerificationMeta(
    'durationMinutes',
  );
  @override
  late final GeneratedColumn<int> durationMinutes = GeneratedColumn<int>(
    'duration_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(30),
  );
  static const VerificationMeta _drillsJsonMeta = const VerificationMeta(
    'drillsJson',
  );
  @override
  late final GeneratedColumn<String> drillsJson = GeneratedColumn<String>(
    'drills_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    description,
    role,
    premium,
    durationMinutes,
    drillsJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trainings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Training> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    }
    if (data.containsKey('premium')) {
      context.handle(
        _premiumMeta,
        premium.isAcceptableOrUnknown(data['premium']!, _premiumMeta),
      );
    }
    if (data.containsKey('duration_minutes')) {
      context.handle(
        _durationMinutesMeta,
        durationMinutes.isAcceptableOrUnknown(
          data['duration_minutes']!,
          _durationMinutesMeta,
        ),
      );
    }
    if (data.containsKey('drills_json')) {
      context.handle(
        _drillsJsonMeta,
        drillsJson.isAcceptableOrUnknown(data['drills_json']!, _drillsJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Training map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Training(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      premium: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}premium'],
      )!,
      durationMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_minutes'],
      )!,
      drillsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}drills_json'],
      )!,
    );
  }

  @override
  $TrainingsTable createAlias(String alias) {
    return $TrainingsTable(attachedDatabase, alias);
  }
}

class Training extends DataClass implements Insertable<Training> {
  final String id;
  final String title;
  final String description;
  final String role;
  final bool premium;
  final int durationMinutes;

  /// JSON list of drills: [{name, minutes, note}].
  final String drillsJson;
  const Training({
    required this.id,
    required this.title,
    required this.description,
    required this.role,
    required this.premium,
    required this.durationMinutes,
    required this.drillsJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['role'] = Variable<String>(role);
    map['premium'] = Variable<bool>(premium);
    map['duration_minutes'] = Variable<int>(durationMinutes);
    map['drills_json'] = Variable<String>(drillsJson);
    return map;
  }

  TrainingsCompanion toCompanion(bool nullToAbsent) {
    return TrainingsCompanion(
      id: Value(id),
      title: Value(title),
      description: Value(description),
      role: Value(role),
      premium: Value(premium),
      durationMinutes: Value(durationMinutes),
      drillsJson: Value(drillsJson),
    );
  }

  factory Training.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Training(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      role: serializer.fromJson<String>(json['role']),
      premium: serializer.fromJson<bool>(json['premium']),
      durationMinutes: serializer.fromJson<int>(json['durationMinutes']),
      drillsJson: serializer.fromJson<String>(json['drillsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'role': serializer.toJson<String>(role),
      'premium': serializer.toJson<bool>(premium),
      'durationMinutes': serializer.toJson<int>(durationMinutes),
      'drillsJson': serializer.toJson<String>(drillsJson),
    };
  }

  Training copyWith({
    String? id,
    String? title,
    String? description,
    String? role,
    bool? premium,
    int? durationMinutes,
    String? drillsJson,
  }) => Training(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    role: role ?? this.role,
    premium: premium ?? this.premium,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    drillsJson: drillsJson ?? this.drillsJson,
  );
  Training copyWithCompanion(TrainingsCompanion data) {
    return Training(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      role: data.role.present ? data.role.value : this.role,
      premium: data.premium.present ? data.premium.value : this.premium,
      durationMinutes: data.durationMinutes.present
          ? data.durationMinutes.value
          : this.durationMinutes,
      drillsJson: data.drillsJson.present
          ? data.drillsJson.value
          : this.drillsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Training(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('role: $role, ')
          ..write('premium: $premium, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('drillsJson: $drillsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    role,
    premium,
    durationMinutes,
    drillsJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Training &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.role == this.role &&
          other.premium == this.premium &&
          other.durationMinutes == this.durationMinutes &&
          other.drillsJson == this.drillsJson);
}

class TrainingsCompanion extends UpdateCompanion<Training> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> description;
  final Value<String> role;
  final Value<bool> premium;
  final Value<int> durationMinutes;
  final Value<String> drillsJson;
  final Value<int> rowid;
  const TrainingsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.role = const Value.absent(),
    this.premium = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.drillsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrainingsCompanion.insert({
    required String id,
    required String title,
    this.description = const Value.absent(),
    this.role = const Value.absent(),
    this.premium = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.drillsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title);
  static Insertable<Training> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? role,
    Expression<bool>? premium,
    Expression<int>? durationMinutes,
    Expression<String>? drillsJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (role != null) 'role': role,
      if (premium != null) 'premium': premium,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (drillsJson != null) 'drills_json': drillsJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrainingsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? description,
    Value<String>? role,
    Value<bool>? premium,
    Value<int>? durationMinutes,
    Value<String>? drillsJson,
    Value<int>? rowid,
  }) {
    return TrainingsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      role: role ?? this.role,
      premium: premium ?? this.premium,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      drillsJson: drillsJson ?? this.drillsJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (premium.present) {
      map['premium'] = Variable<bool>(premium.value);
    }
    if (durationMinutes.present) {
      map['duration_minutes'] = Variable<int>(durationMinutes.value);
    }
    if (drillsJson.present) {
      map['drills_json'] = Variable<String>(drillsJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrainingsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('role: $role, ')
          ..write('premium: $premium, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('drillsJson: $drillsJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrainingLogsTable extends TrainingLogs
    with TableInfo<$TrainingLogsTable, TrainingLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrainingLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trainingIdMeta = const VerificationMeta(
    'trainingId',
  );
  @override
  late final GeneratedColumn<String> trainingId = GeneratedColumn<String>(
    'training_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES trainings (id)',
    ),
  );
  static const VerificationMeta _dateMsMeta = const VerificationMeta('dateMs');
  @override
  late final GeneratedColumn<int> dateMs = GeneratedColumn<int>(
    'date_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _rpeMeta = const VerificationMeta('rpe');
  @override
  late final GeneratedColumn<int> rpe = GeneratedColumn<int>(
    'rpe',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _minutesMeta = const VerificationMeta(
    'minutes',
  );
  @override
  late final GeneratedColumn<int> minutes = GeneratedColumn<int>(
    'minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    trainingId,
    dateMs,
    completed,
    notes,
    rpe,
    minutes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'training_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrainingLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('training_id')) {
      context.handle(
        _trainingIdMeta,
        trainingId.isAcceptableOrUnknown(data['training_id']!, _trainingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trainingIdMeta);
    }
    if (data.containsKey('date_ms')) {
      context.handle(
        _dateMsMeta,
        dateMs.isAcceptableOrUnknown(data['date_ms']!, _dateMsMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMsMeta);
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('rpe')) {
      context.handle(
        _rpeMeta,
        rpe.isAcceptableOrUnknown(data['rpe']!, _rpeMeta),
      );
    }
    if (data.containsKey('minutes')) {
      context.handle(
        _minutesMeta,
        minutes.isAcceptableOrUnknown(data['minutes']!, _minutesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TrainingLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrainingLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      trainingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}training_id'],
      )!,
      dateMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}date_ms'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      rpe: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rpe'],
      )!,
      minutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}minutes'],
      )!,
    );
  }

  @override
  $TrainingLogsTable createAlias(String alias) {
    return $TrainingLogsTable(attachedDatabase, alias);
  }
}

class TrainingLog extends DataClass implements Insertable<TrainingLog> {
  final String id;
  final String trainingId;
  final int dateMs;
  final bool completed;
  final String notes;

  /// Sforzo percepito 1-10 (RPE, 0 = non registrato) e minuti effettivi:
  /// alimentano il carico settimanale (ACWR) del training.
  final int rpe;
  final int minutes;
  const TrainingLog({
    required this.id,
    required this.trainingId,
    required this.dateMs,
    required this.completed,
    required this.notes,
    required this.rpe,
    required this.minutes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['training_id'] = Variable<String>(trainingId);
    map['date_ms'] = Variable<int>(dateMs);
    map['completed'] = Variable<bool>(completed);
    map['notes'] = Variable<String>(notes);
    map['rpe'] = Variable<int>(rpe);
    map['minutes'] = Variable<int>(minutes);
    return map;
  }

  TrainingLogsCompanion toCompanion(bool nullToAbsent) {
    return TrainingLogsCompanion(
      id: Value(id),
      trainingId: Value(trainingId),
      dateMs: Value(dateMs),
      completed: Value(completed),
      notes: Value(notes),
      rpe: Value(rpe),
      minutes: Value(minutes),
    );
  }

  factory TrainingLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrainingLog(
      id: serializer.fromJson<String>(json['id']),
      trainingId: serializer.fromJson<String>(json['trainingId']),
      dateMs: serializer.fromJson<int>(json['dateMs']),
      completed: serializer.fromJson<bool>(json['completed']),
      notes: serializer.fromJson<String>(json['notes']),
      rpe: serializer.fromJson<int>(json['rpe']),
      minutes: serializer.fromJson<int>(json['minutes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'trainingId': serializer.toJson<String>(trainingId),
      'dateMs': serializer.toJson<int>(dateMs),
      'completed': serializer.toJson<bool>(completed),
      'notes': serializer.toJson<String>(notes),
      'rpe': serializer.toJson<int>(rpe),
      'minutes': serializer.toJson<int>(minutes),
    };
  }

  TrainingLog copyWith({
    String? id,
    String? trainingId,
    int? dateMs,
    bool? completed,
    String? notes,
    int? rpe,
    int? minutes,
  }) => TrainingLog(
    id: id ?? this.id,
    trainingId: trainingId ?? this.trainingId,
    dateMs: dateMs ?? this.dateMs,
    completed: completed ?? this.completed,
    notes: notes ?? this.notes,
    rpe: rpe ?? this.rpe,
    minutes: minutes ?? this.minutes,
  );
  TrainingLog copyWithCompanion(TrainingLogsCompanion data) {
    return TrainingLog(
      id: data.id.present ? data.id.value : this.id,
      trainingId: data.trainingId.present
          ? data.trainingId.value
          : this.trainingId,
      dateMs: data.dateMs.present ? data.dateMs.value : this.dateMs,
      completed: data.completed.present ? data.completed.value : this.completed,
      notes: data.notes.present ? data.notes.value : this.notes,
      rpe: data.rpe.present ? data.rpe.value : this.rpe,
      minutes: data.minutes.present ? data.minutes.value : this.minutes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrainingLog(')
          ..write('id: $id, ')
          ..write('trainingId: $trainingId, ')
          ..write('dateMs: $dateMs, ')
          ..write('completed: $completed, ')
          ..write('notes: $notes, ')
          ..write('rpe: $rpe, ')
          ..write('minutes: $minutes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, trainingId, dateMs, completed, notes, rpe, minutes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrainingLog &&
          other.id == this.id &&
          other.trainingId == this.trainingId &&
          other.dateMs == this.dateMs &&
          other.completed == this.completed &&
          other.notes == this.notes &&
          other.rpe == this.rpe &&
          other.minutes == this.minutes);
}

class TrainingLogsCompanion extends UpdateCompanion<TrainingLog> {
  final Value<String> id;
  final Value<String> trainingId;
  final Value<int> dateMs;
  final Value<bool> completed;
  final Value<String> notes;
  final Value<int> rpe;
  final Value<int> minutes;
  final Value<int> rowid;
  const TrainingLogsCompanion({
    this.id = const Value.absent(),
    this.trainingId = const Value.absent(),
    this.dateMs = const Value.absent(),
    this.completed = const Value.absent(),
    this.notes = const Value.absent(),
    this.rpe = const Value.absent(),
    this.minutes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrainingLogsCompanion.insert({
    required String id,
    required String trainingId,
    required int dateMs,
    this.completed = const Value.absent(),
    this.notes = const Value.absent(),
    this.rpe = const Value.absent(),
    this.minutes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       trainingId = Value(trainingId),
       dateMs = Value(dateMs);
  static Insertable<TrainingLog> custom({
    Expression<String>? id,
    Expression<String>? trainingId,
    Expression<int>? dateMs,
    Expression<bool>? completed,
    Expression<String>? notes,
    Expression<int>? rpe,
    Expression<int>? minutes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trainingId != null) 'training_id': trainingId,
      if (dateMs != null) 'date_ms': dateMs,
      if (completed != null) 'completed': completed,
      if (notes != null) 'notes': notes,
      if (rpe != null) 'rpe': rpe,
      if (minutes != null) 'minutes': minutes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrainingLogsCompanion copyWith({
    Value<String>? id,
    Value<String>? trainingId,
    Value<int>? dateMs,
    Value<bool>? completed,
    Value<String>? notes,
    Value<int>? rpe,
    Value<int>? minutes,
    Value<int>? rowid,
  }) {
    return TrainingLogsCompanion(
      id: id ?? this.id,
      trainingId: trainingId ?? this.trainingId,
      dateMs: dateMs ?? this.dateMs,
      completed: completed ?? this.completed,
      notes: notes ?? this.notes,
      rpe: rpe ?? this.rpe,
      minutes: minutes ?? this.minutes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (trainingId.present) {
      map['training_id'] = Variable<String>(trainingId.value);
    }
    if (dateMs.present) {
      map['date_ms'] = Variable<int>(dateMs.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rpe.present) {
      map['rpe'] = Variable<int>(rpe.value);
    }
    if (minutes.present) {
      map['minutes'] = Variable<int>(minutes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrainingLogsCompanion(')
          ..write('id: $id, ')
          ..write('trainingId: $trainingId, ')
          ..write('dateMs: $dateMs, ')
          ..write('completed: $completed, ')
          ..write('notes: $notes, ')
          ..write('rpe: $rpe, ')
          ..write('minutes: $minutes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConnectedDevicesTable extends ConnectedDevices
    with TableInfo<$ConnectedDevicesTable, ConnectedDevice> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConnectedDevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _platformMeta = const VerificationMeta(
    'platform',
  );
  @override
  late final GeneratedColumn<String> platform = GeneratedColumn<String>(
    'platform',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _familyMeta = const VerificationMeta('family');
  @override
  late final GeneratedColumn<String> family = GeneratedColumn<String>(
    'family',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _aliasMeta = const VerificationMeta('alias');
  @override
  late final GeneratedColumn<String> alias = GeneratedColumn<String>(
    'alias',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('NOT_REACHABLE'),
  );
  static const VerificationMeta _capabilitiesJsonMeta = const VerificationMeta(
    'capabilitiesJson',
  );
  @override
  late final GeneratedColumn<String> capabilitiesJson = GeneratedColumn<String>(
    'capabilities_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _companionInstalledMeta =
      const VerificationMeta('companionInstalled');
  @override
  late final GeneratedColumn<bool> companionInstalled = GeneratedColumn<bool>(
    'companion_installed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("companion_installed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _permissionsCompleteMeta =
      const VerificationMeta('permissionsComplete');
  @override
  late final GeneratedColumn<bool> permissionsComplete = GeneratedColumn<bool>(
    'permissions_complete',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("permissions_complete" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _setupStepMeta = const VerificationMeta(
    'setupStep',
  );
  @override
  late final GeneratedColumn<int> setupStep = GeneratedColumn<int>(
    'setup_step',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastSeenAtMsMeta = const VerificationMeta(
    'lastSeenAtMs',
  );
  @override
  late final GeneratedColumn<int> lastSeenAtMs = GeneratedColumn<int>(
    'last_seen_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncAtMsMeta = const VerificationMeta(
    'lastSyncAtMs',
  );
  @override
  late final GeneratedColumn<int> lastSyncAtMs = GeneratedColumn<int>(
    'last_sync_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    platform,
    family,
    displayName,
    alias,
    status,
    capabilitiesJson,
    companionInstalled,
    permissionsComplete,
    isDefault,
    setupStep,
    lastSeenAtMs,
    lastSyncAtMs,
    createdAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'connected_devices';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConnectedDevice> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('platform')) {
      context.handle(
        _platformMeta,
        platform.isAcceptableOrUnknown(data['platform']!, _platformMeta),
      );
    } else if (isInserting) {
      context.missing(_platformMeta);
    }
    if (data.containsKey('family')) {
      context.handle(
        _familyMeta,
        family.isAcceptableOrUnknown(data['family']!, _familyMeta),
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
    if (data.containsKey('alias')) {
      context.handle(
        _aliasMeta,
        alias.isAcceptableOrUnknown(data['alias']!, _aliasMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('capabilities_json')) {
      context.handle(
        _capabilitiesJsonMeta,
        capabilitiesJson.isAcceptableOrUnknown(
          data['capabilities_json']!,
          _capabilitiesJsonMeta,
        ),
      );
    }
    if (data.containsKey('companion_installed')) {
      context.handle(
        _companionInstalledMeta,
        companionInstalled.isAcceptableOrUnknown(
          data['companion_installed']!,
          _companionInstalledMeta,
        ),
      );
    }
    if (data.containsKey('permissions_complete')) {
      context.handle(
        _permissionsCompleteMeta,
        permissionsComplete.isAcceptableOrUnknown(
          data['permissions_complete']!,
          _permissionsCompleteMeta,
        ),
      );
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    if (data.containsKey('setup_step')) {
      context.handle(
        _setupStepMeta,
        setupStep.isAcceptableOrUnknown(data['setup_step']!, _setupStepMeta),
      );
    }
    if (data.containsKey('last_seen_at_ms')) {
      context.handle(
        _lastSeenAtMsMeta,
        lastSeenAtMs.isAcceptableOrUnknown(
          data['last_seen_at_ms']!,
          _lastSeenAtMsMeta,
        ),
      );
    }
    if (data.containsKey('last_sync_at_ms')) {
      context.handle(
        _lastSyncAtMsMeta,
        lastSyncAtMs.isAcceptableOrUnknown(
          data['last_sync_at_ms']!,
          _lastSyncAtMsMeta,
        ),
      );
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConnectedDevice map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConnectedDevice(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      platform: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform'],
      )!,
      family: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      alias: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alias'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      capabilitiesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capabilities_json'],
      )!,
      companionInstalled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}companion_installed'],
      )!,
      permissionsComplete: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}permissions_complete'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      setupStep: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}setup_step'],
      )!,
      lastSeenAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seen_at_ms'],
      ),
      lastSyncAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_sync_at_ms'],
      ),
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
    );
  }

  @override
  $ConnectedDevicesTable createAlias(String alias) {
    return $ConnectedDevicesTable(attachedDatabase, alias);
  }
}

class ConnectedDevice extends DataClass implements Insertable<ConnectedDevice> {
  final String id;
  final String platform;
  final String family;
  final String displayName;
  final String alias;
  final String status;
  final String capabilitiesJson;
  final bool companionInstalled;
  final bool permissionsComplete;
  final bool isDefault;
  final int setupStep;
  final int? lastSeenAtMs;
  final int? lastSyncAtMs;
  final int createdAtMs;
  const ConnectedDevice({
    required this.id,
    required this.platform,
    required this.family,
    required this.displayName,
    required this.alias,
    required this.status,
    required this.capabilitiesJson,
    required this.companionInstalled,
    required this.permissionsComplete,
    required this.isDefault,
    required this.setupStep,
    this.lastSeenAtMs,
    this.lastSyncAtMs,
    required this.createdAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['platform'] = Variable<String>(platform);
    map['family'] = Variable<String>(family);
    map['display_name'] = Variable<String>(displayName);
    map['alias'] = Variable<String>(alias);
    map['status'] = Variable<String>(status);
    map['capabilities_json'] = Variable<String>(capabilitiesJson);
    map['companion_installed'] = Variable<bool>(companionInstalled);
    map['permissions_complete'] = Variable<bool>(permissionsComplete);
    map['is_default'] = Variable<bool>(isDefault);
    map['setup_step'] = Variable<int>(setupStep);
    if (!nullToAbsent || lastSeenAtMs != null) {
      map['last_seen_at_ms'] = Variable<int>(lastSeenAtMs);
    }
    if (!nullToAbsent || lastSyncAtMs != null) {
      map['last_sync_at_ms'] = Variable<int>(lastSyncAtMs);
    }
    map['created_at_ms'] = Variable<int>(createdAtMs);
    return map;
  }

  ConnectedDevicesCompanion toCompanion(bool nullToAbsent) {
    return ConnectedDevicesCompanion(
      id: Value(id),
      platform: Value(platform),
      family: Value(family),
      displayName: Value(displayName),
      alias: Value(alias),
      status: Value(status),
      capabilitiesJson: Value(capabilitiesJson),
      companionInstalled: Value(companionInstalled),
      permissionsComplete: Value(permissionsComplete),
      isDefault: Value(isDefault),
      setupStep: Value(setupStep),
      lastSeenAtMs: lastSeenAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeenAtMs),
      lastSyncAtMs: lastSyncAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncAtMs),
      createdAtMs: Value(createdAtMs),
    );
  }

  factory ConnectedDevice.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConnectedDevice(
      id: serializer.fromJson<String>(json['id']),
      platform: serializer.fromJson<String>(json['platform']),
      family: serializer.fromJson<String>(json['family']),
      displayName: serializer.fromJson<String>(json['displayName']),
      alias: serializer.fromJson<String>(json['alias']),
      status: serializer.fromJson<String>(json['status']),
      capabilitiesJson: serializer.fromJson<String>(json['capabilitiesJson']),
      companionInstalled: serializer.fromJson<bool>(json['companionInstalled']),
      permissionsComplete: serializer.fromJson<bool>(
        json['permissionsComplete'],
      ),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      setupStep: serializer.fromJson<int>(json['setupStep']),
      lastSeenAtMs: serializer.fromJson<int?>(json['lastSeenAtMs']),
      lastSyncAtMs: serializer.fromJson<int?>(json['lastSyncAtMs']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'platform': serializer.toJson<String>(platform),
      'family': serializer.toJson<String>(family),
      'displayName': serializer.toJson<String>(displayName),
      'alias': serializer.toJson<String>(alias),
      'status': serializer.toJson<String>(status),
      'capabilitiesJson': serializer.toJson<String>(capabilitiesJson),
      'companionInstalled': serializer.toJson<bool>(companionInstalled),
      'permissionsComplete': serializer.toJson<bool>(permissionsComplete),
      'isDefault': serializer.toJson<bool>(isDefault),
      'setupStep': serializer.toJson<int>(setupStep),
      'lastSeenAtMs': serializer.toJson<int?>(lastSeenAtMs),
      'lastSyncAtMs': serializer.toJson<int?>(lastSyncAtMs),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
    };
  }

  ConnectedDevice copyWith({
    String? id,
    String? platform,
    String? family,
    String? displayName,
    String? alias,
    String? status,
    String? capabilitiesJson,
    bool? companionInstalled,
    bool? permissionsComplete,
    bool? isDefault,
    int? setupStep,
    Value<int?> lastSeenAtMs = const Value.absent(),
    Value<int?> lastSyncAtMs = const Value.absent(),
    int? createdAtMs,
  }) => ConnectedDevice(
    id: id ?? this.id,
    platform: platform ?? this.platform,
    family: family ?? this.family,
    displayName: displayName ?? this.displayName,
    alias: alias ?? this.alias,
    status: status ?? this.status,
    capabilitiesJson: capabilitiesJson ?? this.capabilitiesJson,
    companionInstalled: companionInstalled ?? this.companionInstalled,
    permissionsComplete: permissionsComplete ?? this.permissionsComplete,
    isDefault: isDefault ?? this.isDefault,
    setupStep: setupStep ?? this.setupStep,
    lastSeenAtMs: lastSeenAtMs.present ? lastSeenAtMs.value : this.lastSeenAtMs,
    lastSyncAtMs: lastSyncAtMs.present ? lastSyncAtMs.value : this.lastSyncAtMs,
    createdAtMs: createdAtMs ?? this.createdAtMs,
  );
  ConnectedDevice copyWithCompanion(ConnectedDevicesCompanion data) {
    return ConnectedDevice(
      id: data.id.present ? data.id.value : this.id,
      platform: data.platform.present ? data.platform.value : this.platform,
      family: data.family.present ? data.family.value : this.family,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      alias: data.alias.present ? data.alias.value : this.alias,
      status: data.status.present ? data.status.value : this.status,
      capabilitiesJson: data.capabilitiesJson.present
          ? data.capabilitiesJson.value
          : this.capabilitiesJson,
      companionInstalled: data.companionInstalled.present
          ? data.companionInstalled.value
          : this.companionInstalled,
      permissionsComplete: data.permissionsComplete.present
          ? data.permissionsComplete.value
          : this.permissionsComplete,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      setupStep: data.setupStep.present ? data.setupStep.value : this.setupStep,
      lastSeenAtMs: data.lastSeenAtMs.present
          ? data.lastSeenAtMs.value
          : this.lastSeenAtMs,
      lastSyncAtMs: data.lastSyncAtMs.present
          ? data.lastSyncAtMs.value
          : this.lastSyncAtMs,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConnectedDevice(')
          ..write('id: $id, ')
          ..write('platform: $platform, ')
          ..write('family: $family, ')
          ..write('displayName: $displayName, ')
          ..write('alias: $alias, ')
          ..write('status: $status, ')
          ..write('capabilitiesJson: $capabilitiesJson, ')
          ..write('companionInstalled: $companionInstalled, ')
          ..write('permissionsComplete: $permissionsComplete, ')
          ..write('isDefault: $isDefault, ')
          ..write('setupStep: $setupStep, ')
          ..write('lastSeenAtMs: $lastSeenAtMs, ')
          ..write('lastSyncAtMs: $lastSyncAtMs, ')
          ..write('createdAtMs: $createdAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    platform,
    family,
    displayName,
    alias,
    status,
    capabilitiesJson,
    companionInstalled,
    permissionsComplete,
    isDefault,
    setupStep,
    lastSeenAtMs,
    lastSyncAtMs,
    createdAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConnectedDevice &&
          other.id == this.id &&
          other.platform == this.platform &&
          other.family == this.family &&
          other.displayName == this.displayName &&
          other.alias == this.alias &&
          other.status == this.status &&
          other.capabilitiesJson == this.capabilitiesJson &&
          other.companionInstalled == this.companionInstalled &&
          other.permissionsComplete == this.permissionsComplete &&
          other.isDefault == this.isDefault &&
          other.setupStep == this.setupStep &&
          other.lastSeenAtMs == this.lastSeenAtMs &&
          other.lastSyncAtMs == this.lastSyncAtMs &&
          other.createdAtMs == this.createdAtMs);
}

class ConnectedDevicesCompanion extends UpdateCompanion<ConnectedDevice> {
  final Value<String> id;
  final Value<String> platform;
  final Value<String> family;
  final Value<String> displayName;
  final Value<String> alias;
  final Value<String> status;
  final Value<String> capabilitiesJson;
  final Value<bool> companionInstalled;
  final Value<bool> permissionsComplete;
  final Value<bool> isDefault;
  final Value<int> setupStep;
  final Value<int?> lastSeenAtMs;
  final Value<int?> lastSyncAtMs;
  final Value<int> createdAtMs;
  final Value<int> rowid;
  const ConnectedDevicesCompanion({
    this.id = const Value.absent(),
    this.platform = const Value.absent(),
    this.family = const Value.absent(),
    this.displayName = const Value.absent(),
    this.alias = const Value.absent(),
    this.status = const Value.absent(),
    this.capabilitiesJson = const Value.absent(),
    this.companionInstalled = const Value.absent(),
    this.permissionsComplete = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.setupStep = const Value.absent(),
    this.lastSeenAtMs = const Value.absent(),
    this.lastSyncAtMs = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConnectedDevicesCompanion.insert({
    required String id,
    required String platform,
    this.family = const Value.absent(),
    this.displayName = const Value.absent(),
    this.alias = const Value.absent(),
    this.status = const Value.absent(),
    this.capabilitiesJson = const Value.absent(),
    this.companionInstalled = const Value.absent(),
    this.permissionsComplete = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.setupStep = const Value.absent(),
    this.lastSeenAtMs = const Value.absent(),
    this.lastSyncAtMs = const Value.absent(),
    required int createdAtMs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       platform = Value(platform),
       createdAtMs = Value(createdAtMs);
  static Insertable<ConnectedDevice> custom({
    Expression<String>? id,
    Expression<String>? platform,
    Expression<String>? family,
    Expression<String>? displayName,
    Expression<String>? alias,
    Expression<String>? status,
    Expression<String>? capabilitiesJson,
    Expression<bool>? companionInstalled,
    Expression<bool>? permissionsComplete,
    Expression<bool>? isDefault,
    Expression<int>? setupStep,
    Expression<int>? lastSeenAtMs,
    Expression<int>? lastSyncAtMs,
    Expression<int>? createdAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (platform != null) 'platform': platform,
      if (family != null) 'family': family,
      if (displayName != null) 'display_name': displayName,
      if (alias != null) 'alias': alias,
      if (status != null) 'status': status,
      if (capabilitiesJson != null) 'capabilities_json': capabilitiesJson,
      if (companionInstalled != null) 'companion_installed': companionInstalled,
      if (permissionsComplete != null)
        'permissions_complete': permissionsComplete,
      if (isDefault != null) 'is_default': isDefault,
      if (setupStep != null) 'setup_step': setupStep,
      if (lastSeenAtMs != null) 'last_seen_at_ms': lastSeenAtMs,
      if (lastSyncAtMs != null) 'last_sync_at_ms': lastSyncAtMs,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConnectedDevicesCompanion copyWith({
    Value<String>? id,
    Value<String>? platform,
    Value<String>? family,
    Value<String>? displayName,
    Value<String>? alias,
    Value<String>? status,
    Value<String>? capabilitiesJson,
    Value<bool>? companionInstalled,
    Value<bool>? permissionsComplete,
    Value<bool>? isDefault,
    Value<int>? setupStep,
    Value<int?>? lastSeenAtMs,
    Value<int?>? lastSyncAtMs,
    Value<int>? createdAtMs,
    Value<int>? rowid,
  }) {
    return ConnectedDevicesCompanion(
      id: id ?? this.id,
      platform: platform ?? this.platform,
      family: family ?? this.family,
      displayName: displayName ?? this.displayName,
      alias: alias ?? this.alias,
      status: status ?? this.status,
      capabilitiesJson: capabilitiesJson ?? this.capabilitiesJson,
      companionInstalled: companionInstalled ?? this.companionInstalled,
      permissionsComplete: permissionsComplete ?? this.permissionsComplete,
      isDefault: isDefault ?? this.isDefault,
      setupStep: setupStep ?? this.setupStep,
      lastSeenAtMs: lastSeenAtMs ?? this.lastSeenAtMs,
      lastSyncAtMs: lastSyncAtMs ?? this.lastSyncAtMs,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (platform.present) {
      map['platform'] = Variable<String>(platform.value);
    }
    if (family.present) {
      map['family'] = Variable<String>(family.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (alias.present) {
      map['alias'] = Variable<String>(alias.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (capabilitiesJson.present) {
      map['capabilities_json'] = Variable<String>(capabilitiesJson.value);
    }
    if (companionInstalled.present) {
      map['companion_installed'] = Variable<bool>(companionInstalled.value);
    }
    if (permissionsComplete.present) {
      map['permissions_complete'] = Variable<bool>(permissionsComplete.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (setupStep.present) {
      map['setup_step'] = Variable<int>(setupStep.value);
    }
    if (lastSeenAtMs.present) {
      map['last_seen_at_ms'] = Variable<int>(lastSeenAtMs.value);
    }
    if (lastSyncAtMs.present) {
      map['last_sync_at_ms'] = Variable<int>(lastSyncAtMs.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConnectedDevicesCompanion(')
          ..write('id: $id, ')
          ..write('platform: $platform, ')
          ..write('family: $family, ')
          ..write('displayName: $displayName, ')
          ..write('alias: $alias, ')
          ..write('status: $status, ')
          ..write('capabilitiesJson: $capabilitiesJson, ')
          ..write('companionInstalled: $companionInstalled, ')
          ..write('permissionsComplete: $permissionsComplete, ')
          ..write('isDefault: $isDefault, ')
          ..write('setupStep: $setupStep, ')
          ..write('lastSeenAtMs: $lastSeenAtMs, ')
          ..write('lastSyncAtMs: $lastSyncAtMs, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HealthDataSourcesTable extends HealthDataSources
    with TableInfo<$HealthDataSourcesTable, HealthDataSource> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HealthDataSourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceApplicationMeta = const VerificationMeta(
    'sourceApplication',
  );
  @override
  late final GeneratedColumn<String> sourceApplication =
      GeneratedColumn<String>(
        'source_application',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant(''),
      );
  static const VerificationMeta _sourceBundleIdMeta = const VerificationMeta(
    'sourceBundleId',
  );
  @override
  late final GeneratedColumn<String> sourceBundleId = GeneratedColumn<String>(
    'source_bundle_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sourceDeviceMeta = const VerificationMeta(
    'sourceDevice',
  );
  @override
  late final GeneratedColumn<String> sourceDevice = GeneratedColumn<String>(
    'source_device',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sourceModelMeta = const VerificationMeta(
    'sourceModel',
  );
  @override
  late final GeneratedColumn<String> sourceModel = GeneratedColumn<String>(
    'source_model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _connectionIdMeta = const VerificationMeta(
    'connectionId',
  );
  @override
  late final GeneratedColumn<String> connectionId = GeneratedColumn<String>(
    'connection_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPreferredMeta = const VerificationMeta(
    'isPreferred',
  );
  @override
  late final GeneratedColumn<bool> isPreferred = GeneratedColumn<bool>(
    'is_preferred',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_preferred" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _supportsLiveDataMeta = const VerificationMeta(
    'supportsLiveData',
  );
  @override
  late final GeneratedColumn<bool> supportsLiveData = GeneratedColumn<bool>(
    'supports_live_data',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("supports_live_data" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _availableMetricsJsonMeta =
      const VerificationMeta('availableMetricsJson');
  @override
  late final GeneratedColumn<String> availableMetricsJson =
      GeneratedColumn<String>(
        'available_metrics_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _detectedAtMsMeta = const VerificationMeta(
    'detectedAtMs',
  );
  @override
  late final GeneratedColumn<int> detectedAtMs = GeneratedColumn<int>(
    'detected_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerId,
    provider,
    sourceApplication,
    sourceBundleId,
    sourceDevice,
    sourceModel,
    connectionId,
    isPreferred,
    supportsLiveData,
    availableMetricsJson,
    detectedAtMs,
    updatedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'health_data_sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<HealthDataSource> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('source_application')) {
      context.handle(
        _sourceApplicationMeta,
        sourceApplication.isAcceptableOrUnknown(
          data['source_application']!,
          _sourceApplicationMeta,
        ),
      );
    }
    if (data.containsKey('source_bundle_id')) {
      context.handle(
        _sourceBundleIdMeta,
        sourceBundleId.isAcceptableOrUnknown(
          data['source_bundle_id']!,
          _sourceBundleIdMeta,
        ),
      );
    }
    if (data.containsKey('source_device')) {
      context.handle(
        _sourceDeviceMeta,
        sourceDevice.isAcceptableOrUnknown(
          data['source_device']!,
          _sourceDeviceMeta,
        ),
      );
    }
    if (data.containsKey('source_model')) {
      context.handle(
        _sourceModelMeta,
        sourceModel.isAcceptableOrUnknown(
          data['source_model']!,
          _sourceModelMeta,
        ),
      );
    }
    if (data.containsKey('connection_id')) {
      context.handle(
        _connectionIdMeta,
        connectionId.isAcceptableOrUnknown(
          data['connection_id']!,
          _connectionIdMeta,
        ),
      );
    }
    if (data.containsKey('is_preferred')) {
      context.handle(
        _isPreferredMeta,
        isPreferred.isAcceptableOrUnknown(
          data['is_preferred']!,
          _isPreferredMeta,
        ),
      );
    }
    if (data.containsKey('supports_live_data')) {
      context.handle(
        _supportsLiveDataMeta,
        supportsLiveData.isAcceptableOrUnknown(
          data['supports_live_data']!,
          _supportsLiveDataMeta,
        ),
      );
    }
    if (data.containsKey('available_metrics_json')) {
      context.handle(
        _availableMetricsJsonMeta,
        availableMetricsJson.isAcceptableOrUnknown(
          data['available_metrics_json']!,
          _availableMetricsJsonMeta,
        ),
      );
    }
    if (data.containsKey('detected_at_ms')) {
      context.handle(
        _detectedAtMsMeta,
        detectedAtMs.isAcceptableOrUnknown(
          data['detected_at_ms']!,
          _detectedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_detectedAtMsMeta);
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HealthDataSource map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HealthDataSource(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      sourceApplication: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_application'],
      )!,
      sourceBundleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_bundle_id'],
      )!,
      sourceDevice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_device'],
      )!,
      sourceModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_model'],
      )!,
      connectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}connection_id'],
      ),
      isPreferred: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_preferred'],
      )!,
      supportsLiveData: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}supports_live_data'],
      )!,
      availableMetricsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}available_metrics_json'],
      )!,
      detectedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}detected_at_ms'],
      )!,
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
    );
  }

  @override
  $HealthDataSourcesTable createAlias(String alias) {
    return $HealthDataSourcesTable(attachedDatabase, alias);
  }
}

class HealthDataSource extends DataClass
    implements Insertable<HealthDataSource> {
  final String id;
  final String ownerId;
  final String provider;
  final String sourceApplication;
  final String sourceBundleId;
  final String sourceDevice;
  final String sourceModel;
  final String? connectionId;
  final bool isPreferred;
  final bool supportsLiveData;
  final String availableMetricsJson;
  final int detectedAtMs;
  final int updatedAtMs;
  const HealthDataSource({
    required this.id,
    required this.ownerId,
    required this.provider,
    required this.sourceApplication,
    required this.sourceBundleId,
    required this.sourceDevice,
    required this.sourceModel,
    this.connectionId,
    required this.isPreferred,
    required this.supportsLiveData,
    required this.availableMetricsJson,
    required this.detectedAtMs,
    required this.updatedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['provider'] = Variable<String>(provider);
    map['source_application'] = Variable<String>(sourceApplication);
    map['source_bundle_id'] = Variable<String>(sourceBundleId);
    map['source_device'] = Variable<String>(sourceDevice);
    map['source_model'] = Variable<String>(sourceModel);
    if (!nullToAbsent || connectionId != null) {
      map['connection_id'] = Variable<String>(connectionId);
    }
    map['is_preferred'] = Variable<bool>(isPreferred);
    map['supports_live_data'] = Variable<bool>(supportsLiveData);
    map['available_metrics_json'] = Variable<String>(availableMetricsJson);
    map['detected_at_ms'] = Variable<int>(detectedAtMs);
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    return map;
  }

  HealthDataSourcesCompanion toCompanion(bool nullToAbsent) {
    return HealthDataSourcesCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      provider: Value(provider),
      sourceApplication: Value(sourceApplication),
      sourceBundleId: Value(sourceBundleId),
      sourceDevice: Value(sourceDevice),
      sourceModel: Value(sourceModel),
      connectionId: connectionId == null && nullToAbsent
          ? const Value.absent()
          : Value(connectionId),
      isPreferred: Value(isPreferred),
      supportsLiveData: Value(supportsLiveData),
      availableMetricsJson: Value(availableMetricsJson),
      detectedAtMs: Value(detectedAtMs),
      updatedAtMs: Value(updatedAtMs),
    );
  }

  factory HealthDataSource.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HealthDataSource(
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      provider: serializer.fromJson<String>(json['provider']),
      sourceApplication: serializer.fromJson<String>(json['sourceApplication']),
      sourceBundleId: serializer.fromJson<String>(json['sourceBundleId']),
      sourceDevice: serializer.fromJson<String>(json['sourceDevice']),
      sourceModel: serializer.fromJson<String>(json['sourceModel']),
      connectionId: serializer.fromJson<String?>(json['connectionId']),
      isPreferred: serializer.fromJson<bool>(json['isPreferred']),
      supportsLiveData: serializer.fromJson<bool>(json['supportsLiveData']),
      availableMetricsJson: serializer.fromJson<String>(
        json['availableMetricsJson'],
      ),
      detectedAtMs: serializer.fromJson<int>(json['detectedAtMs']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'provider': serializer.toJson<String>(provider),
      'sourceApplication': serializer.toJson<String>(sourceApplication),
      'sourceBundleId': serializer.toJson<String>(sourceBundleId),
      'sourceDevice': serializer.toJson<String>(sourceDevice),
      'sourceModel': serializer.toJson<String>(sourceModel),
      'connectionId': serializer.toJson<String?>(connectionId),
      'isPreferred': serializer.toJson<bool>(isPreferred),
      'supportsLiveData': serializer.toJson<bool>(supportsLiveData),
      'availableMetricsJson': serializer.toJson<String>(availableMetricsJson),
      'detectedAtMs': serializer.toJson<int>(detectedAtMs),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
    };
  }

  HealthDataSource copyWith({
    String? id,
    String? ownerId,
    String? provider,
    String? sourceApplication,
    String? sourceBundleId,
    String? sourceDevice,
    String? sourceModel,
    Value<String?> connectionId = const Value.absent(),
    bool? isPreferred,
    bool? supportsLiveData,
    String? availableMetricsJson,
    int? detectedAtMs,
    int? updatedAtMs,
  }) => HealthDataSource(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    provider: provider ?? this.provider,
    sourceApplication: sourceApplication ?? this.sourceApplication,
    sourceBundleId: sourceBundleId ?? this.sourceBundleId,
    sourceDevice: sourceDevice ?? this.sourceDevice,
    sourceModel: sourceModel ?? this.sourceModel,
    connectionId: connectionId.present ? connectionId.value : this.connectionId,
    isPreferred: isPreferred ?? this.isPreferred,
    supportsLiveData: supportsLiveData ?? this.supportsLiveData,
    availableMetricsJson: availableMetricsJson ?? this.availableMetricsJson,
    detectedAtMs: detectedAtMs ?? this.detectedAtMs,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
  );
  HealthDataSource copyWithCompanion(HealthDataSourcesCompanion data) {
    return HealthDataSource(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      provider: data.provider.present ? data.provider.value : this.provider,
      sourceApplication: data.sourceApplication.present
          ? data.sourceApplication.value
          : this.sourceApplication,
      sourceBundleId: data.sourceBundleId.present
          ? data.sourceBundleId.value
          : this.sourceBundleId,
      sourceDevice: data.sourceDevice.present
          ? data.sourceDevice.value
          : this.sourceDevice,
      sourceModel: data.sourceModel.present
          ? data.sourceModel.value
          : this.sourceModel,
      connectionId: data.connectionId.present
          ? data.connectionId.value
          : this.connectionId,
      isPreferred: data.isPreferred.present
          ? data.isPreferred.value
          : this.isPreferred,
      supportsLiveData: data.supportsLiveData.present
          ? data.supportsLiveData.value
          : this.supportsLiveData,
      availableMetricsJson: data.availableMetricsJson.present
          ? data.availableMetricsJson.value
          : this.availableMetricsJson,
      detectedAtMs: data.detectedAtMs.present
          ? data.detectedAtMs.value
          : this.detectedAtMs,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HealthDataSource(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('provider: $provider, ')
          ..write('sourceApplication: $sourceApplication, ')
          ..write('sourceBundleId: $sourceBundleId, ')
          ..write('sourceDevice: $sourceDevice, ')
          ..write('sourceModel: $sourceModel, ')
          ..write('connectionId: $connectionId, ')
          ..write('isPreferred: $isPreferred, ')
          ..write('supportsLiveData: $supportsLiveData, ')
          ..write('availableMetricsJson: $availableMetricsJson, ')
          ..write('detectedAtMs: $detectedAtMs, ')
          ..write('updatedAtMs: $updatedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerId,
    provider,
    sourceApplication,
    sourceBundleId,
    sourceDevice,
    sourceModel,
    connectionId,
    isPreferred,
    supportsLiveData,
    availableMetricsJson,
    detectedAtMs,
    updatedAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HealthDataSource &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.provider == this.provider &&
          other.sourceApplication == this.sourceApplication &&
          other.sourceBundleId == this.sourceBundleId &&
          other.sourceDevice == this.sourceDevice &&
          other.sourceModel == this.sourceModel &&
          other.connectionId == this.connectionId &&
          other.isPreferred == this.isPreferred &&
          other.supportsLiveData == this.supportsLiveData &&
          other.availableMetricsJson == this.availableMetricsJson &&
          other.detectedAtMs == this.detectedAtMs &&
          other.updatedAtMs == this.updatedAtMs);
}

class HealthDataSourcesCompanion extends UpdateCompanion<HealthDataSource> {
  final Value<String> id;
  final Value<String> ownerId;
  final Value<String> provider;
  final Value<String> sourceApplication;
  final Value<String> sourceBundleId;
  final Value<String> sourceDevice;
  final Value<String> sourceModel;
  final Value<String?> connectionId;
  final Value<bool> isPreferred;
  final Value<bool> supportsLiveData;
  final Value<String> availableMetricsJson;
  final Value<int> detectedAtMs;
  final Value<int> updatedAtMs;
  final Value<int> rowid;
  const HealthDataSourcesCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.provider = const Value.absent(),
    this.sourceApplication = const Value.absent(),
    this.sourceBundleId = const Value.absent(),
    this.sourceDevice = const Value.absent(),
    this.sourceModel = const Value.absent(),
    this.connectionId = const Value.absent(),
    this.isPreferred = const Value.absent(),
    this.supportsLiveData = const Value.absent(),
    this.availableMetricsJson = const Value.absent(),
    this.detectedAtMs = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HealthDataSourcesCompanion.insert({
    required String id,
    this.ownerId = const Value.absent(),
    required String provider,
    this.sourceApplication = const Value.absent(),
    this.sourceBundleId = const Value.absent(),
    this.sourceDevice = const Value.absent(),
    this.sourceModel = const Value.absent(),
    this.connectionId = const Value.absent(),
    this.isPreferred = const Value.absent(),
    this.supportsLiveData = const Value.absent(),
    this.availableMetricsJson = const Value.absent(),
    required int detectedAtMs,
    required int updatedAtMs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       provider = Value(provider),
       detectedAtMs = Value(detectedAtMs),
       updatedAtMs = Value(updatedAtMs);
  static Insertable<HealthDataSource> custom({
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<String>? provider,
    Expression<String>? sourceApplication,
    Expression<String>? sourceBundleId,
    Expression<String>? sourceDevice,
    Expression<String>? sourceModel,
    Expression<String>? connectionId,
    Expression<bool>? isPreferred,
    Expression<bool>? supportsLiveData,
    Expression<String>? availableMetricsJson,
    Expression<int>? detectedAtMs,
    Expression<int>? updatedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (provider != null) 'provider': provider,
      if (sourceApplication != null) 'source_application': sourceApplication,
      if (sourceBundleId != null) 'source_bundle_id': sourceBundleId,
      if (sourceDevice != null) 'source_device': sourceDevice,
      if (sourceModel != null) 'source_model': sourceModel,
      if (connectionId != null) 'connection_id': connectionId,
      if (isPreferred != null) 'is_preferred': isPreferred,
      if (supportsLiveData != null) 'supports_live_data': supportsLiveData,
      if (availableMetricsJson != null)
        'available_metrics_json': availableMetricsJson,
      if (detectedAtMs != null) 'detected_at_ms': detectedAtMs,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HealthDataSourcesCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerId,
    Value<String>? provider,
    Value<String>? sourceApplication,
    Value<String>? sourceBundleId,
    Value<String>? sourceDevice,
    Value<String>? sourceModel,
    Value<String?>? connectionId,
    Value<bool>? isPreferred,
    Value<bool>? supportsLiveData,
    Value<String>? availableMetricsJson,
    Value<int>? detectedAtMs,
    Value<int>? updatedAtMs,
    Value<int>? rowid,
  }) {
    return HealthDataSourcesCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      provider: provider ?? this.provider,
      sourceApplication: sourceApplication ?? this.sourceApplication,
      sourceBundleId: sourceBundleId ?? this.sourceBundleId,
      sourceDevice: sourceDevice ?? this.sourceDevice,
      sourceModel: sourceModel ?? this.sourceModel,
      connectionId: connectionId ?? this.connectionId,
      isPreferred: isPreferred ?? this.isPreferred,
      supportsLiveData: supportsLiveData ?? this.supportsLiveData,
      availableMetricsJson: availableMetricsJson ?? this.availableMetricsJson,
      detectedAtMs: detectedAtMs ?? this.detectedAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (sourceApplication.present) {
      map['source_application'] = Variable<String>(sourceApplication.value);
    }
    if (sourceBundleId.present) {
      map['source_bundle_id'] = Variable<String>(sourceBundleId.value);
    }
    if (sourceDevice.present) {
      map['source_device'] = Variable<String>(sourceDevice.value);
    }
    if (sourceModel.present) {
      map['source_model'] = Variable<String>(sourceModel.value);
    }
    if (connectionId.present) {
      map['connection_id'] = Variable<String>(connectionId.value);
    }
    if (isPreferred.present) {
      map['is_preferred'] = Variable<bool>(isPreferred.value);
    }
    if (supportsLiveData.present) {
      map['supports_live_data'] = Variable<bool>(supportsLiveData.value);
    }
    if (availableMetricsJson.present) {
      map['available_metrics_json'] = Variable<String>(
        availableMetricsJson.value,
      );
    }
    if (detectedAtMs.present) {
      map['detected_at_ms'] = Variable<int>(detectedAtMs.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HealthDataSourcesCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('provider: $provider, ')
          ..write('sourceApplication: $sourceApplication, ')
          ..write('sourceBundleId: $sourceBundleId, ')
          ..write('sourceDevice: $sourceDevice, ')
          ..write('sourceModel: $sourceModel, ')
          ..write('connectionId: $connectionId, ')
          ..write('isPreferred: $isPreferred, ')
          ..write('supportsLiveData: $supportsLiveData, ')
          ..write('availableMetricsJson: $availableMetricsJson, ')
          ..write('detectedAtMs: $detectedAtMs, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HealthMetricRecordsTable extends HealthMetricRecords
    with TableInfo<$HealthMetricRecordsTable, HealthMetricRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HealthMetricRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES health_data_sources (id)',
    ),
  );
  static const VerificationMeta _externalRecordIdMeta = const VerificationMeta(
    'externalRecordId',
  );
  @override
  late final GeneratedColumn<String> externalRecordId = GeneratedColumn<String>(
    'external_record_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metricTypeMeta = const VerificationMeta(
    'metricType',
  );
  @override
  late final GeneratedColumn<String> metricType = GeneratedColumn<String>(
    'metric_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startTimeMsMeta = const VerificationMeta(
    'startTimeMs',
  );
  @override
  late final GeneratedColumn<int> startTimeMs = GeneratedColumn<int>(
    'start_time_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endTimeMsMeta = const VerificationMeta(
    'endTimeMs',
  );
  @override
  late final GeneratedColumn<int> endTimeMs = GeneratedColumn<int>(
    'end_time_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<double> value = GeneratedColumn<double>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metadataJsonMeta = const VerificationMeta(
    'metadataJson',
  );
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
    'metadata_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _contentHashMeta = const VerificationMeta(
    'contentHash',
  );
  @override
  late final GeneratedColumn<String> contentHash = GeneratedColumn<String>(
    'content_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncVersionMeta = const VerificationMeta(
    'syncVersion',
  );
  @override
  late final GeneratedColumn<int> syncVersion = GeneratedColumn<int>(
    'sync_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerId,
    provider,
    sourceId,
    externalRecordId,
    metricType,
    startTimeMs,
    endTimeMs,
    value,
    unit,
    metadataJson,
    contentHash,
    syncVersion,
    synced,
    createdAtMs,
    updatedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'health_metric_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<HealthMetricRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('external_record_id')) {
      context.handle(
        _externalRecordIdMeta,
        externalRecordId.isAcceptableOrUnknown(
          data['external_record_id']!,
          _externalRecordIdMeta,
        ),
      );
    }
    if (data.containsKey('metric_type')) {
      context.handle(
        _metricTypeMeta,
        metricType.isAcceptableOrUnknown(data['metric_type']!, _metricTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_metricTypeMeta);
    }
    if (data.containsKey('start_time_ms')) {
      context.handle(
        _startTimeMsMeta,
        startTimeMs.isAcceptableOrUnknown(
          data['start_time_ms']!,
          _startTimeMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startTimeMsMeta);
    }
    if (data.containsKey('end_time_ms')) {
      context.handle(
        _endTimeMsMeta,
        endTimeMs.isAcceptableOrUnknown(data['end_time_ms']!, _endTimeMsMeta),
      );
    } else if (isInserting) {
      context.missing(_endTimeMsMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
        _metadataJsonMeta,
        metadataJson.isAcceptableOrUnknown(
          data['metadata_json']!,
          _metadataJsonMeta,
        ),
      );
    }
    if (data.containsKey('content_hash')) {
      context.handle(
        _contentHashMeta,
        contentHash.isAcceptableOrUnknown(
          data['content_hash']!,
          _contentHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentHashMeta);
    }
    if (data.containsKey('sync_version')) {
      context.handle(
        _syncVersionMeta,
        syncVersion.isAcceptableOrUnknown(
          data['sync_version']!,
          _syncVersionMeta,
        ),
      );
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HealthMetricRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HealthMetricRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      externalRecordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_record_id'],
      ),
      metricType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metric_type'],
      )!,
      startTimeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_time_ms'],
      )!,
      endTimeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}end_time_ms'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}value'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      metadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_json'],
      )!,
      contentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_hash'],
      )!,
      syncVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sync_version'],
      )!,
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
    );
  }

  @override
  $HealthMetricRecordsTable createAlias(String alias) {
    return $HealthMetricRecordsTable(attachedDatabase, alias);
  }
}

class HealthMetricRecord extends DataClass
    implements Insertable<HealthMetricRecord> {
  final String id;
  final String ownerId;
  final String provider;
  final String sourceId;
  final String? externalRecordId;
  final String metricType;
  final int startTimeMs;
  final int endTimeMs;
  final double value;
  final String unit;
  final String metadataJson;
  final String contentHash;
  final int syncVersion;
  final bool synced;
  final int createdAtMs;
  final int updatedAtMs;
  const HealthMetricRecord({
    required this.id,
    required this.ownerId,
    required this.provider,
    required this.sourceId,
    this.externalRecordId,
    required this.metricType,
    required this.startTimeMs,
    required this.endTimeMs,
    required this.value,
    required this.unit,
    required this.metadataJson,
    required this.contentHash,
    required this.syncVersion,
    required this.synced,
    required this.createdAtMs,
    required this.updatedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['provider'] = Variable<String>(provider);
    map['source_id'] = Variable<String>(sourceId);
    if (!nullToAbsent || externalRecordId != null) {
      map['external_record_id'] = Variable<String>(externalRecordId);
    }
    map['metric_type'] = Variable<String>(metricType);
    map['start_time_ms'] = Variable<int>(startTimeMs);
    map['end_time_ms'] = Variable<int>(endTimeMs);
    map['value'] = Variable<double>(value);
    map['unit'] = Variable<String>(unit);
    map['metadata_json'] = Variable<String>(metadataJson);
    map['content_hash'] = Variable<String>(contentHash);
    map['sync_version'] = Variable<int>(syncVersion);
    map['synced'] = Variable<bool>(synced);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    return map;
  }

  HealthMetricRecordsCompanion toCompanion(bool nullToAbsent) {
    return HealthMetricRecordsCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      provider: Value(provider),
      sourceId: Value(sourceId),
      externalRecordId: externalRecordId == null && nullToAbsent
          ? const Value.absent()
          : Value(externalRecordId),
      metricType: Value(metricType),
      startTimeMs: Value(startTimeMs),
      endTimeMs: Value(endTimeMs),
      value: Value(value),
      unit: Value(unit),
      metadataJson: Value(metadataJson),
      contentHash: Value(contentHash),
      syncVersion: Value(syncVersion),
      synced: Value(synced),
      createdAtMs: Value(createdAtMs),
      updatedAtMs: Value(updatedAtMs),
    );
  }

  factory HealthMetricRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HealthMetricRecord(
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      provider: serializer.fromJson<String>(json['provider']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      externalRecordId: serializer.fromJson<String?>(json['externalRecordId']),
      metricType: serializer.fromJson<String>(json['metricType']),
      startTimeMs: serializer.fromJson<int>(json['startTimeMs']),
      endTimeMs: serializer.fromJson<int>(json['endTimeMs']),
      value: serializer.fromJson<double>(json['value']),
      unit: serializer.fromJson<String>(json['unit']),
      metadataJson: serializer.fromJson<String>(json['metadataJson']),
      contentHash: serializer.fromJson<String>(json['contentHash']),
      syncVersion: serializer.fromJson<int>(json['syncVersion']),
      synced: serializer.fromJson<bool>(json['synced']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'provider': serializer.toJson<String>(provider),
      'sourceId': serializer.toJson<String>(sourceId),
      'externalRecordId': serializer.toJson<String?>(externalRecordId),
      'metricType': serializer.toJson<String>(metricType),
      'startTimeMs': serializer.toJson<int>(startTimeMs),
      'endTimeMs': serializer.toJson<int>(endTimeMs),
      'value': serializer.toJson<double>(value),
      'unit': serializer.toJson<String>(unit),
      'metadataJson': serializer.toJson<String>(metadataJson),
      'contentHash': serializer.toJson<String>(contentHash),
      'syncVersion': serializer.toJson<int>(syncVersion),
      'synced': serializer.toJson<bool>(synced),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
    };
  }

  HealthMetricRecord copyWith({
    String? id,
    String? ownerId,
    String? provider,
    String? sourceId,
    Value<String?> externalRecordId = const Value.absent(),
    String? metricType,
    int? startTimeMs,
    int? endTimeMs,
    double? value,
    String? unit,
    String? metadataJson,
    String? contentHash,
    int? syncVersion,
    bool? synced,
    int? createdAtMs,
    int? updatedAtMs,
  }) => HealthMetricRecord(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    provider: provider ?? this.provider,
    sourceId: sourceId ?? this.sourceId,
    externalRecordId: externalRecordId.present
        ? externalRecordId.value
        : this.externalRecordId,
    metricType: metricType ?? this.metricType,
    startTimeMs: startTimeMs ?? this.startTimeMs,
    endTimeMs: endTimeMs ?? this.endTimeMs,
    value: value ?? this.value,
    unit: unit ?? this.unit,
    metadataJson: metadataJson ?? this.metadataJson,
    contentHash: contentHash ?? this.contentHash,
    syncVersion: syncVersion ?? this.syncVersion,
    synced: synced ?? this.synced,
    createdAtMs: createdAtMs ?? this.createdAtMs,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
  );
  HealthMetricRecord copyWithCompanion(HealthMetricRecordsCompanion data) {
    return HealthMetricRecord(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      provider: data.provider.present ? data.provider.value : this.provider,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      externalRecordId: data.externalRecordId.present
          ? data.externalRecordId.value
          : this.externalRecordId,
      metricType: data.metricType.present
          ? data.metricType.value
          : this.metricType,
      startTimeMs: data.startTimeMs.present
          ? data.startTimeMs.value
          : this.startTimeMs,
      endTimeMs: data.endTimeMs.present ? data.endTimeMs.value : this.endTimeMs,
      value: data.value.present ? data.value.value : this.value,
      unit: data.unit.present ? data.unit.value : this.unit,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
      contentHash: data.contentHash.present
          ? data.contentHash.value
          : this.contentHash,
      syncVersion: data.syncVersion.present
          ? data.syncVersion.value
          : this.syncVersion,
      synced: data.synced.present ? data.synced.value : this.synced,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HealthMetricRecord(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('provider: $provider, ')
          ..write('sourceId: $sourceId, ')
          ..write('externalRecordId: $externalRecordId, ')
          ..write('metricType: $metricType, ')
          ..write('startTimeMs: $startTimeMs, ')
          ..write('endTimeMs: $endTimeMs, ')
          ..write('value: $value, ')
          ..write('unit: $unit, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('contentHash: $contentHash, ')
          ..write('syncVersion: $syncVersion, ')
          ..write('synced: $synced, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('updatedAtMs: $updatedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerId,
    provider,
    sourceId,
    externalRecordId,
    metricType,
    startTimeMs,
    endTimeMs,
    value,
    unit,
    metadataJson,
    contentHash,
    syncVersion,
    synced,
    createdAtMs,
    updatedAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HealthMetricRecord &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.provider == this.provider &&
          other.sourceId == this.sourceId &&
          other.externalRecordId == this.externalRecordId &&
          other.metricType == this.metricType &&
          other.startTimeMs == this.startTimeMs &&
          other.endTimeMs == this.endTimeMs &&
          other.value == this.value &&
          other.unit == this.unit &&
          other.metadataJson == this.metadataJson &&
          other.contentHash == this.contentHash &&
          other.syncVersion == this.syncVersion &&
          other.synced == this.synced &&
          other.createdAtMs == this.createdAtMs &&
          other.updatedAtMs == this.updatedAtMs);
}

class HealthMetricRecordsCompanion extends UpdateCompanion<HealthMetricRecord> {
  final Value<String> id;
  final Value<String> ownerId;
  final Value<String> provider;
  final Value<String> sourceId;
  final Value<String?> externalRecordId;
  final Value<String> metricType;
  final Value<int> startTimeMs;
  final Value<int> endTimeMs;
  final Value<double> value;
  final Value<String> unit;
  final Value<String> metadataJson;
  final Value<String> contentHash;
  final Value<int> syncVersion;
  final Value<bool> synced;
  final Value<int> createdAtMs;
  final Value<int> updatedAtMs;
  final Value<int> rowid;
  const HealthMetricRecordsCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.provider = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.externalRecordId = const Value.absent(),
    this.metricType = const Value.absent(),
    this.startTimeMs = const Value.absent(),
    this.endTimeMs = const Value.absent(),
    this.value = const Value.absent(),
    this.unit = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.contentHash = const Value.absent(),
    this.syncVersion = const Value.absent(),
    this.synced = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HealthMetricRecordsCompanion.insert({
    required String id,
    this.ownerId = const Value.absent(),
    required String provider,
    required String sourceId,
    this.externalRecordId = const Value.absent(),
    required String metricType,
    required int startTimeMs,
    required int endTimeMs,
    required double value,
    required String unit,
    this.metadataJson = const Value.absent(),
    required String contentHash,
    this.syncVersion = const Value.absent(),
    this.synced = const Value.absent(),
    required int createdAtMs,
    required int updatedAtMs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       provider = Value(provider),
       sourceId = Value(sourceId),
       metricType = Value(metricType),
       startTimeMs = Value(startTimeMs),
       endTimeMs = Value(endTimeMs),
       value = Value(value),
       unit = Value(unit),
       contentHash = Value(contentHash),
       createdAtMs = Value(createdAtMs),
       updatedAtMs = Value(updatedAtMs);
  static Insertable<HealthMetricRecord> custom({
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<String>? provider,
    Expression<String>? sourceId,
    Expression<String>? externalRecordId,
    Expression<String>? metricType,
    Expression<int>? startTimeMs,
    Expression<int>? endTimeMs,
    Expression<double>? value,
    Expression<String>? unit,
    Expression<String>? metadataJson,
    Expression<String>? contentHash,
    Expression<int>? syncVersion,
    Expression<bool>? synced,
    Expression<int>? createdAtMs,
    Expression<int>? updatedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (provider != null) 'provider': provider,
      if (sourceId != null) 'source_id': sourceId,
      if (externalRecordId != null) 'external_record_id': externalRecordId,
      if (metricType != null) 'metric_type': metricType,
      if (startTimeMs != null) 'start_time_ms': startTimeMs,
      if (endTimeMs != null) 'end_time_ms': endTimeMs,
      if (value != null) 'value': value,
      if (unit != null) 'unit': unit,
      if (metadataJson != null) 'metadata_json': metadataJson,
      if (contentHash != null) 'content_hash': contentHash,
      if (syncVersion != null) 'sync_version': syncVersion,
      if (synced != null) 'synced': synced,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HealthMetricRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerId,
    Value<String>? provider,
    Value<String>? sourceId,
    Value<String?>? externalRecordId,
    Value<String>? metricType,
    Value<int>? startTimeMs,
    Value<int>? endTimeMs,
    Value<double>? value,
    Value<String>? unit,
    Value<String>? metadataJson,
    Value<String>? contentHash,
    Value<int>? syncVersion,
    Value<bool>? synced,
    Value<int>? createdAtMs,
    Value<int>? updatedAtMs,
    Value<int>? rowid,
  }) {
    return HealthMetricRecordsCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      provider: provider ?? this.provider,
      sourceId: sourceId ?? this.sourceId,
      externalRecordId: externalRecordId ?? this.externalRecordId,
      metricType: metricType ?? this.metricType,
      startTimeMs: startTimeMs ?? this.startTimeMs,
      endTimeMs: endTimeMs ?? this.endTimeMs,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      metadataJson: metadataJson ?? this.metadataJson,
      contentHash: contentHash ?? this.contentHash,
      syncVersion: syncVersion ?? this.syncVersion,
      synced: synced ?? this.synced,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (externalRecordId.present) {
      map['external_record_id'] = Variable<String>(externalRecordId.value);
    }
    if (metricType.present) {
      map['metric_type'] = Variable<String>(metricType.value);
    }
    if (startTimeMs.present) {
      map['start_time_ms'] = Variable<int>(startTimeMs.value);
    }
    if (endTimeMs.present) {
      map['end_time_ms'] = Variable<int>(endTimeMs.value);
    }
    if (value.present) {
      map['value'] = Variable<double>(value.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    if (contentHash.present) {
      map['content_hash'] = Variable<String>(contentHash.value);
    }
    if (syncVersion.present) {
      map['sync_version'] = Variable<int>(syncVersion.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HealthMetricRecordsCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('provider: $provider, ')
          ..write('sourceId: $sourceId, ')
          ..write('externalRecordId: $externalRecordId, ')
          ..write('metricType: $metricType, ')
          ..write('startTimeMs: $startTimeMs, ')
          ..write('endTimeMs: $endTimeMs, ')
          ..write('value: $value, ')
          ..write('unit: $unit, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('contentHash: $contentHash, ')
          ..write('syncVersion: $syncVersion, ')
          ..write('synced: $synced, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HealthSourcePreferencesTable extends HealthSourcePreferences
    with TableInfo<$HealthSourcePreferencesTable, HealthSourcePreference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HealthSourcePreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  static const VerificationMeta _metricTypeMeta = const VerificationMeta(
    'metricType',
  );
  @override
  late final GeneratedColumn<String> metricType = GeneratedColumn<String>(
    'metric_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES health_data_sources (id)',
    ),
  );
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    ownerId,
    metricType,
    sourceId,
    updatedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'health_source_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<HealthSourcePreference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    }
    if (data.containsKey('metric_type')) {
      context.handle(
        _metricTypeMeta,
        metricType.isAcceptableOrUnknown(data['metric_type']!, _metricTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_metricTypeMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ownerId, metricType};
  @override
  HealthSourcePreference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HealthSourcePreference(
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      metricType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metric_type'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
    );
  }

  @override
  $HealthSourcePreferencesTable createAlias(String alias) {
    return $HealthSourcePreferencesTable(attachedDatabase, alias);
  }
}

class HealthSourcePreference extends DataClass
    implements Insertable<HealthSourcePreference> {
  final String ownerId;
  final String metricType;
  final String sourceId;
  final int updatedAtMs;
  const HealthSourcePreference({
    required this.ownerId,
    required this.metricType,
    required this.sourceId,
    required this.updatedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['owner_id'] = Variable<String>(ownerId);
    map['metric_type'] = Variable<String>(metricType);
    map['source_id'] = Variable<String>(sourceId);
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    return map;
  }

  HealthSourcePreferencesCompanion toCompanion(bool nullToAbsent) {
    return HealthSourcePreferencesCompanion(
      ownerId: Value(ownerId),
      metricType: Value(metricType),
      sourceId: Value(sourceId),
      updatedAtMs: Value(updatedAtMs),
    );
  }

  factory HealthSourcePreference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HealthSourcePreference(
      ownerId: serializer.fromJson<String>(json['ownerId']),
      metricType: serializer.fromJson<String>(json['metricType']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ownerId': serializer.toJson<String>(ownerId),
      'metricType': serializer.toJson<String>(metricType),
      'sourceId': serializer.toJson<String>(sourceId),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
    };
  }

  HealthSourcePreference copyWith({
    String? ownerId,
    String? metricType,
    String? sourceId,
    int? updatedAtMs,
  }) => HealthSourcePreference(
    ownerId: ownerId ?? this.ownerId,
    metricType: metricType ?? this.metricType,
    sourceId: sourceId ?? this.sourceId,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
  );
  HealthSourcePreference copyWithCompanion(
    HealthSourcePreferencesCompanion data,
  ) {
    return HealthSourcePreference(
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      metricType: data.metricType.present
          ? data.metricType.value
          : this.metricType,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HealthSourcePreference(')
          ..write('ownerId: $ownerId, ')
          ..write('metricType: $metricType, ')
          ..write('sourceId: $sourceId, ')
          ..write('updatedAtMs: $updatedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(ownerId, metricType, sourceId, updatedAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HealthSourcePreference &&
          other.ownerId == this.ownerId &&
          other.metricType == this.metricType &&
          other.sourceId == this.sourceId &&
          other.updatedAtMs == this.updatedAtMs);
}

class HealthSourcePreferencesCompanion
    extends UpdateCompanion<HealthSourcePreference> {
  final Value<String> ownerId;
  final Value<String> metricType;
  final Value<String> sourceId;
  final Value<int> updatedAtMs;
  final Value<int> rowid;
  const HealthSourcePreferencesCompanion({
    this.ownerId = const Value.absent(),
    this.metricType = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HealthSourcePreferencesCompanion.insert({
    this.ownerId = const Value.absent(),
    required String metricType,
    required String sourceId,
    required int updatedAtMs,
    this.rowid = const Value.absent(),
  }) : metricType = Value(metricType),
       sourceId = Value(sourceId),
       updatedAtMs = Value(updatedAtMs);
  static Insertable<HealthSourcePreference> custom({
    Expression<String>? ownerId,
    Expression<String>? metricType,
    Expression<String>? sourceId,
    Expression<int>? updatedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ownerId != null) 'owner_id': ownerId,
      if (metricType != null) 'metric_type': metricType,
      if (sourceId != null) 'source_id': sourceId,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HealthSourcePreferencesCompanion copyWith({
    Value<String>? ownerId,
    Value<String>? metricType,
    Value<String>? sourceId,
    Value<int>? updatedAtMs,
    Value<int>? rowid,
  }) {
    return HealthSourcePreferencesCompanion(
      ownerId: ownerId ?? this.ownerId,
      metricType: metricType ?? this.metricType,
      sourceId: sourceId ?? this.sourceId,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (metricType.present) {
      map['metric_type'] = Variable<String>(metricType.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HealthSourcePreferencesCompanion(')
          ..write('ownerId: $ownerId, ')
          ..write('metricType: $metricType, ')
          ..write('sourceId: $sourceId, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MatchHealthSummariesTable extends MatchHealthSummaries
    with TableInfo<$MatchHealthSummariesTable, MatchHealthSummary> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MatchHealthSummariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _matchIdMeta = const VerificationMeta(
    'matchId',
  );
  @override
  late final GeneratedColumn<String> matchId = GeneratedColumn<String>(
    'match_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES matches (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  static const VerificationMeta _primarySourceIdMeta = const VerificationMeta(
    'primarySourceId',
  );
  @override
  late final GeneratedColumn<String> primarySourceId = GeneratedColumn<String>(
    'primary_source_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES health_data_sources (id)',
    ),
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _averageHeartRateMeta = const VerificationMeta(
    'averageHeartRate',
  );
  @override
  late final GeneratedColumn<double> averageHeartRate = GeneratedColumn<double>(
    'average_heart_rate',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxHeartRateMeta = const VerificationMeta(
    'maxHeartRate',
  );
  @override
  late final GeneratedColumn<double> maxHeartRate = GeneratedColumn<double>(
    'max_heart_rate',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _minHeartRateMeta = const VerificationMeta(
    'minHeartRate',
  );
  @override
  late final GeneratedColumn<double> minHeartRate = GeneratedColumn<double>(
    'min_heart_rate',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activeEnergyKcalMeta = const VerificationMeta(
    'activeEnergyKcal',
  );
  @override
  late final GeneratedColumn<double> activeEnergyKcal = GeneratedColumn<double>(
    'active_energy_kcal',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalEnergyKcalMeta = const VerificationMeta(
    'totalEnergyKcal',
  );
  @override
  late final GeneratedColumn<double> totalEnergyKcal = GeneratedColumn<double>(
    'total_energy_kcal',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stepsMeta = const VerificationMeta('steps');
  @override
  late final GeneratedColumn<int> steps = GeneratedColumn<int>(
    'steps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _distanceMetersMeta = const VerificationMeta(
    'distanceMeters',
  );
  @override
  late final GeneratedColumn<double> distanceMeters = GeneratedColumn<double>(
    'distance_meters',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _highIntensityMinutesMeta =
      const VerificationMeta('highIntensityMinutes');
  @override
  late final GeneratedColumn<int> highIntensityMinutes = GeneratedColumn<int>(
    'high_intensity_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recoveryDeltaMeta = const VerificationMeta(
    'recoveryDelta',
  );
  @override
  late final GeneratedColumn<double> recoveryDelta = GeneratedColumn<double>(
    'recovery_delta',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sleepScoreMeta = const VerificationMeta(
    'sleepScore',
  );
  @override
  late final GeneratedColumn<double> sleepScore = GeneratedColumn<double>(
    'sleep_score',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _readinessScoreMeta = const VerificationMeta(
    'readinessScore',
  );
  @override
  late final GeneratedColumn<double> readinessScore = GeneratedColumn<double>(
    'readiness_score',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recoveryScoreMeta = const VerificationMeta(
    'recoveryScore',
  );
  @override
  late final GeneratedColumn<double> recoveryScore = GeneratedColumn<double>(
    'recovery_score',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _strainScoreMeta = const VerificationMeta(
    'strainScore',
  );
  @override
  late final GeneratedColumn<double> strainScore = GeneratedColumn<double>(
    'strain_score',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dataQualityMeta = const VerificationMeta(
    'dataQuality',
  );
  @override
  late final GeneratedColumn<String> dataQuality = GeneratedColumn<String>(
    'data_quality',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('UNKNOWN'),
  );
  static const VerificationMeta _calculatedAtMsMeta = const VerificationMeta(
    'calculatedAtMs',
  );
  @override
  late final GeneratedColumn<int> calculatedAtMs = GeneratedColumn<int>(
    'calculated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    matchId,
    ownerId,
    primarySourceId,
    durationSeconds,
    averageHeartRate,
    maxHeartRate,
    minHeartRate,
    activeEnergyKcal,
    totalEnergyKcal,
    steps,
    distanceMeters,
    highIntensityMinutes,
    recoveryDelta,
    sleepScore,
    readinessScore,
    recoveryScore,
    strainScore,
    dataQuality,
    calculatedAtMs,
    synced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'match_health_summaries';
  @override
  VerificationContext validateIntegrity(
    Insertable<MatchHealthSummary> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('match_id')) {
      context.handle(
        _matchIdMeta,
        matchId.isAcceptableOrUnknown(data['match_id']!, _matchIdMeta),
      );
    } else if (isInserting) {
      context.missing(_matchIdMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    }
    if (data.containsKey('primary_source_id')) {
      context.handle(
        _primarySourceIdMeta,
        primarySourceId.isAcceptableOrUnknown(
          data['primary_source_id']!,
          _primarySourceIdMeta,
        ),
      );
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('average_heart_rate')) {
      context.handle(
        _averageHeartRateMeta,
        averageHeartRate.isAcceptableOrUnknown(
          data['average_heart_rate']!,
          _averageHeartRateMeta,
        ),
      );
    }
    if (data.containsKey('max_heart_rate')) {
      context.handle(
        _maxHeartRateMeta,
        maxHeartRate.isAcceptableOrUnknown(
          data['max_heart_rate']!,
          _maxHeartRateMeta,
        ),
      );
    }
    if (data.containsKey('min_heart_rate')) {
      context.handle(
        _minHeartRateMeta,
        minHeartRate.isAcceptableOrUnknown(
          data['min_heart_rate']!,
          _minHeartRateMeta,
        ),
      );
    }
    if (data.containsKey('active_energy_kcal')) {
      context.handle(
        _activeEnergyKcalMeta,
        activeEnergyKcal.isAcceptableOrUnknown(
          data['active_energy_kcal']!,
          _activeEnergyKcalMeta,
        ),
      );
    }
    if (data.containsKey('total_energy_kcal')) {
      context.handle(
        _totalEnergyKcalMeta,
        totalEnergyKcal.isAcceptableOrUnknown(
          data['total_energy_kcal']!,
          _totalEnergyKcalMeta,
        ),
      );
    }
    if (data.containsKey('steps')) {
      context.handle(
        _stepsMeta,
        steps.isAcceptableOrUnknown(data['steps']!, _stepsMeta),
      );
    }
    if (data.containsKey('distance_meters')) {
      context.handle(
        _distanceMetersMeta,
        distanceMeters.isAcceptableOrUnknown(
          data['distance_meters']!,
          _distanceMetersMeta,
        ),
      );
    }
    if (data.containsKey('high_intensity_minutes')) {
      context.handle(
        _highIntensityMinutesMeta,
        highIntensityMinutes.isAcceptableOrUnknown(
          data['high_intensity_minutes']!,
          _highIntensityMinutesMeta,
        ),
      );
    }
    if (data.containsKey('recovery_delta')) {
      context.handle(
        _recoveryDeltaMeta,
        recoveryDelta.isAcceptableOrUnknown(
          data['recovery_delta']!,
          _recoveryDeltaMeta,
        ),
      );
    }
    if (data.containsKey('sleep_score')) {
      context.handle(
        _sleepScoreMeta,
        sleepScore.isAcceptableOrUnknown(data['sleep_score']!, _sleepScoreMeta),
      );
    }
    if (data.containsKey('readiness_score')) {
      context.handle(
        _readinessScoreMeta,
        readinessScore.isAcceptableOrUnknown(
          data['readiness_score']!,
          _readinessScoreMeta,
        ),
      );
    }
    if (data.containsKey('recovery_score')) {
      context.handle(
        _recoveryScoreMeta,
        recoveryScore.isAcceptableOrUnknown(
          data['recovery_score']!,
          _recoveryScoreMeta,
        ),
      );
    }
    if (data.containsKey('strain_score')) {
      context.handle(
        _strainScoreMeta,
        strainScore.isAcceptableOrUnknown(
          data['strain_score']!,
          _strainScoreMeta,
        ),
      );
    }
    if (data.containsKey('data_quality')) {
      context.handle(
        _dataQualityMeta,
        dataQuality.isAcceptableOrUnknown(
          data['data_quality']!,
          _dataQualityMeta,
        ),
      );
    }
    if (data.containsKey('calculated_at_ms')) {
      context.handle(
        _calculatedAtMsMeta,
        calculatedAtMs.isAcceptableOrUnknown(
          data['calculated_at_ms']!,
          _calculatedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_calculatedAtMsMeta);
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MatchHealthSummary map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MatchHealthSummary(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      matchId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}match_id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      primarySourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}primary_source_id'],
      ),
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      ),
      averageHeartRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}average_heart_rate'],
      ),
      maxHeartRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}max_heart_rate'],
      ),
      minHeartRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}min_heart_rate'],
      ),
      activeEnergyKcal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}active_energy_kcal'],
      ),
      totalEnergyKcal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_energy_kcal'],
      ),
      steps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}steps'],
      ),
      distanceMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}distance_meters'],
      ),
      highIntensityMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}high_intensity_minutes'],
      ),
      recoveryDelta: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}recovery_delta'],
      ),
      sleepScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sleep_score'],
      ),
      readinessScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}readiness_score'],
      ),
      recoveryScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}recovery_score'],
      ),
      strainScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}strain_score'],
      ),
      dataQuality: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_quality'],
      )!,
      calculatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}calculated_at_ms'],
      )!,
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
    );
  }

  @override
  $MatchHealthSummariesTable createAlias(String alias) {
    return $MatchHealthSummariesTable(attachedDatabase, alias);
  }
}

class MatchHealthSummary extends DataClass
    implements Insertable<MatchHealthSummary> {
  final String id;
  final String matchId;
  final String ownerId;
  final String? primarySourceId;
  final int? durationSeconds;
  final double? averageHeartRate;
  final double? maxHeartRate;
  final double? minHeartRate;
  final double? activeEnergyKcal;
  final double? totalEnergyKcal;
  final int? steps;
  final double? distanceMeters;
  final int? highIntensityMinutes;
  final double? recoveryDelta;
  final double? sleepScore;
  final double? readinessScore;
  final double? recoveryScore;
  final double? strainScore;
  final String dataQuality;
  final int calculatedAtMs;
  final bool synced;
  const MatchHealthSummary({
    required this.id,
    required this.matchId,
    required this.ownerId,
    this.primarySourceId,
    this.durationSeconds,
    this.averageHeartRate,
    this.maxHeartRate,
    this.minHeartRate,
    this.activeEnergyKcal,
    this.totalEnergyKcal,
    this.steps,
    this.distanceMeters,
    this.highIntensityMinutes,
    this.recoveryDelta,
    this.sleepScore,
    this.readinessScore,
    this.recoveryScore,
    this.strainScore,
    required this.dataQuality,
    required this.calculatedAtMs,
    required this.synced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['match_id'] = Variable<String>(matchId);
    map['owner_id'] = Variable<String>(ownerId);
    if (!nullToAbsent || primarySourceId != null) {
      map['primary_source_id'] = Variable<String>(primarySourceId);
    }
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<int>(durationSeconds);
    }
    if (!nullToAbsent || averageHeartRate != null) {
      map['average_heart_rate'] = Variable<double>(averageHeartRate);
    }
    if (!nullToAbsent || maxHeartRate != null) {
      map['max_heart_rate'] = Variable<double>(maxHeartRate);
    }
    if (!nullToAbsent || minHeartRate != null) {
      map['min_heart_rate'] = Variable<double>(minHeartRate);
    }
    if (!nullToAbsent || activeEnergyKcal != null) {
      map['active_energy_kcal'] = Variable<double>(activeEnergyKcal);
    }
    if (!nullToAbsent || totalEnergyKcal != null) {
      map['total_energy_kcal'] = Variable<double>(totalEnergyKcal);
    }
    if (!nullToAbsent || steps != null) {
      map['steps'] = Variable<int>(steps);
    }
    if (!nullToAbsent || distanceMeters != null) {
      map['distance_meters'] = Variable<double>(distanceMeters);
    }
    if (!nullToAbsent || highIntensityMinutes != null) {
      map['high_intensity_minutes'] = Variable<int>(highIntensityMinutes);
    }
    if (!nullToAbsent || recoveryDelta != null) {
      map['recovery_delta'] = Variable<double>(recoveryDelta);
    }
    if (!nullToAbsent || sleepScore != null) {
      map['sleep_score'] = Variable<double>(sleepScore);
    }
    if (!nullToAbsent || readinessScore != null) {
      map['readiness_score'] = Variable<double>(readinessScore);
    }
    if (!nullToAbsent || recoveryScore != null) {
      map['recovery_score'] = Variable<double>(recoveryScore);
    }
    if (!nullToAbsent || strainScore != null) {
      map['strain_score'] = Variable<double>(strainScore);
    }
    map['data_quality'] = Variable<String>(dataQuality);
    map['calculated_at_ms'] = Variable<int>(calculatedAtMs);
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  MatchHealthSummariesCompanion toCompanion(bool nullToAbsent) {
    return MatchHealthSummariesCompanion(
      id: Value(id),
      matchId: Value(matchId),
      ownerId: Value(ownerId),
      primarySourceId: primarySourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(primarySourceId),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
      averageHeartRate: averageHeartRate == null && nullToAbsent
          ? const Value.absent()
          : Value(averageHeartRate),
      maxHeartRate: maxHeartRate == null && nullToAbsent
          ? const Value.absent()
          : Value(maxHeartRate),
      minHeartRate: minHeartRate == null && nullToAbsent
          ? const Value.absent()
          : Value(minHeartRate),
      activeEnergyKcal: activeEnergyKcal == null && nullToAbsent
          ? const Value.absent()
          : Value(activeEnergyKcal),
      totalEnergyKcal: totalEnergyKcal == null && nullToAbsent
          ? const Value.absent()
          : Value(totalEnergyKcal),
      steps: steps == null && nullToAbsent
          ? const Value.absent()
          : Value(steps),
      distanceMeters: distanceMeters == null && nullToAbsent
          ? const Value.absent()
          : Value(distanceMeters),
      highIntensityMinutes: highIntensityMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(highIntensityMinutes),
      recoveryDelta: recoveryDelta == null && nullToAbsent
          ? const Value.absent()
          : Value(recoveryDelta),
      sleepScore: sleepScore == null && nullToAbsent
          ? const Value.absent()
          : Value(sleepScore),
      readinessScore: readinessScore == null && nullToAbsent
          ? const Value.absent()
          : Value(readinessScore),
      recoveryScore: recoveryScore == null && nullToAbsent
          ? const Value.absent()
          : Value(recoveryScore),
      strainScore: strainScore == null && nullToAbsent
          ? const Value.absent()
          : Value(strainScore),
      dataQuality: Value(dataQuality),
      calculatedAtMs: Value(calculatedAtMs),
      synced: Value(synced),
    );
  }

  factory MatchHealthSummary.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MatchHealthSummary(
      id: serializer.fromJson<String>(json['id']),
      matchId: serializer.fromJson<String>(json['matchId']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      primarySourceId: serializer.fromJson<String?>(json['primarySourceId']),
      durationSeconds: serializer.fromJson<int?>(json['durationSeconds']),
      averageHeartRate: serializer.fromJson<double?>(json['averageHeartRate']),
      maxHeartRate: serializer.fromJson<double?>(json['maxHeartRate']),
      minHeartRate: serializer.fromJson<double?>(json['minHeartRate']),
      activeEnergyKcal: serializer.fromJson<double?>(json['activeEnergyKcal']),
      totalEnergyKcal: serializer.fromJson<double?>(json['totalEnergyKcal']),
      steps: serializer.fromJson<int?>(json['steps']),
      distanceMeters: serializer.fromJson<double?>(json['distanceMeters']),
      highIntensityMinutes: serializer.fromJson<int?>(
        json['highIntensityMinutes'],
      ),
      recoveryDelta: serializer.fromJson<double?>(json['recoveryDelta']),
      sleepScore: serializer.fromJson<double?>(json['sleepScore']),
      readinessScore: serializer.fromJson<double?>(json['readinessScore']),
      recoveryScore: serializer.fromJson<double?>(json['recoveryScore']),
      strainScore: serializer.fromJson<double?>(json['strainScore']),
      dataQuality: serializer.fromJson<String>(json['dataQuality']),
      calculatedAtMs: serializer.fromJson<int>(json['calculatedAtMs']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'matchId': serializer.toJson<String>(matchId),
      'ownerId': serializer.toJson<String>(ownerId),
      'primarySourceId': serializer.toJson<String?>(primarySourceId),
      'durationSeconds': serializer.toJson<int?>(durationSeconds),
      'averageHeartRate': serializer.toJson<double?>(averageHeartRate),
      'maxHeartRate': serializer.toJson<double?>(maxHeartRate),
      'minHeartRate': serializer.toJson<double?>(minHeartRate),
      'activeEnergyKcal': serializer.toJson<double?>(activeEnergyKcal),
      'totalEnergyKcal': serializer.toJson<double?>(totalEnergyKcal),
      'steps': serializer.toJson<int?>(steps),
      'distanceMeters': serializer.toJson<double?>(distanceMeters),
      'highIntensityMinutes': serializer.toJson<int?>(highIntensityMinutes),
      'recoveryDelta': serializer.toJson<double?>(recoveryDelta),
      'sleepScore': serializer.toJson<double?>(sleepScore),
      'readinessScore': serializer.toJson<double?>(readinessScore),
      'recoveryScore': serializer.toJson<double?>(recoveryScore),
      'strainScore': serializer.toJson<double?>(strainScore),
      'dataQuality': serializer.toJson<String>(dataQuality),
      'calculatedAtMs': serializer.toJson<int>(calculatedAtMs),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  MatchHealthSummary copyWith({
    String? id,
    String? matchId,
    String? ownerId,
    Value<String?> primarySourceId = const Value.absent(),
    Value<int?> durationSeconds = const Value.absent(),
    Value<double?> averageHeartRate = const Value.absent(),
    Value<double?> maxHeartRate = const Value.absent(),
    Value<double?> minHeartRate = const Value.absent(),
    Value<double?> activeEnergyKcal = const Value.absent(),
    Value<double?> totalEnergyKcal = const Value.absent(),
    Value<int?> steps = const Value.absent(),
    Value<double?> distanceMeters = const Value.absent(),
    Value<int?> highIntensityMinutes = const Value.absent(),
    Value<double?> recoveryDelta = const Value.absent(),
    Value<double?> sleepScore = const Value.absent(),
    Value<double?> readinessScore = const Value.absent(),
    Value<double?> recoveryScore = const Value.absent(),
    Value<double?> strainScore = const Value.absent(),
    String? dataQuality,
    int? calculatedAtMs,
    bool? synced,
  }) => MatchHealthSummary(
    id: id ?? this.id,
    matchId: matchId ?? this.matchId,
    ownerId: ownerId ?? this.ownerId,
    primarySourceId: primarySourceId.present
        ? primarySourceId.value
        : this.primarySourceId,
    durationSeconds: durationSeconds.present
        ? durationSeconds.value
        : this.durationSeconds,
    averageHeartRate: averageHeartRate.present
        ? averageHeartRate.value
        : this.averageHeartRate,
    maxHeartRate: maxHeartRate.present ? maxHeartRate.value : this.maxHeartRate,
    minHeartRate: minHeartRate.present ? minHeartRate.value : this.minHeartRate,
    activeEnergyKcal: activeEnergyKcal.present
        ? activeEnergyKcal.value
        : this.activeEnergyKcal,
    totalEnergyKcal: totalEnergyKcal.present
        ? totalEnergyKcal.value
        : this.totalEnergyKcal,
    steps: steps.present ? steps.value : this.steps,
    distanceMeters: distanceMeters.present
        ? distanceMeters.value
        : this.distanceMeters,
    highIntensityMinutes: highIntensityMinutes.present
        ? highIntensityMinutes.value
        : this.highIntensityMinutes,
    recoveryDelta: recoveryDelta.present
        ? recoveryDelta.value
        : this.recoveryDelta,
    sleepScore: sleepScore.present ? sleepScore.value : this.sleepScore,
    readinessScore: readinessScore.present
        ? readinessScore.value
        : this.readinessScore,
    recoveryScore: recoveryScore.present
        ? recoveryScore.value
        : this.recoveryScore,
    strainScore: strainScore.present ? strainScore.value : this.strainScore,
    dataQuality: dataQuality ?? this.dataQuality,
    calculatedAtMs: calculatedAtMs ?? this.calculatedAtMs,
    synced: synced ?? this.synced,
  );
  MatchHealthSummary copyWithCompanion(MatchHealthSummariesCompanion data) {
    return MatchHealthSummary(
      id: data.id.present ? data.id.value : this.id,
      matchId: data.matchId.present ? data.matchId.value : this.matchId,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      primarySourceId: data.primarySourceId.present
          ? data.primarySourceId.value
          : this.primarySourceId,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      averageHeartRate: data.averageHeartRate.present
          ? data.averageHeartRate.value
          : this.averageHeartRate,
      maxHeartRate: data.maxHeartRate.present
          ? data.maxHeartRate.value
          : this.maxHeartRate,
      minHeartRate: data.minHeartRate.present
          ? data.minHeartRate.value
          : this.minHeartRate,
      activeEnergyKcal: data.activeEnergyKcal.present
          ? data.activeEnergyKcal.value
          : this.activeEnergyKcal,
      totalEnergyKcal: data.totalEnergyKcal.present
          ? data.totalEnergyKcal.value
          : this.totalEnergyKcal,
      steps: data.steps.present ? data.steps.value : this.steps,
      distanceMeters: data.distanceMeters.present
          ? data.distanceMeters.value
          : this.distanceMeters,
      highIntensityMinutes: data.highIntensityMinutes.present
          ? data.highIntensityMinutes.value
          : this.highIntensityMinutes,
      recoveryDelta: data.recoveryDelta.present
          ? data.recoveryDelta.value
          : this.recoveryDelta,
      sleepScore: data.sleepScore.present
          ? data.sleepScore.value
          : this.sleepScore,
      readinessScore: data.readinessScore.present
          ? data.readinessScore.value
          : this.readinessScore,
      recoveryScore: data.recoveryScore.present
          ? data.recoveryScore.value
          : this.recoveryScore,
      strainScore: data.strainScore.present
          ? data.strainScore.value
          : this.strainScore,
      dataQuality: data.dataQuality.present
          ? data.dataQuality.value
          : this.dataQuality,
      calculatedAtMs: data.calculatedAtMs.present
          ? data.calculatedAtMs.value
          : this.calculatedAtMs,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MatchHealthSummary(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('ownerId: $ownerId, ')
          ..write('primarySourceId: $primarySourceId, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('averageHeartRate: $averageHeartRate, ')
          ..write('maxHeartRate: $maxHeartRate, ')
          ..write('minHeartRate: $minHeartRate, ')
          ..write('activeEnergyKcal: $activeEnergyKcal, ')
          ..write('totalEnergyKcal: $totalEnergyKcal, ')
          ..write('steps: $steps, ')
          ..write('distanceMeters: $distanceMeters, ')
          ..write('highIntensityMinutes: $highIntensityMinutes, ')
          ..write('recoveryDelta: $recoveryDelta, ')
          ..write('sleepScore: $sleepScore, ')
          ..write('readinessScore: $readinessScore, ')
          ..write('recoveryScore: $recoveryScore, ')
          ..write('strainScore: $strainScore, ')
          ..write('dataQuality: $dataQuality, ')
          ..write('calculatedAtMs: $calculatedAtMs, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    matchId,
    ownerId,
    primarySourceId,
    durationSeconds,
    averageHeartRate,
    maxHeartRate,
    minHeartRate,
    activeEnergyKcal,
    totalEnergyKcal,
    steps,
    distanceMeters,
    highIntensityMinutes,
    recoveryDelta,
    sleepScore,
    readinessScore,
    recoveryScore,
    strainScore,
    dataQuality,
    calculatedAtMs,
    synced,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MatchHealthSummary &&
          other.id == this.id &&
          other.matchId == this.matchId &&
          other.ownerId == this.ownerId &&
          other.primarySourceId == this.primarySourceId &&
          other.durationSeconds == this.durationSeconds &&
          other.averageHeartRate == this.averageHeartRate &&
          other.maxHeartRate == this.maxHeartRate &&
          other.minHeartRate == this.minHeartRate &&
          other.activeEnergyKcal == this.activeEnergyKcal &&
          other.totalEnergyKcal == this.totalEnergyKcal &&
          other.steps == this.steps &&
          other.distanceMeters == this.distanceMeters &&
          other.highIntensityMinutes == this.highIntensityMinutes &&
          other.recoveryDelta == this.recoveryDelta &&
          other.sleepScore == this.sleepScore &&
          other.readinessScore == this.readinessScore &&
          other.recoveryScore == this.recoveryScore &&
          other.strainScore == this.strainScore &&
          other.dataQuality == this.dataQuality &&
          other.calculatedAtMs == this.calculatedAtMs &&
          other.synced == this.synced);
}

class MatchHealthSummariesCompanion
    extends UpdateCompanion<MatchHealthSummary> {
  final Value<String> id;
  final Value<String> matchId;
  final Value<String> ownerId;
  final Value<String?> primarySourceId;
  final Value<int?> durationSeconds;
  final Value<double?> averageHeartRate;
  final Value<double?> maxHeartRate;
  final Value<double?> minHeartRate;
  final Value<double?> activeEnergyKcal;
  final Value<double?> totalEnergyKcal;
  final Value<int?> steps;
  final Value<double?> distanceMeters;
  final Value<int?> highIntensityMinutes;
  final Value<double?> recoveryDelta;
  final Value<double?> sleepScore;
  final Value<double?> readinessScore;
  final Value<double?> recoveryScore;
  final Value<double?> strainScore;
  final Value<String> dataQuality;
  final Value<int> calculatedAtMs;
  final Value<bool> synced;
  final Value<int> rowid;
  const MatchHealthSummariesCompanion({
    this.id = const Value.absent(),
    this.matchId = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.primarySourceId = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.averageHeartRate = const Value.absent(),
    this.maxHeartRate = const Value.absent(),
    this.minHeartRate = const Value.absent(),
    this.activeEnergyKcal = const Value.absent(),
    this.totalEnergyKcal = const Value.absent(),
    this.steps = const Value.absent(),
    this.distanceMeters = const Value.absent(),
    this.highIntensityMinutes = const Value.absent(),
    this.recoveryDelta = const Value.absent(),
    this.sleepScore = const Value.absent(),
    this.readinessScore = const Value.absent(),
    this.recoveryScore = const Value.absent(),
    this.strainScore = const Value.absent(),
    this.dataQuality = const Value.absent(),
    this.calculatedAtMs = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MatchHealthSummariesCompanion.insert({
    required String id,
    required String matchId,
    this.ownerId = const Value.absent(),
    this.primarySourceId = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.averageHeartRate = const Value.absent(),
    this.maxHeartRate = const Value.absent(),
    this.minHeartRate = const Value.absent(),
    this.activeEnergyKcal = const Value.absent(),
    this.totalEnergyKcal = const Value.absent(),
    this.steps = const Value.absent(),
    this.distanceMeters = const Value.absent(),
    this.highIntensityMinutes = const Value.absent(),
    this.recoveryDelta = const Value.absent(),
    this.sleepScore = const Value.absent(),
    this.readinessScore = const Value.absent(),
    this.recoveryScore = const Value.absent(),
    this.strainScore = const Value.absent(),
    this.dataQuality = const Value.absent(),
    required int calculatedAtMs,
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       matchId = Value(matchId),
       calculatedAtMs = Value(calculatedAtMs);
  static Insertable<MatchHealthSummary> custom({
    Expression<String>? id,
    Expression<String>? matchId,
    Expression<String>? ownerId,
    Expression<String>? primarySourceId,
    Expression<int>? durationSeconds,
    Expression<double>? averageHeartRate,
    Expression<double>? maxHeartRate,
    Expression<double>? minHeartRate,
    Expression<double>? activeEnergyKcal,
    Expression<double>? totalEnergyKcal,
    Expression<int>? steps,
    Expression<double>? distanceMeters,
    Expression<int>? highIntensityMinutes,
    Expression<double>? recoveryDelta,
    Expression<double>? sleepScore,
    Expression<double>? readinessScore,
    Expression<double>? recoveryScore,
    Expression<double>? strainScore,
    Expression<String>? dataQuality,
    Expression<int>? calculatedAtMs,
    Expression<bool>? synced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (matchId != null) 'match_id': matchId,
      if (ownerId != null) 'owner_id': ownerId,
      if (primarySourceId != null) 'primary_source_id': primarySourceId,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (averageHeartRate != null) 'average_heart_rate': averageHeartRate,
      if (maxHeartRate != null) 'max_heart_rate': maxHeartRate,
      if (minHeartRate != null) 'min_heart_rate': minHeartRate,
      if (activeEnergyKcal != null) 'active_energy_kcal': activeEnergyKcal,
      if (totalEnergyKcal != null) 'total_energy_kcal': totalEnergyKcal,
      if (steps != null) 'steps': steps,
      if (distanceMeters != null) 'distance_meters': distanceMeters,
      if (highIntensityMinutes != null)
        'high_intensity_minutes': highIntensityMinutes,
      if (recoveryDelta != null) 'recovery_delta': recoveryDelta,
      if (sleepScore != null) 'sleep_score': sleepScore,
      if (readinessScore != null) 'readiness_score': readinessScore,
      if (recoveryScore != null) 'recovery_score': recoveryScore,
      if (strainScore != null) 'strain_score': strainScore,
      if (dataQuality != null) 'data_quality': dataQuality,
      if (calculatedAtMs != null) 'calculated_at_ms': calculatedAtMs,
      if (synced != null) 'synced': synced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MatchHealthSummariesCompanion copyWith({
    Value<String>? id,
    Value<String>? matchId,
    Value<String>? ownerId,
    Value<String?>? primarySourceId,
    Value<int?>? durationSeconds,
    Value<double?>? averageHeartRate,
    Value<double?>? maxHeartRate,
    Value<double?>? minHeartRate,
    Value<double?>? activeEnergyKcal,
    Value<double?>? totalEnergyKcal,
    Value<int?>? steps,
    Value<double?>? distanceMeters,
    Value<int?>? highIntensityMinutes,
    Value<double?>? recoveryDelta,
    Value<double?>? sleepScore,
    Value<double?>? readinessScore,
    Value<double?>? recoveryScore,
    Value<double?>? strainScore,
    Value<String>? dataQuality,
    Value<int>? calculatedAtMs,
    Value<bool>? synced,
    Value<int>? rowid,
  }) {
    return MatchHealthSummariesCompanion(
      id: id ?? this.id,
      matchId: matchId ?? this.matchId,
      ownerId: ownerId ?? this.ownerId,
      primarySourceId: primarySourceId ?? this.primarySourceId,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      averageHeartRate: averageHeartRate ?? this.averageHeartRate,
      maxHeartRate: maxHeartRate ?? this.maxHeartRate,
      minHeartRate: minHeartRate ?? this.minHeartRate,
      activeEnergyKcal: activeEnergyKcal ?? this.activeEnergyKcal,
      totalEnergyKcal: totalEnergyKcal ?? this.totalEnergyKcal,
      steps: steps ?? this.steps,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      highIntensityMinutes: highIntensityMinutes ?? this.highIntensityMinutes,
      recoveryDelta: recoveryDelta ?? this.recoveryDelta,
      sleepScore: sleepScore ?? this.sleepScore,
      readinessScore: readinessScore ?? this.readinessScore,
      recoveryScore: recoveryScore ?? this.recoveryScore,
      strainScore: strainScore ?? this.strainScore,
      dataQuality: dataQuality ?? this.dataQuality,
      calculatedAtMs: calculatedAtMs ?? this.calculatedAtMs,
      synced: synced ?? this.synced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (matchId.present) {
      map['match_id'] = Variable<String>(matchId.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (primarySourceId.present) {
      map['primary_source_id'] = Variable<String>(primarySourceId.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (averageHeartRate.present) {
      map['average_heart_rate'] = Variable<double>(averageHeartRate.value);
    }
    if (maxHeartRate.present) {
      map['max_heart_rate'] = Variable<double>(maxHeartRate.value);
    }
    if (minHeartRate.present) {
      map['min_heart_rate'] = Variable<double>(minHeartRate.value);
    }
    if (activeEnergyKcal.present) {
      map['active_energy_kcal'] = Variable<double>(activeEnergyKcal.value);
    }
    if (totalEnergyKcal.present) {
      map['total_energy_kcal'] = Variable<double>(totalEnergyKcal.value);
    }
    if (steps.present) {
      map['steps'] = Variable<int>(steps.value);
    }
    if (distanceMeters.present) {
      map['distance_meters'] = Variable<double>(distanceMeters.value);
    }
    if (highIntensityMinutes.present) {
      map['high_intensity_minutes'] = Variable<int>(highIntensityMinutes.value);
    }
    if (recoveryDelta.present) {
      map['recovery_delta'] = Variable<double>(recoveryDelta.value);
    }
    if (sleepScore.present) {
      map['sleep_score'] = Variable<double>(sleepScore.value);
    }
    if (readinessScore.present) {
      map['readiness_score'] = Variable<double>(readinessScore.value);
    }
    if (recoveryScore.present) {
      map['recovery_score'] = Variable<double>(recoveryScore.value);
    }
    if (strainScore.present) {
      map['strain_score'] = Variable<double>(strainScore.value);
    }
    if (dataQuality.present) {
      map['data_quality'] = Variable<String>(dataQuality.value);
    }
    if (calculatedAtMs.present) {
      map['calculated_at_ms'] = Variable<int>(calculatedAtMs.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MatchHealthSummariesCompanion(')
          ..write('id: $id, ')
          ..write('matchId: $matchId, ')
          ..write('ownerId: $ownerId, ')
          ..write('primarySourceId: $primarySourceId, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('averageHeartRate: $averageHeartRate, ')
          ..write('maxHeartRate: $maxHeartRate, ')
          ..write('minHeartRate: $minHeartRate, ')
          ..write('activeEnergyKcal: $activeEnergyKcal, ')
          ..write('totalEnergyKcal: $totalEnergyKcal, ')
          ..write('steps: $steps, ')
          ..write('distanceMeters: $distanceMeters, ')
          ..write('highIntensityMinutes: $highIntensityMinutes, ')
          ..write('recoveryDelta: $recoveryDelta, ')
          ..write('sleepScore: $sleepScore, ')
          ..write('readinessScore: $readinessScore, ')
          ..write('recoveryScore: $recoveryScore, ')
          ..write('strainScore: $strainScore, ')
          ..write('dataQuality: $dataQuality, ')
          ..write('calculatedAtMs: $calculatedAtMs, ')
          ..write('synced: $synced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HealthSyncJobsTable extends HealthSyncJobs
    with TableInfo<$HealthSyncJobsTable, HealthSyncJob> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HealthSyncJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<String> ownerId = GeneratedColumn<String>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncTypeMeta = const VerificationMeta(
    'syncType',
  );
  @override
  late final GeneratedColumn<String> syncType = GeneratedColumn<String>(
    'sync_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateFromMsMeta = const VerificationMeta(
    'dateFromMs',
  );
  @override
  late final GeneratedColumn<int> dateFromMs = GeneratedColumn<int>(
    'date_from_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateToMsMeta = const VerificationMeta(
    'dateToMs',
  );
  @override
  late final GeneratedColumn<int> dateToMs = GeneratedColumn<int>(
    'date_to_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('PENDING'),
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextRetryAtMsMeta = const VerificationMeta(
    'nextRetryAtMs',
  );
  @override
  late final GeneratedColumn<int> nextRetryAtMs = GeneratedColumn<int>(
    'next_retry_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorCodeMeta = const VerificationMeta(
    'lastErrorCode',
  );
  @override
  late final GeneratedColumn<String> lastErrorCode = GeneratedColumn<String>(
    'last_error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMsMeta = const VerificationMeta(
    'completedAtMs',
  );
  @override
  late final GeneratedColumn<int> completedAtMs = GeneratedColumn<int>(
    'completed_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ownerId,
    provider,
    syncType,
    dateFromMs,
    dateToMs,
    status,
    retryCount,
    nextRetryAtMs,
    lastErrorCode,
    createdAtMs,
    completedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'health_sync_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<HealthSyncJob> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('sync_type')) {
      context.handle(
        _syncTypeMeta,
        syncType.isAcceptableOrUnknown(data['sync_type']!, _syncTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_syncTypeMeta);
    }
    if (data.containsKey('date_from_ms')) {
      context.handle(
        _dateFromMsMeta,
        dateFromMs.isAcceptableOrUnknown(
          data['date_from_ms']!,
          _dateFromMsMeta,
        ),
      );
    }
    if (data.containsKey('date_to_ms')) {
      context.handle(
        _dateToMsMeta,
        dateToMs.isAcceptableOrUnknown(data['date_to_ms']!, _dateToMsMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('next_retry_at_ms')) {
      context.handle(
        _nextRetryAtMsMeta,
        nextRetryAtMs.isAcceptableOrUnknown(
          data['next_retry_at_ms']!,
          _nextRetryAtMsMeta,
        ),
      );
    }
    if (data.containsKey('last_error_code')) {
      context.handle(
        _lastErrorCodeMeta,
        lastErrorCode.isAcceptableOrUnknown(
          data['last_error_code']!,
          _lastErrorCodeMeta,
        ),
      );
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    if (data.containsKey('completed_at_ms')) {
      context.handle(
        _completedAtMsMeta,
        completedAtMs.isAcceptableOrUnknown(
          data['completed_at_ms']!,
          _completedAtMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HealthSyncJob map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HealthSyncJob(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_id'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      syncType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_type'],
      )!,
      dateFromMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}date_from_ms'],
      ),
      dateToMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}date_to_ms'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      nextRetryAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_retry_at_ms'],
      ),
      lastErrorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error_code'],
      ),
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
      completedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at_ms'],
      ),
    );
  }

  @override
  $HealthSyncJobsTable createAlias(String alias) {
    return $HealthSyncJobsTable(attachedDatabase, alias);
  }
}

class HealthSyncJob extends DataClass implements Insertable<HealthSyncJob> {
  final String id;
  final String ownerId;
  final String provider;
  final String syncType;
  final int? dateFromMs;
  final int? dateToMs;
  final String status;
  final int retryCount;
  final int? nextRetryAtMs;
  final String? lastErrorCode;
  final int createdAtMs;
  final int? completedAtMs;
  const HealthSyncJob({
    required this.id,
    required this.ownerId,
    required this.provider,
    required this.syncType,
    this.dateFromMs,
    this.dateToMs,
    required this.status,
    required this.retryCount,
    this.nextRetryAtMs,
    this.lastErrorCode,
    required this.createdAtMs,
    this.completedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['owner_id'] = Variable<String>(ownerId);
    map['provider'] = Variable<String>(provider);
    map['sync_type'] = Variable<String>(syncType);
    if (!nullToAbsent || dateFromMs != null) {
      map['date_from_ms'] = Variable<int>(dateFromMs);
    }
    if (!nullToAbsent || dateToMs != null) {
      map['date_to_ms'] = Variable<int>(dateToMs);
    }
    map['status'] = Variable<String>(status);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || nextRetryAtMs != null) {
      map['next_retry_at_ms'] = Variable<int>(nextRetryAtMs);
    }
    if (!nullToAbsent || lastErrorCode != null) {
      map['last_error_code'] = Variable<String>(lastErrorCode);
    }
    map['created_at_ms'] = Variable<int>(createdAtMs);
    if (!nullToAbsent || completedAtMs != null) {
      map['completed_at_ms'] = Variable<int>(completedAtMs);
    }
    return map;
  }

  HealthSyncJobsCompanion toCompanion(bool nullToAbsent) {
    return HealthSyncJobsCompanion(
      id: Value(id),
      ownerId: Value(ownerId),
      provider: Value(provider),
      syncType: Value(syncType),
      dateFromMs: dateFromMs == null && nullToAbsent
          ? const Value.absent()
          : Value(dateFromMs),
      dateToMs: dateToMs == null && nullToAbsent
          ? const Value.absent()
          : Value(dateToMs),
      status: Value(status),
      retryCount: Value(retryCount),
      nextRetryAtMs: nextRetryAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRetryAtMs),
      lastErrorCode: lastErrorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(lastErrorCode),
      createdAtMs: Value(createdAtMs),
      completedAtMs: completedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAtMs),
    );
  }

  factory HealthSyncJob.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HealthSyncJob(
      id: serializer.fromJson<String>(json['id']),
      ownerId: serializer.fromJson<String>(json['ownerId']),
      provider: serializer.fromJson<String>(json['provider']),
      syncType: serializer.fromJson<String>(json['syncType']),
      dateFromMs: serializer.fromJson<int?>(json['dateFromMs']),
      dateToMs: serializer.fromJson<int?>(json['dateToMs']),
      status: serializer.fromJson<String>(json['status']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      nextRetryAtMs: serializer.fromJson<int?>(json['nextRetryAtMs']),
      lastErrorCode: serializer.fromJson<String?>(json['lastErrorCode']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
      completedAtMs: serializer.fromJson<int?>(json['completedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ownerId': serializer.toJson<String>(ownerId),
      'provider': serializer.toJson<String>(provider),
      'syncType': serializer.toJson<String>(syncType),
      'dateFromMs': serializer.toJson<int?>(dateFromMs),
      'dateToMs': serializer.toJson<int?>(dateToMs),
      'status': serializer.toJson<String>(status),
      'retryCount': serializer.toJson<int>(retryCount),
      'nextRetryAtMs': serializer.toJson<int?>(nextRetryAtMs),
      'lastErrorCode': serializer.toJson<String?>(lastErrorCode),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
      'completedAtMs': serializer.toJson<int?>(completedAtMs),
    };
  }

  HealthSyncJob copyWith({
    String? id,
    String? ownerId,
    String? provider,
    String? syncType,
    Value<int?> dateFromMs = const Value.absent(),
    Value<int?> dateToMs = const Value.absent(),
    String? status,
    int? retryCount,
    Value<int?> nextRetryAtMs = const Value.absent(),
    Value<String?> lastErrorCode = const Value.absent(),
    int? createdAtMs,
    Value<int?> completedAtMs = const Value.absent(),
  }) => HealthSyncJob(
    id: id ?? this.id,
    ownerId: ownerId ?? this.ownerId,
    provider: provider ?? this.provider,
    syncType: syncType ?? this.syncType,
    dateFromMs: dateFromMs.present ? dateFromMs.value : this.dateFromMs,
    dateToMs: dateToMs.present ? dateToMs.value : this.dateToMs,
    status: status ?? this.status,
    retryCount: retryCount ?? this.retryCount,
    nextRetryAtMs: nextRetryAtMs.present
        ? nextRetryAtMs.value
        : this.nextRetryAtMs,
    lastErrorCode: lastErrorCode.present
        ? lastErrorCode.value
        : this.lastErrorCode,
    createdAtMs: createdAtMs ?? this.createdAtMs,
    completedAtMs: completedAtMs.present
        ? completedAtMs.value
        : this.completedAtMs,
  );
  HealthSyncJob copyWithCompanion(HealthSyncJobsCompanion data) {
    return HealthSyncJob(
      id: data.id.present ? data.id.value : this.id,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      provider: data.provider.present ? data.provider.value : this.provider,
      syncType: data.syncType.present ? data.syncType.value : this.syncType,
      dateFromMs: data.dateFromMs.present
          ? data.dateFromMs.value
          : this.dateFromMs,
      dateToMs: data.dateToMs.present ? data.dateToMs.value : this.dateToMs,
      status: data.status.present ? data.status.value : this.status,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      nextRetryAtMs: data.nextRetryAtMs.present
          ? data.nextRetryAtMs.value
          : this.nextRetryAtMs,
      lastErrorCode: data.lastErrorCode.present
          ? data.lastErrorCode.value
          : this.lastErrorCode,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
      completedAtMs: data.completedAtMs.present
          ? data.completedAtMs.value
          : this.completedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HealthSyncJob(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('provider: $provider, ')
          ..write('syncType: $syncType, ')
          ..write('dateFromMs: $dateFromMs, ')
          ..write('dateToMs: $dateToMs, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextRetryAtMs: $nextRetryAtMs, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('completedAtMs: $completedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ownerId,
    provider,
    syncType,
    dateFromMs,
    dateToMs,
    status,
    retryCount,
    nextRetryAtMs,
    lastErrorCode,
    createdAtMs,
    completedAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HealthSyncJob &&
          other.id == this.id &&
          other.ownerId == this.ownerId &&
          other.provider == this.provider &&
          other.syncType == this.syncType &&
          other.dateFromMs == this.dateFromMs &&
          other.dateToMs == this.dateToMs &&
          other.status == this.status &&
          other.retryCount == this.retryCount &&
          other.nextRetryAtMs == this.nextRetryAtMs &&
          other.lastErrorCode == this.lastErrorCode &&
          other.createdAtMs == this.createdAtMs &&
          other.completedAtMs == this.completedAtMs);
}

class HealthSyncJobsCompanion extends UpdateCompanion<HealthSyncJob> {
  final Value<String> id;
  final Value<String> ownerId;
  final Value<String> provider;
  final Value<String> syncType;
  final Value<int?> dateFromMs;
  final Value<int?> dateToMs;
  final Value<String> status;
  final Value<int> retryCount;
  final Value<int?> nextRetryAtMs;
  final Value<String?> lastErrorCode;
  final Value<int> createdAtMs;
  final Value<int?> completedAtMs;
  final Value<int> rowid;
  const HealthSyncJobsCompanion({
    this.id = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.provider = const Value.absent(),
    this.syncType = const Value.absent(),
    this.dateFromMs = const Value.absent(),
    this.dateToMs = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.nextRetryAtMs = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.completedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HealthSyncJobsCompanion.insert({
    required String id,
    this.ownerId = const Value.absent(),
    required String provider,
    required String syncType,
    this.dateFromMs = const Value.absent(),
    this.dateToMs = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.nextRetryAtMs = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    required int createdAtMs,
    this.completedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       provider = Value(provider),
       syncType = Value(syncType),
       createdAtMs = Value(createdAtMs);
  static Insertable<HealthSyncJob> custom({
    Expression<String>? id,
    Expression<String>? ownerId,
    Expression<String>? provider,
    Expression<String>? syncType,
    Expression<int>? dateFromMs,
    Expression<int>? dateToMs,
    Expression<String>? status,
    Expression<int>? retryCount,
    Expression<int>? nextRetryAtMs,
    Expression<String>? lastErrorCode,
    Expression<int>? createdAtMs,
    Expression<int>? completedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ownerId != null) 'owner_id': ownerId,
      if (provider != null) 'provider': provider,
      if (syncType != null) 'sync_type': syncType,
      if (dateFromMs != null) 'date_from_ms': dateFromMs,
      if (dateToMs != null) 'date_to_ms': dateToMs,
      if (status != null) 'status': status,
      if (retryCount != null) 'retry_count': retryCount,
      if (nextRetryAtMs != null) 'next_retry_at_ms': nextRetryAtMs,
      if (lastErrorCode != null) 'last_error_code': lastErrorCode,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (completedAtMs != null) 'completed_at_ms': completedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HealthSyncJobsCompanion copyWith({
    Value<String>? id,
    Value<String>? ownerId,
    Value<String>? provider,
    Value<String>? syncType,
    Value<int?>? dateFromMs,
    Value<int?>? dateToMs,
    Value<String>? status,
    Value<int>? retryCount,
    Value<int?>? nextRetryAtMs,
    Value<String?>? lastErrorCode,
    Value<int>? createdAtMs,
    Value<int?>? completedAtMs,
    Value<int>? rowid,
  }) {
    return HealthSyncJobsCompanion(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      provider: provider ?? this.provider,
      syncType: syncType ?? this.syncType,
      dateFromMs: dateFromMs ?? this.dateFromMs,
      dateToMs: dateToMs ?? this.dateToMs,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAtMs: nextRetryAtMs ?? this.nextRetryAtMs,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      completedAtMs: completedAtMs ?? this.completedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<String>(ownerId.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (syncType.present) {
      map['sync_type'] = Variable<String>(syncType.value);
    }
    if (dateFromMs.present) {
      map['date_from_ms'] = Variable<int>(dateFromMs.value);
    }
    if (dateToMs.present) {
      map['date_to_ms'] = Variable<int>(dateToMs.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (nextRetryAtMs.present) {
      map['next_retry_at_ms'] = Variable<int>(nextRetryAtMs.value);
    }
    if (lastErrorCode.present) {
      map['last_error_code'] = Variable<String>(lastErrorCode.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (completedAtMs.present) {
      map['completed_at_ms'] = Variable<int>(completedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HealthSyncJobsCompanion(')
          ..write('id: $id, ')
          ..write('ownerId: $ownerId, ')
          ..write('provider: $provider, ')
          ..write('syncType: $syncType, ')
          ..write('dateFromMs: $dateFromMs, ')
          ..write('dateToMs: $dateToMs, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextRetryAtMs: $nextRetryAtMs, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('completedAtMs: $completedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BleSensorDevicesTable extends BleSensorDevices
    with TableInfo<$BleSensorDevicesTable, BleSensorDevice> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BleSensorDevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localIdentifierMeta = const VerificationMeta(
    'localIdentifier',
  );
  @override
  late final GeneratedColumn<String> localIdentifier = GeneratedColumn<String>(
    'local_identifier',
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _deviceTypeMeta = const VerificationMeta(
    'deviceType',
  );
  @override
  late final GeneratedColumn<String> deviceType = GeneratedColumn<String>(
    'device_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('HEART_RATE_SENSOR'),
  );
  static const VerificationMeta _manufacturerMeta = const VerificationMeta(
    'manufacturer',
  );
  @override
  late final GeneratedColumn<String> manufacturer = GeneratedColumn<String>(
    'manufacturer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _capabilitiesJsonMeta = const VerificationMeta(
    'capabilitiesJson',
  );
  @override
  late final GeneratedColumn<String> capabilitiesJson = GeneratedColumn<String>(
    'capabilities_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _lastSeenAtMsMeta = const VerificationMeta(
    'lastSeenAtMs',
  );
  @override
  late final GeneratedColumn<int> lastSeenAtMs = GeneratedColumn<int>(
    'last_seen_at_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPreferredMeta = const VerificationMeta(
    'isPreferred',
  );
  @override
  late final GeneratedColumn<bool> isPreferred = GeneratedColumn<bool>(
    'is_preferred',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_preferred" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isConnectedMeta = const VerificationMeta(
    'isConnected',
  );
  @override
  late final GeneratedColumn<bool> isConnected = GeneratedColumn<bool>(
    'is_connected',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_connected" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMsMeta = const VerificationMeta(
    'updatedAtMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtMs = GeneratedColumn<int>(
    'updated_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    localIdentifier,
    displayName,
    deviceType,
    manufacturer,
    capabilitiesJson,
    lastSeenAtMs,
    isPreferred,
    isConnected,
    createdAtMs,
    updatedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ble_sensor_devices';
  @override
  VerificationContext validateIntegrity(
    Insertable<BleSensorDevice> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('local_identifier')) {
      context.handle(
        _localIdentifierMeta,
        localIdentifier.isAcceptableOrUnknown(
          data['local_identifier']!,
          _localIdentifierMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localIdentifierMeta);
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
    if (data.containsKey('device_type')) {
      context.handle(
        _deviceTypeMeta,
        deviceType.isAcceptableOrUnknown(data['device_type']!, _deviceTypeMeta),
      );
    }
    if (data.containsKey('manufacturer')) {
      context.handle(
        _manufacturerMeta,
        manufacturer.isAcceptableOrUnknown(
          data['manufacturer']!,
          _manufacturerMeta,
        ),
      );
    }
    if (data.containsKey('capabilities_json')) {
      context.handle(
        _capabilitiesJsonMeta,
        capabilitiesJson.isAcceptableOrUnknown(
          data['capabilities_json']!,
          _capabilitiesJsonMeta,
        ),
      );
    }
    if (data.containsKey('last_seen_at_ms')) {
      context.handle(
        _lastSeenAtMsMeta,
        lastSeenAtMs.isAcceptableOrUnknown(
          data['last_seen_at_ms']!,
          _lastSeenAtMsMeta,
        ),
      );
    }
    if (data.containsKey('is_preferred')) {
      context.handle(
        _isPreferredMeta,
        isPreferred.isAcceptableOrUnknown(
          data['is_preferred']!,
          _isPreferredMeta,
        ),
      );
    }
    if (data.containsKey('is_connected')) {
      context.handle(
        _isConnectedMeta,
        isConnected.isAcceptableOrUnknown(
          data['is_connected']!,
          _isConnectedMeta,
        ),
      );
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    if (data.containsKey('updated_at_ms')) {
      context.handle(
        _updatedAtMsMeta,
        updatedAtMs.isAcceptableOrUnknown(
          data['updated_at_ms']!,
          _updatedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BleSensorDevice map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BleSensorDevice(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      localIdentifier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_identifier'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      deviceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_type'],
      )!,
      manufacturer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manufacturer'],
      )!,
      capabilitiesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capabilities_json'],
      )!,
      lastSeenAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seen_at_ms'],
      ),
      isPreferred: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_preferred'],
      )!,
      isConnected: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_connected'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
      updatedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_ms'],
      )!,
    );
  }

  @override
  $BleSensorDevicesTable createAlias(String alias) {
    return $BleSensorDevicesTable(attachedDatabase, alias);
  }
}

class BleSensorDevice extends DataClass implements Insertable<BleSensorDevice> {
  final String id;
  final String localIdentifier;
  final String displayName;
  final String deviceType;
  final String manufacturer;
  final String capabilitiesJson;
  final int? lastSeenAtMs;
  final bool isPreferred;
  final bool isConnected;
  final int createdAtMs;
  final int updatedAtMs;
  const BleSensorDevice({
    required this.id,
    required this.localIdentifier,
    required this.displayName,
    required this.deviceType,
    required this.manufacturer,
    required this.capabilitiesJson,
    this.lastSeenAtMs,
    required this.isPreferred,
    required this.isConnected,
    required this.createdAtMs,
    required this.updatedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['local_identifier'] = Variable<String>(localIdentifier);
    map['display_name'] = Variable<String>(displayName);
    map['device_type'] = Variable<String>(deviceType);
    map['manufacturer'] = Variable<String>(manufacturer);
    map['capabilities_json'] = Variable<String>(capabilitiesJson);
    if (!nullToAbsent || lastSeenAtMs != null) {
      map['last_seen_at_ms'] = Variable<int>(lastSeenAtMs);
    }
    map['is_preferred'] = Variable<bool>(isPreferred);
    map['is_connected'] = Variable<bool>(isConnected);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    map['updated_at_ms'] = Variable<int>(updatedAtMs);
    return map;
  }

  BleSensorDevicesCompanion toCompanion(bool nullToAbsent) {
    return BleSensorDevicesCompanion(
      id: Value(id),
      localIdentifier: Value(localIdentifier),
      displayName: Value(displayName),
      deviceType: Value(deviceType),
      manufacturer: Value(manufacturer),
      capabilitiesJson: Value(capabilitiesJson),
      lastSeenAtMs: lastSeenAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeenAtMs),
      isPreferred: Value(isPreferred),
      isConnected: Value(isConnected),
      createdAtMs: Value(createdAtMs),
      updatedAtMs: Value(updatedAtMs),
    );
  }

  factory BleSensorDevice.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BleSensorDevice(
      id: serializer.fromJson<String>(json['id']),
      localIdentifier: serializer.fromJson<String>(json['localIdentifier']),
      displayName: serializer.fromJson<String>(json['displayName']),
      deviceType: serializer.fromJson<String>(json['deviceType']),
      manufacturer: serializer.fromJson<String>(json['manufacturer']),
      capabilitiesJson: serializer.fromJson<String>(json['capabilitiesJson']),
      lastSeenAtMs: serializer.fromJson<int?>(json['lastSeenAtMs']),
      isPreferred: serializer.fromJson<bool>(json['isPreferred']),
      isConnected: serializer.fromJson<bool>(json['isConnected']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
      updatedAtMs: serializer.fromJson<int>(json['updatedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'localIdentifier': serializer.toJson<String>(localIdentifier),
      'displayName': serializer.toJson<String>(displayName),
      'deviceType': serializer.toJson<String>(deviceType),
      'manufacturer': serializer.toJson<String>(manufacturer),
      'capabilitiesJson': serializer.toJson<String>(capabilitiesJson),
      'lastSeenAtMs': serializer.toJson<int?>(lastSeenAtMs),
      'isPreferred': serializer.toJson<bool>(isPreferred),
      'isConnected': serializer.toJson<bool>(isConnected),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
      'updatedAtMs': serializer.toJson<int>(updatedAtMs),
    };
  }

  BleSensorDevice copyWith({
    String? id,
    String? localIdentifier,
    String? displayName,
    String? deviceType,
    String? manufacturer,
    String? capabilitiesJson,
    Value<int?> lastSeenAtMs = const Value.absent(),
    bool? isPreferred,
    bool? isConnected,
    int? createdAtMs,
    int? updatedAtMs,
  }) => BleSensorDevice(
    id: id ?? this.id,
    localIdentifier: localIdentifier ?? this.localIdentifier,
    displayName: displayName ?? this.displayName,
    deviceType: deviceType ?? this.deviceType,
    manufacturer: manufacturer ?? this.manufacturer,
    capabilitiesJson: capabilitiesJson ?? this.capabilitiesJson,
    lastSeenAtMs: lastSeenAtMs.present ? lastSeenAtMs.value : this.lastSeenAtMs,
    isPreferred: isPreferred ?? this.isPreferred,
    isConnected: isConnected ?? this.isConnected,
    createdAtMs: createdAtMs ?? this.createdAtMs,
    updatedAtMs: updatedAtMs ?? this.updatedAtMs,
  );
  BleSensorDevice copyWithCompanion(BleSensorDevicesCompanion data) {
    return BleSensorDevice(
      id: data.id.present ? data.id.value : this.id,
      localIdentifier: data.localIdentifier.present
          ? data.localIdentifier.value
          : this.localIdentifier,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      deviceType: data.deviceType.present
          ? data.deviceType.value
          : this.deviceType,
      manufacturer: data.manufacturer.present
          ? data.manufacturer.value
          : this.manufacturer,
      capabilitiesJson: data.capabilitiesJson.present
          ? data.capabilitiesJson.value
          : this.capabilitiesJson,
      lastSeenAtMs: data.lastSeenAtMs.present
          ? data.lastSeenAtMs.value
          : this.lastSeenAtMs,
      isPreferred: data.isPreferred.present
          ? data.isPreferred.value
          : this.isPreferred,
      isConnected: data.isConnected.present
          ? data.isConnected.value
          : this.isConnected,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
      updatedAtMs: data.updatedAtMs.present
          ? data.updatedAtMs.value
          : this.updatedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BleSensorDevice(')
          ..write('id: $id, ')
          ..write('localIdentifier: $localIdentifier, ')
          ..write('displayName: $displayName, ')
          ..write('deviceType: $deviceType, ')
          ..write('manufacturer: $manufacturer, ')
          ..write('capabilitiesJson: $capabilitiesJson, ')
          ..write('lastSeenAtMs: $lastSeenAtMs, ')
          ..write('isPreferred: $isPreferred, ')
          ..write('isConnected: $isConnected, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('updatedAtMs: $updatedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    localIdentifier,
    displayName,
    deviceType,
    manufacturer,
    capabilitiesJson,
    lastSeenAtMs,
    isPreferred,
    isConnected,
    createdAtMs,
    updatedAtMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BleSensorDevice &&
          other.id == this.id &&
          other.localIdentifier == this.localIdentifier &&
          other.displayName == this.displayName &&
          other.deviceType == this.deviceType &&
          other.manufacturer == this.manufacturer &&
          other.capabilitiesJson == this.capabilitiesJson &&
          other.lastSeenAtMs == this.lastSeenAtMs &&
          other.isPreferred == this.isPreferred &&
          other.isConnected == this.isConnected &&
          other.createdAtMs == this.createdAtMs &&
          other.updatedAtMs == this.updatedAtMs);
}

class BleSensorDevicesCompanion extends UpdateCompanion<BleSensorDevice> {
  final Value<String> id;
  final Value<String> localIdentifier;
  final Value<String> displayName;
  final Value<String> deviceType;
  final Value<String> manufacturer;
  final Value<String> capabilitiesJson;
  final Value<int?> lastSeenAtMs;
  final Value<bool> isPreferred;
  final Value<bool> isConnected;
  final Value<int> createdAtMs;
  final Value<int> updatedAtMs;
  final Value<int> rowid;
  const BleSensorDevicesCompanion({
    this.id = const Value.absent(),
    this.localIdentifier = const Value.absent(),
    this.displayName = const Value.absent(),
    this.deviceType = const Value.absent(),
    this.manufacturer = const Value.absent(),
    this.capabilitiesJson = const Value.absent(),
    this.lastSeenAtMs = const Value.absent(),
    this.isPreferred = const Value.absent(),
    this.isConnected = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.updatedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BleSensorDevicesCompanion.insert({
    required String id,
    required String localIdentifier,
    this.displayName = const Value.absent(),
    this.deviceType = const Value.absent(),
    this.manufacturer = const Value.absent(),
    this.capabilitiesJson = const Value.absent(),
    this.lastSeenAtMs = const Value.absent(),
    this.isPreferred = const Value.absent(),
    this.isConnected = const Value.absent(),
    required int createdAtMs,
    required int updatedAtMs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       localIdentifier = Value(localIdentifier),
       createdAtMs = Value(createdAtMs),
       updatedAtMs = Value(updatedAtMs);
  static Insertable<BleSensorDevice> custom({
    Expression<String>? id,
    Expression<String>? localIdentifier,
    Expression<String>? displayName,
    Expression<String>? deviceType,
    Expression<String>? manufacturer,
    Expression<String>? capabilitiesJson,
    Expression<int>? lastSeenAtMs,
    Expression<bool>? isPreferred,
    Expression<bool>? isConnected,
    Expression<int>? createdAtMs,
    Expression<int>? updatedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (localIdentifier != null) 'local_identifier': localIdentifier,
      if (displayName != null) 'display_name': displayName,
      if (deviceType != null) 'device_type': deviceType,
      if (manufacturer != null) 'manufacturer': manufacturer,
      if (capabilitiesJson != null) 'capabilities_json': capabilitiesJson,
      if (lastSeenAtMs != null) 'last_seen_at_ms': lastSeenAtMs,
      if (isPreferred != null) 'is_preferred': isPreferred,
      if (isConnected != null) 'is_connected': isConnected,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (updatedAtMs != null) 'updated_at_ms': updatedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BleSensorDevicesCompanion copyWith({
    Value<String>? id,
    Value<String>? localIdentifier,
    Value<String>? displayName,
    Value<String>? deviceType,
    Value<String>? manufacturer,
    Value<String>? capabilitiesJson,
    Value<int?>? lastSeenAtMs,
    Value<bool>? isPreferred,
    Value<bool>? isConnected,
    Value<int>? createdAtMs,
    Value<int>? updatedAtMs,
    Value<int>? rowid,
  }) {
    return BleSensorDevicesCompanion(
      id: id ?? this.id,
      localIdentifier: localIdentifier ?? this.localIdentifier,
      displayName: displayName ?? this.displayName,
      deviceType: deviceType ?? this.deviceType,
      manufacturer: manufacturer ?? this.manufacturer,
      capabilitiesJson: capabilitiesJson ?? this.capabilitiesJson,
      lastSeenAtMs: lastSeenAtMs ?? this.lastSeenAtMs,
      isPreferred: isPreferred ?? this.isPreferred,
      isConnected: isConnected ?? this.isConnected,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (localIdentifier.present) {
      map['local_identifier'] = Variable<String>(localIdentifier.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (deviceType.present) {
      map['device_type'] = Variable<String>(deviceType.value);
    }
    if (manufacturer.present) {
      map['manufacturer'] = Variable<String>(manufacturer.value);
    }
    if (capabilitiesJson.present) {
      map['capabilities_json'] = Variable<String>(capabilitiesJson.value);
    }
    if (lastSeenAtMs.present) {
      map['last_seen_at_ms'] = Variable<int>(lastSeenAtMs.value);
    }
    if (isPreferred.present) {
      map['is_preferred'] = Variable<bool>(isPreferred.value);
    }
    if (isConnected.present) {
      map['is_connected'] = Variable<bool>(isConnected.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (updatedAtMs.present) {
      map['updated_at_ms'] = Variable<int>(updatedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BleSensorDevicesCompanion(')
          ..write('id: $id, ')
          ..write('localIdentifier: $localIdentifier, ')
          ..write('displayName: $displayName, ')
          ..write('deviceType: $deviceType, ')
          ..write('manufacturer: $manufacturer, ')
          ..write('capabilitiesJson: $capabilitiesJson, ')
          ..write('lastSeenAtMs: $lastSeenAtMs, ')
          ..write('isPreferred: $isPreferred, ')
          ..write('isConnected: $isConnected, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('updatedAtMs: $updatedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KeyValuesTable extends KeyValues
    with TableInfo<$KeyValuesTable, KeyValue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KeyValuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'key_values';
  @override
  VerificationContext validateIntegrity(
    Insertable<KeyValue> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  KeyValue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KeyValue(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $KeyValuesTable createAlias(String alias) {
    return $KeyValuesTable(attachedDatabase, alias);
  }
}

class KeyValue extends DataClass implements Insertable<KeyValue> {
  final String key;
  final String value;
  const KeyValue({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  KeyValuesCompanion toCompanion(bool nullToAbsent) {
    return KeyValuesCompanion(key: Value(key), value: Value(value));
  }

  factory KeyValue.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KeyValue(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  KeyValue copyWith({String? key, String? value}) =>
      KeyValue(key: key ?? this.key, value: value ?? this.value);
  KeyValue copyWithCompanion(KeyValuesCompanion data) {
    return KeyValue(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KeyValue(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KeyValue && other.key == this.key && other.value == this.value);
}

class KeyValuesCompanion extends UpdateCompanion<KeyValue> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const KeyValuesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KeyValuesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<KeyValue> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KeyValuesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return KeyValuesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KeyValuesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PlayersTable players = $PlayersTable(this);
  late final $TeamsTable teams = $TeamsTable(this);
  late final $MatchesTable matches = $MatchesTable(this);
  late final $MatchEventRowsTable matchEventRows = $MatchEventRowsTable(this);
  late final $TrainingsTable trainings = $TrainingsTable(this);
  late final $TrainingLogsTable trainingLogs = $TrainingLogsTable(this);
  late final $ConnectedDevicesTable connectedDevices = $ConnectedDevicesTable(
    this,
  );
  late final $HealthDataSourcesTable healthDataSources =
      $HealthDataSourcesTable(this);
  late final $HealthMetricRecordsTable healthMetricRecords =
      $HealthMetricRecordsTable(this);
  late final $HealthSourcePreferencesTable healthSourcePreferences =
      $HealthSourcePreferencesTable(this);
  late final $MatchHealthSummariesTable matchHealthSummaries =
      $MatchHealthSummariesTable(this);
  late final $HealthSyncJobsTable healthSyncJobs = $HealthSyncJobsTable(this);
  late final $BleSensorDevicesTable bleSensorDevices = $BleSensorDevicesTable(
    this,
  );
  late final $KeyValuesTable keyValues = $KeyValuesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    players,
    teams,
    matches,
    matchEventRows,
    trainings,
    trainingLogs,
    connectedDevices,
    healthDataSources,
    healthMetricRecords,
    healthSourcePreferences,
    matchHealthSummaries,
    healthSyncJobs,
    bleSensorDevices,
    keyValues,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'matches',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('match_health_summaries', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$PlayersTableCreateCompanionBuilder =
    PlayersCompanion Function({
      required String id,
      required String name,
      Value<String> nickname,
      Value<bool> isMe,
      Value<String> dominantHand,
      Value<String> preferredRole,
      Value<String> level,
      Value<String> goal,
      Value<String> clubs,
      Value<String> bio,
      Value<String> homeArea,
      Value<String> preferredSide,
      Value<String> preferredTime,
      Value<String> playFrequency,
      Value<String> privacy,
      Value<String?> avatarLocalPath,
      Value<String?> avatarCloudPath,
      Value<int> avatarVersion,
      Value<int> avatarCloudVersion,
      Value<String> availability,
      Value<String> styleTags,
      required int createdAtMs,
      Value<int> rowid,
    });
typedef $$PlayersTableUpdateCompanionBuilder =
    PlayersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> nickname,
      Value<bool> isMe,
      Value<String> dominantHand,
      Value<String> preferredRole,
      Value<String> level,
      Value<String> goal,
      Value<String> clubs,
      Value<String> bio,
      Value<String> homeArea,
      Value<String> preferredSide,
      Value<String> preferredTime,
      Value<String> playFrequency,
      Value<String> privacy,
      Value<String?> avatarLocalPath,
      Value<String?> avatarCloudPath,
      Value<int> avatarVersion,
      Value<int> avatarCloudVersion,
      Value<String> availability,
      Value<String> styleTags,
      Value<int> createdAtMs,
      Value<int> rowid,
    });

final class $$PlayersTableReferences
    extends BaseReferences<_$AppDatabase, $PlayersTable, Player> {
  $$PlayersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TeamsTable, List<Team>> _teamsAsPlayerATable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.teams,
    aliasName: $_aliasNameGenerator(db.players.id, db.teams.playerAId),
  );

  $$TeamsTableProcessedTableManager get teamsAsPlayerA {
    final manager = $$TeamsTableTableManager(
      $_db,
      $_db.teams,
    ).filter((f) => f.playerAId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_teamsAsPlayerATable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TeamsTable, List<Team>> _teamsAsPlayerBTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.teams,
    aliasName: $_aliasNameGenerator(db.players.id, db.teams.playerBId),
  );

  $$TeamsTableProcessedTableManager get teamsAsPlayerB {
    final manager = $$TeamsTableTableManager(
      $_db,
      $_db.teams,
    ).filter((f) => f.playerBId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_teamsAsPlayerBTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlayersTableFilterComposer
    extends Composer<_$AppDatabase, $PlayersTable> {
  $$PlayersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMe => $composableBuilder(
    column: $table.isMe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dominantHand => $composableBuilder(
    column: $table.dominantHand,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferredRole => $composableBuilder(
    column: $table.preferredRole,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get goal => $composableBuilder(
    column: $table.goal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clubs => $composableBuilder(
    column: $table.clubs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bio => $composableBuilder(
    column: $table.bio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get homeArea => $composableBuilder(
    column: $table.homeArea,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferredSide => $composableBuilder(
    column: $table.preferredSide,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferredTime => $composableBuilder(
    column: $table.preferredTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get playFrequency => $composableBuilder(
    column: $table.playFrequency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get privacy => $composableBuilder(
    column: $table.privacy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarLocalPath => $composableBuilder(
    column: $table.avatarLocalPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarCloudPath => $composableBuilder(
    column: $table.avatarCloudPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get avatarVersion => $composableBuilder(
    column: $table.avatarVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get avatarCloudVersion => $composableBuilder(
    column: $table.avatarCloudVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get availability => $composableBuilder(
    column: $table.availability,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get styleTags => $composableBuilder(
    column: $table.styleTags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> teamsAsPlayerA(
    Expression<bool> Function($$TeamsTableFilterComposer f) f,
  ) {
    final $$TeamsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.playerAId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableFilterComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> teamsAsPlayerB(
    Expression<bool> Function($$TeamsTableFilterComposer f) f,
  ) {
    final $$TeamsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.playerBId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableFilterComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlayersTableOrderingComposer
    extends Composer<_$AppDatabase, $PlayersTable> {
  $$PlayersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMe => $composableBuilder(
    column: $table.isMe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dominantHand => $composableBuilder(
    column: $table.dominantHand,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredRole => $composableBuilder(
    column: $table.preferredRole,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get goal => $composableBuilder(
    column: $table.goal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clubs => $composableBuilder(
    column: $table.clubs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bio => $composableBuilder(
    column: $table.bio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get homeArea => $composableBuilder(
    column: $table.homeArea,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredSide => $composableBuilder(
    column: $table.preferredSide,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredTime => $composableBuilder(
    column: $table.preferredTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playFrequency => $composableBuilder(
    column: $table.playFrequency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get privacy => $composableBuilder(
    column: $table.privacy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarLocalPath => $composableBuilder(
    column: $table.avatarLocalPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarCloudPath => $composableBuilder(
    column: $table.avatarCloudPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get avatarVersion => $composableBuilder(
    column: $table.avatarVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get avatarCloudVersion => $composableBuilder(
    column: $table.avatarCloudVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get availability => $composableBuilder(
    column: $table.availability,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get styleTags => $composableBuilder(
    column: $table.styleTags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlayersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlayersTable> {
  $$PlayersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get nickname =>
      $composableBuilder(column: $table.nickname, builder: (column) => column);

  GeneratedColumn<bool> get isMe =>
      $composableBuilder(column: $table.isMe, builder: (column) => column);

  GeneratedColumn<String> get dominantHand => $composableBuilder(
    column: $table.dominantHand,
    builder: (column) => column,
  );

  GeneratedColumn<String> get preferredRole => $composableBuilder(
    column: $table.preferredRole,
    builder: (column) => column,
  );

  GeneratedColumn<String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get goal =>
      $composableBuilder(column: $table.goal, builder: (column) => column);

  GeneratedColumn<String> get clubs =>
      $composableBuilder(column: $table.clubs, builder: (column) => column);

  GeneratedColumn<String> get bio =>
      $composableBuilder(column: $table.bio, builder: (column) => column);

  GeneratedColumn<String> get homeArea =>
      $composableBuilder(column: $table.homeArea, builder: (column) => column);

  GeneratedColumn<String> get preferredSide => $composableBuilder(
    column: $table.preferredSide,
    builder: (column) => column,
  );

  GeneratedColumn<String> get preferredTime => $composableBuilder(
    column: $table.preferredTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get playFrequency => $composableBuilder(
    column: $table.playFrequency,
    builder: (column) => column,
  );

  GeneratedColumn<String> get privacy =>
      $composableBuilder(column: $table.privacy, builder: (column) => column);

  GeneratedColumn<String> get avatarLocalPath => $composableBuilder(
    column: $table.avatarLocalPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get avatarCloudPath => $composableBuilder(
    column: $table.avatarCloudPath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get avatarVersion => $composableBuilder(
    column: $table.avatarVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get avatarCloudVersion => $composableBuilder(
    column: $table.avatarCloudVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get availability => $composableBuilder(
    column: $table.availability,
    builder: (column) => column,
  );

  GeneratedColumn<String> get styleTags =>
      $composableBuilder(column: $table.styleTags, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  Expression<T> teamsAsPlayerA<T extends Object>(
    Expression<T> Function($$TeamsTableAnnotationComposer a) f,
  ) {
    final $$TeamsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.playerAId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableAnnotationComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> teamsAsPlayerB<T extends Object>(
    Expression<T> Function($$TeamsTableAnnotationComposer a) f,
  ) {
    final $$TeamsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.playerBId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableAnnotationComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlayersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlayersTable,
          Player,
          $$PlayersTableFilterComposer,
          $$PlayersTableOrderingComposer,
          $$PlayersTableAnnotationComposer,
          $$PlayersTableCreateCompanionBuilder,
          $$PlayersTableUpdateCompanionBuilder,
          (Player, $$PlayersTableReferences),
          Player,
          PrefetchHooks Function({bool teamsAsPlayerA, bool teamsAsPlayerB})
        > {
  $$PlayersTableTableManager(_$AppDatabase db, $PlayersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlayersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlayersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> nickname = const Value.absent(),
                Value<bool> isMe = const Value.absent(),
                Value<String> dominantHand = const Value.absent(),
                Value<String> preferredRole = const Value.absent(),
                Value<String> level = const Value.absent(),
                Value<String> goal = const Value.absent(),
                Value<String> clubs = const Value.absent(),
                Value<String> bio = const Value.absent(),
                Value<String> homeArea = const Value.absent(),
                Value<String> preferredSide = const Value.absent(),
                Value<String> preferredTime = const Value.absent(),
                Value<String> playFrequency = const Value.absent(),
                Value<String> privacy = const Value.absent(),
                Value<String?> avatarLocalPath = const Value.absent(),
                Value<String?> avatarCloudPath = const Value.absent(),
                Value<int> avatarVersion = const Value.absent(),
                Value<int> avatarCloudVersion = const Value.absent(),
                Value<String> availability = const Value.absent(),
                Value<String> styleTags = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlayersCompanion(
                id: id,
                name: name,
                nickname: nickname,
                isMe: isMe,
                dominantHand: dominantHand,
                preferredRole: preferredRole,
                level: level,
                goal: goal,
                clubs: clubs,
                bio: bio,
                homeArea: homeArea,
                preferredSide: preferredSide,
                preferredTime: preferredTime,
                playFrequency: playFrequency,
                privacy: privacy,
                avatarLocalPath: avatarLocalPath,
                avatarCloudPath: avatarCloudPath,
                avatarVersion: avatarVersion,
                avatarCloudVersion: avatarCloudVersion,
                availability: availability,
                styleTags: styleTags,
                createdAtMs: createdAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> nickname = const Value.absent(),
                Value<bool> isMe = const Value.absent(),
                Value<String> dominantHand = const Value.absent(),
                Value<String> preferredRole = const Value.absent(),
                Value<String> level = const Value.absent(),
                Value<String> goal = const Value.absent(),
                Value<String> clubs = const Value.absent(),
                Value<String> bio = const Value.absent(),
                Value<String> homeArea = const Value.absent(),
                Value<String> preferredSide = const Value.absent(),
                Value<String> preferredTime = const Value.absent(),
                Value<String> playFrequency = const Value.absent(),
                Value<String> privacy = const Value.absent(),
                Value<String?> avatarLocalPath = const Value.absent(),
                Value<String?> avatarCloudPath = const Value.absent(),
                Value<int> avatarVersion = const Value.absent(),
                Value<int> avatarCloudVersion = const Value.absent(),
                Value<String> availability = const Value.absent(),
                Value<String> styleTags = const Value.absent(),
                required int createdAtMs,
                Value<int> rowid = const Value.absent(),
              }) => PlayersCompanion.insert(
                id: id,
                name: name,
                nickname: nickname,
                isMe: isMe,
                dominantHand: dominantHand,
                preferredRole: preferredRole,
                level: level,
                goal: goal,
                clubs: clubs,
                bio: bio,
                homeArea: homeArea,
                preferredSide: preferredSide,
                preferredTime: preferredTime,
                playFrequency: playFrequency,
                privacy: privacy,
                avatarLocalPath: avatarLocalPath,
                avatarCloudPath: avatarCloudPath,
                avatarVersion: avatarVersion,
                avatarCloudVersion: avatarCloudVersion,
                availability: availability,
                styleTags: styleTags,
                createdAtMs: createdAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlayersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({teamsAsPlayerA = false, teamsAsPlayerB = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (teamsAsPlayerA) db.teams,
                    if (teamsAsPlayerB) db.teams,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (teamsAsPlayerA)
                        await $_getPrefetchedData<Player, $PlayersTable, Team>(
                          currentTable: table,
                          referencedTable: $$PlayersTableReferences
                              ._teamsAsPlayerATable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlayersTableReferences(
                                db,
                                table,
                                p0,
                              ).teamsAsPlayerA,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.playerAId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (teamsAsPlayerB)
                        await $_getPrefetchedData<Player, $PlayersTable, Team>(
                          currentTable: table,
                          referencedTable: $$PlayersTableReferences
                              ._teamsAsPlayerBTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlayersTableReferences(
                                db,
                                table,
                                p0,
                              ).teamsAsPlayerB,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.playerBId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PlayersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlayersTable,
      Player,
      $$PlayersTableFilterComposer,
      $$PlayersTableOrderingComposer,
      $$PlayersTableAnnotationComposer,
      $$PlayersTableCreateCompanionBuilder,
      $$PlayersTableUpdateCompanionBuilder,
      (Player, $$PlayersTableReferences),
      Player,
      PrefetchHooks Function({bool teamsAsPlayerA, bool teamsAsPlayerB})
    >;
typedef $$TeamsTableCreateCompanionBuilder =
    TeamsCompanion Function({
      required String id,
      required String name,
      required String playerAId,
      Value<String?> playerBId,
      Value<String> playerBName,
      Value<String> roleA,
      Value<String> roleB,
      Value<String> tacticalNotes,
      Value<String> goals,
      Value<String?> imageLocalPath,
      Value<String?> imageCloudPath,
      Value<int> imageVersion,
      Value<int> imageCloudVersion,
      Value<String> scoringStyle,
      Value<int> colorArgb,
      Value<String?> cloudId,
      Value<String> cloudRole,
      Value<bool> archived,
      required int createdAtMs,
      Value<int> rowid,
    });
typedef $$TeamsTableUpdateCompanionBuilder =
    TeamsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> playerAId,
      Value<String?> playerBId,
      Value<String> playerBName,
      Value<String> roleA,
      Value<String> roleB,
      Value<String> tacticalNotes,
      Value<String> goals,
      Value<String?> imageLocalPath,
      Value<String?> imageCloudPath,
      Value<int> imageVersion,
      Value<int> imageCloudVersion,
      Value<String> scoringStyle,
      Value<int> colorArgb,
      Value<String?> cloudId,
      Value<String> cloudRole,
      Value<bool> archived,
      Value<int> createdAtMs,
      Value<int> rowid,
    });

final class $$TeamsTableReferences
    extends BaseReferences<_$AppDatabase, $TeamsTable, Team> {
  $$TeamsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PlayersTable _playerAIdTable(_$AppDatabase db) => db.players
      .createAlias($_aliasNameGenerator(db.teams.playerAId, db.players.id));

  $$PlayersTableProcessedTableManager get playerAId {
    final $_column = $_itemColumn<String>('player_a_id')!;

    final manager = $$PlayersTableTableManager(
      $_db,
      $_db.players,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playerAIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $PlayersTable _playerBIdTable(_$AppDatabase db) => db.players
      .createAlias($_aliasNameGenerator(db.teams.playerBId, db.players.id));

  $$PlayersTableProcessedTableManager? get playerBId {
    final $_column = $_itemColumn<String>('player_b_id');
    if ($_column == null) return null;
    final manager = $$PlayersTableTableManager(
      $_db,
      $_db.players,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playerBIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$MatchesTable, List<MatchRow>> _matchesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.matches,
    aliasName: $_aliasNameGenerator(db.teams.id, db.matches.teamId),
  );

  $$MatchesTableProcessedTableManager get matchesRefs {
    final manager = $$MatchesTableTableManager(
      $_db,
      $_db.matches,
    ).filter((f) => f.teamId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_matchesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TeamsTableFilterComposer extends Composer<_$AppDatabase, $TeamsTable> {
  $$TeamsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get playerBName => $composableBuilder(
    column: $table.playerBName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roleA => $composableBuilder(
    column: $table.roleA,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roleB => $composableBuilder(
    column: $table.roleB,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tacticalNotes => $composableBuilder(
    column: $table.tacticalNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get goals => $composableBuilder(
    column: $table.goals,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageLocalPath => $composableBuilder(
    column: $table.imageLocalPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageCloudPath => $composableBuilder(
    column: $table.imageCloudPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get imageVersion => $composableBuilder(
    column: $table.imageVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get imageCloudVersion => $composableBuilder(
    column: $table.imageCloudVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scoringStyle => $composableBuilder(
    column: $table.scoringStyle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get colorArgb => $composableBuilder(
    column: $table.colorArgb,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cloudId => $composableBuilder(
    column: $table.cloudId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cloudRole => $composableBuilder(
    column: $table.cloudRole,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  $$PlayersTableFilterComposer get playerAId {
    final $$PlayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerAId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableFilterComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlayersTableFilterComposer get playerBId {
    final $$PlayersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerBId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableFilterComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> matchesRefs(
    Expression<bool> Function($$MatchesTableFilterComposer f) f,
  ) {
    final $$MatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.teamId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableFilterComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TeamsTableOrderingComposer
    extends Composer<_$AppDatabase, $TeamsTable> {
  $$TeamsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playerBName => $composableBuilder(
    column: $table.playerBName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roleA => $composableBuilder(
    column: $table.roleA,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roleB => $composableBuilder(
    column: $table.roleB,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tacticalNotes => $composableBuilder(
    column: $table.tacticalNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get goals => $composableBuilder(
    column: $table.goals,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageLocalPath => $composableBuilder(
    column: $table.imageLocalPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageCloudPath => $composableBuilder(
    column: $table.imageCloudPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get imageVersion => $composableBuilder(
    column: $table.imageVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get imageCloudVersion => $composableBuilder(
    column: $table.imageCloudVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scoringStyle => $composableBuilder(
    column: $table.scoringStyle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get colorArgb => $composableBuilder(
    column: $table.colorArgb,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cloudId => $composableBuilder(
    column: $table.cloudId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cloudRole => $composableBuilder(
    column: $table.cloudRole,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlayersTableOrderingComposer get playerAId {
    final $$PlayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerAId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableOrderingComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlayersTableOrderingComposer get playerBId {
    final $$PlayersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerBId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableOrderingComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TeamsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TeamsTable> {
  $$TeamsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get playerBName => $composableBuilder(
    column: $table.playerBName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get roleA =>
      $composableBuilder(column: $table.roleA, builder: (column) => column);

  GeneratedColumn<String> get roleB =>
      $composableBuilder(column: $table.roleB, builder: (column) => column);

  GeneratedColumn<String> get tacticalNotes => $composableBuilder(
    column: $table.tacticalNotes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get goals =>
      $composableBuilder(column: $table.goals, builder: (column) => column);

  GeneratedColumn<String> get imageLocalPath => $composableBuilder(
    column: $table.imageLocalPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageCloudPath => $composableBuilder(
    column: $table.imageCloudPath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get imageVersion => $composableBuilder(
    column: $table.imageVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get imageCloudVersion => $composableBuilder(
    column: $table.imageCloudVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scoringStyle => $composableBuilder(
    column: $table.scoringStyle,
    builder: (column) => column,
  );

  GeneratedColumn<int> get colorArgb =>
      $composableBuilder(column: $table.colorArgb, builder: (column) => column);

  GeneratedColumn<String> get cloudId =>
      $composableBuilder(column: $table.cloudId, builder: (column) => column);

  GeneratedColumn<String> get cloudRole =>
      $composableBuilder(column: $table.cloudRole, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  $$PlayersTableAnnotationComposer get playerAId {
    final $$PlayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerAId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableAnnotationComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$PlayersTableAnnotationComposer get playerBId {
    final $$PlayersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playerBId,
      referencedTable: $db.players,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlayersTableAnnotationComposer(
            $db: $db,
            $table: $db.players,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> matchesRefs<T extends Object>(
    Expression<T> Function($$MatchesTableAnnotationComposer a) f,
  ) {
    final $$MatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.teamId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TeamsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TeamsTable,
          Team,
          $$TeamsTableFilterComposer,
          $$TeamsTableOrderingComposer,
          $$TeamsTableAnnotationComposer,
          $$TeamsTableCreateCompanionBuilder,
          $$TeamsTableUpdateCompanionBuilder,
          (Team, $$TeamsTableReferences),
          Team,
          PrefetchHooks Function({
            bool playerAId,
            bool playerBId,
            bool matchesRefs,
          })
        > {
  $$TeamsTableTableManager(_$AppDatabase db, $TeamsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TeamsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TeamsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TeamsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> playerAId = const Value.absent(),
                Value<String?> playerBId = const Value.absent(),
                Value<String> playerBName = const Value.absent(),
                Value<String> roleA = const Value.absent(),
                Value<String> roleB = const Value.absent(),
                Value<String> tacticalNotes = const Value.absent(),
                Value<String> goals = const Value.absent(),
                Value<String?> imageLocalPath = const Value.absent(),
                Value<String?> imageCloudPath = const Value.absent(),
                Value<int> imageVersion = const Value.absent(),
                Value<int> imageCloudVersion = const Value.absent(),
                Value<String> scoringStyle = const Value.absent(),
                Value<int> colorArgb = const Value.absent(),
                Value<String?> cloudId = const Value.absent(),
                Value<String> cloudRole = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TeamsCompanion(
                id: id,
                name: name,
                playerAId: playerAId,
                playerBId: playerBId,
                playerBName: playerBName,
                roleA: roleA,
                roleB: roleB,
                tacticalNotes: tacticalNotes,
                goals: goals,
                imageLocalPath: imageLocalPath,
                imageCloudPath: imageCloudPath,
                imageVersion: imageVersion,
                imageCloudVersion: imageCloudVersion,
                scoringStyle: scoringStyle,
                colorArgb: colorArgb,
                cloudId: cloudId,
                cloudRole: cloudRole,
                archived: archived,
                createdAtMs: createdAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String playerAId,
                Value<String?> playerBId = const Value.absent(),
                Value<String> playerBName = const Value.absent(),
                Value<String> roleA = const Value.absent(),
                Value<String> roleB = const Value.absent(),
                Value<String> tacticalNotes = const Value.absent(),
                Value<String> goals = const Value.absent(),
                Value<String?> imageLocalPath = const Value.absent(),
                Value<String?> imageCloudPath = const Value.absent(),
                Value<int> imageVersion = const Value.absent(),
                Value<int> imageCloudVersion = const Value.absent(),
                Value<String> scoringStyle = const Value.absent(),
                Value<int> colorArgb = const Value.absent(),
                Value<String?> cloudId = const Value.absent(),
                Value<String> cloudRole = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                required int createdAtMs,
                Value<int> rowid = const Value.absent(),
              }) => TeamsCompanion.insert(
                id: id,
                name: name,
                playerAId: playerAId,
                playerBId: playerBId,
                playerBName: playerBName,
                roleA: roleA,
                roleB: roleB,
                tacticalNotes: tacticalNotes,
                goals: goals,
                imageLocalPath: imageLocalPath,
                imageCloudPath: imageCloudPath,
                imageVersion: imageVersion,
                imageCloudVersion: imageCloudVersion,
                scoringStyle: scoringStyle,
                colorArgb: colorArgb,
                cloudId: cloudId,
                cloudRole: cloudRole,
                archived: archived,
                createdAtMs: createdAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TeamsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({playerAId = false, playerBId = false, matchesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [if (matchesRefs) db.matches],
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
                        if (playerAId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.playerAId,
                                    referencedTable: $$TeamsTableReferences
                                        ._playerAIdTable(db),
                                    referencedColumn: $$TeamsTableReferences
                                        ._playerAIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (playerBId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.playerBId,
                                    referencedTable: $$TeamsTableReferences
                                        ._playerBIdTable(db),
                                    referencedColumn: $$TeamsTableReferences
                                        ._playerBIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (matchesRefs)
                        await $_getPrefetchedData<Team, $TeamsTable, MatchRow>(
                          currentTable: table,
                          referencedTable: $$TeamsTableReferences
                              ._matchesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TeamsTableReferences(db, table, p0).matchesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.teamId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TeamsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TeamsTable,
      Team,
      $$TeamsTableFilterComposer,
      $$TeamsTableOrderingComposer,
      $$TeamsTableAnnotationComposer,
      $$TeamsTableCreateCompanionBuilder,
      $$TeamsTableUpdateCompanionBuilder,
      (Team, $$TeamsTableReferences),
      Team,
      PrefetchHooks Function({bool playerAId, bool playerBId, bool matchesRefs})
    >;
typedef $$MatchesTableCreateCompanionBuilder =
    MatchesCompanion Function({
      required String id,
      Value<String?> teamId,
      required String formatJson,
      Value<String> firstServer,
      Value<String> status,
      Value<int?> startTimeMs,
      Value<int?> endTimeMs,
      Value<bool?> wonByUs,
      Value<String> myRole,
      Value<String> opponentLabel,
      Value<String> opponentTags,
      Value<int> opponentDifficulty,
      Value<String> location,
      Value<String> notes,
      Value<String?> summaryJson,
      Value<bool> duoMode,
      Value<String?> duoTeam,
      Value<String?> duoSessionId,
      Value<String?> duoJoinCode,
      Value<String?> duoOwnerUserId,
      Value<String?> duoCloudStatus,
      Value<int?> duoLastSyncAtMs,
      Value<int> rowid,
    });
typedef $$MatchesTableUpdateCompanionBuilder =
    MatchesCompanion Function({
      Value<String> id,
      Value<String?> teamId,
      Value<String> formatJson,
      Value<String> firstServer,
      Value<String> status,
      Value<int?> startTimeMs,
      Value<int?> endTimeMs,
      Value<bool?> wonByUs,
      Value<String> myRole,
      Value<String> opponentLabel,
      Value<String> opponentTags,
      Value<int> opponentDifficulty,
      Value<String> location,
      Value<String> notes,
      Value<String?> summaryJson,
      Value<bool> duoMode,
      Value<String?> duoTeam,
      Value<String?> duoSessionId,
      Value<String?> duoJoinCode,
      Value<String?> duoOwnerUserId,
      Value<String?> duoCloudStatus,
      Value<int?> duoLastSyncAtMs,
      Value<int> rowid,
    });

final class $$MatchesTableReferences
    extends BaseReferences<_$AppDatabase, $MatchesTable, MatchRow> {
  $$MatchesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TeamsTable _teamIdTable(_$AppDatabase db) => db.teams.createAlias(
    $_aliasNameGenerator(db.matches.teamId, db.teams.id),
  );

  $$TeamsTableProcessedTableManager? get teamId {
    final $_column = $_itemColumn<String>('team_id');
    if ($_column == null) return null;
    final manager = $$TeamsTableTableManager(
      $_db,
      $_db.teams,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_teamIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$MatchEventRowsTable, List<MatchEventRow>>
  _matchEventRowsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.matchEventRows,
    aliasName: $_aliasNameGenerator(db.matches.id, db.matchEventRows.matchId),
  );

  $$MatchEventRowsTableProcessedTableManager get matchEventRowsRefs {
    final manager = $$MatchEventRowsTableTableManager(
      $_db,
      $_db.matchEventRows,
    ).filter((f) => f.matchId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_matchEventRowsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $MatchHealthSummariesTable,
    List<MatchHealthSummary>
  >
  _matchHealthSummariesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.matchHealthSummaries,
        aliasName: $_aliasNameGenerator(
          db.matches.id,
          db.matchHealthSummaries.matchId,
        ),
      );

  $$MatchHealthSummariesTableProcessedTableManager
  get matchHealthSummariesRefs {
    final manager = $$MatchHealthSummariesTableTableManager(
      $_db,
      $_db.matchHealthSummaries,
    ).filter((f) => f.matchId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _matchHealthSummariesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MatchesTableFilterComposer
    extends Composer<_$AppDatabase, $MatchesTable> {
  $$MatchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get formatJson => $composableBuilder(
    column: $table.formatJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firstServer => $composableBuilder(
    column: $table.firstServer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startTimeMs => $composableBuilder(
    column: $table.startTimeMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endTimeMs => $composableBuilder(
    column: $table.endTimeMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get wonByUs => $composableBuilder(
    column: $table.wonByUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get myRole => $composableBuilder(
    column: $table.myRole,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get opponentLabel => $composableBuilder(
    column: $table.opponentLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get opponentTags => $composableBuilder(
    column: $table.opponentTags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get opponentDifficulty => $composableBuilder(
    column: $table.opponentDifficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get duoMode => $composableBuilder(
    column: $table.duoMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get duoTeam => $composableBuilder(
    column: $table.duoTeam,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get duoSessionId => $composableBuilder(
    column: $table.duoSessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get duoJoinCode => $composableBuilder(
    column: $table.duoJoinCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get duoOwnerUserId => $composableBuilder(
    column: $table.duoOwnerUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get duoCloudStatus => $composableBuilder(
    column: $table.duoCloudStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get duoLastSyncAtMs => $composableBuilder(
    column: $table.duoLastSyncAtMs,
    builder: (column) => ColumnFilters(column),
  );

  $$TeamsTableFilterComposer get teamId {
    final $$TeamsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.teamId,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableFilterComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> matchEventRowsRefs(
    Expression<bool> Function($$MatchEventRowsTableFilterComposer f) f,
  ) {
    final $$MatchEventRowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchEventRows,
      getReferencedColumn: (t) => t.matchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchEventRowsTableFilterComposer(
            $db: $db,
            $table: $db.matchEventRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> matchHealthSummariesRefs(
    Expression<bool> Function($$MatchHealthSummariesTableFilterComposer f) f,
  ) {
    final $$MatchHealthSummariesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchHealthSummaries,
      getReferencedColumn: (t) => t.matchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchHealthSummariesTableFilterComposer(
            $db: $db,
            $table: $db.matchHealthSummaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MatchesTableOrderingComposer
    extends Composer<_$AppDatabase, $MatchesTable> {
  $$MatchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get formatJson => $composableBuilder(
    column: $table.formatJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firstServer => $composableBuilder(
    column: $table.firstServer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startTimeMs => $composableBuilder(
    column: $table.startTimeMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endTimeMs => $composableBuilder(
    column: $table.endTimeMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get wonByUs => $composableBuilder(
    column: $table.wonByUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get myRole => $composableBuilder(
    column: $table.myRole,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get opponentLabel => $composableBuilder(
    column: $table.opponentLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get opponentTags => $composableBuilder(
    column: $table.opponentTags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get opponentDifficulty => $composableBuilder(
    column: $table.opponentDifficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get duoMode => $composableBuilder(
    column: $table.duoMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get duoTeam => $composableBuilder(
    column: $table.duoTeam,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get duoSessionId => $composableBuilder(
    column: $table.duoSessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get duoJoinCode => $composableBuilder(
    column: $table.duoJoinCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get duoOwnerUserId => $composableBuilder(
    column: $table.duoOwnerUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get duoCloudStatus => $composableBuilder(
    column: $table.duoCloudStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get duoLastSyncAtMs => $composableBuilder(
    column: $table.duoLastSyncAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  $$TeamsTableOrderingComposer get teamId {
    final $$TeamsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.teamId,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableOrderingComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MatchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MatchesTable> {
  $$MatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get formatJson => $composableBuilder(
    column: $table.formatJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get firstServer => $composableBuilder(
    column: $table.firstServer,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get startTimeMs => $composableBuilder(
    column: $table.startTimeMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endTimeMs =>
      $composableBuilder(column: $table.endTimeMs, builder: (column) => column);

  GeneratedColumn<bool> get wonByUs =>
      $composableBuilder(column: $table.wonByUs, builder: (column) => column);

  GeneratedColumn<String> get myRole =>
      $composableBuilder(column: $table.myRole, builder: (column) => column);

  GeneratedColumn<String> get opponentLabel => $composableBuilder(
    column: $table.opponentLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get opponentTags => $composableBuilder(
    column: $table.opponentTags,
    builder: (column) => column,
  );

  GeneratedColumn<int> get opponentDifficulty => $composableBuilder(
    column: $table.opponentDifficulty,
    builder: (column) => column,
  );

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get duoMode =>
      $composableBuilder(column: $table.duoMode, builder: (column) => column);

  GeneratedColumn<String> get duoTeam =>
      $composableBuilder(column: $table.duoTeam, builder: (column) => column);

  GeneratedColumn<String> get duoSessionId => $composableBuilder(
    column: $table.duoSessionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get duoJoinCode => $composableBuilder(
    column: $table.duoJoinCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get duoOwnerUserId => $composableBuilder(
    column: $table.duoOwnerUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get duoCloudStatus => $composableBuilder(
    column: $table.duoCloudStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get duoLastSyncAtMs => $composableBuilder(
    column: $table.duoLastSyncAtMs,
    builder: (column) => column,
  );

  $$TeamsTableAnnotationComposer get teamId {
    final $$TeamsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.teamId,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableAnnotationComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> matchEventRowsRefs<T extends Object>(
    Expression<T> Function($$MatchEventRowsTableAnnotationComposer a) f,
  ) {
    final $$MatchEventRowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchEventRows,
      getReferencedColumn: (t) => t.matchId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchEventRowsTableAnnotationComposer(
            $db: $db,
            $table: $db.matchEventRows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> matchHealthSummariesRefs<T extends Object>(
    Expression<T> Function($$MatchHealthSummariesTableAnnotationComposer a) f,
  ) {
    final $$MatchHealthSummariesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.matchHealthSummaries,
          getReferencedColumn: (t) => t.matchId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MatchHealthSummariesTableAnnotationComposer(
                $db: $db,
                $table: $db.matchHealthSummaries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$MatchesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MatchesTable,
          MatchRow,
          $$MatchesTableFilterComposer,
          $$MatchesTableOrderingComposer,
          $$MatchesTableAnnotationComposer,
          $$MatchesTableCreateCompanionBuilder,
          $$MatchesTableUpdateCompanionBuilder,
          (MatchRow, $$MatchesTableReferences),
          MatchRow,
          PrefetchHooks Function({
            bool teamId,
            bool matchEventRowsRefs,
            bool matchHealthSummariesRefs,
          })
        > {
  $$MatchesTableTableManager(_$AppDatabase db, $MatchesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> teamId = const Value.absent(),
                Value<String> formatJson = const Value.absent(),
                Value<String> firstServer = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> startTimeMs = const Value.absent(),
                Value<int?> endTimeMs = const Value.absent(),
                Value<bool?> wonByUs = const Value.absent(),
                Value<String> myRole = const Value.absent(),
                Value<String> opponentLabel = const Value.absent(),
                Value<String> opponentTags = const Value.absent(),
                Value<int> opponentDifficulty = const Value.absent(),
                Value<String> location = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<String?> summaryJson = const Value.absent(),
                Value<bool> duoMode = const Value.absent(),
                Value<String?> duoTeam = const Value.absent(),
                Value<String?> duoSessionId = const Value.absent(),
                Value<String?> duoJoinCode = const Value.absent(),
                Value<String?> duoOwnerUserId = const Value.absent(),
                Value<String?> duoCloudStatus = const Value.absent(),
                Value<int?> duoLastSyncAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchesCompanion(
                id: id,
                teamId: teamId,
                formatJson: formatJson,
                firstServer: firstServer,
                status: status,
                startTimeMs: startTimeMs,
                endTimeMs: endTimeMs,
                wonByUs: wonByUs,
                myRole: myRole,
                opponentLabel: opponentLabel,
                opponentTags: opponentTags,
                opponentDifficulty: opponentDifficulty,
                location: location,
                notes: notes,
                summaryJson: summaryJson,
                duoMode: duoMode,
                duoTeam: duoTeam,
                duoSessionId: duoSessionId,
                duoJoinCode: duoJoinCode,
                duoOwnerUserId: duoOwnerUserId,
                duoCloudStatus: duoCloudStatus,
                duoLastSyncAtMs: duoLastSyncAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> teamId = const Value.absent(),
                required String formatJson,
                Value<String> firstServer = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int?> startTimeMs = const Value.absent(),
                Value<int?> endTimeMs = const Value.absent(),
                Value<bool?> wonByUs = const Value.absent(),
                Value<String> myRole = const Value.absent(),
                Value<String> opponentLabel = const Value.absent(),
                Value<String> opponentTags = const Value.absent(),
                Value<int> opponentDifficulty = const Value.absent(),
                Value<String> location = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<String?> summaryJson = const Value.absent(),
                Value<bool> duoMode = const Value.absent(),
                Value<String?> duoTeam = const Value.absent(),
                Value<String?> duoSessionId = const Value.absent(),
                Value<String?> duoJoinCode = const Value.absent(),
                Value<String?> duoOwnerUserId = const Value.absent(),
                Value<String?> duoCloudStatus = const Value.absent(),
                Value<int?> duoLastSyncAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchesCompanion.insert(
                id: id,
                teamId: teamId,
                formatJson: formatJson,
                firstServer: firstServer,
                status: status,
                startTimeMs: startTimeMs,
                endTimeMs: endTimeMs,
                wonByUs: wonByUs,
                myRole: myRole,
                opponentLabel: opponentLabel,
                opponentTags: opponentTags,
                opponentDifficulty: opponentDifficulty,
                location: location,
                notes: notes,
                summaryJson: summaryJson,
                duoMode: duoMode,
                duoTeam: duoTeam,
                duoSessionId: duoSessionId,
                duoJoinCode: duoJoinCode,
                duoOwnerUserId: duoOwnerUserId,
                duoCloudStatus: duoCloudStatus,
                duoLastSyncAtMs: duoLastSyncAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MatchesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                teamId = false,
                matchEventRowsRefs = false,
                matchHealthSummariesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (matchEventRowsRefs) db.matchEventRows,
                    if (matchHealthSummariesRefs) db.matchHealthSummaries,
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
                        if (teamId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.teamId,
                                    referencedTable: $$MatchesTableReferences
                                        ._teamIdTable(db),
                                    referencedColumn: $$MatchesTableReferences
                                        ._teamIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (matchEventRowsRefs)
                        await $_getPrefetchedData<
                          MatchRow,
                          $MatchesTable,
                          MatchEventRow
                        >(
                          currentTable: table,
                          referencedTable: $$MatchesTableReferences
                              ._matchEventRowsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MatchesTableReferences(
                                db,
                                table,
                                p0,
                              ).matchEventRowsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.matchId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (matchHealthSummariesRefs)
                        await $_getPrefetchedData<
                          MatchRow,
                          $MatchesTable,
                          MatchHealthSummary
                        >(
                          currentTable: table,
                          referencedTable: $$MatchesTableReferences
                              ._matchHealthSummariesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MatchesTableReferences(
                                db,
                                table,
                                p0,
                              ).matchHealthSummariesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.matchId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$MatchesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MatchesTable,
      MatchRow,
      $$MatchesTableFilterComposer,
      $$MatchesTableOrderingComposer,
      $$MatchesTableAnnotationComposer,
      $$MatchesTableCreateCompanionBuilder,
      $$MatchesTableUpdateCompanionBuilder,
      (MatchRow, $$MatchesTableReferences),
      MatchRow,
      PrefetchHooks Function({
        bool teamId,
        bool matchEventRowsRefs,
        bool matchHealthSummariesRefs,
      })
    >;
typedef $$MatchEventRowsTableCreateCompanionBuilder =
    MatchEventRowsCompanion Function({
      required String eventId,
      required String matchId,
      required int seq,
      required int timestampMs,
      required String type,
      Value<String?> teamId,
      Value<String?> scoreBefore,
      Value<String?> scoreAfter,
      Value<String> sourceDevice,
      Value<String> sourceMethod,
      Value<bool> synced,
      Value<String?> payloadJson,
      Value<String?> sourceUserId,
      Value<String?> sourceTeamId,
      Value<bool> duoMode,
      Value<int?> createdLocallyAtMs,
      Value<bool> cloudSynced,
      Value<int> rowid,
    });
typedef $$MatchEventRowsTableUpdateCompanionBuilder =
    MatchEventRowsCompanion Function({
      Value<String> eventId,
      Value<String> matchId,
      Value<int> seq,
      Value<int> timestampMs,
      Value<String> type,
      Value<String?> teamId,
      Value<String?> scoreBefore,
      Value<String?> scoreAfter,
      Value<String> sourceDevice,
      Value<String> sourceMethod,
      Value<bool> synced,
      Value<String?> payloadJson,
      Value<String?> sourceUserId,
      Value<String?> sourceTeamId,
      Value<bool> duoMode,
      Value<int?> createdLocallyAtMs,
      Value<bool> cloudSynced,
      Value<int> rowid,
    });

final class $$MatchEventRowsTableReferences
    extends BaseReferences<_$AppDatabase, $MatchEventRowsTable, MatchEventRow> {
  $$MatchEventRowsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MatchesTable _matchIdTable(_$AppDatabase db) =>
      db.matches.createAlias(
        $_aliasNameGenerator(db.matchEventRows.matchId, db.matches.id),
      );

  $$MatchesTableProcessedTableManager get matchId {
    final $_column = $_itemColumn<String>('match_id')!;

    final manager = $$MatchesTableTableManager(
      $_db,
      $_db.matches,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_matchIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MatchEventRowsTableFilterComposer
    extends Composer<_$AppDatabase, $MatchEventRowsTable> {
  $$MatchEventRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get teamId => $composableBuilder(
    column: $table.teamId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scoreBefore => $composableBuilder(
    column: $table.scoreBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scoreAfter => $composableBuilder(
    column: $table.scoreAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceDevice => $composableBuilder(
    column: $table.sourceDevice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceMethod => $composableBuilder(
    column: $table.sourceMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUserId => $composableBuilder(
    column: $table.sourceUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceTeamId => $composableBuilder(
    column: $table.sourceTeamId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get duoMode => $composableBuilder(
    column: $table.duoMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdLocallyAtMs => $composableBuilder(
    column: $table.createdLocallyAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get cloudSynced => $composableBuilder(
    column: $table.cloudSynced,
    builder: (column) => ColumnFilters(column),
  );

  $$MatchesTableFilterComposer get matchId {
    final $$MatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableFilterComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MatchEventRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $MatchEventRowsTable> {
  $$MatchEventRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get teamId => $composableBuilder(
    column: $table.teamId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scoreBefore => $composableBuilder(
    column: $table.scoreBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scoreAfter => $composableBuilder(
    column: $table.scoreAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceDevice => $composableBuilder(
    column: $table.sourceDevice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceMethod => $composableBuilder(
    column: $table.sourceMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUserId => $composableBuilder(
    column: $table.sourceUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceTeamId => $composableBuilder(
    column: $table.sourceTeamId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get duoMode => $composableBuilder(
    column: $table.duoMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdLocallyAtMs => $composableBuilder(
    column: $table.createdLocallyAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get cloudSynced => $composableBuilder(
    column: $table.cloudSynced,
    builder: (column) => ColumnOrderings(column),
  );

  $$MatchesTableOrderingComposer get matchId {
    final $$MatchesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableOrderingComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MatchEventRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MatchEventRowsTable> {
  $$MatchEventRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<int> get timestampMs => $composableBuilder(
    column: $table.timestampMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get teamId =>
      $composableBuilder(column: $table.teamId, builder: (column) => column);

  GeneratedColumn<String> get scoreBefore => $composableBuilder(
    column: $table.scoreBefore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scoreAfter => $composableBuilder(
    column: $table.scoreAfter,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceDevice => $composableBuilder(
    column: $table.sourceDevice,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceMethod => $composableBuilder(
    column: $table.sourceMethod,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceUserId => $composableBuilder(
    column: $table.sourceUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceTeamId => $composableBuilder(
    column: $table.sourceTeamId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get duoMode =>
      $composableBuilder(column: $table.duoMode, builder: (column) => column);

  GeneratedColumn<int> get createdLocallyAtMs => $composableBuilder(
    column: $table.createdLocallyAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get cloudSynced => $composableBuilder(
    column: $table.cloudSynced,
    builder: (column) => column,
  );

  $$MatchesTableAnnotationComposer get matchId {
    final $$MatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MatchEventRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MatchEventRowsTable,
          MatchEventRow,
          $$MatchEventRowsTableFilterComposer,
          $$MatchEventRowsTableOrderingComposer,
          $$MatchEventRowsTableAnnotationComposer,
          $$MatchEventRowsTableCreateCompanionBuilder,
          $$MatchEventRowsTableUpdateCompanionBuilder,
          (MatchEventRow, $$MatchEventRowsTableReferences),
          MatchEventRow,
          PrefetchHooks Function({bool matchId})
        > {
  $$MatchEventRowsTableTableManager(
    _$AppDatabase db,
    $MatchEventRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MatchEventRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MatchEventRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MatchEventRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> eventId = const Value.absent(),
                Value<String> matchId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<int> timestampMs = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> teamId = const Value.absent(),
                Value<String?> scoreBefore = const Value.absent(),
                Value<String?> scoreAfter = const Value.absent(),
                Value<String> sourceDevice = const Value.absent(),
                Value<String> sourceMethod = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<String?> payloadJson = const Value.absent(),
                Value<String?> sourceUserId = const Value.absent(),
                Value<String?> sourceTeamId = const Value.absent(),
                Value<bool> duoMode = const Value.absent(),
                Value<int?> createdLocallyAtMs = const Value.absent(),
                Value<bool> cloudSynced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchEventRowsCompanion(
                eventId: eventId,
                matchId: matchId,
                seq: seq,
                timestampMs: timestampMs,
                type: type,
                teamId: teamId,
                scoreBefore: scoreBefore,
                scoreAfter: scoreAfter,
                sourceDevice: sourceDevice,
                sourceMethod: sourceMethod,
                synced: synced,
                payloadJson: payloadJson,
                sourceUserId: sourceUserId,
                sourceTeamId: sourceTeamId,
                duoMode: duoMode,
                createdLocallyAtMs: createdLocallyAtMs,
                cloudSynced: cloudSynced,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String eventId,
                required String matchId,
                required int seq,
                required int timestampMs,
                required String type,
                Value<String?> teamId = const Value.absent(),
                Value<String?> scoreBefore = const Value.absent(),
                Value<String?> scoreAfter = const Value.absent(),
                Value<String> sourceDevice = const Value.absent(),
                Value<String> sourceMethod = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<String?> payloadJson = const Value.absent(),
                Value<String?> sourceUserId = const Value.absent(),
                Value<String?> sourceTeamId = const Value.absent(),
                Value<bool> duoMode = const Value.absent(),
                Value<int?> createdLocallyAtMs = const Value.absent(),
                Value<bool> cloudSynced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchEventRowsCompanion.insert(
                eventId: eventId,
                matchId: matchId,
                seq: seq,
                timestampMs: timestampMs,
                type: type,
                teamId: teamId,
                scoreBefore: scoreBefore,
                scoreAfter: scoreAfter,
                sourceDevice: sourceDevice,
                sourceMethod: sourceMethod,
                synced: synced,
                payloadJson: payloadJson,
                sourceUserId: sourceUserId,
                sourceTeamId: sourceTeamId,
                duoMode: duoMode,
                createdLocallyAtMs: createdLocallyAtMs,
                cloudSynced: cloudSynced,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MatchEventRowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({matchId = false}) {
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
                    if (matchId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.matchId,
                                referencedTable: $$MatchEventRowsTableReferences
                                    ._matchIdTable(db),
                                referencedColumn:
                                    $$MatchEventRowsTableReferences
                                        ._matchIdTable(db)
                                        .id,
                              )
                              as T;
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

typedef $$MatchEventRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MatchEventRowsTable,
      MatchEventRow,
      $$MatchEventRowsTableFilterComposer,
      $$MatchEventRowsTableOrderingComposer,
      $$MatchEventRowsTableAnnotationComposer,
      $$MatchEventRowsTableCreateCompanionBuilder,
      $$MatchEventRowsTableUpdateCompanionBuilder,
      (MatchEventRow, $$MatchEventRowsTableReferences),
      MatchEventRow,
      PrefetchHooks Function({bool matchId})
    >;
typedef $$TrainingsTableCreateCompanionBuilder =
    TrainingsCompanion Function({
      required String id,
      required String title,
      Value<String> description,
      Value<String> role,
      Value<bool> premium,
      Value<int> durationMinutes,
      Value<String> drillsJson,
      Value<int> rowid,
    });
typedef $$TrainingsTableUpdateCompanionBuilder =
    TrainingsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> description,
      Value<String> role,
      Value<bool> premium,
      Value<int> durationMinutes,
      Value<String> drillsJson,
      Value<int> rowid,
    });

final class $$TrainingsTableReferences
    extends BaseReferences<_$AppDatabase, $TrainingsTable, Training> {
  $$TrainingsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TrainingLogsTable, List<TrainingLog>>
  _trainingLogsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.trainingLogs,
    aliasName: $_aliasNameGenerator(
      db.trainings.id,
      db.trainingLogs.trainingId,
    ),
  );

  $$TrainingLogsTableProcessedTableManager get trainingLogsRefs {
    final manager = $$TrainingLogsTableTableManager(
      $_db,
      $_db.trainingLogs,
    ).filter((f) => f.trainingId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_trainingLogsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TrainingsTableFilterComposer
    extends Composer<_$AppDatabase, $TrainingsTable> {
  $$TrainingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get premium => $composableBuilder(
    column: $table.premium,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get drillsJson => $composableBuilder(
    column: $table.drillsJson,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> trainingLogsRefs(
    Expression<bool> Function($$TrainingLogsTableFilterComposer f) f,
  ) {
    final $$TrainingLogsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trainingLogs,
      getReferencedColumn: (t) => t.trainingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingLogsTableFilterComposer(
            $db: $db,
            $table: $db.trainingLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TrainingsTableOrderingComposer
    extends Composer<_$AppDatabase, $TrainingsTable> {
  $$TrainingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get premium => $composableBuilder(
    column: $table.premium,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get drillsJson => $composableBuilder(
    column: $table.drillsJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TrainingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrainingsTable> {
  $$TrainingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<bool> get premium =>
      $composableBuilder(column: $table.premium, builder: (column) => column);

  GeneratedColumn<int> get durationMinutes => $composableBuilder(
    column: $table.durationMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get drillsJson => $composableBuilder(
    column: $table.drillsJson,
    builder: (column) => column,
  );

  Expression<T> trainingLogsRefs<T extends Object>(
    Expression<T> Function($$TrainingLogsTableAnnotationComposer a) f,
  ) {
    final $$TrainingLogsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trainingLogs,
      getReferencedColumn: (t) => t.trainingId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingLogsTableAnnotationComposer(
            $db: $db,
            $table: $db.trainingLogs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TrainingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TrainingsTable,
          Training,
          $$TrainingsTableFilterComposer,
          $$TrainingsTableOrderingComposer,
          $$TrainingsTableAnnotationComposer,
          $$TrainingsTableCreateCompanionBuilder,
          $$TrainingsTableUpdateCompanionBuilder,
          (Training, $$TrainingsTableReferences),
          Training,
          PrefetchHooks Function({bool trainingLogsRefs})
        > {
  $$TrainingsTableTableManager(_$AppDatabase db, $TrainingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrainingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrainingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrainingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<bool> premium = const Value.absent(),
                Value<int> durationMinutes = const Value.absent(),
                Value<String> drillsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrainingsCompanion(
                id: id,
                title: title,
                description: description,
                role: role,
                premium: premium,
                durationMinutes: durationMinutes,
                drillsJson: drillsJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String> description = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<bool> premium = const Value.absent(),
                Value<int> durationMinutes = const Value.absent(),
                Value<String> drillsJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrainingsCompanion.insert(
                id: id,
                title: title,
                description: description,
                role: role,
                premium: premium,
                durationMinutes: durationMinutes,
                drillsJson: drillsJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TrainingsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trainingLogsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (trainingLogsRefs) db.trainingLogs],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (trainingLogsRefs)
                    await $_getPrefetchedData<
                      Training,
                      $TrainingsTable,
                      TrainingLog
                    >(
                      currentTable: table,
                      referencedTable: $$TrainingsTableReferences
                          ._trainingLogsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TrainingsTableReferences(
                            db,
                            table,
                            p0,
                          ).trainingLogsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.trainingId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TrainingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TrainingsTable,
      Training,
      $$TrainingsTableFilterComposer,
      $$TrainingsTableOrderingComposer,
      $$TrainingsTableAnnotationComposer,
      $$TrainingsTableCreateCompanionBuilder,
      $$TrainingsTableUpdateCompanionBuilder,
      (Training, $$TrainingsTableReferences),
      Training,
      PrefetchHooks Function({bool trainingLogsRefs})
    >;
typedef $$TrainingLogsTableCreateCompanionBuilder =
    TrainingLogsCompanion Function({
      required String id,
      required String trainingId,
      required int dateMs,
      Value<bool> completed,
      Value<String> notes,
      Value<int> rpe,
      Value<int> minutes,
      Value<int> rowid,
    });
typedef $$TrainingLogsTableUpdateCompanionBuilder =
    TrainingLogsCompanion Function({
      Value<String> id,
      Value<String> trainingId,
      Value<int> dateMs,
      Value<bool> completed,
      Value<String> notes,
      Value<int> rpe,
      Value<int> minutes,
      Value<int> rowid,
    });

final class $$TrainingLogsTableReferences
    extends BaseReferences<_$AppDatabase, $TrainingLogsTable, TrainingLog> {
  $$TrainingLogsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TrainingsTable _trainingIdTable(_$AppDatabase db) =>
      db.trainings.createAlias(
        $_aliasNameGenerator(db.trainingLogs.trainingId, db.trainings.id),
      );

  $$TrainingsTableProcessedTableManager get trainingId {
    final $_column = $_itemColumn<String>('training_id')!;

    final manager = $$TrainingsTableTableManager(
      $_db,
      $_db.trainings,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trainingIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TrainingLogsTableFilterComposer
    extends Composer<_$AppDatabase, $TrainingLogsTable> {
  $$TrainingLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dateMs => $composableBuilder(
    column: $table.dateMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rpe => $composableBuilder(
    column: $table.rpe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minutes => $composableBuilder(
    column: $table.minutes,
    builder: (column) => ColumnFilters(column),
  );

  $$TrainingsTableFilterComposer get trainingId {
    final $$TrainingsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trainingId,
      referencedTable: $db.trainings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingsTableFilterComposer(
            $db: $db,
            $table: $db.trainings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrainingLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $TrainingLogsTable> {
  $$TrainingLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dateMs => $composableBuilder(
    column: $table.dateMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rpe => $composableBuilder(
    column: $table.rpe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minutes => $composableBuilder(
    column: $table.minutes,
    builder: (column) => ColumnOrderings(column),
  );

  $$TrainingsTableOrderingComposer get trainingId {
    final $$TrainingsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trainingId,
      referencedTable: $db.trainings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingsTableOrderingComposer(
            $db: $db,
            $table: $db.trainings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrainingLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrainingLogsTable> {
  $$TrainingLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get dateMs =>
      $composableBuilder(column: $table.dateMs, builder: (column) => column);

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get rpe =>
      $composableBuilder(column: $table.rpe, builder: (column) => column);

  GeneratedColumn<int> get minutes =>
      $composableBuilder(column: $table.minutes, builder: (column) => column);

  $$TrainingsTableAnnotationComposer get trainingId {
    final $$TrainingsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trainingId,
      referencedTable: $db.trainings,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrainingsTableAnnotationComposer(
            $db: $db,
            $table: $db.trainings,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrainingLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TrainingLogsTable,
          TrainingLog,
          $$TrainingLogsTableFilterComposer,
          $$TrainingLogsTableOrderingComposer,
          $$TrainingLogsTableAnnotationComposer,
          $$TrainingLogsTableCreateCompanionBuilder,
          $$TrainingLogsTableUpdateCompanionBuilder,
          (TrainingLog, $$TrainingLogsTableReferences),
          TrainingLog,
          PrefetchHooks Function({bool trainingId})
        > {
  $$TrainingLogsTableTableManager(_$AppDatabase db, $TrainingLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrainingLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrainingLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrainingLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> trainingId = const Value.absent(),
                Value<int> dateMs = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<int> rpe = const Value.absent(),
                Value<int> minutes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrainingLogsCompanion(
                id: id,
                trainingId: trainingId,
                dateMs: dateMs,
                completed: completed,
                notes: notes,
                rpe: rpe,
                minutes: minutes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String trainingId,
                required int dateMs,
                Value<bool> completed = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<int> rpe = const Value.absent(),
                Value<int> minutes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrainingLogsCompanion.insert(
                id: id,
                trainingId: trainingId,
                dateMs: dateMs,
                completed: completed,
                notes: notes,
                rpe: rpe,
                minutes: minutes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TrainingLogsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trainingId = false}) {
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
                    if (trainingId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.trainingId,
                                referencedTable: $$TrainingLogsTableReferences
                                    ._trainingIdTable(db),
                                referencedColumn: $$TrainingLogsTableReferences
                                    ._trainingIdTable(db)
                                    .id,
                              )
                              as T;
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

typedef $$TrainingLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TrainingLogsTable,
      TrainingLog,
      $$TrainingLogsTableFilterComposer,
      $$TrainingLogsTableOrderingComposer,
      $$TrainingLogsTableAnnotationComposer,
      $$TrainingLogsTableCreateCompanionBuilder,
      $$TrainingLogsTableUpdateCompanionBuilder,
      (TrainingLog, $$TrainingLogsTableReferences),
      TrainingLog,
      PrefetchHooks Function({bool trainingId})
    >;
typedef $$ConnectedDevicesTableCreateCompanionBuilder =
    ConnectedDevicesCompanion Function({
      required String id,
      required String platform,
      Value<String> family,
      Value<String> displayName,
      Value<String> alias,
      Value<String> status,
      Value<String> capabilitiesJson,
      Value<bool> companionInstalled,
      Value<bool> permissionsComplete,
      Value<bool> isDefault,
      Value<int> setupStep,
      Value<int?> lastSeenAtMs,
      Value<int?> lastSyncAtMs,
      required int createdAtMs,
      Value<int> rowid,
    });
typedef $$ConnectedDevicesTableUpdateCompanionBuilder =
    ConnectedDevicesCompanion Function({
      Value<String> id,
      Value<String> platform,
      Value<String> family,
      Value<String> displayName,
      Value<String> alias,
      Value<String> status,
      Value<String> capabilitiesJson,
      Value<bool> companionInstalled,
      Value<bool> permissionsComplete,
      Value<bool> isDefault,
      Value<int> setupStep,
      Value<int?> lastSeenAtMs,
      Value<int?> lastSyncAtMs,
      Value<int> createdAtMs,
      Value<int> rowid,
    });

class $$ConnectedDevicesTableFilterComposer
    extends Composer<_$AppDatabase, $ConnectedDevicesTable> {
  $$ConnectedDevicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get family => $composableBuilder(
    column: $table.family,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alias => $composableBuilder(
    column: $table.alias,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capabilitiesJson => $composableBuilder(
    column: $table.capabilitiesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get companionInstalled => $composableBuilder(
    column: $table.companionInstalled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get permissionsComplete => $composableBuilder(
    column: $table.permissionsComplete,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get setupStep => $composableBuilder(
    column: $table.setupStep,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeenAtMs => $composableBuilder(
    column: $table.lastSeenAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSyncAtMs => $composableBuilder(
    column: $table.lastSyncAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConnectedDevicesTableOrderingComposer
    extends Composer<_$AppDatabase, $ConnectedDevicesTable> {
  $$ConnectedDevicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get family => $composableBuilder(
    column: $table.family,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alias => $composableBuilder(
    column: $table.alias,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capabilitiesJson => $composableBuilder(
    column: $table.capabilitiesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get companionInstalled => $composableBuilder(
    column: $table.companionInstalled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get permissionsComplete => $composableBuilder(
    column: $table.permissionsComplete,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get setupStep => $composableBuilder(
    column: $table.setupStep,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeenAtMs => $composableBuilder(
    column: $table.lastSeenAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSyncAtMs => $composableBuilder(
    column: $table.lastSyncAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConnectedDevicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConnectedDevicesTable> {
  $$ConnectedDevicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumn<String> get family =>
      $composableBuilder(column: $table.family, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get alias =>
      $composableBuilder(column: $table.alias, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get capabilitiesJson => $composableBuilder(
    column: $table.capabilitiesJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get companionInstalled => $composableBuilder(
    column: $table.companionInstalled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get permissionsComplete => $composableBuilder(
    column: $table.permissionsComplete,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<int> get setupStep =>
      $composableBuilder(column: $table.setupStep, builder: (column) => column);

  GeneratedColumn<int> get lastSeenAtMs => $composableBuilder(
    column: $table.lastSeenAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSyncAtMs => $composableBuilder(
    column: $table.lastSyncAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );
}

class $$ConnectedDevicesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConnectedDevicesTable,
          ConnectedDevice,
          $$ConnectedDevicesTableFilterComposer,
          $$ConnectedDevicesTableOrderingComposer,
          $$ConnectedDevicesTableAnnotationComposer,
          $$ConnectedDevicesTableCreateCompanionBuilder,
          $$ConnectedDevicesTableUpdateCompanionBuilder,
          (
            ConnectedDevice,
            BaseReferences<
              _$AppDatabase,
              $ConnectedDevicesTable,
              ConnectedDevice
            >,
          ),
          ConnectedDevice,
          PrefetchHooks Function()
        > {
  $$ConnectedDevicesTableTableManager(
    _$AppDatabase db,
    $ConnectedDevicesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConnectedDevicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConnectedDevicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConnectedDevicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> platform = const Value.absent(),
                Value<String> family = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> alias = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> capabilitiesJson = const Value.absent(),
                Value<bool> companionInstalled = const Value.absent(),
                Value<bool> permissionsComplete = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<int> setupStep = const Value.absent(),
                Value<int?> lastSeenAtMs = const Value.absent(),
                Value<int?> lastSyncAtMs = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConnectedDevicesCompanion(
                id: id,
                platform: platform,
                family: family,
                displayName: displayName,
                alias: alias,
                status: status,
                capabilitiesJson: capabilitiesJson,
                companionInstalled: companionInstalled,
                permissionsComplete: permissionsComplete,
                isDefault: isDefault,
                setupStep: setupStep,
                lastSeenAtMs: lastSeenAtMs,
                lastSyncAtMs: lastSyncAtMs,
                createdAtMs: createdAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String platform,
                Value<String> family = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> alias = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> capabilitiesJson = const Value.absent(),
                Value<bool> companionInstalled = const Value.absent(),
                Value<bool> permissionsComplete = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<int> setupStep = const Value.absent(),
                Value<int?> lastSeenAtMs = const Value.absent(),
                Value<int?> lastSyncAtMs = const Value.absent(),
                required int createdAtMs,
                Value<int> rowid = const Value.absent(),
              }) => ConnectedDevicesCompanion.insert(
                id: id,
                platform: platform,
                family: family,
                displayName: displayName,
                alias: alias,
                status: status,
                capabilitiesJson: capabilitiesJson,
                companionInstalled: companionInstalled,
                permissionsComplete: permissionsComplete,
                isDefault: isDefault,
                setupStep: setupStep,
                lastSeenAtMs: lastSeenAtMs,
                lastSyncAtMs: lastSyncAtMs,
                createdAtMs: createdAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConnectedDevicesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConnectedDevicesTable,
      ConnectedDevice,
      $$ConnectedDevicesTableFilterComposer,
      $$ConnectedDevicesTableOrderingComposer,
      $$ConnectedDevicesTableAnnotationComposer,
      $$ConnectedDevicesTableCreateCompanionBuilder,
      $$ConnectedDevicesTableUpdateCompanionBuilder,
      (
        ConnectedDevice,
        BaseReferences<_$AppDatabase, $ConnectedDevicesTable, ConnectedDevice>,
      ),
      ConnectedDevice,
      PrefetchHooks Function()
    >;
typedef $$HealthDataSourcesTableCreateCompanionBuilder =
    HealthDataSourcesCompanion Function({
      required String id,
      Value<String> ownerId,
      required String provider,
      Value<String> sourceApplication,
      Value<String> sourceBundleId,
      Value<String> sourceDevice,
      Value<String> sourceModel,
      Value<String?> connectionId,
      Value<bool> isPreferred,
      Value<bool> supportsLiveData,
      Value<String> availableMetricsJson,
      required int detectedAtMs,
      required int updatedAtMs,
      Value<int> rowid,
    });
typedef $$HealthDataSourcesTableUpdateCompanionBuilder =
    HealthDataSourcesCompanion Function({
      Value<String> id,
      Value<String> ownerId,
      Value<String> provider,
      Value<String> sourceApplication,
      Value<String> sourceBundleId,
      Value<String> sourceDevice,
      Value<String> sourceModel,
      Value<String?> connectionId,
      Value<bool> isPreferred,
      Value<bool> supportsLiveData,
      Value<String> availableMetricsJson,
      Value<int> detectedAtMs,
      Value<int> updatedAtMs,
      Value<int> rowid,
    });

final class $$HealthDataSourcesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $HealthDataSourcesTable,
          HealthDataSource
        > {
  $$HealthDataSourcesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $HealthMetricRecordsTable,
    List<HealthMetricRecord>
  >
  _healthMetricRecordsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.healthMetricRecords,
        aliasName: $_aliasNameGenerator(
          db.healthDataSources.id,
          db.healthMetricRecords.sourceId,
        ),
      );

  $$HealthMetricRecordsTableProcessedTableManager get healthMetricRecordsRefs {
    final manager = $$HealthMetricRecordsTableTableManager(
      $_db,
      $_db.healthMetricRecords,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _healthMetricRecordsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $HealthSourcePreferencesTable,
    List<HealthSourcePreference>
  >
  _healthSourcePreferencesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.healthSourcePreferences,
        aliasName: $_aliasNameGenerator(
          db.healthDataSources.id,
          db.healthSourcePreferences.sourceId,
        ),
      );

  $$HealthSourcePreferencesTableProcessedTableManager
  get healthSourcePreferencesRefs {
    final manager = $$HealthSourcePreferencesTableTableManager(
      $_db,
      $_db.healthSourcePreferences,
    ).filter((f) => f.sourceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _healthSourcePreferencesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $MatchHealthSummariesTable,
    List<MatchHealthSummary>
  >
  _matchHealthSummariesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.matchHealthSummaries,
        aliasName: $_aliasNameGenerator(
          db.healthDataSources.id,
          db.matchHealthSummaries.primarySourceId,
        ),
      );

  $$MatchHealthSummariesTableProcessedTableManager
  get matchHealthSummariesRefs {
    final manager =
        $$MatchHealthSummariesTableTableManager(
          $_db,
          $_db.matchHealthSummaries,
        ).filter(
          (f) => f.primarySourceId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _matchHealthSummariesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$HealthDataSourcesTableFilterComposer
    extends Composer<_$AppDatabase, $HealthDataSourcesTable> {
  $$HealthDataSourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceApplication => $composableBuilder(
    column: $table.sourceApplication,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceBundleId => $composableBuilder(
    column: $table.sourceBundleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceDevice => $composableBuilder(
    column: $table.sourceDevice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceModel => $composableBuilder(
    column: $table.sourceModel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get connectionId => $composableBuilder(
    column: $table.connectionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPreferred => $composableBuilder(
    column: $table.isPreferred,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get supportsLiveData => $composableBuilder(
    column: $table.supportsLiveData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get availableMetricsJson => $composableBuilder(
    column: $table.availableMetricsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get detectedAtMs => $composableBuilder(
    column: $table.detectedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> healthMetricRecordsRefs(
    Expression<bool> Function($$HealthMetricRecordsTableFilterComposer f) f,
  ) {
    final $$HealthMetricRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.healthMetricRecords,
      getReferencedColumn: (t) => t.sourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HealthMetricRecordsTableFilterComposer(
            $db: $db,
            $table: $db.healthMetricRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> healthSourcePreferencesRefs(
    Expression<bool> Function($$HealthSourcePreferencesTableFilterComposer f) f,
  ) {
    final $$HealthSourcePreferencesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.healthSourcePreferences,
          getReferencedColumn: (t) => t.sourceId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$HealthSourcePreferencesTableFilterComposer(
                $db: $db,
                $table: $db.healthSourcePreferences,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> matchHealthSummariesRefs(
    Expression<bool> Function($$MatchHealthSummariesTableFilterComposer f) f,
  ) {
    final $$MatchHealthSummariesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.matchHealthSummaries,
      getReferencedColumn: (t) => t.primarySourceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchHealthSummariesTableFilterComposer(
            $db: $db,
            $table: $db.matchHealthSummaries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$HealthDataSourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $HealthDataSourcesTable> {
  $$HealthDataSourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceApplication => $composableBuilder(
    column: $table.sourceApplication,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceBundleId => $composableBuilder(
    column: $table.sourceBundleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceDevice => $composableBuilder(
    column: $table.sourceDevice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceModel => $composableBuilder(
    column: $table.sourceModel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get connectionId => $composableBuilder(
    column: $table.connectionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPreferred => $composableBuilder(
    column: $table.isPreferred,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get supportsLiveData => $composableBuilder(
    column: $table.supportsLiveData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get availableMetricsJson => $composableBuilder(
    column: $table.availableMetricsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get detectedAtMs => $composableBuilder(
    column: $table.detectedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HealthDataSourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $HealthDataSourcesTable> {
  $$HealthDataSourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get sourceApplication => $composableBuilder(
    column: $table.sourceApplication,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceBundleId => $composableBuilder(
    column: $table.sourceBundleId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceDevice => $composableBuilder(
    column: $table.sourceDevice,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceModel => $composableBuilder(
    column: $table.sourceModel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get connectionId => $composableBuilder(
    column: $table.connectionId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPreferred => $composableBuilder(
    column: $table.isPreferred,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get supportsLiveData => $composableBuilder(
    column: $table.supportsLiveData,
    builder: (column) => column,
  );

  GeneratedColumn<String> get availableMetricsJson => $composableBuilder(
    column: $table.availableMetricsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get detectedAtMs => $composableBuilder(
    column: $table.detectedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );

  Expression<T> healthMetricRecordsRefs<T extends Object>(
    Expression<T> Function($$HealthMetricRecordsTableAnnotationComposer a) f,
  ) {
    final $$HealthMetricRecordsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.healthMetricRecords,
          getReferencedColumn: (t) => t.sourceId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$HealthMetricRecordsTableAnnotationComposer(
                $db: $db,
                $table: $db.healthMetricRecords,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> healthSourcePreferencesRefs<T extends Object>(
    Expression<T> Function($$HealthSourcePreferencesTableAnnotationComposer a)
    f,
  ) {
    final $$HealthSourcePreferencesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.healthSourcePreferences,
          getReferencedColumn: (t) => t.sourceId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$HealthSourcePreferencesTableAnnotationComposer(
                $db: $db,
                $table: $db.healthSourcePreferences,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> matchHealthSummariesRefs<T extends Object>(
    Expression<T> Function($$MatchHealthSummariesTableAnnotationComposer a) f,
  ) {
    final $$MatchHealthSummariesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.matchHealthSummaries,
          getReferencedColumn: (t) => t.primarySourceId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MatchHealthSummariesTableAnnotationComposer(
                $db: $db,
                $table: $db.matchHealthSummaries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$HealthDataSourcesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HealthDataSourcesTable,
          HealthDataSource,
          $$HealthDataSourcesTableFilterComposer,
          $$HealthDataSourcesTableOrderingComposer,
          $$HealthDataSourcesTableAnnotationComposer,
          $$HealthDataSourcesTableCreateCompanionBuilder,
          $$HealthDataSourcesTableUpdateCompanionBuilder,
          (HealthDataSource, $$HealthDataSourcesTableReferences),
          HealthDataSource,
          PrefetchHooks Function({
            bool healthMetricRecordsRefs,
            bool healthSourcePreferencesRefs,
            bool matchHealthSummariesRefs,
          })
        > {
  $$HealthDataSourcesTableTableManager(
    _$AppDatabase db,
    $HealthDataSourcesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HealthDataSourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HealthDataSourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HealthDataSourcesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> sourceApplication = const Value.absent(),
                Value<String> sourceBundleId = const Value.absent(),
                Value<String> sourceDevice = const Value.absent(),
                Value<String> sourceModel = const Value.absent(),
                Value<String?> connectionId = const Value.absent(),
                Value<bool> isPreferred = const Value.absent(),
                Value<bool> supportsLiveData = const Value.absent(),
                Value<String> availableMetricsJson = const Value.absent(),
                Value<int> detectedAtMs = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HealthDataSourcesCompanion(
                id: id,
                ownerId: ownerId,
                provider: provider,
                sourceApplication: sourceApplication,
                sourceBundleId: sourceBundleId,
                sourceDevice: sourceDevice,
                sourceModel: sourceModel,
                connectionId: connectionId,
                isPreferred: isPreferred,
                supportsLiveData: supportsLiveData,
                availableMetricsJson: availableMetricsJson,
                detectedAtMs: detectedAtMs,
                updatedAtMs: updatedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> ownerId = const Value.absent(),
                required String provider,
                Value<String> sourceApplication = const Value.absent(),
                Value<String> sourceBundleId = const Value.absent(),
                Value<String> sourceDevice = const Value.absent(),
                Value<String> sourceModel = const Value.absent(),
                Value<String?> connectionId = const Value.absent(),
                Value<bool> isPreferred = const Value.absent(),
                Value<bool> supportsLiveData = const Value.absent(),
                Value<String> availableMetricsJson = const Value.absent(),
                required int detectedAtMs,
                required int updatedAtMs,
                Value<int> rowid = const Value.absent(),
              }) => HealthDataSourcesCompanion.insert(
                id: id,
                ownerId: ownerId,
                provider: provider,
                sourceApplication: sourceApplication,
                sourceBundleId: sourceBundleId,
                sourceDevice: sourceDevice,
                sourceModel: sourceModel,
                connectionId: connectionId,
                isPreferred: isPreferred,
                supportsLiveData: supportsLiveData,
                availableMetricsJson: availableMetricsJson,
                detectedAtMs: detectedAtMs,
                updatedAtMs: updatedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$HealthDataSourcesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                healthMetricRecordsRefs = false,
                healthSourcePreferencesRefs = false,
                matchHealthSummariesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (healthMetricRecordsRefs) db.healthMetricRecords,
                    if (healthSourcePreferencesRefs) db.healthSourcePreferences,
                    if (matchHealthSummariesRefs) db.matchHealthSummaries,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (healthMetricRecordsRefs)
                        await $_getPrefetchedData<
                          HealthDataSource,
                          $HealthDataSourcesTable,
                          HealthMetricRecord
                        >(
                          currentTable: table,
                          referencedTable: $$HealthDataSourcesTableReferences
                              ._healthMetricRecordsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$HealthDataSourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).healthMetricRecordsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (healthSourcePreferencesRefs)
                        await $_getPrefetchedData<
                          HealthDataSource,
                          $HealthDataSourcesTable,
                          HealthSourcePreference
                        >(
                          currentTable: table,
                          referencedTable: $$HealthDataSourcesTableReferences
                              ._healthSourcePreferencesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$HealthDataSourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).healthSourcePreferencesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (matchHealthSummariesRefs)
                        await $_getPrefetchedData<
                          HealthDataSource,
                          $HealthDataSourcesTable,
                          MatchHealthSummary
                        >(
                          currentTable: table,
                          referencedTable: $$HealthDataSourcesTableReferences
                              ._matchHealthSummariesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$HealthDataSourcesTableReferences(
                                db,
                                table,
                                p0,
                              ).matchHealthSummariesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.primarySourceId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$HealthDataSourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HealthDataSourcesTable,
      HealthDataSource,
      $$HealthDataSourcesTableFilterComposer,
      $$HealthDataSourcesTableOrderingComposer,
      $$HealthDataSourcesTableAnnotationComposer,
      $$HealthDataSourcesTableCreateCompanionBuilder,
      $$HealthDataSourcesTableUpdateCompanionBuilder,
      (HealthDataSource, $$HealthDataSourcesTableReferences),
      HealthDataSource,
      PrefetchHooks Function({
        bool healthMetricRecordsRefs,
        bool healthSourcePreferencesRefs,
        bool matchHealthSummariesRefs,
      })
    >;
typedef $$HealthMetricRecordsTableCreateCompanionBuilder =
    HealthMetricRecordsCompanion Function({
      required String id,
      Value<String> ownerId,
      required String provider,
      required String sourceId,
      Value<String?> externalRecordId,
      required String metricType,
      required int startTimeMs,
      required int endTimeMs,
      required double value,
      required String unit,
      Value<String> metadataJson,
      required String contentHash,
      Value<int> syncVersion,
      Value<bool> synced,
      required int createdAtMs,
      required int updatedAtMs,
      Value<int> rowid,
    });
typedef $$HealthMetricRecordsTableUpdateCompanionBuilder =
    HealthMetricRecordsCompanion Function({
      Value<String> id,
      Value<String> ownerId,
      Value<String> provider,
      Value<String> sourceId,
      Value<String?> externalRecordId,
      Value<String> metricType,
      Value<int> startTimeMs,
      Value<int> endTimeMs,
      Value<double> value,
      Value<String> unit,
      Value<String> metadataJson,
      Value<String> contentHash,
      Value<int> syncVersion,
      Value<bool> synced,
      Value<int> createdAtMs,
      Value<int> updatedAtMs,
      Value<int> rowid,
    });

final class $$HealthMetricRecordsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $HealthMetricRecordsTable,
          HealthMetricRecord
        > {
  $$HealthMetricRecordsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $HealthDataSourcesTable _sourceIdTable(_$AppDatabase db) =>
      db.healthDataSources.createAlias(
        $_aliasNameGenerator(
          db.healthMetricRecords.sourceId,
          db.healthDataSources.id,
        ),
      );

  $$HealthDataSourcesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $$HealthDataSourcesTableTableManager(
      $_db,
      $_db.healthDataSources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$HealthMetricRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $HealthMetricRecordsTable> {
  $$HealthMetricRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalRecordId => $composableBuilder(
    column: $table.externalRecordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metricType => $composableBuilder(
    column: $table.metricType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startTimeMs => $composableBuilder(
    column: $table.startTimeMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endTimeMs => $composableBuilder(
    column: $table.endTimeMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  $$HealthDataSourcesTableFilterComposer get sourceId {
    final $$HealthDataSourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.healthDataSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HealthDataSourcesTableFilterComposer(
            $db: $db,
            $table: $db.healthDataSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HealthMetricRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $HealthMetricRecordsTable> {
  $$HealthMetricRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalRecordId => $composableBuilder(
    column: $table.externalRecordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metricType => $composableBuilder(
    column: $table.metricType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startTimeMs => $composableBuilder(
    column: $table.startTimeMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endTimeMs => $composableBuilder(
    column: $table.endTimeMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  $$HealthDataSourcesTableOrderingComposer get sourceId {
    final $$HealthDataSourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.healthDataSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HealthDataSourcesTableOrderingComposer(
            $db: $db,
            $table: $db.healthDataSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HealthMetricRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HealthMetricRecordsTable> {
  $$HealthMetricRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get externalRecordId => $composableBuilder(
    column: $table.externalRecordId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get metricType => $composableBuilder(
    column: $table.metricType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startTimeMs => $composableBuilder(
    column: $table.startTimeMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endTimeMs =>
      $composableBuilder(column: $table.endTimeMs, builder: (column) => column);

  GeneratedColumn<double> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get contentHash => $composableBuilder(
    column: $table.contentHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncVersion => $composableBuilder(
    column: $table.syncVersion,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );

  $$HealthDataSourcesTableAnnotationComposer get sourceId {
    final $$HealthDataSourcesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sourceId,
          referencedTable: $db.healthDataSources,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$HealthDataSourcesTableAnnotationComposer(
                $db: $db,
                $table: $db.healthDataSources,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$HealthMetricRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HealthMetricRecordsTable,
          HealthMetricRecord,
          $$HealthMetricRecordsTableFilterComposer,
          $$HealthMetricRecordsTableOrderingComposer,
          $$HealthMetricRecordsTableAnnotationComposer,
          $$HealthMetricRecordsTableCreateCompanionBuilder,
          $$HealthMetricRecordsTableUpdateCompanionBuilder,
          (HealthMetricRecord, $$HealthMetricRecordsTableReferences),
          HealthMetricRecord,
          PrefetchHooks Function({bool sourceId})
        > {
  $$HealthMetricRecordsTableTableManager(
    _$AppDatabase db,
    $HealthMetricRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HealthMetricRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HealthMetricRecordsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$HealthMetricRecordsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String?> externalRecordId = const Value.absent(),
                Value<String> metricType = const Value.absent(),
                Value<int> startTimeMs = const Value.absent(),
                Value<int> endTimeMs = const Value.absent(),
                Value<double> value = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<String> metadataJson = const Value.absent(),
                Value<String> contentHash = const Value.absent(),
                Value<int> syncVersion = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HealthMetricRecordsCompanion(
                id: id,
                ownerId: ownerId,
                provider: provider,
                sourceId: sourceId,
                externalRecordId: externalRecordId,
                metricType: metricType,
                startTimeMs: startTimeMs,
                endTimeMs: endTimeMs,
                value: value,
                unit: unit,
                metadataJson: metadataJson,
                contentHash: contentHash,
                syncVersion: syncVersion,
                synced: synced,
                createdAtMs: createdAtMs,
                updatedAtMs: updatedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> ownerId = const Value.absent(),
                required String provider,
                required String sourceId,
                Value<String?> externalRecordId = const Value.absent(),
                required String metricType,
                required int startTimeMs,
                required int endTimeMs,
                required double value,
                required String unit,
                Value<String> metadataJson = const Value.absent(),
                required String contentHash,
                Value<int> syncVersion = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                required int createdAtMs,
                required int updatedAtMs,
                Value<int> rowid = const Value.absent(),
              }) => HealthMetricRecordsCompanion.insert(
                id: id,
                ownerId: ownerId,
                provider: provider,
                sourceId: sourceId,
                externalRecordId: externalRecordId,
                metricType: metricType,
                startTimeMs: startTimeMs,
                endTimeMs: endTimeMs,
                value: value,
                unit: unit,
                metadataJson: metadataJson,
                contentHash: contentHash,
                syncVersion: syncVersion,
                synced: synced,
                createdAtMs: createdAtMs,
                updatedAtMs: updatedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$HealthMetricRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sourceId = false}) {
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
                    if (sourceId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sourceId,
                                referencedTable:
                                    $$HealthMetricRecordsTableReferences
                                        ._sourceIdTable(db),
                                referencedColumn:
                                    $$HealthMetricRecordsTableReferences
                                        ._sourceIdTable(db)
                                        .id,
                              )
                              as T;
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

typedef $$HealthMetricRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HealthMetricRecordsTable,
      HealthMetricRecord,
      $$HealthMetricRecordsTableFilterComposer,
      $$HealthMetricRecordsTableOrderingComposer,
      $$HealthMetricRecordsTableAnnotationComposer,
      $$HealthMetricRecordsTableCreateCompanionBuilder,
      $$HealthMetricRecordsTableUpdateCompanionBuilder,
      (HealthMetricRecord, $$HealthMetricRecordsTableReferences),
      HealthMetricRecord,
      PrefetchHooks Function({bool sourceId})
    >;
typedef $$HealthSourcePreferencesTableCreateCompanionBuilder =
    HealthSourcePreferencesCompanion Function({
      Value<String> ownerId,
      required String metricType,
      required String sourceId,
      required int updatedAtMs,
      Value<int> rowid,
    });
typedef $$HealthSourcePreferencesTableUpdateCompanionBuilder =
    HealthSourcePreferencesCompanion Function({
      Value<String> ownerId,
      Value<String> metricType,
      Value<String> sourceId,
      Value<int> updatedAtMs,
      Value<int> rowid,
    });

final class $$HealthSourcePreferencesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $HealthSourcePreferencesTable,
          HealthSourcePreference
        > {
  $$HealthSourcePreferencesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $HealthDataSourcesTable _sourceIdTable(_$AppDatabase db) =>
      db.healthDataSources.createAlias(
        $_aliasNameGenerator(
          db.healthSourcePreferences.sourceId,
          db.healthDataSources.id,
        ),
      );

  $$HealthDataSourcesTableProcessedTableManager get sourceId {
    final $_column = $_itemColumn<String>('source_id')!;

    final manager = $$HealthDataSourcesTableTableManager(
      $_db,
      $_db.healthDataSources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$HealthSourcePreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $HealthSourcePreferencesTable> {
  $$HealthSourcePreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metricType => $composableBuilder(
    column: $table.metricType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  $$HealthDataSourcesTableFilterComposer get sourceId {
    final $$HealthDataSourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.healthDataSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HealthDataSourcesTableFilterComposer(
            $db: $db,
            $table: $db.healthDataSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HealthSourcePreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $HealthSourcePreferencesTable> {
  $$HealthSourcePreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metricType => $composableBuilder(
    column: $table.metricType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  $$HealthDataSourcesTableOrderingComposer get sourceId {
    final $$HealthDataSourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sourceId,
      referencedTable: $db.healthDataSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HealthDataSourcesTableOrderingComposer(
            $db: $db,
            $table: $db.healthDataSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$HealthSourcePreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $HealthSourcePreferencesTable> {
  $$HealthSourcePreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get metricType => $composableBuilder(
    column: $table.metricType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );

  $$HealthDataSourcesTableAnnotationComposer get sourceId {
    final $$HealthDataSourcesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.sourceId,
          referencedTable: $db.healthDataSources,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$HealthDataSourcesTableAnnotationComposer(
                $db: $db,
                $table: $db.healthDataSources,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$HealthSourcePreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HealthSourcePreferencesTable,
          HealthSourcePreference,
          $$HealthSourcePreferencesTableFilterComposer,
          $$HealthSourcePreferencesTableOrderingComposer,
          $$HealthSourcePreferencesTableAnnotationComposer,
          $$HealthSourcePreferencesTableCreateCompanionBuilder,
          $$HealthSourcePreferencesTableUpdateCompanionBuilder,
          (HealthSourcePreference, $$HealthSourcePreferencesTableReferences),
          HealthSourcePreference,
          PrefetchHooks Function({bool sourceId})
        > {
  $$HealthSourcePreferencesTableTableManager(
    _$AppDatabase db,
    $HealthSourcePreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HealthSourcePreferencesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$HealthSourcePreferencesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$HealthSourcePreferencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> ownerId = const Value.absent(),
                Value<String> metricType = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HealthSourcePreferencesCompanion(
                ownerId: ownerId,
                metricType: metricType,
                sourceId: sourceId,
                updatedAtMs: updatedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> ownerId = const Value.absent(),
                required String metricType,
                required String sourceId,
                required int updatedAtMs,
                Value<int> rowid = const Value.absent(),
              }) => HealthSourcePreferencesCompanion.insert(
                ownerId: ownerId,
                metricType: metricType,
                sourceId: sourceId,
                updatedAtMs: updatedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$HealthSourcePreferencesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sourceId = false}) {
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
                    if (sourceId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sourceId,
                                referencedTable:
                                    $$HealthSourcePreferencesTableReferences
                                        ._sourceIdTable(db),
                                referencedColumn:
                                    $$HealthSourcePreferencesTableReferences
                                        ._sourceIdTable(db)
                                        .id,
                              )
                              as T;
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

typedef $$HealthSourcePreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HealthSourcePreferencesTable,
      HealthSourcePreference,
      $$HealthSourcePreferencesTableFilterComposer,
      $$HealthSourcePreferencesTableOrderingComposer,
      $$HealthSourcePreferencesTableAnnotationComposer,
      $$HealthSourcePreferencesTableCreateCompanionBuilder,
      $$HealthSourcePreferencesTableUpdateCompanionBuilder,
      (HealthSourcePreference, $$HealthSourcePreferencesTableReferences),
      HealthSourcePreference,
      PrefetchHooks Function({bool sourceId})
    >;
typedef $$MatchHealthSummariesTableCreateCompanionBuilder =
    MatchHealthSummariesCompanion Function({
      required String id,
      required String matchId,
      Value<String> ownerId,
      Value<String?> primarySourceId,
      Value<int?> durationSeconds,
      Value<double?> averageHeartRate,
      Value<double?> maxHeartRate,
      Value<double?> minHeartRate,
      Value<double?> activeEnergyKcal,
      Value<double?> totalEnergyKcal,
      Value<int?> steps,
      Value<double?> distanceMeters,
      Value<int?> highIntensityMinutes,
      Value<double?> recoveryDelta,
      Value<double?> sleepScore,
      Value<double?> readinessScore,
      Value<double?> recoveryScore,
      Value<double?> strainScore,
      Value<String> dataQuality,
      required int calculatedAtMs,
      Value<bool> synced,
      Value<int> rowid,
    });
typedef $$MatchHealthSummariesTableUpdateCompanionBuilder =
    MatchHealthSummariesCompanion Function({
      Value<String> id,
      Value<String> matchId,
      Value<String> ownerId,
      Value<String?> primarySourceId,
      Value<int?> durationSeconds,
      Value<double?> averageHeartRate,
      Value<double?> maxHeartRate,
      Value<double?> minHeartRate,
      Value<double?> activeEnergyKcal,
      Value<double?> totalEnergyKcal,
      Value<int?> steps,
      Value<double?> distanceMeters,
      Value<int?> highIntensityMinutes,
      Value<double?> recoveryDelta,
      Value<double?> sleepScore,
      Value<double?> readinessScore,
      Value<double?> recoveryScore,
      Value<double?> strainScore,
      Value<String> dataQuality,
      Value<int> calculatedAtMs,
      Value<bool> synced,
      Value<int> rowid,
    });

final class $$MatchHealthSummariesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $MatchHealthSummariesTable,
          MatchHealthSummary
        > {
  $$MatchHealthSummariesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MatchesTable _matchIdTable(_$AppDatabase db) =>
      db.matches.createAlias(
        $_aliasNameGenerator(db.matchHealthSummaries.matchId, db.matches.id),
      );

  $$MatchesTableProcessedTableManager get matchId {
    final $_column = $_itemColumn<String>('match_id')!;

    final manager = $$MatchesTableTableManager(
      $_db,
      $_db.matches,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_matchIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $HealthDataSourcesTable _primarySourceIdTable(_$AppDatabase db) =>
      db.healthDataSources.createAlias(
        $_aliasNameGenerator(
          db.matchHealthSummaries.primarySourceId,
          db.healthDataSources.id,
        ),
      );

  $$HealthDataSourcesTableProcessedTableManager? get primarySourceId {
    final $_column = $_itemColumn<String>('primary_source_id');
    if ($_column == null) return null;
    final manager = $$HealthDataSourcesTableTableManager(
      $_db,
      $_db.healthDataSources,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_primarySourceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MatchHealthSummariesTableFilterComposer
    extends Composer<_$AppDatabase, $MatchHealthSummariesTable> {
  $$MatchHealthSummariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get averageHeartRate => $composableBuilder(
    column: $table.averageHeartRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get maxHeartRate => $composableBuilder(
    column: $table.maxHeartRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get minHeartRate => $composableBuilder(
    column: $table.minHeartRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get activeEnergyKcal => $composableBuilder(
    column: $table.activeEnergyKcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalEnergyKcal => $composableBuilder(
    column: $table.totalEnergyKcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get distanceMeters => $composableBuilder(
    column: $table.distanceMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get highIntensityMinutes => $composableBuilder(
    column: $table.highIntensityMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get recoveryDelta => $composableBuilder(
    column: $table.recoveryDelta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sleepScore => $composableBuilder(
    column: $table.sleepScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get readinessScore => $composableBuilder(
    column: $table.readinessScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get recoveryScore => $composableBuilder(
    column: $table.recoveryScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get strainScore => $composableBuilder(
    column: $table.strainScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataQuality => $composableBuilder(
    column: $table.dataQuality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get calculatedAtMs => $composableBuilder(
    column: $table.calculatedAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );

  $$MatchesTableFilterComposer get matchId {
    final $$MatchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableFilterComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$HealthDataSourcesTableFilterComposer get primarySourceId {
    final $$HealthDataSourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.primarySourceId,
      referencedTable: $db.healthDataSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HealthDataSourcesTableFilterComposer(
            $db: $db,
            $table: $db.healthDataSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MatchHealthSummariesTableOrderingComposer
    extends Composer<_$AppDatabase, $MatchHealthSummariesTable> {
  $$MatchHealthSummariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get averageHeartRate => $composableBuilder(
    column: $table.averageHeartRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get maxHeartRate => $composableBuilder(
    column: $table.maxHeartRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get minHeartRate => $composableBuilder(
    column: $table.minHeartRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get activeEnergyKcal => $composableBuilder(
    column: $table.activeEnergyKcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalEnergyKcal => $composableBuilder(
    column: $table.totalEnergyKcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get distanceMeters => $composableBuilder(
    column: $table.distanceMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get highIntensityMinutes => $composableBuilder(
    column: $table.highIntensityMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get recoveryDelta => $composableBuilder(
    column: $table.recoveryDelta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sleepScore => $composableBuilder(
    column: $table.sleepScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get readinessScore => $composableBuilder(
    column: $table.readinessScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get recoveryScore => $composableBuilder(
    column: $table.recoveryScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get strainScore => $composableBuilder(
    column: $table.strainScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataQuality => $composableBuilder(
    column: $table.dataQuality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get calculatedAtMs => $composableBuilder(
    column: $table.calculatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );

  $$MatchesTableOrderingComposer get matchId {
    final $$MatchesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableOrderingComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$HealthDataSourcesTableOrderingComposer get primarySourceId {
    final $$HealthDataSourcesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.primarySourceId,
      referencedTable: $db.healthDataSources,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$HealthDataSourcesTableOrderingComposer(
            $db: $db,
            $table: $db.healthDataSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MatchHealthSummariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MatchHealthSummariesTable> {
  $$MatchHealthSummariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<double> get averageHeartRate => $composableBuilder(
    column: $table.averageHeartRate,
    builder: (column) => column,
  );

  GeneratedColumn<double> get maxHeartRate => $composableBuilder(
    column: $table.maxHeartRate,
    builder: (column) => column,
  );

  GeneratedColumn<double> get minHeartRate => $composableBuilder(
    column: $table.minHeartRate,
    builder: (column) => column,
  );

  GeneratedColumn<double> get activeEnergyKcal => $composableBuilder(
    column: $table.activeEnergyKcal,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalEnergyKcal => $composableBuilder(
    column: $table.totalEnergyKcal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get steps =>
      $composableBuilder(column: $table.steps, builder: (column) => column);

  GeneratedColumn<double> get distanceMeters => $composableBuilder(
    column: $table.distanceMeters,
    builder: (column) => column,
  );

  GeneratedColumn<int> get highIntensityMinutes => $composableBuilder(
    column: $table.highIntensityMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<double> get recoveryDelta => $composableBuilder(
    column: $table.recoveryDelta,
    builder: (column) => column,
  );

  GeneratedColumn<double> get sleepScore => $composableBuilder(
    column: $table.sleepScore,
    builder: (column) => column,
  );

  GeneratedColumn<double> get readinessScore => $composableBuilder(
    column: $table.readinessScore,
    builder: (column) => column,
  );

  GeneratedColumn<double> get recoveryScore => $composableBuilder(
    column: $table.recoveryScore,
    builder: (column) => column,
  );

  GeneratedColumn<double> get strainScore => $composableBuilder(
    column: $table.strainScore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dataQuality => $composableBuilder(
    column: $table.dataQuality,
    builder: (column) => column,
  );

  GeneratedColumn<int> get calculatedAtMs => $composableBuilder(
    column: $table.calculatedAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);

  $$MatchesTableAnnotationComposer get matchId {
    final $$MatchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.matchId,
      referencedTable: $db.matches,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MatchesTableAnnotationComposer(
            $db: $db,
            $table: $db.matches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$HealthDataSourcesTableAnnotationComposer get primarySourceId {
    final $$HealthDataSourcesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.primarySourceId,
          referencedTable: $db.healthDataSources,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$HealthDataSourcesTableAnnotationComposer(
                $db: $db,
                $table: $db.healthDataSources,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$MatchHealthSummariesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MatchHealthSummariesTable,
          MatchHealthSummary,
          $$MatchHealthSummariesTableFilterComposer,
          $$MatchHealthSummariesTableOrderingComposer,
          $$MatchHealthSummariesTableAnnotationComposer,
          $$MatchHealthSummariesTableCreateCompanionBuilder,
          $$MatchHealthSummariesTableUpdateCompanionBuilder,
          (MatchHealthSummary, $$MatchHealthSummariesTableReferences),
          MatchHealthSummary,
          PrefetchHooks Function({bool matchId, bool primarySourceId})
        > {
  $$MatchHealthSummariesTableTableManager(
    _$AppDatabase db,
    $MatchHealthSummariesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MatchHealthSummariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MatchHealthSummariesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MatchHealthSummariesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> matchId = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String?> primarySourceId = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<double?> averageHeartRate = const Value.absent(),
                Value<double?> maxHeartRate = const Value.absent(),
                Value<double?> minHeartRate = const Value.absent(),
                Value<double?> activeEnergyKcal = const Value.absent(),
                Value<double?> totalEnergyKcal = const Value.absent(),
                Value<int?> steps = const Value.absent(),
                Value<double?> distanceMeters = const Value.absent(),
                Value<int?> highIntensityMinutes = const Value.absent(),
                Value<double?> recoveryDelta = const Value.absent(),
                Value<double?> sleepScore = const Value.absent(),
                Value<double?> readinessScore = const Value.absent(),
                Value<double?> recoveryScore = const Value.absent(),
                Value<double?> strainScore = const Value.absent(),
                Value<String> dataQuality = const Value.absent(),
                Value<int> calculatedAtMs = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchHealthSummariesCompanion(
                id: id,
                matchId: matchId,
                ownerId: ownerId,
                primarySourceId: primarySourceId,
                durationSeconds: durationSeconds,
                averageHeartRate: averageHeartRate,
                maxHeartRate: maxHeartRate,
                minHeartRate: minHeartRate,
                activeEnergyKcal: activeEnergyKcal,
                totalEnergyKcal: totalEnergyKcal,
                steps: steps,
                distanceMeters: distanceMeters,
                highIntensityMinutes: highIntensityMinutes,
                recoveryDelta: recoveryDelta,
                sleepScore: sleepScore,
                readinessScore: readinessScore,
                recoveryScore: recoveryScore,
                strainScore: strainScore,
                dataQuality: dataQuality,
                calculatedAtMs: calculatedAtMs,
                synced: synced,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String matchId,
                Value<String> ownerId = const Value.absent(),
                Value<String?> primarySourceId = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<double?> averageHeartRate = const Value.absent(),
                Value<double?> maxHeartRate = const Value.absent(),
                Value<double?> minHeartRate = const Value.absent(),
                Value<double?> activeEnergyKcal = const Value.absent(),
                Value<double?> totalEnergyKcal = const Value.absent(),
                Value<int?> steps = const Value.absent(),
                Value<double?> distanceMeters = const Value.absent(),
                Value<int?> highIntensityMinutes = const Value.absent(),
                Value<double?> recoveryDelta = const Value.absent(),
                Value<double?> sleepScore = const Value.absent(),
                Value<double?> readinessScore = const Value.absent(),
                Value<double?> recoveryScore = const Value.absent(),
                Value<double?> strainScore = const Value.absent(),
                Value<String> dataQuality = const Value.absent(),
                required int calculatedAtMs,
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MatchHealthSummariesCompanion.insert(
                id: id,
                matchId: matchId,
                ownerId: ownerId,
                primarySourceId: primarySourceId,
                durationSeconds: durationSeconds,
                averageHeartRate: averageHeartRate,
                maxHeartRate: maxHeartRate,
                minHeartRate: minHeartRate,
                activeEnergyKcal: activeEnergyKcal,
                totalEnergyKcal: totalEnergyKcal,
                steps: steps,
                distanceMeters: distanceMeters,
                highIntensityMinutes: highIntensityMinutes,
                recoveryDelta: recoveryDelta,
                sleepScore: sleepScore,
                readinessScore: readinessScore,
                recoveryScore: recoveryScore,
                strainScore: strainScore,
                dataQuality: dataQuality,
                calculatedAtMs: calculatedAtMs,
                synced: synced,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MatchHealthSummariesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({matchId = false, primarySourceId = false}) {
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
                    if (matchId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.matchId,
                                referencedTable:
                                    $$MatchHealthSummariesTableReferences
                                        ._matchIdTable(db),
                                referencedColumn:
                                    $$MatchHealthSummariesTableReferences
                                        ._matchIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (primarySourceId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.primarySourceId,
                                referencedTable:
                                    $$MatchHealthSummariesTableReferences
                                        ._primarySourceIdTable(db),
                                referencedColumn:
                                    $$MatchHealthSummariesTableReferences
                                        ._primarySourceIdTable(db)
                                        .id,
                              )
                              as T;
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

typedef $$MatchHealthSummariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MatchHealthSummariesTable,
      MatchHealthSummary,
      $$MatchHealthSummariesTableFilterComposer,
      $$MatchHealthSummariesTableOrderingComposer,
      $$MatchHealthSummariesTableAnnotationComposer,
      $$MatchHealthSummariesTableCreateCompanionBuilder,
      $$MatchHealthSummariesTableUpdateCompanionBuilder,
      (MatchHealthSummary, $$MatchHealthSummariesTableReferences),
      MatchHealthSummary,
      PrefetchHooks Function({bool matchId, bool primarySourceId})
    >;
typedef $$HealthSyncJobsTableCreateCompanionBuilder =
    HealthSyncJobsCompanion Function({
      required String id,
      Value<String> ownerId,
      required String provider,
      required String syncType,
      Value<int?> dateFromMs,
      Value<int?> dateToMs,
      Value<String> status,
      Value<int> retryCount,
      Value<int?> nextRetryAtMs,
      Value<String?> lastErrorCode,
      required int createdAtMs,
      Value<int?> completedAtMs,
      Value<int> rowid,
    });
typedef $$HealthSyncJobsTableUpdateCompanionBuilder =
    HealthSyncJobsCompanion Function({
      Value<String> id,
      Value<String> ownerId,
      Value<String> provider,
      Value<String> syncType,
      Value<int?> dateFromMs,
      Value<int?> dateToMs,
      Value<String> status,
      Value<int> retryCount,
      Value<int?> nextRetryAtMs,
      Value<String?> lastErrorCode,
      Value<int> createdAtMs,
      Value<int?> completedAtMs,
      Value<int> rowid,
    });

class $$HealthSyncJobsTableFilterComposer
    extends Composer<_$AppDatabase, $HealthSyncJobsTable> {
  $$HealthSyncJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncType => $composableBuilder(
    column: $table.syncType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dateFromMs => $composableBuilder(
    column: $table.dateFromMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dateToMs => $composableBuilder(
    column: $table.dateToMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextRetryAtMs => $composableBuilder(
    column: $table.nextRetryAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAtMs => $composableBuilder(
    column: $table.completedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HealthSyncJobsTableOrderingComposer
    extends Composer<_$AppDatabase, $HealthSyncJobsTable> {
  $$HealthSyncJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncType => $composableBuilder(
    column: $table.syncType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dateFromMs => $composableBuilder(
    column: $table.dateFromMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dateToMs => $composableBuilder(
    column: $table.dateToMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextRetryAtMs => $composableBuilder(
    column: $table.nextRetryAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAtMs => $composableBuilder(
    column: $table.completedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HealthSyncJobsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HealthSyncJobsTable> {
  $$HealthSyncJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get syncType =>
      $composableBuilder(column: $table.syncType, builder: (column) => column);

  GeneratedColumn<int> get dateFromMs => $composableBuilder(
    column: $table.dateFromMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dateToMs =>
      $composableBuilder(column: $table.dateToMs, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nextRetryAtMs => $composableBuilder(
    column: $table.nextRetryAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedAtMs => $composableBuilder(
    column: $table.completedAtMs,
    builder: (column) => column,
  );
}

class $$HealthSyncJobsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HealthSyncJobsTable,
          HealthSyncJob,
          $$HealthSyncJobsTableFilterComposer,
          $$HealthSyncJobsTableOrderingComposer,
          $$HealthSyncJobsTableAnnotationComposer,
          $$HealthSyncJobsTableCreateCompanionBuilder,
          $$HealthSyncJobsTableUpdateCompanionBuilder,
          (
            HealthSyncJob,
            BaseReferences<_$AppDatabase, $HealthSyncJobsTable, HealthSyncJob>,
          ),
          HealthSyncJob,
          PrefetchHooks Function()
        > {
  $$HealthSyncJobsTableTableManager(
    _$AppDatabase db,
    $HealthSyncJobsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HealthSyncJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HealthSyncJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HealthSyncJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ownerId = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String> syncType = const Value.absent(),
                Value<int?> dateFromMs = const Value.absent(),
                Value<int?> dateToMs = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<int?> nextRetryAtMs = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<int?> completedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HealthSyncJobsCompanion(
                id: id,
                ownerId: ownerId,
                provider: provider,
                syncType: syncType,
                dateFromMs: dateFromMs,
                dateToMs: dateToMs,
                status: status,
                retryCount: retryCount,
                nextRetryAtMs: nextRetryAtMs,
                lastErrorCode: lastErrorCode,
                createdAtMs: createdAtMs,
                completedAtMs: completedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> ownerId = const Value.absent(),
                required String provider,
                required String syncType,
                Value<int?> dateFromMs = const Value.absent(),
                Value<int?> dateToMs = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<int?> nextRetryAtMs = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
                required int createdAtMs,
                Value<int?> completedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HealthSyncJobsCompanion.insert(
                id: id,
                ownerId: ownerId,
                provider: provider,
                syncType: syncType,
                dateFromMs: dateFromMs,
                dateToMs: dateToMs,
                status: status,
                retryCount: retryCount,
                nextRetryAtMs: nextRetryAtMs,
                lastErrorCode: lastErrorCode,
                createdAtMs: createdAtMs,
                completedAtMs: completedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HealthSyncJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HealthSyncJobsTable,
      HealthSyncJob,
      $$HealthSyncJobsTableFilterComposer,
      $$HealthSyncJobsTableOrderingComposer,
      $$HealthSyncJobsTableAnnotationComposer,
      $$HealthSyncJobsTableCreateCompanionBuilder,
      $$HealthSyncJobsTableUpdateCompanionBuilder,
      (
        HealthSyncJob,
        BaseReferences<_$AppDatabase, $HealthSyncJobsTable, HealthSyncJob>,
      ),
      HealthSyncJob,
      PrefetchHooks Function()
    >;
typedef $$BleSensorDevicesTableCreateCompanionBuilder =
    BleSensorDevicesCompanion Function({
      required String id,
      required String localIdentifier,
      Value<String> displayName,
      Value<String> deviceType,
      Value<String> manufacturer,
      Value<String> capabilitiesJson,
      Value<int?> lastSeenAtMs,
      Value<bool> isPreferred,
      Value<bool> isConnected,
      required int createdAtMs,
      required int updatedAtMs,
      Value<int> rowid,
    });
typedef $$BleSensorDevicesTableUpdateCompanionBuilder =
    BleSensorDevicesCompanion Function({
      Value<String> id,
      Value<String> localIdentifier,
      Value<String> displayName,
      Value<String> deviceType,
      Value<String> manufacturer,
      Value<String> capabilitiesJson,
      Value<int?> lastSeenAtMs,
      Value<bool> isPreferred,
      Value<bool> isConnected,
      Value<int> createdAtMs,
      Value<int> updatedAtMs,
      Value<int> rowid,
    });

class $$BleSensorDevicesTableFilterComposer
    extends Composer<_$AppDatabase, $BleSensorDevicesTable> {
  $$BleSensorDevicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localIdentifier => $composableBuilder(
    column: $table.localIdentifier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceType => $composableBuilder(
    column: $table.deviceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manufacturer => $composableBuilder(
    column: $table.manufacturer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capabilitiesJson => $composableBuilder(
    column: $table.capabilitiesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeenAtMs => $composableBuilder(
    column: $table.lastSeenAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPreferred => $composableBuilder(
    column: $table.isPreferred,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isConnected => $composableBuilder(
    column: $table.isConnected,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BleSensorDevicesTableOrderingComposer
    extends Composer<_$AppDatabase, $BleSensorDevicesTable> {
  $$BleSensorDevicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localIdentifier => $composableBuilder(
    column: $table.localIdentifier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceType => $composableBuilder(
    column: $table.deviceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manufacturer => $composableBuilder(
    column: $table.manufacturer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capabilitiesJson => $composableBuilder(
    column: $table.capabilitiesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeenAtMs => $composableBuilder(
    column: $table.lastSeenAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPreferred => $composableBuilder(
    column: $table.isPreferred,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isConnected => $composableBuilder(
    column: $table.isConnected,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BleSensorDevicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BleSensorDevicesTable> {
  $$BleSensorDevicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get localIdentifier => $composableBuilder(
    column: $table.localIdentifier,
    builder: (column) => column,
  );

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceType => $composableBuilder(
    column: $table.deviceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get manufacturer => $composableBuilder(
    column: $table.manufacturer,
    builder: (column) => column,
  );

  GeneratedColumn<String> get capabilitiesJson => $composableBuilder(
    column: $table.capabilitiesJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSeenAtMs => $composableBuilder(
    column: $table.lastSeenAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPreferred => $composableBuilder(
    column: $table.isPreferred,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isConnected => $composableBuilder(
    column: $table.isConnected,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtMs => $composableBuilder(
    column: $table.updatedAtMs,
    builder: (column) => column,
  );
}

class $$BleSensorDevicesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BleSensorDevicesTable,
          BleSensorDevice,
          $$BleSensorDevicesTableFilterComposer,
          $$BleSensorDevicesTableOrderingComposer,
          $$BleSensorDevicesTableAnnotationComposer,
          $$BleSensorDevicesTableCreateCompanionBuilder,
          $$BleSensorDevicesTableUpdateCompanionBuilder,
          (
            BleSensorDevice,
            BaseReferences<
              _$AppDatabase,
              $BleSensorDevicesTable,
              BleSensorDevice
            >,
          ),
          BleSensorDevice,
          PrefetchHooks Function()
        > {
  $$BleSensorDevicesTableTableManager(
    _$AppDatabase db,
    $BleSensorDevicesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BleSensorDevicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BleSensorDevicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BleSensorDevicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> localIdentifier = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> deviceType = const Value.absent(),
                Value<String> manufacturer = const Value.absent(),
                Value<String> capabilitiesJson = const Value.absent(),
                Value<int?> lastSeenAtMs = const Value.absent(),
                Value<bool> isPreferred = const Value.absent(),
                Value<bool> isConnected = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<int> updatedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BleSensorDevicesCompanion(
                id: id,
                localIdentifier: localIdentifier,
                displayName: displayName,
                deviceType: deviceType,
                manufacturer: manufacturer,
                capabilitiesJson: capabilitiesJson,
                lastSeenAtMs: lastSeenAtMs,
                isPreferred: isPreferred,
                isConnected: isConnected,
                createdAtMs: createdAtMs,
                updatedAtMs: updatedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String localIdentifier,
                Value<String> displayName = const Value.absent(),
                Value<String> deviceType = const Value.absent(),
                Value<String> manufacturer = const Value.absent(),
                Value<String> capabilitiesJson = const Value.absent(),
                Value<int?> lastSeenAtMs = const Value.absent(),
                Value<bool> isPreferred = const Value.absent(),
                Value<bool> isConnected = const Value.absent(),
                required int createdAtMs,
                required int updatedAtMs,
                Value<int> rowid = const Value.absent(),
              }) => BleSensorDevicesCompanion.insert(
                id: id,
                localIdentifier: localIdentifier,
                displayName: displayName,
                deviceType: deviceType,
                manufacturer: manufacturer,
                capabilitiesJson: capabilitiesJson,
                lastSeenAtMs: lastSeenAtMs,
                isPreferred: isPreferred,
                isConnected: isConnected,
                createdAtMs: createdAtMs,
                updatedAtMs: updatedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BleSensorDevicesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BleSensorDevicesTable,
      BleSensorDevice,
      $$BleSensorDevicesTableFilterComposer,
      $$BleSensorDevicesTableOrderingComposer,
      $$BleSensorDevicesTableAnnotationComposer,
      $$BleSensorDevicesTableCreateCompanionBuilder,
      $$BleSensorDevicesTableUpdateCompanionBuilder,
      (
        BleSensorDevice,
        BaseReferences<_$AppDatabase, $BleSensorDevicesTable, BleSensorDevice>,
      ),
      BleSensorDevice,
      PrefetchHooks Function()
    >;
typedef $$KeyValuesTableCreateCompanionBuilder =
    KeyValuesCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$KeyValuesTableUpdateCompanionBuilder =
    KeyValuesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$KeyValuesTableFilterComposer
    extends Composer<_$AppDatabase, $KeyValuesTable> {
  $$KeyValuesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KeyValuesTableOrderingComposer
    extends Composer<_$AppDatabase, $KeyValuesTable> {
  $$KeyValuesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KeyValuesTableAnnotationComposer
    extends Composer<_$AppDatabase, $KeyValuesTable> {
  $$KeyValuesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$KeyValuesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KeyValuesTable,
          KeyValue,
          $$KeyValuesTableFilterComposer,
          $$KeyValuesTableOrderingComposer,
          $$KeyValuesTableAnnotationComposer,
          $$KeyValuesTableCreateCompanionBuilder,
          $$KeyValuesTableUpdateCompanionBuilder,
          (KeyValue, BaseReferences<_$AppDatabase, $KeyValuesTable, KeyValue>),
          KeyValue,
          PrefetchHooks Function()
        > {
  $$KeyValuesTableTableManager(_$AppDatabase db, $KeyValuesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KeyValuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KeyValuesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KeyValuesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KeyValuesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => KeyValuesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KeyValuesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KeyValuesTable,
      KeyValue,
      $$KeyValuesTableFilterComposer,
      $$KeyValuesTableOrderingComposer,
      $$KeyValuesTableAnnotationComposer,
      $$KeyValuesTableCreateCompanionBuilder,
      $$KeyValuesTableUpdateCompanionBuilder,
      (KeyValue, BaseReferences<_$AppDatabase, $KeyValuesTable, KeyValue>),
      KeyValue,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PlayersTableTableManager get players =>
      $$PlayersTableTableManager(_db, _db.players);
  $$TeamsTableTableManager get teams =>
      $$TeamsTableTableManager(_db, _db.teams);
  $$MatchesTableTableManager get matches =>
      $$MatchesTableTableManager(_db, _db.matches);
  $$MatchEventRowsTableTableManager get matchEventRows =>
      $$MatchEventRowsTableTableManager(_db, _db.matchEventRows);
  $$TrainingsTableTableManager get trainings =>
      $$TrainingsTableTableManager(_db, _db.trainings);
  $$TrainingLogsTableTableManager get trainingLogs =>
      $$TrainingLogsTableTableManager(_db, _db.trainingLogs);
  $$ConnectedDevicesTableTableManager get connectedDevices =>
      $$ConnectedDevicesTableTableManager(_db, _db.connectedDevices);
  $$HealthDataSourcesTableTableManager get healthDataSources =>
      $$HealthDataSourcesTableTableManager(_db, _db.healthDataSources);
  $$HealthMetricRecordsTableTableManager get healthMetricRecords =>
      $$HealthMetricRecordsTableTableManager(_db, _db.healthMetricRecords);
  $$HealthSourcePreferencesTableTableManager get healthSourcePreferences =>
      $$HealthSourcePreferencesTableTableManager(
        _db,
        _db.healthSourcePreferences,
      );
  $$MatchHealthSummariesTableTableManager get matchHealthSummaries =>
      $$MatchHealthSummariesTableTableManager(_db, _db.matchHealthSummaries);
  $$HealthSyncJobsTableTableManager get healthSyncJobs =>
      $$HealthSyncJobsTableTableManager(_db, _db.healthSyncJobs);
  $$BleSensorDevicesTableTableManager get bleSensorDevices =>
      $$BleSensorDevicesTableTableManager(_db, _db.bleSensorDevices);
  $$KeyValuesTableTableManager get keyValues =>
      $$KeyValuesTableTableManager(_db, _db.keyValues);
}
