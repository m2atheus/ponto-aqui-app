import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig(String baseUrl, {bool allowDevelopmentHttp = false}) {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        (uri.scheme != 'https' &&
            !(uri.scheme == 'http' && allowDevelopmentHttp && !kReleaseMode))) {
      throw const FormatException(
        'Configure API_BASE_URL com a origem HTTPS do Flask. '
        'HTTP exige ALLOW_DEV_HTTP=true em desenvolvimento.',
      );
    }
    origin = uri.origin;
  }

  late final String origin;

  factory AppConfig.environment() => AppConfig(
    const String.fromEnvironment('API_BASE_URL'),
    allowDevelopmentHttp: const bool.fromEnvironment('ALLOW_DEV_HTTP'),
  );

  static const maxClockAge = Duration(hours: 24);
  static const batchSize = 50;
  static const cyclesPerRun = 3;
}
