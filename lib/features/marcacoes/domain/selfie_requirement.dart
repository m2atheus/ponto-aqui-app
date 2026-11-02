import 'dart:math' as math;

import '../../../core/device/evidence_sensors.dart';
import '../../bootstrap/data/mobile_sync_dto.dart';

/// A avaliacao local decide apenas a captura da foto, nunca a aprovacao do ponto.
class SelfieRequirement {
  const SelfieRequirement(this.presence, this.reason);
  final String presence;
  final String? reason;
  bool get required => reason != null;

  String get message => switch (reason) {
    'fora_dos_locais' => 'Você está fora dos locais vinculados ao seu cadastro. Para registrar o ponto, tire uma selfie.',
    'localizacao_nao_confirmada' => 'Não foi possível confirmar sua presença em um local vinculado. Para registrar o ponto, tire uma selfie.',
    _ => 'Este local exige uma selfie para registrar o ponto.',
  };

  static SelfieRequirement evaluate({
    required PositionEvidence location,
    required Iterable<SetorSyncDto> workplaces,
    required bool alwaysRequired,
  }) {
    final presence = _presence(location, workplaces);
    return SelfieRequirement(presence, switch (presence) {
      'fora' => 'fora_dos_locais',
      'nao_confirmada' => 'localizacao_nao_confirmada',
      _ => alwaysRequired ? 'politica_do_setor' : null,
    });
  }

  static String _presence(
    PositionEvidence location,
    Iterable<SetorSyncDto> workplaces,
  ) {
    final position = location.position;
    if (position == null ||
        !{'capturada', 'baixa_precisao'}.contains(location.status)) {
      return 'nao_confirmada';
    }
    final latitude = position['latitude'];
    final longitude = position['longitude'];
    final accuracy = position['precisao_metros'];
    if (latitude is! num ||
        longitude is! num ||
        accuracy is! num ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        !accuracy.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180 ||
        accuracy < 0 ||
        accuracy > 100) {
      return 'nao_confirmada';
    }
    var hasWorkplace = false;
    var nearBoundary = false;
    for (final workplace in workplaces) {
      hasWorkplace = true;
      final distance = _distance(
        latitude.toDouble(),
        longitude.toDouble(),
        workplace.latitude,
        workplace.longitude,
      );
      // So dispensar a selfie quando a margem de precisao couber no local.
      if (distance + accuracy <= workplace.raioMetros) return 'dentro';
      if (distance - accuracy <= workplace.raioMetros) nearBoundary = true;
    }
    return !hasWorkplace || nearBoundary ? 'nao_confirmada' : 'fora';
  }

  static double _distance(double lat1, double lon1, double lat2, double lon2) {
    const radians = math.pi / 180;
    final deltaLat = (lat2 - lat1) * radians;
    final deltaLon = (lon2 - lon1) * radians;
    final a =
        math.pow(math.sin(deltaLat / 2), 2) +
        math.cos(lat1 * radians) *
            math.cos(lat2 * radians) *
            math.pow(math.sin(deltaLon / 2), 2);
    return 6371008.8 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
  }
}
