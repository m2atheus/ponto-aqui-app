import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Contem somente o diagnostico sanitizado, nunca a resposta ou a sessao.
class ParsingDiagnostic {
  ParsingDiagnostic._({
    required this.source,
    required this.mode,
    required this.role,
    required this.exceptionText,
    required this.stackTrace,
  });

  final String source, mode, role, exceptionText;
  final StackTrace stackTrace;

  factory ParsingDiagnostic.capture({
    required String source,
    required Object error,
    required StackTrace stackTrace,
    required Object? payload,
    required String token,
    required String role,
  }) {
    final secrets = <String>{if (token.isNotEmpty) token};
    final sensitiveKey = RegExp(
      r'token|password|passwd|senha|authorization|secret|credential|api.?key',
      caseSensitive: false,
    );
    void collect(Object? value, {bool sensitive = false}) {
      if (value is Map) {
        for (final entry in value.entries) {
          collect(
            entry.value,
            sensitive: sensitive || sensitiveKey.hasMatch(entry.key.toString()),
          );
        }
      } else if (value is List) {
        for (final item in value) {
          collect(item, sensitive: sensitive);
        }
      } else if (sensitive && value != null && value.toString().isNotEmpty) {
        secrets.add(value.toString());
      }
    }

    collect(payload);
    final orderedSecrets = secrets.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    String redact(String text) {
      for (final secret in orderedSecrets) {
        text = text.replaceAll(secret, '[REDACTED]');
      }
      text = text.replaceAll(
        RegExp(r'Bearer\s+[^\s,;\x22\x27}]+', caseSensitive: false),
        'Bearer [REDACTED]',
      );
      text = text.replaceAll(
        RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
        '[REDACTED]',
      );
      return text.replaceAllMapped(
        RegExp(
          r'([\x22\x27]?(?:access_token|refresh_token|token|password|passwd|senha|authorization|client_secret|api_key)[\x22\x27]?\s*[:=]\s*)(?:\x22[^\x22]*\x22|\x27[^\x27]*\x27|[^\s,;}\]]+)',
          caseSensitive: false,
        ),
        (match) => '${match[1]}[REDACTED]',
      );
    }

    final rawMode = payload is Map ? payload['modo_operacao'] : null;
    // FormatException.toString() pode incluir toda a fonte JSON. Preservar a
    // mensagem completa e o offset, sem imprimir esse trecho do payload.
    final exception = error is FormatException
        ? 'FormatException: ${error.message}${error.offset == null ? '' : ' (offset ${error.offset}; fonte omitida)'}'
        : '${error.runtimeType}: $error';
    return ParsingDiagnostic._(
      source: {'api', 'cache'}.contains(source) ? source : 'desconhecida',
      mode: rawMode == 'PESSOAL' || rawMode == 'RELOGIO'
          ? rawMode as String
          : 'INVALIDO_OU_AUSENTE',
      role: {'FUNCIONARIO', 'USUARIO_SETOR', 'RH', 'SUPERADMIN'}.contains(role)
          ? role
          : 'INVALIDO',
      exceptionText: redact(exception),
      stackTrace: StackTrace.fromString(redact(stackTrace.toString())),
    );
  }

  String get message =>
      '[bootstrap.parse][$source] modo=$mode papel=$role\n$exceptionText';

  static void log(ParsingDiagnostic diagnostic) {
    developer.log(
      diagnostic.message,
      name: 'ponto_aqui.bootstrap',
      level: 1000,
      error: diagnostic.exceptionText,
      stackTrace: diagnostic.stackTrace,
    );
    if (kDebugMode) {
      debugPrint('${diagnostic.message}\n${diagnostic.stackTrace}');
    }
  }
}
