import 'dart:convert';
import 'dart:io';

import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:ponto_aqui_app/features/bootstrap/data/mobile_sync_dto.dart';
import 'package:ponto_aqui_app/features/escala/domain/schedule_projector.dart';

/// Valida uma carga salva sem tokens usando o mesmo parser e projetor do app.
void main(List<String> args) {
  try {
    if (args.length != 1) throw const FormatException('Informe a carga JSON.');
    tzdata.initializeTimeZones();
    final text = File(args.single)
        .readAsStringSync()
        .replaceFirst('\uFEFF', '');
    final snapshot = MobileSyncDto.fromJson(jsonDecode(text));
    final now = tz.TZDateTime.from(
      snapshot.serverTimestamp,
      tz.getLocation(snapshot.fusoHorario),
    );
    final civilDate =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    if (civilDate != snapshot.dataReferencia) {
      throw const FormatException('Data civil diverge do horario do servidor.');
    }
    var projected = 0;
    final projector = ScheduleProjector();
    for (final allocation in snapshot.alocacoes) {
      final scale = allocation.escala;
      if (scale == null || scale.modelo == 'Legado' || scale.turnos.isEmpty) {
        continue;
      }
      final days = projector.project(
        allocation,
        snapshot.fusoHorario,
        snapshot.dataReferencia,
      );
      if (days.length != 7) throw const FormatException('Janela incompleta.');
      projected++;
    }
    stdout.writeln(
      jsonEncode({
        'ok': true,
        'status': snapshot.status,
        'modo': snapshot.modoOperacao.name,
        'alocacoes': snapshot.alocacoes.length,
        'escalas_projetadas': projected,
        'data_referencia': snapshot.dataReferencia,
        'fuso_horario': snapshot.fusoHorario,
      }),
    );
  } catch (_) {
    stderr.writeln(
      'Carga rejeitada pelo parser, fuso ou projetor do aplicativo.',
    );
    exitCode = 1;
  }
}
