import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ponto_aqui_app/core/database/app_database.dart';
import 'package:ponto_aqui_app/core/errors/app_failure.dart';
import 'package:ponto_aqui_app/features/marcacoes/data/outbox_repository.dart';
import 'package:ponto_aqui_app/features/sincronizacao/domain/sync_worker.dart';

import 'support.dart';

void main() {
  late AppDatabase db;
  late OutboxRepository outbox;
  final now = DateTime.utc(2026, 10, 5, 15);
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    outbox = OutboxRepository(db);
  });
  tearDown(() async {
    await db.close();
  });
  Future<void> run(
    FakeAdapter adapter, {
    bool manual = false,
    bool Function()? authorized,
    Future<void> Function(AppFailure)? onDenied,
  }) => SyncWorker(outbox, fakeApi(adapter), now: () => now).run(
    session,
    authorized: authorized ?? () => true,
    onDenied: onDenied ?? (_) async {},
    manual: manual,
  );

  test('207 confirms accepted/refused items and preserves action-required failures', () async {
    final payloads = List.generate(3, (_) => evidence());
    for (final item in payloads) {
      await outbox.save(session.scope, event(item));
    }
    final adapter = FakeAdapter((request) {
      final sent = (request.data as Map)['marcacoes'] as List;
      return FakeAdapter.json({
        'resultados': sent.indexed.map((entry) {
          final item = entry.$2 as Map<String, dynamic>;
          if (item['evento_cliente_id'] == payloads[1]['evento_cliente_id']) {
            return {
              'indice': entry.$1,
              'evento_cliente_id': item['evento_cliente_id'],
              'http_status': 422,
              'persistida': false,
              'erro': {'codigo': 'DADOS_INVALIDOS', 'mensagem': 'Inválido'},
            };
          }
          return receipt(
            item,
            entry.$1,
            situation:
                item['evento_cliente_id'] == payloads[2]['evento_cliente_id']
                ? 'Recusada'
                : 'Aceita',
          );
        }).toList(),
      }, 207);
    });
    await run(adapter);
    final rows = await outbox.list(session.scope);
    expect(
      rows
          .singleWhere((r) => r.eventId == payloads[1]['evento_cliente_id'])
          .transport,
      'erro_requer_acao',
    );
    expect(rows.where((r) => r.transport == 'confirmada'), hasLength(2));
    await run(adapter, manual: true);
    expect(adapter.requests, hasLength(1));
  });
  test(
    'lost response after server commit retries the identical UUID and payload',
    () async {
      final payload = evidence();
      await outbox.save(session.scope, event(payload));
      var committed = false;
      final adapter = FakeAdapter((request) {
        final sent = (request.data as Map)['marcacoes'] as List;
        expect(sent.single, payload);
        if (!committed) {
          committed = true;
          throw DioException(
            requestOptions: request,
            type: DioExceptionType.receiveTimeout,
          );
        }
        return FakeAdapter.json({
          'resultados': [receipt(payload, 0, duplicate: true)],
        });
      });
      await run(adapter);
      expect((await outbox.list(session.scope)).single.transport, 'na_fila');
      await run(adapter, manual: true);
      final row = (await outbox.list(session.scope)).single;
      expect(row.transport, 'confirmada');
      expect(row.attempts, 2);
      expect(jsonDecode(row.payload), payload);
    },
  );
  test('partial and duplicate-index responses do not confirm missing or ambiguous events', () async {
    final first = evidence(), second = evidence();
    await outbox.save(session.scope, event(first));
    await outbox.save(session.scope, event(second));
    await run(
      FakeAdapter((request) {
        final sent = (request.data as Map)['marcacoes'] as List;
        final index = sent.indexWhere(
          (p) => p['evento_cliente_id'] == first['evento_cliente_id'],
        );
        return FakeAdapter.json({
          'resultados': [receipt(first, index)],
        }, 207);
      }),
    );
    final rows = await outbox.list(session.scope);
    expect(
      rows
          .singleWhere((r) => r.eventId == first['evento_cliente_id'])
          .transport,
      'confirmada',
    );
    expect(
      rows
          .singleWhere((r) => r.eventId == second['evento_cliente_id'])
          .transport,
      'na_fila',
    );
    await run(
      FakeAdapter(
        (_) => FakeAdapter.json({
          'resultados': [receipt(second, 0), receipt(second, 0)],
        }),
      ),
      manual: true,
    );
    expect(
      (await outbox.list(session.scope))
          .singleWhere((r) => r.eventId == second['evento_cliente_id'])
          .transport,
      'na_fila',
    );
  });
  for (final code in [401, 403]) {
    test(
      '$code suspends sending and preserves evidence and identity',
      () async {
        final payload = evidence();
        await outbox.save(session.scope, event(payload));
        var denied = false;
        final adapter = FakeAdapter(
          (_) => FakeAdapter.json({
            'erro': {'codigo': 'ACESSO_NEGADO', 'mensagem': 'Acesso negado'},
          }, code),
        );
        await run(
          adapter,
          onDenied: (error) async {
            denied = error.status == code;
          },
        );
        expect(denied, isTrue);
        final row = (await outbox.list(session.scope)).single;
        expect(row.transport, 'na_fila');
        expect(jsonDecode(row.payload), payload);
        await run(adapter, authorized: () => false, manual: true);
        expect(adapter.requests, hasLength(1));
      },
    );
  }
  test('scope prevents sending another account or device outbox', () async {
    await outbox.save('other-account', event(evidence()));
    final adapter = FakeAdapter((_) => throw StateError('must not send'));
    await run(adapter);
    expect(adapter.requests, isEmpty);
    expect(await outbox.list('other-account'), hasLength(1));
  });
  test(
    'concurrent workers produce a single request for a leased batch',
    () async {
      final payload = evidence();
      await outbox.save(session.scope, event(payload));
      final requestStarted = Completer<void>();
      final response = Completer<ResponseBody>();
      final adapter = FakeAdapter((_) {
        requestStarted.complete();
        return response.future;
      });
      final first = run(adapter);
      await requestStarted.future;
      await run(adapter);
      response.complete(
        FakeAdapter.json({
          'resultados': [receipt(payload, 0)],
        }),
      );
      await first;
      expect(adapter.requests, hasLength(1));
    },
  );
  test(
    'selfie uploads only after point commit and retries original file bytes',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'pontoaqui-test-photo-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final bytes = [255, 216, 255, 42, 255, 217];
      final file = await File('${dir.path}/evidence.jpg').writeAsBytes(bytes);
      final hash = sha256.convert(bytes).toString();
      final payload = evidence();
      await outbox.save(
        session.scope,
        event(payload, photoPath: file.path, photoSha: hash),
      );
      var photos = 0;
      final adapter = FakeAdapter((request) {
        if (request.path.endsWith('/lote')) {
          return FakeAdapter.json({
            'resultados': [receipt(payload, 0)],
          });
        }
        photos++;
        expect((request.data as FormData).files.single.key, 'selfie');
        expect(file.readAsBytesSync(), bytes);
        if (photos == 1) {
          return FakeAdapter.json({
            'erro': {'mensagem': 'Tente novamente'},
          }, 503);
        }
        return FakeAdapter.json({
          'evento_cliente_id': payload['evento_cliente_id'],
          'selfie_id': 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
          'sha256': hash,
          'content_type': 'image/jpeg',
          'duplicada': true,
        });
      });
      await run(adapter);
      var row = (await outbox.list(session.scope)).single;
      expect(row.transport, 'confirmada');
      expect(row.photoTransport, 'na_fila');
      await run(adapter, manual: true);
      row = (await outbox.list(session.scope)).single;
      expect(row.photoTransport, 'confirmada');
      expect(file.readAsBytesSync(), bytes);
      expect(
        adapter.requests.where((r) => r.path.endsWith('/lote')),
        hasLength(1),
      );
    },
  );
  test(
    '503 applies backoff; connectivity signal never acknowledges an event',
    () async {
      await outbox.save(session.scope, event(evidence()));
      final adapter = FakeAdapter((_) => FakeAdapter.json({}, 503));
      await run(adapter);
      await run(adapter);
      expect(adapter.requests, hasLength(1));
      expect(
        (await outbox.list(session.scope)).single.nextAttemptMs,
        greaterThan(now.millisecondsSinceEpoch),
      );
    },
  );
}
