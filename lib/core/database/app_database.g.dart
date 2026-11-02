// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $BootstrapCachesTable extends BootstrapCaches
    with TableInfo<$BootstrapCachesTable, BootstrapCache> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BootstrapCachesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receivedMsMeta = const VerificationMeta(
    'receivedMs',
  );
  @override
  late final GeneratedColumn<int> receivedMs = GeneratedColumn<int>(
    'received_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _offsetMsMeta = const VerificationMeta(
    'offsetMs',
  );
  @override
  late final GeneratedColumn<int> offsetMs = GeneratedColumn<int>(
    'offset_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roundTripMsMeta = const VerificationMeta(
    'roundTripMs',
  );
  @override
  late final GeneratedColumn<int> roundTripMs = GeneratedColumn<int>(
    'round_trip_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    scope,
    payload,
    receivedMs,
    offsetMs,
    roundTripMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bootstrap_caches';
  @override
  VerificationContext validateIntegrity(
    Insertable<BootstrapCache> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('received_ms')) {
      context.handle(
        _receivedMsMeta,
        receivedMs.isAcceptableOrUnknown(data['received_ms']!, _receivedMsMeta),
      );
    } else if (isInserting) {
      context.missing(_receivedMsMeta);
    }
    if (data.containsKey('offset_ms')) {
      context.handle(
        _offsetMsMeta,
        offsetMs.isAcceptableOrUnknown(data['offset_ms']!, _offsetMsMeta),
      );
    } else if (isInserting) {
      context.missing(_offsetMsMeta);
    }
    if (data.containsKey('round_trip_ms')) {
      context.handle(
        _roundTripMsMeta,
        roundTripMs.isAcceptableOrUnknown(
          data['round_trip_ms']!,
          _roundTripMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_roundTripMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scope};
  @override
  BootstrapCache map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BootstrapCache(
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      receivedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}received_ms'],
      )!,
      offsetMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}offset_ms'],
      )!,
      roundTripMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}round_trip_ms'],
      )!,
    );
  }

  @override
  $BootstrapCachesTable createAlias(String alias) {
    return $BootstrapCachesTable(attachedDatabase, alias);
  }
}

