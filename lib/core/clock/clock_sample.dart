import 'package:timezone/timezone.dart' as tz;

import '../config/app_config.dart';

class ClockSample {
  const ClockSample({
    required this.offsetMs,
    required this.receivedAt,
    required this.roundTripMs,
  });
  final int offsetMs, roundTripMs;
  final DateTime receivedAt;
  int get driftSeconds => offsetMs ~/ 1000;
  DateTime estimate(DateTime deviceUtc) =>
      deviceUtc.toUtc().add(Duration(milliseconds: offsetMs));
  Duration age(DateTime deviceUtc) => deviceUtc.toUtc().difference(receivedAt);
  bool usable(DateTime deviceUtc) =>
      !age(deviceUtc).isNegative && age(deviceUtc) <= AppConfig.maxClockAge;

  static String civilDate(DateTime instant, String zone) {
    final date = tz.TZDateTime.from(instant, tz.getLocation(zone));
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
