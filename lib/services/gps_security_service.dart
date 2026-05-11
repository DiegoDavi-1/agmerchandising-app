import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

class GPSSecurityResult {
  final bool isSecure;
  final String statusMessage;
  final SecurityLevel level;
  final List<String> warnings;
  final Position? position;
  final bool isMockLocation;
  final double? accuracy;

  GPSSecurityResult({
    required this.isSecure,
    required this.statusMessage,
    required this.level,
    required this.warnings,
    this.position,
    this.isMockLocation = false,
    this.accuracy,
  });

  Color get statusColor {
    switch (level) {
      case SecurityLevel.high:
        return Colors.green;
      case SecurityLevel.medium:
        return Colors.orange;
      case SecurityLevel.low:
        return Colors.red;
      case SecurityLevel.critical:
        return Colors.red.shade900;
    }
  }

  IconData get statusIcon {
    switch (level) {
      case SecurityLevel.high:
        return Icons.verified_user;
      case SecurityLevel.medium:
        return Icons.warning_amber;
      case SecurityLevel.low:
        return Icons.error_outline;
      case SecurityLevel.critical:
        return Icons.block;
    }
  }
}

enum SecurityLevel {
  high,    // GPS confiável e preciso
  medium,  // GPS com precisão moderada
  low,     // GPS com problemas de precisão
  critical // GPS falso detectado ou indisponível
}

class GPSSecurityService {
  static const double _minAcceptableAccuracy = 50.0; // metros
  static const double _optimalAccuracy = 20.0; // metros
  static const double _maxReasonableSpeed = 150.0; // km/h (considerando veículos)
  
  /// Verifica a segurança e autenticidade do GPS
  static Future<GPSSecurityResult> verifyGPSSecurity() async {
    List<String> warnings = [];
    bool isMockLocation = false;
    SecurityLevel level = SecurityLevel.high;
    
    try {
      // 1. Verificar permissões
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        return GPSSecurityResult(
          isSecure: false,
          statusMessage: '🔒 Permissão de localização negada',
          level: SecurityLevel.critical,
          warnings: ['Permissão de GPS não concedida'],
        );
      }

      // 2. Verificar se o serviço de localização está ativo
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return GPSSecurityResult(
          isSecure: false,
          statusMessage: '📡 GPS desativado no dispositivo',
          level: SecurityLevel.critical,
          warnings: ['Serviço de localização desativado'],
        );
      }

      // 3. Obter posição com alta precisão
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // 4. DETECÇÃO DE MOCK LOCATION (GPS falso)
      // Nota: No Android, Position.isMocked indica se a localização é simulada
      // Infelizmente o Flutter não expõe diretamente, mas vamos usar a precisão
      // e outras métricas para detectar
      
      // 4.1 Verificar precisão suspeita (muito precisa = fake)
      if (position.accuracy < 1.0) {
        warnings.add('⚠️ Precisão suspeita (muito precisa)');
        isMockLocation = true;
        level = SecurityLevel.critical;
      }

      // 4.2 Verificar altitude suspeita
      if (position.altitude < -500 || position.altitude > 10000) {
        warnings.add('⚠️ Altitude fora do padrão');
        isMockLocation = true;
        level = SecurityLevel.critical;
      }

      // 4.3 Verificar velocidade anormal
      if (position.speed > _maxReasonableSpeed / 3.6) { // Converter km/h para m/s
        warnings.add('⚠️ Velocidade anormal detectada');
        level = level == SecurityLevel.high ? SecurityLevel.medium : level;
      }

      // 5. Análise de precisão do GPS
      if (position.accuracy > _minAcceptableAccuracy) {
        warnings.add('📍 Precisão baixa: ${position.accuracy.toStringAsFixed(0)}m');
        level = level == SecurityLevel.high ? SecurityLevel.low : level;
      } else if (position.accuracy > _optimalAccuracy) {
        warnings.add('📍 Precisão moderada: ${position.accuracy.toStringAsFixed(0)}m');
        level = level == SecurityLevel.high ? SecurityLevel.medium : level;
      }

      // 6. Verificar timestamp (localização muito antiga = suspeito)
      final locationAge = DateTime.now().difference(position.timestamp).inSeconds;
      if (locationAge > 60) {
        warnings.add('⏰ Localização desatualizada (${locationAge}s)');
        level = level == SecurityLevel.high ? SecurityLevel.medium : level;
      }

