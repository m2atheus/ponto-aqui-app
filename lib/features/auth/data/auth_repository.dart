import 'dart:convert';

import '../../../core/errors/app_failure.dart';
import '../../../core/network/mobile_api.dart';
import '../../../core/storage/session_storage.dart';
import '../domain/mobile_session.dart';

class AuthRepository {
  AuthRepository(this.api, this.storage);
  final MobileApi api;
  final SessionStorage storage;

  Future<MobileSession> login(
    String email,
    String password, {
    String? sectorId,
  }) async {
    final deviceUuid = _uuid(await storage.installationUuid());
    late final Map<String, dynamic> response;
    try {
      response = await api.request(
        'POST',
        '/api/mobile/auth/login',
        data: {
          'email': email.trim(),
          'senha': password,
          'device_uuid': deviceUuid,
          if (sectorId != null) 'setor_id': _uuid(sectorId),
        },
      );
    } on AppFailure catch (error) {
      if (error.authorizationDenied) {
        throw AppFailure(
          'Usuário ou senha inválidos',
          status: error.status,
          code: 'LOGIN_INVALIDO',
        );
      }
      rethrow;
    }
    final user = response['usuario'];
    if (response['access_token'] is! String ||
        response['token_type'] != 'Bearer' ||
        user is! Map<String, dynamic>) {
      throw const AppFailure('Resposta de autenticação inválida.');
    }
    final token = response['access_token'] as String;
    // Somente leitura dos metadados emitidos pelo servidor. A assinatura e a
    // identidade sao verificadas pela API em /me antes de salvar a sessao.
    final claims = _claims(token);
    final deviceId = _uuid(claims['dispositivo_id']);
    if (_uuid(claims['device_uuid']) != deviceUuid) {
      throw const AppFailure('Contexto do aparelho inconsistente.');
    }
    final provisional = _session(user, token, deviceId, deviceUuid);
    final validated = await api.request(
      'GET',
      '/api/mobile/auth/me',
      session: provisional,
    );
    if (validated['usuario'] is! Map<String, dynamic>) {
      throw const AppFailure('Perfil inválido.');
    }
    final restored = _session(
      validated['usuario'] as Map<String, dynamic>,
      token,
      deviceId,
      deviceUuid,
    );
    if (restored.scope != provisional.scope) {
      throw const AppFailure('Contexto da sessão inconsistente.');
    }
    await storage.save(restored);
    return restored;
  }

  String _uuid(Object? value) {
    if (value is! String ||
        !RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')
            .hasMatch(value)) {
      throw const AppFailure(
        'Contexto do aparelho ou da sessão inválido. Entre novamente.',
      );
    }
    return value.toLowerCase();
  }

  Map<String, dynamic> _claims(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) throw const FormatException();
      final value = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (value is! Map<String, dynamic>) throw const FormatException();
      return value;
    } catch (_) {
      throw const AppFailure(
        'Resposta de autenticação inválida. Entre novamente.',
      );
    }
  }

  MobileSession _session(
    Map<String, dynamic> user,
    String token,
    String deviceId,
    String uuid,
  ) {
    for (final key in ['id', 'empresa_id', 'nome', 'email', 'papel']) {
      if (user[key] is! String || (user[key] as String).isEmpty) {
        throw const AppFailure(
          'O perfil não possui um contexto mobile válido.',
        );
      }
    }
    if (!['FUNCIONARIO', 'USUARIO_SETOR'].contains(user['papel'])) {
      throw const AppFailure(
        'Utilize uma conta de funcionário. Contas administrativas usam o painel Web.',
      );
    }
    final claims = _claims(token);
    if (_uuid(claims['sub']) != _uuid(user['id']) ||
        _uuid(claims['empresa_id']) != _uuid(user['empresa_id']) ||
        claims['role'] != user['papel'] ||
        _uuid(claims['dispositivo_id']) != deviceId ||
        (claims['device_uuid'] != null &&
            _uuid(claims['device_uuid']) != uuid)) {
      throw const AppFailure(
        'Contexto da sessão inconsistente. Entre novamente.',
      );
    }
    final initialSector = claims['setor_id'] == null
        ? null
        : _uuid(claims['setor_id']);
    final sectors = claims['setor_ids'];
    if (sectors != null && sectors is! List) {
      throw const AppFailure('Contexto de setores inválido.');
    }
    final sectorIds = sectors is List
        ? sectors.map(_uuid).toList()
        : <String>[];
    if (initialSector != null &&
        sectorIds.isNotEmpty &&
        !sectorIds.contains(initialSector)) {
      throw const AppFailure('Contexto de setores inválido.');
    }
    return MobileSession(
      initialSectorId: initialSector,
      authorizedSectorIds: List.unmodifiable(sectorIds),
      origin: api.config.origin,
      token: token,
      userId: user['id'] as String,
      companyId: user['empresa_id'] as String,
      name: user['nome'] as String,
      email: user['email'] as String,
      role: user['papel'] as String,
      deviceId: deviceId,
      deviceUuid: uuid,
    );
  }

  Future<MobileSession?> restore() async {
    final session = await storage.restore();
    if (session == null || session.origin != api.config.origin) return null;
    if (!session.canSend) return session;
    try {
      final response = await api.request(
        'GET',
        '/api/mobile/auth/me',
        session: session,
      );
      final user = response['usuario'];
      if (user is! Map<String, dynamic>) {
        throw const AppFailure('Perfil inválido.');
      }
      final validated = _session(
        user,
        session.token,
        session.deviceId,
        session.deviceUuid,
      );
      if (session.scope != validated.scope) {
        throw const AppFailure('Contexto da sessão inconsistente.');
      }
      await storage.save(validated);
      return validated;
    } on AppFailure catch (error) {
      if (error.authorizationDenied ||
          (error.status == null && error.code != 'REDE_INDISPONIVEL')) {
        final blocked = session.blocked(
          'Sessão expirada ou acesso negado. Entre novamente.',
        );
        await storage.save(blocked);
        return blocked;
      }
      if (!error.retryable) rethrow;
      // Only the previously server-validated identity may restore offline.
      return session;
    }
  }
}
