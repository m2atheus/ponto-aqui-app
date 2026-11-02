import '../../../core/clock/clock_sample.dart';
import '../../bootstrap/data/mobile_sync_dto.dart';

bool coherentReceipt(
  Map<String, dynamic> result,
  Map<String, dynamic> evidence,
  int index,
) {
  try {
    final status = result['http_status'];
    final situation = result['situacao'];
    final reasons = result['motivos'];
    final distance = result['distancia_centro_metros'];
    final original = DateTime.parse(evidence['ocorrido_em'] as String);
    final offsetText = evidence['ocorrido_em'] as String;
    final suffix = RegExp(r'([+-])(\d{2}):(\d{2})$').firstMatch(offsetText);
    final offsetMinutes = suffix == null
        ? 0
        : (int.parse(suffix[2]!) * 60 + int.parse(suffix[3]!)) *
              (suffix[1] == '-' ? -1 : 1);
    return result['indice'] == index &&
        result['evento_cliente_id'] == evidence['evento_cliente_id'] &&
        result['persistida'] == true &&
        ((status == 201 && result['duplicada'] == false) ||
            (status == 200 && result['duplicada'] == true)) &&
        result['registro_id'] is String &&
        RegExp(r'^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$')
            .hasMatch(result['registro_id'] as String) &&
        ['Aceita', 'PendenteAnalise', 'Recusada'].contains(situation) &&
        reasons is List &&
        reasons.every((v) => v is String && v.isNotEmpty) &&
        ((situation == 'Aceita' && reasons.isEmpty) ||
            (situation != 'Aceita' && reasons.isNotEmpty)) &&
        result['desvio_relogio_segundos'] ==
            evidence['desvio_relogio_segundos'] &&
        result['registrado_offline'] == evidence['registrado_offline'] &&
        result['offset_original_minutos'] == offsetMinutes &&
        parseTimestampUtc(result['ocorrido_em']).isAtSameMomentAs(original) &&
        parseTimestampUtc(result['recebido_em']).isUtc &&
        (distance == null ||
            (distance is num && distance.isFinite && distance >= 0));
  } catch (_) {
    return false;
  }
}

// Deliberately the same sign as clockOffsetMs; no timezone conversion here.
int signedDriftSeconds(int offsetMs) => ClockSample(
  offsetMs: offsetMs,
  receivedAt: DateTime.utc(2000),
  roundTripMs: 0,
).driftSeconds;
