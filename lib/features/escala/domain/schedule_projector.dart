import 'dart:math';

import 'package:timezone/timezone.dart' as tz;

import '../../bootstrap/data/mobile_sync_dto.dart';

class ShiftWindow {
  const ShiftWindow(this.start, this.end, this.breakMinutes);
  final tz.TZDateTime start, end;
  final int breakMinutes;
  bool overlaps(DateTime startOfDay, DateTime endOfDay) =>
      start.isBefore(endOfDay) && end.isAfter(startOfDay);
}

class ScheduleDay {
  const ScheduleDay(this.date, this.windows);
  final tz.TZDateTime date;
  final List<ShiftWindow> windows;
}

class ScheduleProjector {
  List<ScheduleDay> project(
    AlocacaoPessoalSyncDto allocation,
    String zoneName,
    String firstDate, {
    int days = 7,
  }) {
    final scale = allocation.escala;
    if (scale == null || scale.modelo == 'Legado' || scale.turnos.isEmpty) {
      throw const FormatException(
        'Escala sem programação estruturada disponível.',
      );
    }
    if (days < 1 || days > 31) throw const FormatException('Janela inválida.');
    final zone = tz.getLocation(zoneName);
    final parsed = DateTime.parse(firstDate);
    final first = tz.TZDateTime(zone, parsed.year, parsed.month, parsed.day);
    final end = tz.TZDateTime(zone, first.year, first.month, first.day + days);
    final windows = <ShiftWindow>[];
    if (['12x36', '24x72'].contains(scale.modelo)) {
      if (scale.dataReferencia == null) {
        throw const FormatException('Ciclo sem referência.');
      }
      final reference = DateTime.parse(scale.dataReferencia!);
      final firstShift = scale.turnos.first;
      final anchor = _local(zone, reference, firstShift.horaInicio);
      final period = Duration(hours: scale.modelo == '12x36' ? 48 : 96);
      final duration = scale.modelo == '12x36' ? 720 : 1440;
      final anchorMinute = anchor.hour * 60 + anchor.minute;
      final components = scale.turnos.map((turn) {
        final parts = turn.horaInicio.split(':').map(int.parse).toList();
        final offset = (parts[0] * 60 + parts[1] - anchorMinute) % 1440;
        final gross = durationMinutes(turn);
        if (offset + gross > duration) {
          throw const FormatException('Componente fora do plantão.');
        }
        return (offset: offset, duration: gross, pause: turn.tempoIntervalo);
      }).toList()..sort((a, b) => a.offset.compareTo(b.offset));
      if (components.last.offset + components.last.duration != duration ||
          components.first.offset != 0) {
        throw const FormatException('Plantão incompleto.');
      }
      for (var i = 1; i < components.length; i++) {
        if (components[i - 1].offset + components[i - 1].duration >
            components[i].offset) {
          throw const FormatException('Turnos sobrepostos.');
        }
      }
      var index = max(
        0,
        first
                .toUtc()
                .subtract(const Duration(days: 1))
                .difference(anchor.toUtc())
                .inMilliseconds ~/
            period.inMilliseconds,
      );
      var start = anchor.toUtc().add(period * index);
      while (start.isBefore(end)) {
        final origin = tz.TZDateTime.from(start, zone);
        if (_active(allocation, origin)) {
          for (final component in components) {
            windows.add(
              ShiftWindow(
                tz.TZDateTime.from(
                  start.add(Duration(minutes: component.offset)),
                  zone,
                ),
                tz.TZDateTime.from(
                  start.add(
                    Duration(minutes: component.offset + component.duration),
                  ),
                  zone,
                ),
                component.pause,
              ),
            );
          }
        }
        start = anchor.toUtc().add(period * ++index);
      }
    } else {
      for (var day = -1; day < days; day++) {
        final date = tz.TZDateTime(
          zone,
          first.year,
          first.month,
          first.day + day,
        );
        if (!_active(allocation, date)) continue;
        for (final turn in scale.turnos) {
          if (!turn.diasSemana.contains(date.weekday)) continue;
          durationMinutes(turn);
          final crosses =
              turn.fimDiaSeguinte ||
              turn.horaFim.compareTo(turn.horaInicio) < 0;
          final start = _local(zone, date, turn.horaInicio);
          final finishDate = DateTime.utc(
            date.year,
            date.month,
            date.day + (crosses ? 1 : 0),
          );
          final finish = _local(zone, finishDate, turn.horaFim);
          windows.add(ShiftWindow(start, finish, turn.tempoIntervalo));
        }
      }
    }
    return List.generate(days, (i) {
      final start = tz.TZDateTime(zone, first.year, first.month, first.day + i);
      final finish = tz.TZDateTime(
        zone,
        first.year,
        first.month,
        first.day + i + 1,
      );
      return ScheduleDay(
        start,
        windows.where((w) => w.overlaps(start, finish)).toList()
          ..sort((a, b) => a.start.compareTo(b.start)),
      );
    });
  }

  static int durationMinutes(TurnoSyncDto turn) {
    int minutes(String time) {
      final parts = time.split(':').map(int.parse).toList();
      return parts[0] * 60 + parts[1];
    }

    var duration = minutes(turn.horaFim) - minutes(turn.horaInicio);
    if (duration < 0 || turn.fimDiaSeguinte) duration += 1440;
    if (duration <= 0 ||
        duration > 1440 ||
        turn.tempoIntervalo < 0 ||
        turn.tempoIntervalo >= duration ||
        (turn.fimDiaSeguinte && turn.horaFim.compareTo(turn.horaInicio) > 0)) {
      throw const FormatException('Duração de turno inválida.');
    }
    return duration;
  }

  bool _active(AlocacaoPessoalSyncDto allocation, tz.TZDateTime date) {
    final value =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return value.compareTo(allocation.dataInicio) >= 0 &&
        (allocation.dataFim == null ||
            value.compareTo(allocation.dataFim!) <= 0);
  }

  tz.TZDateTime _local(tz.Location zone, DateTime date, String time) {
    final parts = time.split(':').map(int.parse).toList();
    final result = tz.TZDateTime(
      zone,
      date.year,
      date.month,
      date.day,
      parts[0],
      parts[1],
    );
    if (result.day != date.day ||
        result.hour != parts[0] ||
        result.minute != parts[1]) {
      throw const FormatException('Horário inexistente no fuso da empresa.');
    }
    for (final delta in [-60, 60]) {
      final other = tz.TZDateTime.from(
        result.toUtc().add(Duration(minutes: delta)),
        zone,
      );
      if (other.day == result.day &&
          other.hour == result.hour &&
          other.minute == result.minute) {
        throw const FormatException('Horário ambíguo no fuso da empresa.');
      }
    }
    return result;
  }
}
