import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../../core/device/evidence_sensors.dart';
import '../../../core/errors/app_failure.dart';
import '../../auth/domain/mobile_session.dart';
import '../../bootstrap/domain/bootstrap_snapshot.dart';
import '../data/outbox_repository.dart';
import 'punch_event.dart';
import 'selfie_requirement.dart';

class CapturePunch {
  CapturePunch(
    this.outbox,
    this.sensors,
    this.photoDirectory, {
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;
  final OutboxRepository outbox;
  final EvidenceSensors sensors;
  final Directory photoDirectory;
  final DateTime Function() now;
  bool _busy = false;

  Future<String> call({
    required MobileSession session,
    required BootstrapSnapshot snapshot,
    required String allocationId,
    required PunchType type,
    required bool offlineSignal,
    required bool Function() authorized,
    Future<bool> Function(String message)? confirmSelfie,
  }) async {
    if (_busy) throw const AppFailure('Aguarde a captura atual.');
    _busy = true;
    File? photo;
    var saved = false;
    try {
      void validate() {
        if (!session.canSend || !authorized()) {
          throw const AppFailure(
            'A sessão mudou. Entre novamente antes de registrar.',
          );
        }
        final restriction = snapshot.captureRestriction(now().toUtc());
        if (restriction != null) throw AppFailure(restriction);
      }

      validate();
      final allocations = snapshot.data.alocacoes
          .where((a) => a.id == allocationId)
          .toList();
      if (allocations.length != 1) {
        throw const AppFailure('Selecione uma alocação válida.');
      }
      final allocation = allocations.single;
      final policy = allocation.setor.politicas;
      final eventId = const Uuid().v4();
      // GPS tambem e necessario quando o setor dispensa geofencing no servidor:
      // sem ele nao podemos dispensar a selfie por presenca em local vinculado.
      final location = await sensors.location(ignored: false);
      validate();
      final selfie = SelfieRequirement.evaluate(
        location: location,
        workplaces: snapshot.data.alocacoes
            .where(
              (a) =>
                  a.dataInicio.compareTo(snapshot.data.dataReferencia) <= 0 &&
                  (a.dataFim == null ||
                      a.dataFim!.compareTo(snapshot.data.dataReferencia) >= 0),
            )
            .map((a) => a.setor),
        alwaysRequired: policy.exigeSelfie,
      );
      String? digest;
      if (selfie.required) {
        if (confirmSelfie != null && !await confirmSelfie(selfie.message)) {
          throw const AppFailure('Captura cancelada. O ponto não foi salvo.');
        }
        validate();
        final bytes = await sensors.selfie();
        if (bytes.isEmpty) {
          throw const AppFailure(
            'A selfie não foi capturada. Tente novamente.',
          );
        }
        final directory = Directory(
          '${photoDirectory.path}/${sha256.convert(session.scope.codeUnits)}',
        );
        await directory.create(recursive: true);
        final temporary = File('${directory.path}/$eventId.part');
        await temporary.writeAsBytes(bytes, flush: true);
        photo = await temporary.rename('${directory.path}/$eventId.jpg');
        digest = sha256.convert(bytes).toString();
      }
      validate();
      final captured = now();
      final date = snapshot.clock.estimate(captured);
      // Allocation dates are civil dates from the company, not phone dates.
      final reference = snapshot.data.dataReferencia;
      if (reference.compareTo(allocation.dataInicio) < 0 ||
          (allocation.dataFim != null &&
              reference.compareTo(allocation.dataFim!) > 0)) {
        throw const AppFailure(
          'A alocação não está vigente. Atualize seus dados.',
        );
      }
      final offset = captured.timeZoneOffset;
      final minutes = offset.inMinutes.abs();
      final zone = captured.isUtc
          ? 'Z'
          : '${offset.isNegative ? '-' : '+'}${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
      final occurred = captured.isUtc
          ? captured.toIso8601String()
          : '${captured.toIso8601String()}$zone';
      final event = PunchEvent(
        payload: {
          'evento_cliente_id': eventId,
          'dispositivo_id': session.deviceId,
          'alocacao_id': allocation.id,
          'tipo': type.wire,
          'ocorrido_em': occurred,
          'desvio_relogio_segundos': snapshot.clock.driftSeconds,
          'registrado_offline': offlineSignal,
          'posicao': location.position,
        },
        metadata: {
          'localizacao_status': location.status,
          'presenca_local_vinculado': selfie.presence,
          'selfie_obrigatoria': selfie.required,
          'selfie_motivo': selfie.reason,
          'clock_offset_ms': snapshot.clock.offsetMs,
          'clock_sample_received_at': snapshot.clock.receivedAt
              .toIso8601String(),
          'clock_sample_age_ms': snapshot.clock.age(captured).inMilliseconds,
          'clock_round_trip_ms': snapshot.clock.roundTripMs,
          'estimated_server_utc': date.toUtc().toIso8601String(),
          'bootstrap_reference': reference,
          'connectivity_is_only_a_signal': true,
        },
        capturedMs: captured.millisecondsSinceEpoch,
        photoPath: photo?.path,
        photoSha: digest,
      );
      await outbox.save(session.scope, event);
      saved = true;
      return location.status;
    } finally {
      _busy = false;
      if (!saved && photo != null && await photo.exists()) await photo.delete();
    }
  }
}
