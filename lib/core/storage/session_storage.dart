import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import '../../features/auth/domain/mobile_session.dart';

class SessionStorage {
  SessionStorage(this.storage);
  final FlutterSecureStorage storage;
  static const _sessionKey = 'ponto_aqui.session.v1';
  static const _installationKey = 'ponto_aqui.installation.v1';

  Future<String> installationUuid() async {
    final existing = await storage.read(key: _installationKey);
    if (existing != null) return existing;
    final uuid = const Uuid().v4();
    await storage.write(key: _installationKey, value: uuid);
    return uuid;
  }

  Future<MobileSession?> restore() async {
    final json = await storage.read(key: _sessionKey);
    if (json == null) return null;
    return MobileSession.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> save(MobileSession session) =>
      storage.write(key: _sessionKey, value: jsonEncode(session.toJson()));
  Future<void> logout() => storage.delete(key: _sessionKey);
}
