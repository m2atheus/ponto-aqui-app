import 'package:connectivity_plus/connectivity_plus.dart';

abstract interface class ConnectionMonitor {
  Future<bool> isOffline();
  Stream<bool> get changes;
}

class PlatformConnectionMonitor implements ConnectionMonitor {
  final Connectivity _connectivity = Connectivity();
  bool _offline(List<ConnectivityResult> signals) =>
      signals.every((s) => s == ConnectivityResult.none);
  @override
  Future<bool> isOffline() async =>
      _offline(await _connectivity.checkConnectivity());
  @override
  Stream<bool> get changes =>
      _connectivity.onConnectivityChanged.map(_offline).distinct();
}
