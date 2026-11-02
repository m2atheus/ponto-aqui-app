import 'dart:io';

import 'package:dio/dio.dart';

import '../../features/auth/domain/mobile_session.dart';
import '../config/app_config.dart';
import '../errors/app_failure.dart';

class MobileApi {
  MobileApi(this.config, {Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      baseUrl: config.origin,
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      followRedirects: false,
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
      headers: {'Accept': 'application/json'},
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.uri.origin != config.origin) {
            handler.reject(
              DioException(
                requestOptions: options,
                error: const AppFailure('Origem de API inválida.'),
              ),
            );
          } else {
            handler.next(options);
          }
        },
      ),
    );
  }
  final AppConfig config;
  final Dio _dio;

  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    MobileSession? session,
    Object? data,
  }) async {
    if (session != null && session.origin != config.origin) {
      throw const AppFailure('A sessão pertence a outra API.');
    }
    try {
      final response = await _dio.request<Object?>(
        path,
        data: data,
        options: Options(
          method: method,
          headers: {
            if (session != null) ...{
              'Authorization': 'Bearer ${session.token}',
              'X-Device-UUID': session.deviceUuid,
            },
          },
        ),
      );
      final body = response.data;
      final expectedStatuses = path.endsWith('/selfie')
          ? {200, 201}
          : path == '/api/mobile/marcacoes/lote'
          ? {200, 207}
          : {200};
      if (!expectedStatuses.contains(response.statusCode)) {
        throw const AppFailure(
          'Status de resposta inesperado. A confirmação está pendente.',
          code: 'RESPOSTA_INVALIDA',
        );
      }
      if (body is! Map<String, dynamic>) {
        throw const AppFailure(
          'A API retornou uma resposta inválida.',
          code: 'RESPOSTA_INVALIDA',
        );
      }
      if (path.endsWith('/selfie') &&
          body['duplicada'] != (response.statusCode == 200)) {
        throw const AppFailure(
          'Confirmação da selfie inconsistente.',
          code: 'RESPOSTA_INVALIDA',
        );
      }
      if (path == '/api/v1/mobile/sync') {
        final header = response.headers.value('X-Server-Timestamp');
        if (header != null && header != body['server_timestamp']) {
          throw const AppFailure(
            'Hora do servidor inconsistente.',
            code: 'RESPOSTA_INVALIDA',
          );
        }
      }
      return body;
    } on DioException catch (error) {
      final body = error.response?.data;
      final detail = body is Map ? body['erro'] : null;
      throw AppFailure(
        detail is Map && detail['mensagem'] is String
            ? detail['mensagem'] as String
            : 'Não foi possível acessar a API. Suas evidências locais foram preservadas.',
        code: detail is Map && detail['codigo'] is String
            ? detail['codigo'] as String
            : 'REDE_INDISPONIVEL',
        status: error.response?.statusCode,
      );
    }
  }

  Future<Map<String, dynamic>> upload(
    MobileSession session,
    String eventId,
    File photo,
  ) async {
    final data = FormData.fromMap({
      'selfie': await MultipartFile.fromFile(
        photo.path,
        filename: '$eventId.jpg',
      ),
    });
    return request(
      'POST',
      '/api/mobile/marcacoes/$eventId/selfie',
      session: session,
      data: data,
    );
  }

  void close() => _dio.close(force: true);
}
