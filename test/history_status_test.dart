import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'package:ponto_aqui_app/app/theme/app_theme.dart';
import 'package:ponto_aqui_app/core/clock/clock_sample.dart';
import 'package:ponto_aqui_app/core/database/app_database.dart';
import 'package:ponto_aqui_app/features/auth/domain/mobile_session.dart';
import 'package:ponto_aqui_app/features/auth/presentation/auth_view_model.dart';
import 'package:ponto_aqui_app/features/bootstrap/data/bootstrap_repository.dart';
import 'package:ponto_aqui_app/features/bootstrap/data/mobile_sync_dto.dart';
import 'package:ponto_aqui_app/features/bootstrap/domain/bootstrap_snapshot.dart';
import 'package:ponto_aqui_app/features/bootstrap/presentation/work_view_model.dart';
import 'package:ponto_aqui_app/features/marcacoes/data/outbox_repository.dart';
import 'package:ponto_aqui_app/features/marcacoes/presentation/work_views.dart';

import 'support.dart';

String _eventId(int n) =>
    'eeeeeeee-eeee-4eee-8eee-${n.toString().padLeft(12, '0')}';
String _recordId(int n) =>
    'dddddddd-dddd-4ddd-8ddd-${n.toString().padLeft(12, '0')}';
Map<String, dynamic> _payload(int n) => evidence(id: _eventId(n));
Map<String, dynamic> _receipt(int n) => {
  ...receipt(_payload(n), n, situation: 'Recusada'),
  'registro_id': _recordId(n),
  'motivos': ['FORA_DO_PERIMETRO'],
};
Map<String, dynamic> _remote(
  int n, [
  Map<String, dynamic> decision = const {},
]) => {
  'id': _recordId(n),
  'evento_cliente_id': _eventId(n),
  'tipo': 'Entrada',
  'situacao': 'Recusada',
  'ocorrido_em': _receipt(n)['ocorrido_em'],
  'recebido_em': _receipt(n)['recebido_em'],
  'motivos': ['FORA_DO_PERIMETRO'],
  ...decision,
};
OutboxEvent _row(int n, {bool confirmed = true}) => OutboxEvent(
  scope: session.scope,
  eventId: _eventId(n),
  payload: jsonEncode(_payload(n)),
  metadata: jsonEncode({'setor_nome': 'Contabilidade'}),
  capturedMs: DateTime.utc(2026, 10, 5).millisecondsSinceEpoch + n,
  transport: confirmed ? 'confirmada' : 'na_fila',
  photoTransport: 'sem_foto',
  receipt: confirmed ? jsonEncode(_receipt(n)) : null,
  attempts: confirmed ? 1 : 0,
  photoAttempts: 0,
  nextAttemptMs: 0,
);
BootstrapSnapshot _snapshot(List<Map<String, dynamic>> records) =>
    BootstrapSnapshot(
      MobileSyncDto.fromJson(fixture()..['marcacoes_recentes'] = records),
      ClockSample(
        offsetMs: 0,
        receivedAt: DateTime.utc(2026, 10, 5, 15),
        roundTripMs: 0,
      ),
    );

class _Authenticated extends AuthViewModel {
  @override
  Future<MobileSession?> build() async => session;
}

class _Work extends WorkViewModel {
  _Work(this.snapshot) : super(session.scope);
  final BootstrapSnapshot snapshot;
  @override
  WorkState build() => WorkState(snapshot: snapshot, offline: false);
}

