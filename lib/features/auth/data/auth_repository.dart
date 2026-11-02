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
    String password,
    String deviceId,
  ) async {
    if (!RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')
        .hasMatch(deviceId)) {
      throw const AppFailure(
        'Informe o ID cadastrado do aparelho fornecido pelo administrador.',
      );
    }
    final deviceUuid = await storage.installationUuid();
    final response = await api.request(
      'POST',
      '/api/mobile/auth/login',
      data: {
        'email': email.trim(),
        'senha': password,
        'dispositivo_id': deviceId.toLowerCase(),
      },
    );
    final user = response['usuario'];
    if (response['access_token'] is! String ||
        response['token_type'] != 'Bearer' ||
        user is! Map<String, dynamic>) {
      throw const AppFailure('Resposta de autenticação inválida.');
    }
    final session = _session(
      user,
      response['access_token'] as String,
      deviceId.toLowerCase(),
      deviceUuid,
    );
    final validated = await api.request(
      'GET',
      '/api/mobile/auth/me',
      session: session,
    );
    if (validated['usuario'] is! Map<String, dynamic>) {
      throw const AppFailure('Perfil inválido.');
    }
    final restored = _session(
      validated['usuario'] as Map<String, dynamic>,
      session.token,
      session.deviceId,
      deviceUuid,
    );
    if (restored.scope != session.scope) {
      throw const AppFailure('Contexto da sessão inconsistente.');
    }
    await storage.save(restored);
    return restored;
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
    return MobileSession(
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
