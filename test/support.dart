import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ponto_aqui_app/core/config/app_config.dart';
import 'package:ponto_aqui_app/core/device/connection_monitor.dart';
import 'package:ponto_aqui_app/core/network/mobile_api.dart';
import 'package:ponto_aqui_app/core/storage/session_storage.dart';
import 'package:ponto_aqui_app/features/auth/domain/mobile_session.dart';
import 'package:ponto_aqui_app/features/marcacoes/domain/punch_event.dart';
import 'package:uuid/uuid.dart';

const session = MobileSession(
  origin: 'https://api.example.test',
  token: 'test-token',
  userId: '22222222-2222-4222-8222-222222222222',
  companyId: '99999999-9999-4999-8999-999999999999',
  name: 'Ana Silva',
  email: 'ana@example.test',
  role: 'FUNCIONARIO',
  deviceId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  deviceUuid: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
);

Map<String, dynamic> profile() => {
  'id': session.userId,
  'empresa_id': session.companyId,
  'nome': session.name,
  'email': session.email,
  'papel': session.role,
};

class FakeConnections implements ConnectionMonitor {
  final controller = StreamController<bool>.broadcast();
  @override
  Future<bool> isOffline() async => true;
  @override
  Stream<bool> get changes => controller.stream;
}

Map<String, dynamic> fixture([String mode = 'pessoal']) =>
    jsonDecode(File('test/fixtures/w08-$mode.json').readAsStringSync())
        as Map<String, dynamic>;

Map<String, dynamic> evidence({String? id}) => {
  'evento_cliente_id': id ?? const Uuid().v4(),
  'dispositivo_id': session.deviceId,
  'alocacao_id': '55555555-5555-4555-8555-555555555555',
  'tipo': 'Entrada',
  'ocorrido_em': '2026-10-05T08:00:00-03:00',
  'desvio_relogio_segundos': -15,
  'registrado_offline': true,
  'posicao': null,
};

PunchEvent event(
  Map<String, dynamic> payload, {
  String? photoPath,
  String? photoSha,
}) => PunchEvent(
  payload: payload,
  metadata: {'localizacao_status': 'permissao_negada'},
  capturedMs: DateTime.utc(2026, 10, 5).millisecondsSinceEpoch,
  photoPath: photoPath,
  photoSha: photoSha,
);

Map<String, dynamic> receipt(
  Map<String, dynamic> payload,
  int index, {
  bool duplicate = false,
  String situation = 'Aceita',
}) => {
  'indice': index,
  'http_status': duplicate ? 200 : 201,
  'evento_cliente_id': payload['evento_cliente_id'],
  'registro_id': 'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  'persistida': true,
  'duplicada': duplicate,
  'situacao': situation,
  'motivos': situation == 'Aceita' ? [] : ['LOCALIZACAO_AUSENTE'],
  'ocorrido_em': DateTime.parse(payload['ocorrido_em'] as String)
      .toUtc()
      .toIso8601String(),
  'recebido_em': '2026-10-05T15:00:00Z',
  'offset_original_minutos': -180,
  'desvio_relogio_segundos': payload['desvio_relogio_segundos'],
  'registrado_offline': payload['registrado_offline'],
  'distancia_centro_metros': null,
};

class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);
  final FutureOr<ResponseBody> Function(RequestOptions) handler;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    await requestStream?.drain<void>();
    return handler(options);
  }

  static ResponseBody json(Object body, [int status = 200]) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
  @override
  void close({bool force = false}) {}
}

MobileApi fakeApi(FakeAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return MobileApi(AppConfig(session.origin), dio: dio);
}

class MemorySessionStorage extends SessionStorage {
  MemorySessionStorage([this.value]) : super(const FlutterSecureStorage());
  MobileSession? value;
  @override
  Future<String> installationUuid() async => session.deviceUuid;
  @override
  Future<MobileSession?> restore() async => value;
  @override
  Future<void> save(MobileSession session) async {
    value = session;
  }

  @override
  Future<void> logout() async {
    value = null;
  }
}