Future<void> _show(
  WidgetTester tester,
  List<OutboxEvent> rows,
  List<Map<String, dynamic>> records, {
  bool queue = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(500, 2600);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(_Authenticated.new),
        workProvider(session.scope)
            .overrideWith(() => _Work(_snapshot(records))),
        eventsProvider(session.scope).overrideWith((ref) => Stream.value(rows)),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: queue ? const QueueView() : const HistoryView()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(tz.initializeTimeZones);

  for (final situation in ['Aceita', 'PendenteAnalise', 'Recusada']) {
    test('automatic $situation never implies a management decision', () {
      final dto = MarcacaoRecenteDto.fromJson(
        _remote(1)..['situacao'] = situation,
      );
      expect(dto.decisaoRh, isNull);
      expect(dto.toJson().containsKey('aprovado_gestor'), isFalse);
      expect(MarcacaoRecenteDto.fromJson(dto.toJson()).decisaoRh, isNull);
    });
  }

  for (final decision in [
    (
      {'invalidado': false, 'aprovado_gestor': true, 'reaprovado_rh': false},
      'Aprovada pelo Gestor/RH',
    ),
    (
      {'invalidado': true, 'aprovado_gestor': false, 'reaprovado_rh': false},
      'Invalidada pelo Gestor/RH',
    ),
    (
      {'invalidado': false, 'aprovado_gestor': true, 'reaprovado_rh': true},
      'Reaprovada pelo RH',
    ),
    (
      {'invalidado': false, 'aprovado_gestor': false, 'reaprovado_rh': false},
      null,
    ),
  ]) {
    test('optional management flags round-trip: ${decision.$2}', () {
      final raw = _remote(1, decision.$1);
      final dto = MarcacaoRecenteDto.fromJson(raw);
      expect(dto.decisaoRh, decision.$2);
      expect(dto.situacao, 'Recusada');
      expect(dto.motivos, ['FORA_DO_PERIMETRO']);
      final restored = MarcacaoRecenteDto.fromJson(dto.toJson());
      expect(restored.decisaoRh, decision.$2);
      for (final field in decision.$1.keys) {
        expect(restored.toJson()[field], decision.$1[field]);
      }
    });
  }
  for (final flags in <Map<String, dynamic>>[
    {'aprovado_gestor': 'true'},
    {'invalidado': 1},
    {'reaprovado_rh': 'false'},
    {'invalidado': true, 'aprovado_gestor': true},
    {'reaprovado_rh': true, 'aprovado_gestor': false},
  ]) {
    test('invalid management flags are rejected: $flags', () {
      expect(
        () => MarcacaoRecenteDto.fromJson(_remote(1, flags)),
        throwsFormatException,
      );
    });
  }

  test('HTTP refresh/cache preserve per-record decisions and immutable receipts', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final outbox = OutboxRepository(db);
    final original = event(
      _payload(1),
      photoPath: 'synthetic-selfie.jpg',
      photoSha: 'synthetic-sha',
    );
    await outbox.save(session.scope, original);
    await outbox.claim(session.scope, 'worker', DateTime.utc(2026, 10, 5, 15));
    await outbox.confirm(session.scope, 'worker', {_eventId(1): _receipt(1)});
    final before = (await outbox.list(session.scope)).single;
    var records = [
      _remote(1, {'aprovado_gestor': true}),
      _remote(2, {'invalidado': true}),
    ];
    final adapter = FakeAdapter((request) {
      expect(request.path, '/api/v1/mobile/sync');
      expect(request.method, 'GET');
      return FakeAdapter.json(fixture()..['marcacoes_recentes'] = records);
    });
    final repo = BootstrapRepository(
      db,
      fakeApi(adapter),
      now: () => DateTime.utc(2026, 10, 5, 15),
    );
    await repo.refresh(session);
    final cached = (await repo.cached(session))!.data.marcacoesRecentes;
    expect(cached.map((r) => r.decisaoRh), [
      'Aprovada pelo Gestor/RH',
      'Invalidada pelo Gestor/RH',
    ]);
    expect((await outbox.list(session.scope)).single, before);
    // A new response without RH fields must not retain an old cached approval.
    records = [_remote(1), _remote(2)];
    await repo.refresh(session);
    expect(
      (await repo.cached(session))!.data.marcacoesRecentes
          .map((r) => r.decisaoRh),
      [null, null],
    );
    expect((await outbox.list(session.scope)).single, before);
  });

  for (final queue in [false, true]) {
    testWidgets(
      '${queue ? 'queue' : 'history'} does not present original rejection as RH refusal',
      (tester) async {
        await _show(tester, [_row(1)], [_remote(1)], queue: queue);
        expect(
          find.text('Sincronizado · Decisão do RH não disponível'),
          findsOneWidget,
        );
        expect(find.text('Sincronizado · Recusada'), findsNothing);
        expect(find.text('Recusada'), findsNothing);
        await tester.tap(find.text('Validação automática original'));
        await tester.pumpAndSettle();
        expect(find.text('Recusada'), findsOneWidget);
        expect(find.text('FORA_DO_PERIMETRO'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'three approved and one invalidated merge into their own local cards by both IDs',
    (tester) async {
      await _show(
        tester,
        [for (var n = 1; n <= 4; n++) _row(n)],
        [
          _remote(4, {'aprovado_gestor': true}),
          _remote(2, {'invalidado': true}),
          _remote(3, {'aprovado_gestor': true}),
          _remote(1, {'aprovado_gestor': true}),
        ],
      );
      expect(find.byType(Card), findsNWidgets(4));
      for (var i = 0; i < 4; i++) {
        final status = i == 1
            ? 'Invalidada pelo Gestor/RH'
            : 'Aprovada pelo Gestor/RH';
        expect(
          find.descendant(
            of: find.byType(Card).at(i),
            matching: find.text('Sincronizado · $status'),
          ),
          findsOneWidget,
        );
      }
      expect(find.text('Sincronizado · Recusada'), findsNothing);
    },
  );

  for (final mismatch in ['record', 'event', 'duplicate', 'unconfirmed']) {
    testWidgets(
      'a decision cannot attach to a different or ambiguous $mismatch',
      (tester) async {
        final approved = _remote(1, {'aprovado_gestor': true});
        if (mismatch == 'record') approved['id'] = _recordId(2);
        if (mismatch == 'event') approved['evento_cliente_id'] = _eventId(2);
        await _show(
          tester,
          [_row(1, confirmed: mismatch != 'unconfirmed')],
          [approved, if (mismatch == 'duplicate') approved],
        );
        final localCard = find.byType(Card).first;
        expect(
          find.descendant(
            of: localCard,
            matching: find.text('Sincronizado · Aprovada pelo Gestor/RH'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: localCard,
            matching: find.text(
              mismatch == 'unconfirmed'
                  ? 'Salvo no aparelho'
                  : 'Sincronizado · Decisão do RH não disponível',
            ),
          ),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets(
    'remote-only records also separate RH decisions from automatic classification',
    (tester) async {
      await _show(tester, [], [
        _remote(1, {'aprovado_gestor': true}),
        _remote(2),
      ]);
      expect(
        find.text('Sincronizado · Aprovada pelo Gestor/RH'),
        findsOneWidget,
      );
      expect(
        find.text('Sincronizado · Decisão do RH não disponível'),
        findsOneWidget,
      );
      expect(find.text('Sincronizado · Recusada'), findsNothing);
    },
  );
}
