import 'dart:convert';

class MobileSession {
  const MobileSession({
    required this.origin,
    required this.token,
    required this.userId,
    required this.companyId,
    required this.name,
    required this.email,
    required this.role,
    required this.deviceId,
    required this.deviceUuid,
    this.blockedReason,
    this.initialSectorId,
    this.authorizedSectorIds = const [],
  });

  final String origin, token, userId, companyId, name, email, role;
  final String deviceId, deviceUuid;
  final String? blockedReason;
  final String? initialSectorId;
  final List<String> authorizedSectorIds;
  String get scope =>
      jsonEncode([origin, companyId, userId, deviceUuid, deviceId]);
  bool get canSend => blockedReason == null;

  MobileSession blocked(String message) => MobileSession(
    origin: origin,
    token: token,
    userId: userId,
    companyId: companyId,
    name: name,
    email: email,
    role: role,
    deviceId: deviceId,
    deviceUuid: deviceUuid,
    blockedReason: message,
    initialSectorId: initialSectorId,
    authorizedSectorIds: authorizedSectorIds,
  );

  Map<String, dynamic> toJson() => {
    'origin': origin,
    'token': token,
    'userId': userId,
    'companyId': companyId,
    'name': name,
    'email': email,
    'role': role,
    'deviceId': deviceId,
    'deviceUuid': deviceUuid,
    'blockedReason': blockedReason,
    'initialSectorId': initialSectorId,
    'authorizedSectorIds': authorizedSectorIds,
  };

  factory MobileSession.fromJson(Map<String, dynamic> j) => MobileSession(
    origin: j['origin'] as String,
    token: j['token'] as String,
    userId: j['userId'] as String,
    companyId: j['companyId'] as String,
    name: j['name'] as String,
    email: j['email'] as String,
    role: j['role'] as String,
    deviceId: j['deviceId'] as String,
    deviceUuid: j['deviceUuid'] as String,
    blockedReason: j['blockedReason'] as String?,
    initialSectorId: j['initialSectorId'] as String?,
    authorizedSectorIds: List<String>.unmodifiable(
      (j['authorizedSectorIds'] as List? ?? []).cast<String>(),
    ),
  );
}