      // 7. Determinar se é seguro
      bool isSecure = !isMockLocation && 
                     position.accuracy <= _minAcceptableAccuracy &&
                     level != SecurityLevel.critical;

      // 8. Mensagem de status
      String statusMessage;
      if (isMockLocation) {
        statusMessage = '🚨 GPS FALSO DETECTADO!';
      } else if (level == SecurityLevel.high) {
        statusMessage = '✅ GPS Autêntico e Preciso (${position.accuracy.toStringAsFixed(0)}m)';
      } else if (level == SecurityLevel.medium) {
        statusMessage = '⚠️ GPS Funcional (${position.accuracy.toStringAsFixed(0)}m)';
      } else {
        statusMessage = '❌ GPS com Problemas (${position.accuracy.toStringAsFixed(0)}m)';
      }

      return GPSSecurityResult(
        isSecure: isSecure,
        statusMessage: statusMessage,
        level: level,
        warnings: warnings,
        position: position,
        isMockLocation: isMockLocation,
        accuracy: position.accuracy,
      );

    } catch (e) {
      return GPSSecurityResult(
        isSecure: false,
        statusMessage: '❌ Erro ao verificar GPS: $e',
        level: SecurityLevel.critical,
        warnings: ['Falha na verificação de segurança'],
      );
    }
  }

  /// Verifica continuamente o GPS (para monitoramento em tempo real)
  static Stream<GPSSecurityResult> monitorGPSSecurity() async* {
    while (true) {
      yield await verifyGPSSecurity();
      await Future.delayed(const Duration(seconds: 30));
    }
  }

  /// Valida se duas posições são consistentes (detecta teleporte)
  static bool validatePositionConsistency(
    Position oldPosition,
    Position newPosition,
    Duration timeDifference,
  ) {
    // Calcular distância entre posições
    final distance = Geolocator.distanceBetween(
      oldPosition.latitude,
      oldPosition.longitude,
      newPosition.latitude,
      newPosition.longitude,
    );

    // Calcular velocidade implícita
    final hours = timeDifference.inSeconds / 3600.0;
    final speedKmh = (distance / 1000.0) / hours;

    // Se a velocidade for impossível, é suspeito
    return speedKmh <= _maxReasonableSpeed * 2; // Margem de segurança
  }

  /// Gera relatório de segurança detalhado
  static String generateSecurityReport(GPSSecurityResult result) {
    StringBuffer report = StringBuffer();
    
    report.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    report.writeln('🔐 RELATÓRIO DE SEGURANÇA GPS');
    report.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    report.writeln();
    
    report.writeln('Status: ${result.statusMessage}');
    report.writeln('Nível de Segurança: ${_securityLevelToString(result.level)}');
    report.writeln('GPS Confiável: ${result.isSecure ? "SIM ✓" : "NÃO ✗"}');
    report.writeln();
    
    if (result.position != null) {
      final pos = result.position!;
      report.writeln('📍 DADOS DE LOCALIZAÇÃO:');
      report.writeln('  • Latitude: ${pos.latitude.toStringAsFixed(6)}');
      report.writeln('  • Longitude: ${pos.longitude.toStringAsFixed(6)}');
      report.writeln('  • Precisão: ${pos.accuracy.toStringAsFixed(1)} metros');
      report.writeln('  • Altitude: ${pos.altitude.toStringAsFixed(1)} metros');
      report.writeln('  • Velocidade: ${(pos.speed * 3.6).toStringAsFixed(1)} km/h');
      report.writeln('  • Timestamp: ${pos.timestamp}');
      report.writeln();
    }
    
    if (result.warnings.isNotEmpty) {
      report.writeln('⚠️ AVISOS:');
      for (var warning in result.warnings) {
        report.writeln('  • $warning');
      }
      report.writeln();
    }
    
    if (result.isMockLocation) {
      report.writeln('🚨 ALERTA CRÍTICO:');
      report.writeln('  GPS FALSO DETECTADO!');
      report.writeln('  O dispositivo está usando localização simulada.');
      report.writeln('  Esta ação pode ser uma tentativa de fraude.');
      report.writeln();
    }
    
    report.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    return report.toString();
  }

  static String _securityLevelToString(SecurityLevel level) {
    switch (level) {
      case SecurityLevel.high:
        return 'ALTA ✓✓✓';
      case SecurityLevel.medium:
        return 'MÉDIA ✓✓';
      case SecurityLevel.low:
        return 'BAIXA ✓';
      case SecurityLevel.critical:
        return 'CRÍTICA ✗';
    }
  }
}
