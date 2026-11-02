import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:ponto_aqui_app/core/clock/clock_sample.dart';
import 'package:ponto_aqui_app/core/config/app_config.dart';
import 'package:ponto_aqui_app/features/bootstrap/data/mobile_sync_dto.dart';
import 'package:ponto_aqui_app/features/bootstrap/domain/bootstrap_snapshot.dart';
import 'package:ponto_aqui_app/features/escala/domain/schedule_projector.dart';
import 'package:ponto_aqui_app/features/sincronizacao/domain/receipt_validator.dart';

import 'support.dart';

void main() {
  setUpAll(tz.initializeTimeZones);
  test('weekly schedules include previous night and follow ISO weekdays', () {
    final body = fixture();
    for (final scale in [body['escala'], body['alocacoes'][0]['escala']]) {
      scale['modelo'] = 'Diurno';
      scale['data_referencia'] = null;
      scale['turnos'][0]['dias_semana'] = [1];
    }
    final dto = MobileSyncDto.fromJson(body);
    final days = ScheduleProjector().project(
      dto.alocacoes.single,
      dto.fusoHorario,
      '2026-10-06',
      days: 2,
    );
    expect(days.first.windows.single.start.weekday, 1);
    expect(days.last.windows, isEmpty);
  });
  test(
    'missing clock catalog and contradictory personal status are rejected',
    () {
      final clock = fixture('relogio')..['escalas'] = [];
      expect(() => MobileSyncDto.fromJson(clock), throwsFormatException);
      final personal = fixture()..['status'] = 'SEM_ALOCACAO';
      expect(() => MobileSyncDto.fromJson(personal), throwsFormatException);
    },
  );
  test(
    'DTOs parse both real backend fixtures and distinguish employee/account',
    () {
      final personal = MobileSyncDto.fromJson(fixture());
      final clock = MobileSyncDto.fromJson(fixture('relogio'));
      expect(personal.funcionario!.id, isNot(personal.funcionario!.usuarioId));
      expect(clock.modoOperacao, ModoOperacao.relogio);
      expect(
        clock.funcionarios.single.alocacoes.single.escalaId,
        clock.escalas.single.id,
      );
      expect(
        MobileSyncDto.fromJson(personal.toJson()).toJson(),
        personal.toJson(),
      );
    },
  );
  test('null summaries and multiple allocations remain valid', () {
    final body = fixture();
    body['alocacoes'] = [
      body['alocacoes'][0],
      jsonDecode(jsonEncode(body['alocacoes'][0])),
    ];
    body['alocacoes'][1]['id'] = '77777777-7777-4777-8777-777777777777';
    body['setor'] = null;
    body['escala'] = null;
    body['status'] = 'MULTIPLAS_ALOCACOES';
    expect(MobileSyncDto.fromJson(body).alocacoes, hasLength(2));
    body['alocacoes'] = [];
    body['status'] = 'SEM_ALOCACAO';
    expect(MobileSyncDto.fromJson(body).setor, isNull);
    body['funcionario'] = null;
    body['status'] = 'SEM_FUNCIONARIO';
    expect(MobileSyncDto.fromJson(body).funcionario, isNull);
  });
  for (final mutation in [
    'timestamp',
    'status',
    'latitude',
    'turn',
    'cycle',
    'missing_list',
    'date',
    'mode',
  ]) {
    test('invalid DTO $mutation is rejected', () {
      final body = fixture();
      switch (mutation) {
        case 'timestamp':
          body['server_timestamp'] = '2026-10-05T15:00:00';
        case 'status':
          body['status'] = 'INVALIDO';
        case 'latitude':
          body['setor']['latitude'] = 91;
        case 'turn':
          body['escala']['turnos'][0]['dias_semana'] = [0];
        case 'cycle':
          body['escala']['data_referencia'] = null;
        case 'missing_list':
          body.remove('alocacoes');
        case 'date':
          body['data_referencia'] = '2026-02-30';
        case 'mode':
          body['modo_operacao'] = 'OUTRO';
      }
      expect(() => MobileSyncDto.fromJson(body), throwsFormatException);
    });
  }
  test('clock offset sign, truncation, age and company date are explicit', () {
    final sample = ClockSample(
      offsetMs: 1599,
      receivedAt: DateTime.utc(2026, 10, 5),
      roundTripMs: 100,
    );
    expect(sample.driftSeconds, 1);
    expect(signedDriftSeconds(-1599), -1);
    expect(signedDriftSeconds(-999), 0);
    expect(
      sample
          .estimate(sample.receivedAt)
          .difference(sample.receivedAt)
          .inMilliseconds,
      1599,
    );
    expect(
      sample.usable(sample.receivedAt.add(const Duration(hours: 25))),
      isFalse,
    );
    expect(
      sample.usable(sample.receivedAt.subtract(const Duration(seconds: 1))),
      isFalse,
    );
    expect(
      ClockSample.civilDate(DateTime.utc(2026, 10, 5, 2), 'America/Sao_Paulo'),
      '2026-10-04',
    );
  });
  test('snapshot requires current company date, sample and personal mode', () {
    final dto = MobileSyncDto.fromJson(fixture());
    final sample = ClockSample(
      offsetMs: 0,
      receivedAt: dto.serverTimestamp,
      roundTripMs: 1,
    );
    expect(
      BootstrapSnapshot(dto, sample).captureRestriction(dto.serverTimestamp),
      isNull,
    );
    expect(
      BootstrapSnapshot(
        dto,
        sample,
      ).captureRestriction(dto.serverTimestamp.add(const Duration(days: 1))),
      isNotNull,
    );
    expect(
      BootstrapSnapshot(
        MobileSyncDto.fromJson(fixture('relogio')),
        sample,
      ).captureRestriction(dto.serverTimestamp),
      isNotNull,
    );
  });
  test('12x36 preserves overnight tail and 48 actual hours', () {
    final dto = MobileSyncDto.fromJson(fixture());
    final days = ScheduleProjector().project(
      dto.alocacoes.single,
      dto.fusoHorario,
      '2026-10-06',
      days: 3,
    );
    expect(days.first.windows.single.start.hour, 19);
    expect(days.first.windows.single.end.hour, 7);
    expect(days.first.windows.single.start.day, 5);
    expect(
      days[1].windows.single.start
          .difference(days.first.windows.single.start)
          .inHours,
      48,
    );
    expect(ScheduleProjector.durationMinutes(dto.escala!.turnos.single), 720);
    expect(days.first.windows.single.breakMinutes, 60);
  });
  test('24x72 has 96 actual hours and midnight end is half-open', () {
    final body = fixture();
    final scale = body['alocacoes'][0]['escala'];
    scale['modelo'] = '24x72';
    scale['turnos'][0]
      ..['hora_inicio'] = '00:00'
      ..['hora_fim'] = '00:00'
      ..['fim_dia_seguinte'] = true;
    final dto = MobileSyncDto.fromJson(body);
    final days = ScheduleProjector().project(
      dto.alocacoes.single,
      dto.fusoHorario,
      '2026-10-05',
      days: 5,
    );
    expect(days.map((d) => d.windows.isNotEmpty), [
      true,
      false,
      false,
      false,
      true,
    ]);
    expect(
      days.last.windows.single.start
          .difference(days.first.windows.single.start)
          .inHours,
      96,
    );
  });
  test(
    'cyclic DST preserves elapsed duration rather than local start time',
    () {
      final body = fixture();
      final allocation = body['alocacoes'][0];
      allocation['data_inicio'] = '2026-03-07';
      allocation['escala']['data_referencia'] = '2026-03-07';
      final dto = MobileSyncDto.fromJson(body);
      final days = ScheduleProjector().project(
        dto.alocacoes.single,
        'America/New_York',
        '2026-03-07',
        days: 4,
      );
      final starts =
          days.expand((d) => d.windows).map((w) => w.start).toSet().toList()
            ..sort();
      expect(starts[1].difference(starts[0]).inHours, 48);
    },
  );
  test(
    'legacy is not inferred and inclusive allocation end preserves night',
    () {
      final body = fixture();
      body['alocacoes'][0]['data_fim'] = '2026-10-05';
      var dto = MobileSyncDto.fromJson(body);
      final days = ScheduleProjector().project(
        dto.alocacoes.single,
        dto.fusoHorario,
        '2026-10-06',
        days: 2,
      );
      expect(days.first.windows, hasLength(1));
      expect(days.last.windows, isEmpty);
      body['alocacoes'][0]['escala']['modelo'] = 'Legado';
      dto = MobileSyncDto.fromJson(body);
      expect(
        () => ScheduleProjector().project(
          dto.alocacoes.single,
          dto.fusoHorario,
          '2026-10-05',
        ),
        throwsFormatException,
      );
    },
  );
  test('configuration rejects credential-bearing URLs and arbitrary paths', () {
    for (final uri in [
      'https://user:pass@example.test',
      'https://api.example.test/api/web',
      'http://example.test',
      'https://api.example.test?x=1',
    ]) {
      expect(() => AppConfig(uri), throwsFormatException);
    }
    expect(AppConfig('https://api.example.test/').origin, session.origin);
  });
  test(
    'confirmation requires matching evidence, index and all receipt fields',
    () {
      final payload = evidence();
      final good = receipt(payload, 0);
      expect(coherentReceipt(good, payload, 0), isTrue);
      expect(
        coherentReceipt({...good, 'registrado_offline': false}, payload, 0),
        isFalse,
      );
      expect(coherentReceipt({...good, 'indice': 1}, payload, 0), isFalse);
      expect(
        coherentReceipt({...good}..remove('recebido_em'), payload, 0),
        isFalse,
      );
    },
  );
}
