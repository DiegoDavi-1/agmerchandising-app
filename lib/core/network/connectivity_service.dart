import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../logging/app_logger_v2.dart';

/// Estado de conectividade
enum ConnectivityStatus {
  online,
  offline,
  unknown,
}

/// Provider de conectividade
final connectivityProvider = StreamProvider<ConnectivityStatus>((ref) {
  return Connectivity().onConnectivityChanged.map((results) {
    // results é uma lista de ConnectivityResult
    if (results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet)) {
      appLogger.info('Conectividade: Online');
      return ConnectivityStatus.online;
    } else if (results.contains(ConnectivityResult.none)) {
      appLogger.warning('Conectividade: Offline');
      return ConnectivityStatus.offline;
    } else {
      return ConnectivityStatus.unknown;
    }
  });
});

/// Service para verificar conectividade
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final _connectivity = Connectivity();

  /// Verifica se está online
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);
  }

  /// Verifica se está em Wi-Fi
  Future<bool> isWifi() async {
    final results = await _connectivity.checkConnectivity();
    return results.contains(ConnectivityResult.wifi);
  }

  /// Stream de mudanças de conectividade
  Stream<ConnectivityStatus> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map((results) {
      if (results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet)) {
        return ConnectivityStatus.online;
      } else if (results.contains(ConnectivityResult.none)) {
        return ConnectivityStatus.offline;
      } else {
        return ConnectivityStatus.unknown;
      }
    });
  }
}
