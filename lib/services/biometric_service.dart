import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/app_logger.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _auth = LocalAuthentication();
  final _storage = const FlutterSecureStorage();

  /// Verifica se o dispositivo suporta biometria
  Future<bool> canCheckBiometrics() async {
    try {
      final canAuth = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canAuth || isDeviceSupported;
    } catch (e) {
      AppLogger.error('Erro ao verificar biometria', e);
      return false;
    }
  }

  /// Lista biometrias disponíveis
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      AppLogger.error('Erro ao listar biometrias', e);
      return [];
    }
  }

  /// Autentica com biometria
  Future<bool> authenticate({
    String reason = 'Autentique para continuar',
  }) async {
    try {
      final canAuth = await canCheckBiometrics();
      if (!canAuth) {
        AppLogger.info('Biometria não disponível no dispositivo');
        return false;
      }

      return await _auth.authenticate(
        localizedReason: reason,
      );
    } catch (e) {
      AppLogger.error('Erro na autenticação biométrica', e);
      return false;
    }
  }

  /// Verifica se biometria está habilitada no app
  Future<bool> isBiometricEnabled() async {
    final enabled = await _storage.read(key: 'biometric_enabled');
    return enabled == 'true';
  }

  /// Habilita/desabilita biometria no app
  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: 'biometric_enabled',
      value: enabled ? 'true' : 'false',
    );
  }

  /// Autentica se biometria estiver habilitada
  Future<bool> authenticateIfEnabled({
    String reason = 'Autentique para continuar',
  }) async {
    final enabled = await isBiometricEnabled();
    if (!enabled) return true;

    return await authenticate(reason: reason);
  }
}
