import 'dart:convert';

enum PunchType {
  entrada('Entrada', 'Entrada'),
  inicioIntervalo('InicioIntervalo', 'Início de intervalo'),
  fimIntervalo('FimIntervalo', 'Fim de intervalo'),
  saida('Saida', 'Saída');

  const PunchType(this.wire, this.label);
  final String wire, label;
}

class PunchEvent {
  PunchEvent({
    required Map<String, dynamic> payload,
    required Map<String, dynamic> metadata,
    required this.capturedMs,
    this.photoPath,
    this.photoSha,
  }) : payloadJson = jsonEncode(payload),
       metadataJson = jsonEncode(metadata);
  final String payloadJson, metadataJson;
  final int capturedMs;
  final String? photoPath, photoSha;
  String get id =>
      (jsonDecode(payloadJson) as Map<String, dynamic>)['evento_cliente_id']
          as String;
}