class BootstrapCache extends DataClass implements Insertable<BootstrapCache> {
  final String scope;
  final String payload;
  final int receivedMs;
  final int offsetMs;
  final int roundTripMs;
  const BootstrapCache({
    required this.scope,
    required this.payload,
    required this.receivedMs,
    required this.offsetMs,
    required this.roundTripMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope'] = Variable<String>(scope);
    map['payload'] = Variable<String>(payload);
    map['received_ms'] = Variable<int>(receivedMs);
    map['offset_ms'] = Variable<int>(offsetMs);
    map['round_trip_ms'] = Variable<int>(roundTripMs);
    return map;
  }

  BootstrapCachesCompanion toCompanion(bool nullToAbsent) {
    return BootstrapCachesCompanion(
      scope: Value(scope),
      payload: Value(payload),
      receivedMs: Value(receivedMs),
      offsetMs: Value(offsetMs),
      roundTripMs: Value(roundTripMs),
    );
  }

  factory BootstrapCache.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BootstrapCache(
      scope: serializer.fromJson<String>(json['scope']),
      payload: serializer.fromJson<String>(json['payload']),
      receivedMs: serializer.fromJson<int>(json['receivedMs']),
      offsetMs: serializer.fromJson<int>(json['offsetMs']),
      roundTripMs: serializer.fromJson<int>(json['roundTripMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scope': serializer.toJson<String>(scope),
      'payload': serializer.toJson<String>(payload),
      'receivedMs': serializer.toJson<int>(receivedMs),
      'offsetMs': serializer.toJson<int>(offsetMs),
      'roundTripMs': serializer.toJson<int>(roundTripMs),
    };
  }

  BootstrapCache copyWith({
    String? scope,
    String? payload,
    int? receivedMs,
    int? offsetMs,
    int? roundTripMs,
  }) => BootstrapCache(
    scope: scope ?? this.scope,
    payload: payload ?? this.payload,
    receivedMs: receivedMs ?? this.receivedMs,
    offsetMs: offsetMs ?? this.offsetMs,
    roundTripMs: roundTripMs ?? this.roundTripMs,
  );
  BootstrapCache copyWithCompanion(BootstrapCachesCompanion data) {
    return BootstrapCache(
      scope: data.scope.present ? data.scope.value : this.scope,
      payload: data.payload.present ? data.payload.value : this.payload,
      receivedMs: data.receivedMs.present
          ? data.receivedMs.value
          : this.receivedMs,
      offsetMs: data.offsetMs.present ? data.offsetMs.value : this.offsetMs,
      roundTripMs: data.roundTripMs.present
          ? data.roundTripMs.value
          : this.roundTripMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BootstrapCache(')
          ..write('scope: $scope, ')
          ..write('payload: $payload, ')
          ..write('receivedMs: $receivedMs, ')
          ..write('offsetMs: $offsetMs, ')
          ..write('roundTripMs: $roundTripMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(scope, payload, receivedMs, offsetMs, roundTripMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BootstrapCache &&
          other.scope == this.scope &&
          other.payload == this.payload &&
          other.receivedMs == this.receivedMs &&
          other.offsetMs == this.offsetMs &&
          other.roundTripMs == this.roundTripMs);
}

class BootstrapCachesCompanion extends UpdateCompanion<BootstrapCache> {
  final Value<String> scope;
  final Value<String> payload;
  final Value<int> receivedMs;
  final Value<int> offsetMs;
  final Value<int> roundTripMs;
  final Value<int> rowid;
  const BootstrapCachesCompanion({
    this.scope = const Value.absent(),
    this.payload = const Value.absent(),
    this.receivedMs = const Value.absent(),
    this.offsetMs = const Value.absent(),
    this.roundTripMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BootstrapCachesCompanion.insert({
    required String scope,
    required String payload,
    required int receivedMs,
    required int offsetMs,
    required int roundTripMs,
    this.rowid = const Value.absent(),
  }) : scope = Value(scope),
       payload = Value(payload),
       receivedMs = Value(receivedMs),
       offsetMs = Value(offsetMs),
       roundTripMs = Value(roundTripMs);
  static Insertable<BootstrapCache> custom({
    Expression<String>? scope,
    Expression<String>? payload,
    Expression<int>? receivedMs,
    Expression<int>? offsetMs,
    Expression<int>? roundTripMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scope != null) 'scope': scope,
      if (payload != null) 'payload': payload,
      if (receivedMs != null) 'received_ms': receivedMs,
      if (offsetMs != null) 'offset_ms': offsetMs,
      if (roundTripMs != null) 'round_trip_ms': roundTripMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BootstrapCachesCompanion copyWith({
    Value<String>? scope,
    Value<String>? payload,
    Value<int>? receivedMs,
    Value<int>? offsetMs,
    Value<int>? roundTripMs,
    Value<int>? rowid,
  }) {
    return BootstrapCachesCompanion(
      scope: scope ?? this.scope,
      payload: payload ?? this.payload,
      receivedMs: receivedMs ?? this.receivedMs,
      offsetMs: offsetMs ?? this.offsetMs,
      roundTripMs: roundTripMs ?? this.roundTripMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (receivedMs.present) {
      map['received_ms'] = Variable<int>(receivedMs.value);
    }
    if (offsetMs.present) {
      map['offset_ms'] = Variable<int>(offsetMs.value);
    }
    if (roundTripMs.present) {
      map['round_trip_ms'] = Variable<int>(roundTripMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BootstrapCachesCompanion(')
          ..write('scope: $scope, ')
          ..write('payload: $payload, ')
          ..write('receivedMs: $receivedMs, ')
          ..write('offsetMs: $offsetMs, ')
          ..write('roundTripMs: $roundTripMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxEventsTable extends OutboxEvents
    with TableInfo<$OutboxEventsTable, OutboxEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
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
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metadataMeta = const VerificationMeta(
    'metadata',
  );
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
    'metadata',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capturedMsMeta = const VerificationMeta(
    'capturedMs',
  );
  @override
  late final GeneratedColumn<int> capturedMs = GeneratedColumn<int>(
    'captured_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _photoPathMeta = const VerificationMeta(
    'photoPath',
  );
  @override
  late final GeneratedColumn<String> photoPath = GeneratedColumn<String>(
    'photo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _photoShaMeta = const VerificationMeta(
    'photoSha',
  );
  @override
  late final GeneratedColumn<String> photoSha = GeneratedColumn<String>(
    'photo_sha',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transportMeta = const VerificationMeta(
    'transport',
  );
  @override
  late final GeneratedColumn<String> transport = GeneratedColumn<String>(
    'transport',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('na_fila'),
  );
  static const VerificationMeta _photoTransportMeta = const VerificationMeta(
    'photoTransport',
  );
  @override
  late final GeneratedColumn<String> photoTransport = GeneratedColumn<String>(
    'photo_transport',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('sem_foto'),
  );
  static const VerificationMeta _receiptMeta = const VerificationMeta(
    'receipt',
  );
  @override
  late final GeneratedColumn<String> receipt = GeneratedColumn<String>(
    'receipt',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _photoReceiptMeta = const VerificationMeta(
    'photoReceipt',
  );
  @override
  late final GeneratedColumn<String> photoReceipt = GeneratedColumn<String>(
    'photo_receipt',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
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
  static const VerificationMeta _photoAttemptsMeta = const VerificationMeta(
    'photoAttempts',
  );
  @override
  late final GeneratedColumn<int> photoAttempts = GeneratedColumn<int>(
    'photo_attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastAttemptMsMeta = const VerificationMeta(
    'lastAttemptMs',
  );
  @override
  late final GeneratedColumn<int> lastAttemptMs = GeneratedColumn<int>(
    'last_attempt_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextAttemptMsMeta = const VerificationMeta(
    'nextAttemptMs',
  );
  @override
  late final GeneratedColumn<int> nextAttemptMs = GeneratedColumn<int>(
    'next_attempt_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _leaseOwnerMeta = const VerificationMeta(
    'leaseOwner',
  );
  @override
  late final GeneratedColumn<String> leaseOwner = GeneratedColumn<String>(
    'lease_owner',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _leaseUntilMsMeta = const VerificationMeta(
    'leaseUntilMs',
  );
  @override
  late final GeneratedColumn<int> leaseUntilMs = GeneratedColumn<int>(
    'lease_until_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    scope,
    eventId,
    payload,
    metadata,
    capturedMs,
    photoPath,
    photoSha,
    transport,
    photoTransport,
    receipt,
    photoReceipt,
    attempts,
    photoAttempts,
    lastAttemptMs,
    nextAttemptMs,
    lastError,
    leaseOwner,
    leaseUntilMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('metadata')) {
      context.handle(
        _metadataMeta,
        metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta),
      );
    } else if (isInserting) {
      context.missing(_metadataMeta);
    }
    if (data.containsKey('captured_ms')) {
      context.handle(
        _capturedMsMeta,
        capturedMs.isAcceptableOrUnknown(data['captured_ms']!, _capturedMsMeta),
      );
    } else if (isInserting) {
      context.missing(_capturedMsMeta);
    }
    if (data.containsKey('photo_path')) {
      context.handle(
        _photoPathMeta,
        photoPath.isAcceptableOrUnknown(data['photo_path']!, _photoPathMeta),
      );
    }
    if (data.containsKey('photo_sha')) {
      context.handle(
        _photoShaMeta,
        photoSha.isAcceptableOrUnknown(data['photo_sha']!, _photoShaMeta),
      );
    }
    if (data.containsKey('transport')) {
      context.handle(
        _transportMeta,
        transport.isAcceptableOrUnknown(data['transport']!, _transportMeta),
      );
    }
    if (data.containsKey('photo_transport')) {
      context.handle(
        _photoTransportMeta,
        photoTransport.isAcceptableOrUnknown(
          data['photo_transport']!,
          _photoTransportMeta,
        ),
      );
    }
    if (data.containsKey('receipt')) {
      context.handle(
        _receiptMeta,
        receipt.isAcceptableOrUnknown(data['receipt']!, _receiptMeta),
      );
    }
    if (data.containsKey('photo_receipt')) {
      context.handle(
        _photoReceiptMeta,
        photoReceipt.isAcceptableOrUnknown(
          data['photo_receipt']!,
          _photoReceiptMeta,
        ),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('photo_attempts')) {
      context.handle(
        _photoAttemptsMeta,
        photoAttempts.isAcceptableOrUnknown(
          data['photo_attempts']!,
          _photoAttemptsMeta,
        ),
      );
    }
    if (data.containsKey('last_attempt_ms')) {
      context.handle(
        _lastAttemptMsMeta,
        lastAttemptMs.isAcceptableOrUnknown(
          data['last_attempt_ms']!,
          _lastAttemptMsMeta,
        ),
      );
    }
    if (data.containsKey('next_attempt_ms')) {
      context.handle(
        _nextAttemptMsMeta,
        nextAttemptMs.isAcceptableOrUnknown(
          data['next_attempt_ms']!,
          _nextAttemptMsMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('lease_owner')) {
      context.handle(
        _leaseOwnerMeta,
        leaseOwner.isAcceptableOrUnknown(data['lease_owner']!, _leaseOwnerMeta),
      );
    }
    if (data.containsKey('lease_until_ms')) {
      context.handle(
        _leaseUntilMsMeta,
        leaseUntilMs.isAcceptableOrUnknown(
          data['lease_until_ms']!,
          _leaseUntilMsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scope, eventId};
  @override
  OutboxEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxEvent(
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      metadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata'],
      )!,
      capturedMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}captured_ms'],
      )!,
      photoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_path'],
      ),
      photoSha: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_sha'],
      ),
      transport: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transport'],
      )!,
      photoTransport: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_transport'],
      )!,
      receipt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt'],
      ),
      photoReceipt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_receipt'],
      ),
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      photoAttempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}photo_attempts'],
      )!,
      lastAttemptMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_attempt_ms'],
      ),
      nextAttemptMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_attempt_ms'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      leaseOwner: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lease_owner'],
      ),
      leaseUntilMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lease_until_ms'],
      ),
    );
  }

  @override
  $OutboxEventsTable createAlias(String alias) {
    return $OutboxEventsTable(attachedDatabase, alias);
  }
}

class OutboxEvent extends DataClass implements Insertable<OutboxEvent> {
  final String scope;
  final String eventId;
  final String payload;
  final String metadata;
  final int capturedMs;
  final String? photoPath;
  final String? photoSha;
  final String transport;
  final String photoTransport;
  final String? receipt;
  final String? photoReceipt;
  final int attempts;
  final int photoAttempts;
  final int? lastAttemptMs;
  final int nextAttemptMs;
  final String? lastError;
  final String? leaseOwner;
  final int? leaseUntilMs;
  const OutboxEvent({
    required this.scope,
    required this.eventId,
    required this.payload,
    required this.metadata,
    required this.capturedMs,
    this.photoPath,
    this.photoSha,
    required this.transport,
    required this.photoTransport,
    this.receipt,
    this.photoReceipt,
    required this.attempts,
    required this.photoAttempts,
    this.lastAttemptMs,
    required this.nextAttemptMs,
    this.lastError,
    this.leaseOwner,
    this.leaseUntilMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope'] = Variable<String>(scope);
    map['event_id'] = Variable<String>(eventId);
    map['payload'] = Variable<String>(payload);
    map['metadata'] = Variable<String>(metadata);
    map['captured_ms'] = Variable<int>(capturedMs);
    if (!nullToAbsent || photoPath != null) {
      map['photo_path'] = Variable<String>(photoPath);
    }
    if (!nullToAbsent || photoSha != null) {
      map['photo_sha'] = Variable<String>(photoSha);
    }
    map['transport'] = Variable<String>(transport);
    map['photo_transport'] = Variable<String>(photoTransport);
    if (!nullToAbsent || receipt != null) {
      map['receipt'] = Variable<String>(receipt);
    }
    if (!nullToAbsent || photoReceipt != null) {
      map['photo_receipt'] = Variable<String>(photoReceipt);
    }
    map['attempts'] = Variable<int>(attempts);
    map['photo_attempts'] = Variable<int>(photoAttempts);
    if (!nullToAbsent || lastAttemptMs != null) {
      map['last_attempt_ms'] = Variable<int>(lastAttemptMs);
    }
    map['next_attempt_ms'] = Variable<int>(nextAttemptMs);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || leaseOwner != null) {
      map['lease_owner'] = Variable<String>(leaseOwner);
    }
    if (!nullToAbsent || leaseUntilMs != null) {
      map['lease_until_ms'] = Variable<int>(leaseUntilMs);
    }
    return map;
  }

  OutboxEventsCompanion toCompanion(bool nullToAbsent) {
    return OutboxEventsCompanion(
      scope: Value(scope),
      eventId: Value(eventId),
      payload: Value(payload),
      metadata: Value(metadata),
      capturedMs: Value(capturedMs),
      photoPath: photoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(photoPath),
      photoSha: photoSha == null && nullToAbsent
          ? const Value.absent()
          : Value(photoSha),
      transport: Value(transport),
      photoTransport: Value(photoTransport),
      receipt: receipt == null && nullToAbsent
          ? const Value.absent()
          : Value(receipt),
      photoReceipt: photoReceipt == null && nullToAbsent
          ? const Value.absent()
          : Value(photoReceipt),
      attempts: Value(attempts),
      photoAttempts: Value(photoAttempts),
      lastAttemptMs: lastAttemptMs == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptMs),
      nextAttemptMs: Value(nextAttemptMs),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      leaseOwner: leaseOwner == null && nullToAbsent
          ? const Value.absent()
          : Value(leaseOwner),
      leaseUntilMs: leaseUntilMs == null && nullToAbsent
          ? const Value.absent()
          : Value(leaseUntilMs),
    );
  }

  factory OutboxEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxEvent(
      scope: serializer.fromJson<String>(json['scope']),
      eventId: serializer.fromJson<String>(json['eventId']),
      payload: serializer.fromJson<String>(json['payload']),
      metadata: serializer.fromJson<String>(json['metadata']),
      capturedMs: serializer.fromJson<int>(json['capturedMs']),
      photoPath: serializer.fromJson<String?>(json['photoPath']),
      photoSha: serializer.fromJson<String?>(json['photoSha']),
      transport: serializer.fromJson<String>(json['transport']),
      photoTransport: serializer.fromJson<String>(json['photoTransport']),
      receipt: serializer.fromJson<String?>(json['receipt']),
      photoReceipt: serializer.fromJson<String?>(json['photoReceipt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      photoAttempts: serializer.fromJson<int>(json['photoAttempts']),
      lastAttemptMs: serializer.fromJson<int?>(json['lastAttemptMs']),
      nextAttemptMs: serializer.fromJson<int>(json['nextAttemptMs']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      leaseOwner: serializer.fromJson<String?>(json['leaseOwner']),
      leaseUntilMs: serializer.fromJson<int?>(json['leaseUntilMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scope': serializer.toJson<String>(scope),
      'eventId': serializer.toJson<String>(eventId),
      'payload': serializer.toJson<String>(payload),
      'metadata': serializer.toJson<String>(metadata),
      'capturedMs': serializer.toJson<int>(capturedMs),
      'photoPath': serializer.toJson<String?>(photoPath),
      'photoSha': serializer.toJson<String?>(photoSha),
      'transport': serializer.toJson<String>(transport),
      'photoTransport': serializer.toJson<String>(photoTransport),
      'receipt': serializer.toJson<String?>(receipt),
      'photoReceipt': serializer.toJson<String?>(photoReceipt),
      'attempts': serializer.toJson<int>(attempts),
      'photoAttempts': serializer.toJson<int>(photoAttempts),
      'lastAttemptMs': serializer.toJson<int?>(lastAttemptMs),
      'nextAttemptMs': serializer.toJson<int>(nextAttemptMs),
      'lastError': serializer.toJson<String?>(lastError),
      'leaseOwner': serializer.toJson<String?>(leaseOwner),
      'leaseUntilMs': serializer.toJson<int?>(leaseUntilMs),
    };
  }

  OutboxEvent copyWith({
    String? scope,
    String? eventId,
    String? payload,
    String? metadata,
    int? capturedMs,
    Value<String?> photoPath = const Value.absent(),
    Value<String?> photoSha = const Value.absent(),
    String? transport,
    String? photoTransport,
    Value<String?> receipt = const Value.absent(),
    Value<String?> photoReceipt = const Value.absent(),
    int? attempts,
    int? photoAttempts,
    Value<int?> lastAttemptMs = const Value.absent(),
    int? nextAttemptMs,
    Value<String?> lastError = const Value.absent(),
    Value<String?> leaseOwner = const Value.absent(),
    Value<int?> leaseUntilMs = const Value.absent(),
  }) => OutboxEvent(
    scope: scope ?? this.scope,
    eventId: eventId ?? this.eventId,
    payload: payload ?? this.payload,
    metadata: metadata ?? this.metadata,
    capturedMs: capturedMs ?? this.capturedMs,
    photoPath: photoPath.present ? photoPath.value : this.photoPath,
    photoSha: photoSha.present ? photoSha.value : this.photoSha,
    transport: transport ?? this.transport,
    photoTransport: photoTransport ?? this.photoTransport,
    receipt: receipt.present ? receipt.value : this.receipt,
    photoReceipt: photoReceipt.present ? photoReceipt.value : this.photoReceipt,
    attempts: attempts ?? this.attempts,
    photoAttempts: photoAttempts ?? this.photoAttempts,
    lastAttemptMs: lastAttemptMs.present
        ? lastAttemptMs.value
        : this.lastAttemptMs,
    nextAttemptMs: nextAttemptMs ?? this.nextAttemptMs,
    lastError: lastError.present ? lastError.value : this.lastError,
    leaseOwner: leaseOwner.present ? leaseOwner.value : this.leaseOwner,
    leaseUntilMs: leaseUntilMs.present ? leaseUntilMs.value : this.leaseUntilMs,
  );
  OutboxEvent copyWithCompanion(OutboxEventsCompanion data) {
    return OutboxEvent(
      scope: data.scope.present ? data.scope.value : this.scope,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      payload: data.payload.present ? data.payload.value : this.payload,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
      capturedMs: data.capturedMs.present
          ? data.capturedMs.value
          : this.capturedMs,
      photoPath: data.photoPath.present ? data.photoPath.value : this.photoPath,
      photoSha: data.photoSha.present ? data.photoSha.value : this.photoSha,
      transport: data.transport.present ? data.transport.value : this.transport,
      photoTransport: data.photoTransport.present
          ? data.photoTransport.value
          : this.photoTransport,
      receipt: data.receipt.present ? data.receipt.value : this.receipt,
      photoReceipt: data.photoReceipt.present
          ? data.photoReceipt.value
          : this.photoReceipt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      photoAttempts: data.photoAttempts.present
          ? data.photoAttempts.value
          : this.photoAttempts,
      lastAttemptMs: data.lastAttemptMs.present
          ? data.lastAttemptMs.value
          : this.lastAttemptMs,
      nextAttemptMs: data.nextAttemptMs.present
          ? data.nextAttemptMs.value
          : this.nextAttemptMs,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      leaseOwner: data.leaseOwner.present
          ? data.leaseOwner.value
          : this.leaseOwner,
      leaseUntilMs: data.leaseUntilMs.present
          ? data.leaseUntilMs.value
          : this.leaseUntilMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEvent(')
          ..write('scope: $scope, ')
          ..write('eventId: $eventId, ')
          ..write('payload: $payload, ')
          ..write('metadata: $metadata, ')
          ..write('capturedMs: $capturedMs, ')
          ..write('photoPath: $photoPath, ')
          ..write('photoSha: $photoSha, ')
          ..write('transport: $transport, ')
          ..write('photoTransport: $photoTransport, ')
          ..write('receipt: $receipt, ')
          ..write('photoReceipt: $photoReceipt, ')
          ..write('attempts: $attempts, ')
          ..write('photoAttempts: $photoAttempts, ')
          ..write('lastAttemptMs: $lastAttemptMs, ')
          ..write('nextAttemptMs: $nextAttemptMs, ')
          ..write('lastError: $lastError, ')
          ..write('leaseOwner: $leaseOwner, ')
          ..write('leaseUntilMs: $leaseUntilMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    scope,
    eventId,
    payload,
    metadata,
    capturedMs,
    photoPath,
    photoSha,
    transport,
    photoTransport,
    receipt,
    photoReceipt,
    attempts,
    photoAttempts,
    lastAttemptMs,
    nextAttemptMs,
    lastError,
    leaseOwner,
    leaseUntilMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxEvent &&
          other.scope == this.scope &&
          other.eventId == this.eventId &&
          other.payload == this.payload &&
          other.metadata == this.metadata &&
          other.capturedMs == this.capturedMs &&
          other.photoPath == this.photoPath &&
          other.photoSha == this.photoSha &&
          other.transport == this.transport &&
          other.photoTransport == this.photoTransport &&
          other.receipt == this.receipt &&
          other.photoReceipt == this.photoReceipt &&
          other.attempts == this.attempts &&
          other.photoAttempts == this.photoAttempts &&
          other.lastAttemptMs == this.lastAttemptMs &&
          other.nextAttemptMs == this.nextAttemptMs &&
          other.lastError == this.lastError &&
          other.leaseOwner == this.leaseOwner &&
          other.leaseUntilMs == this.leaseUntilMs);
}

class OutboxEventsCompanion extends UpdateCompanion<OutboxEvent> {
  final Value<String> scope;
  final Value<String> eventId;
  final Value<String> payload;
  final Value<String> metadata;
  final Value<int> capturedMs;
  final Value<String?> photoPath;
  final Value<String?> photoSha;
  final Value<String> transport;
  final Value<String> photoTransport;
  final Value<String?> receipt;
  final Value<String?> photoReceipt;
  final Value<int> attempts;
  final Value<int> photoAttempts;
  final Value<int?> lastAttemptMs;
  final Value<int> nextAttemptMs;
  final Value<String?> lastError;
  final Value<String?> leaseOwner;
  final Value<int?> leaseUntilMs;
  final Value<int> rowid;
  const OutboxEventsCompanion({
    this.scope = const Value.absent(),
    this.eventId = const Value.absent(),
    this.payload = const Value.absent(),
    this.metadata = const Value.absent(),
    this.capturedMs = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.photoSha = const Value.absent(),
    this.transport = const Value.absent(),
    this.photoTransport = const Value.absent(),
    this.receipt = const Value.absent(),
    this.photoReceipt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.photoAttempts = const Value.absent(),
    this.lastAttemptMs = const Value.absent(),
    this.nextAttemptMs = const Value.absent(),
    this.lastError = const Value.absent(),
    this.leaseOwner = const Value.absent(),
    this.leaseUntilMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxEventsCompanion.insert({
    required String scope,
    required String eventId,
    required String payload,
    required String metadata,
    required int capturedMs,
    this.photoPath = const Value.absent(),
    this.photoSha = const Value.absent(),
    this.transport = const Value.absent(),
    this.photoTransport = const Value.absent(),
    this.receipt = const Value.absent(),
    this.photoReceipt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.photoAttempts = const Value.absent(),
    this.lastAttemptMs = const Value.absent(),
    this.nextAttemptMs = const Value.absent(),
    this.lastError = const Value.absent(),
    this.leaseOwner = const Value.absent(),
    this.leaseUntilMs = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : scope = Value(scope),
       eventId = Value(eventId),
       payload = Value(payload),
       metadata = Value(metadata),
       capturedMs = Value(capturedMs);
  static Insertable<OutboxEvent> custom({
    Expression<String>? scope,
    Expression<String>? eventId,
    Expression<String>? payload,
    Expression<String>? metadata,
    Expression<int>? capturedMs,
    Expression<String>? photoPath,
    Expression<String>? photoSha,
    Expression<String>? transport,
    Expression<String>? photoTransport,
    Expression<String>? receipt,
    Expression<String>? photoReceipt,
    Expression<int>? attempts,
    Expression<int>? photoAttempts,
    Expression<int>? lastAttemptMs,
    Expression<int>? nextAttemptMs,
    Expression<String>? lastError,
    Expression<String>? leaseOwner,
    Expression<int>? leaseUntilMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scope != null) 'scope': scope,
      if (eventId != null) 'event_id': eventId,
      if (payload != null) 'payload': payload,
      if (metadata != null) 'metadata': metadata,
      if (capturedMs != null) 'captured_ms': capturedMs,
      if (photoPath != null) 'photo_path': photoPath,
      if (photoSha != null) 'photo_sha': photoSha,
      if (transport != null) 'transport': transport,
      if (photoTransport != null) 'photo_transport': photoTransport,
      if (receipt != null) 'receipt': receipt,
      if (photoReceipt != null) 'photo_receipt': photoReceipt,
      if (attempts != null) 'attempts': attempts,
      if (photoAttempts != null) 'photo_attempts': photoAttempts,
      if (lastAttemptMs != null) 'last_attempt_ms': lastAttemptMs,
      if (nextAttemptMs != null) 'next_attempt_ms': nextAttemptMs,
      if (lastError != null) 'last_error': lastError,
      if (leaseOwner != null) 'lease_owner': leaseOwner,
      if (leaseUntilMs != null) 'lease_until_ms': leaseUntilMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxEventsCompanion copyWith({
    Value<String>? scope,
    Value<String>? eventId,
    Value<String>? payload,
    Value<String>? metadata,
    Value<int>? capturedMs,
    Value<String?>? photoPath,
    Value<String?>? photoSha,
    Value<String>? transport,
    Value<String>? photoTransport,
    Value<String?>? receipt,
    Value<String?>? photoReceipt,
    Value<int>? attempts,
    Value<int>? photoAttempts,
    Value<int?>? lastAttemptMs,
    Value<int>? nextAttemptMs,
    Value<String?>? lastError,
    Value<String?>? leaseOwner,
    Value<int?>? leaseUntilMs,
    Value<int>? rowid,
  }) {
    return OutboxEventsCompanion(
      scope: scope ?? this.scope,
      eventId: eventId ?? this.eventId,
      payload: payload ?? this.payload,
      metadata: metadata ?? this.metadata,
      capturedMs: capturedMs ?? this.capturedMs,
      photoPath: photoPath ?? this.photoPath,
      photoSha: photoSha ?? this.photoSha,
      transport: transport ?? this.transport,
      photoTransport: photoTransport ?? this.photoTransport,
      receipt: receipt ?? this.receipt,
      photoReceipt: photoReceipt ?? this.photoReceipt,
      attempts: attempts ?? this.attempts,
      photoAttempts: photoAttempts ?? this.photoAttempts,
      lastAttemptMs: lastAttemptMs ?? this.lastAttemptMs,
      nextAttemptMs: nextAttemptMs ?? this.nextAttemptMs,
      lastError: lastError ?? this.lastError,
      leaseOwner: leaseOwner ?? this.leaseOwner,
      leaseUntilMs: leaseUntilMs ?? this.leaseUntilMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (capturedMs.present) {
      map['captured_ms'] = Variable<int>(capturedMs.value);
    }
    if (photoPath.present) {
      map['photo_path'] = Variable<String>(photoPath.value);
    }
    if (photoSha.present) {
      map['photo_sha'] = Variable<String>(photoSha.value);
    }
    if (transport.present) {
      map['transport'] = Variable<String>(transport.value);
    }
    if (photoTransport.present) {
      map['photo_transport'] = Variable<String>(photoTransport.value);
    }
    if (receipt.present) {
      map['receipt'] = Variable<String>(receipt.value);
    }
    if (photoReceipt.present) {
      map['photo_receipt'] = Variable<String>(photoReceipt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (photoAttempts.present) {
      map['photo_attempts'] = Variable<int>(photoAttempts.value);
    }
    if (lastAttemptMs.present) {
      map['last_attempt_ms'] = Variable<int>(lastAttemptMs.value);
    }
    if (nextAttemptMs.present) {
      map['next_attempt_ms'] = Variable<int>(nextAttemptMs.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (leaseOwner.present) {
      map['lease_owner'] = Variable<String>(leaseOwner.value);
    }
    if (leaseUntilMs.present) {
      map['lease_until_ms'] = Variable<int>(leaseUntilMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxEventsCompanion(')
          ..write('scope: $scope, ')
          ..write('eventId: $eventId, ')
          ..write('payload: $payload, ')
          ..write('metadata: $metadata, ')
          ..write('capturedMs: $capturedMs, ')
          ..write('photoPath: $photoPath, ')
          ..write('photoSha: $photoSha, ')
          ..write('transport: $transport, ')
          ..write('photoTransport: $photoTransport, ')
          ..write('receipt: $receipt, ')
          ..write('photoReceipt: $photoReceipt, ')
          ..write('attempts: $attempts, ')
          ..write('photoAttempts: $photoAttempts, ')
          ..write('lastAttemptMs: $lastAttemptMs, ')
          ..write('nextAttemptMs: $nextAttemptMs, ')
          ..write('lastError: $lastError, ')
          ..write('leaseOwner: $leaseOwner, ')
          ..write('leaseUntilMs: $leaseUntilMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $BootstrapCachesTable bootstrapCaches = $BootstrapCachesTable(
    this,
  );
  late final $OutboxEventsTable outboxEvents = $OutboxEventsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    bootstrapCaches,
    outboxEvents,
  ];
}

typedef $$BootstrapCachesTableCreateCompanionBuilder =
    BootstrapCachesCompanion Function({
      required String scope,
      required String payload,
      required int receivedMs,
      required int offsetMs,
      required int roundTripMs,
      Value<int> rowid,
    });
typedef $$BootstrapCachesTableUpdateCompanionBuilder =
    BootstrapCachesCompanion Function({
      Value<String> scope,
      Value<String> payload,
      Value<int> receivedMs,
      Value<int> offsetMs,
      Value<int> roundTripMs,
      Value<int> rowid,
    });

class $$BootstrapCachesTableFilterComposer
    extends Composer<_$AppDatabase, $BootstrapCachesTable> {
  $$BootstrapCachesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get receivedMs => $composableBuilder(
    column: $table.receivedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get offsetMs => $composableBuilder(
    column: $table.offsetMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get roundTripMs => $composableBuilder(
    column: $table.roundTripMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BootstrapCachesTableOrderingComposer
    extends Composer<_$AppDatabase, $BootstrapCachesTable> {
  $$BootstrapCachesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get receivedMs => $composableBuilder(
    column: $table.receivedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get offsetMs => $composableBuilder(
    column: $table.offsetMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get roundTripMs => $composableBuilder(
    column: $table.roundTripMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BootstrapCachesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BootstrapCachesTable> {
  $$BootstrapCachesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get receivedMs => $composableBuilder(
    column: $table.receivedMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get offsetMs =>
      $composableBuilder(column: $table.offsetMs, builder: (column) => column);

  GeneratedColumn<int> get roundTripMs => $composableBuilder(
    column: $table.roundTripMs,
    builder: (column) => column,
  );
}

class $$BootstrapCachesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BootstrapCachesTable,
          BootstrapCache,
          $$BootstrapCachesTableFilterComposer,
          $$BootstrapCachesTableOrderingComposer,
          $$BootstrapCachesTableAnnotationComposer,
          $$BootstrapCachesTableCreateCompanionBuilder,
          $$BootstrapCachesTableUpdateCompanionBuilder,
          (
            BootstrapCache,
            BaseReferences<
              _$AppDatabase,
              $BootstrapCachesTable,
              BootstrapCache
            >,
          ),
          BootstrapCache,
          PrefetchHooks Function()
        > {
  $$BootstrapCachesTableTableManager(
    _$AppDatabase db,
    $BootstrapCachesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BootstrapCachesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BootstrapCachesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BootstrapCachesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> scope = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> receivedMs = const Value.absent(),
                Value<int> offsetMs = const Value.absent(),
                Value<int> roundTripMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BootstrapCachesCompanion(
                scope: scope,
                payload: payload,
                receivedMs: receivedMs,
                offsetMs: offsetMs,
                roundTripMs: roundTripMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String scope,
                required String payload,
                required int receivedMs,
                required int offsetMs,
                required int roundTripMs,
                Value<int> rowid = const Value.absent(),
              }) => BootstrapCachesCompanion.insert(
                scope: scope,
                payload: payload,
                receivedMs: receivedMs,
                offsetMs: offsetMs,
                roundTripMs: roundTripMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BootstrapCachesTable, BootstrapCache>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $BootstrapCachesTable,
                    BootstrapCache
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BootstrapCachesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BootstrapCachesTable,
      BootstrapCache,
      $$BootstrapCachesTableFilterComposer,
      $$BootstrapCachesTableOrderingComposer,
      $$BootstrapCachesTableAnnotationComposer,
      $$BootstrapCachesTableCreateCompanionBuilder,
      $$BootstrapCachesTableUpdateCompanionBuilder,
      (
        BootstrapCache,
        BaseReferences<_$AppDatabase, $BootstrapCachesTable, BootstrapCache>,
      ),
      BootstrapCache,
      PrefetchHooks Function()
    >;
typedef $$OutboxEventsTableCreateCompanionBuilder =
    OutboxEventsCompanion Function({
      required String scope,
      required String eventId,
      required String payload,
      required String metadata,
      required int capturedMs,
      Value<String?> photoPath,
      Value<String?> photoSha,
      Value<String> transport,
      Value<String> photoTransport,
      Value<String?> receipt,
      Value<String?> photoReceipt,
      Value<int> attempts,
      Value<int> photoAttempts,
      Value<int?> lastAttemptMs,
      Value<int> nextAttemptMs,
      Value<String?> lastError,
      Value<String?> leaseOwner,
      Value<int?> leaseUntilMs,
      Value<int> rowid,
    });
typedef $$OutboxEventsTableUpdateCompanionBuilder =
    OutboxEventsCompanion Function({
      Value<String> scope,
      Value<String> eventId,
      Value<String> payload,
      Value<String> metadata,
      Value<int> capturedMs,
      Value<String?> photoPath,
      Value<String?> photoSha,
      Value<String> transport,
      Value<String> photoTransport,
      Value<String?> receipt,
      Value<String?> photoReceipt,
      Value<int> attempts,
      Value<int> photoAttempts,
      Value<int?> lastAttemptMs,
      Value<int> nextAttemptMs,
      Value<String?> lastError,
      Value<String?> leaseOwner,
      Value<int?> leaseUntilMs,
      Value<int> rowid,
    });

class $$OutboxEventsTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxEventsTable> {
  $$OutboxEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capturedMs => $composableBuilder(
    column: $table.capturedMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoSha => $composableBuilder(
    column: $table.photoSha,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transport => $composableBuilder(
    column: $table.transport,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoTransport => $composableBuilder(
    column: $table.photoTransport,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get receipt => $composableBuilder(
    column: $table.receipt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoReceipt => $composableBuilder(
    column: $table.photoReceipt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get photoAttempts => $composableBuilder(
    column: $table.photoAttempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastAttemptMs => $composableBuilder(
    column: $table.lastAttemptMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextAttemptMs => $composableBuilder(
    column: $table.nextAttemptMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get leaseOwner => $composableBuilder(
    column: $table.leaseOwner,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get leaseUntilMs => $composableBuilder(
    column: $table.leaseUntilMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxEventsTable> {
  $$OutboxEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capturedMs => $composableBuilder(
    column: $table.capturedMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoSha => $composableBuilder(
    column: $table.photoSha,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transport => $composableBuilder(
    column: $table.transport,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoTransport => $composableBuilder(
    column: $table.photoTransport,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get receipt => $composableBuilder(
    column: $table.receipt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoReceipt => $composableBuilder(
    column: $table.photoReceipt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get photoAttempts => $composableBuilder(
    column: $table.photoAttempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastAttemptMs => $composableBuilder(
    column: $table.lastAttemptMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextAttemptMs => $composableBuilder(
    column: $table.nextAttemptMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get leaseOwner => $composableBuilder(
    column: $table.leaseOwner,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get leaseUntilMs => $composableBuilder(
    column: $table.leaseUntilMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxEventsTable> {
  $$OutboxEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  GeneratedColumn<int> get capturedMs => $composableBuilder(
    column: $table.capturedMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get photoPath =>
      $composableBuilder(column: $table.photoPath, builder: (column) => column);

  GeneratedColumn<String> get photoSha =>
      $composableBuilder(column: $table.photoSha, builder: (column) => column);

  GeneratedColumn<String> get transport =>
      $composableBuilder(column: $table.transport, builder: (column) => column);

  GeneratedColumn<String> get photoTransport => $composableBuilder(
    column: $table.photoTransport,
    builder: (column) => column,
  );

  GeneratedColumn<String> get receipt =>
      $composableBuilder(column: $table.receipt, builder: (column) => column);

  GeneratedColumn<String> get photoReceipt => $composableBuilder(
    column: $table.photoReceipt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<int> get photoAttempts => $composableBuilder(
    column: $table.photoAttempts,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastAttemptMs => $composableBuilder(
    column: $table.lastAttemptMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nextAttemptMs => $composableBuilder(
    column: $table.nextAttemptMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<String> get leaseOwner => $composableBuilder(
    column: $table.leaseOwner,
    builder: (column) => column,
  );

  GeneratedColumn<int> get leaseUntilMs => $composableBuilder(
    column: $table.leaseUntilMs,
    builder: (column) => column,
  );
}

class $$OutboxEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxEventsTable,
          OutboxEvent,
          $$OutboxEventsTableFilterComposer,
          $$OutboxEventsTableOrderingComposer,
          $$OutboxEventsTableAnnotationComposer,
          $$OutboxEventsTableCreateCompanionBuilder,
          $$OutboxEventsTableUpdateCompanionBuilder,
          (
            OutboxEvent,
            BaseReferences<_$AppDatabase, $OutboxEventsTable, OutboxEvent>,
          ),
          OutboxEvent,
          PrefetchHooks Function()
        > {
  $$OutboxEventsTableTableManager(_$AppDatabase db, $OutboxEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> scope = const Value.absent(),
                Value<String> eventId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> metadata = const Value.absent(),
                Value<int> capturedMs = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<String?> photoSha = const Value.absent(),
                Value<String> transport = const Value.absent(),
                Value<String> photoTransport = const Value.absent(),
                Value<String?> receipt = const Value.absent(),
                Value<String?> photoReceipt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> photoAttempts = const Value.absent(),
                Value<int?> lastAttemptMs = const Value.absent(),
                Value<int> nextAttemptMs = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String?> leaseOwner = const Value.absent(),
                Value<int?> leaseUntilMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxEventsCompanion(
                scope: scope,
                eventId: eventId,
                payload: payload,
                metadata: metadata,
                capturedMs: capturedMs,
                photoPath: photoPath,
                photoSha: photoSha,
                transport: transport,
                photoTransport: photoTransport,
                receipt: receipt,
                photoReceipt: photoReceipt,
                attempts: attempts,
                photoAttempts: photoAttempts,
                lastAttemptMs: lastAttemptMs,
                nextAttemptMs: nextAttemptMs,
                lastError: lastError,
                leaseOwner: leaseOwner,
                leaseUntilMs: leaseUntilMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String scope,
                required String eventId,
                required String payload,
                required String metadata,
                required int capturedMs,
                Value<String?> photoPath = const Value.absent(),
                Value<String?> photoSha = const Value.absent(),
                Value<String> transport = const Value.absent(),
                Value<String> photoTransport = const Value.absent(),
                Value<String?> receipt = const Value.absent(),
                Value<String?> photoReceipt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> photoAttempts = const Value.absent(),
                Value<int?> lastAttemptMs = const Value.absent(),
                Value<int> nextAttemptMs = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String?> leaseOwner = const Value.absent(),
                Value<int?> leaseUntilMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxEventsCompanion.insert(
                scope: scope,
                eventId: eventId,
                payload: payload,
                metadata: metadata,
                capturedMs: capturedMs,
                photoPath: photoPath,
                photoSha: photoSha,
                transport: transport,
                photoTransport: photoTransport,
                receipt: receipt,
                photoReceipt: photoReceipt,
                attempts: attempts,
                photoAttempts: photoAttempts,
                lastAttemptMs: lastAttemptMs,
                nextAttemptMs: nextAttemptMs,
                lastError: lastError,
                leaseOwner: leaseOwner,
                leaseUntilMs: leaseUntilMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutboxEventsTable, OutboxEvent>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $OutboxEventsTable,
                    OutboxEvent
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxEventsTable,
      OutboxEvent,
      $$OutboxEventsTableFilterComposer,
      $$OutboxEventsTableOrderingComposer,
      $$OutboxEventsTableAnnotationComposer,
      $$OutboxEventsTableCreateCompanionBuilder,
      $$OutboxEventsTableUpdateCompanionBuilder,
      (
        OutboxEvent,
        BaseReferences<_$AppDatabase, $OutboxEventsTable, OutboxEvent>,
      ),
      OutboxEvent,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$BootstrapCachesTableTableManager get bootstrapCaches =>
      $$BootstrapCachesTableTableManager(_db, _db.bootstrapCaches);
  $$OutboxEventsTableTableManager get outboxEvents =>
      $$OutboxEventsTableTableManager(_db, _db.outboxEvents);
}
