import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../utils/app_logger.dart';

/// Serviço de rastreamento de localização - PREPARADO PARA SERVIDOR
/// Status: Desativado - Timer preparado mas não iniciado
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Timer? _locationTimer;
  bool _isTracking = false;

  // Configuração
  static const Duration updateInterval = Duration(minutes: 5);
  static const bool autoTrackingEnabled = false; // ⚠️ MANTER false ATÉ SERVIDOR ESTAR PRONTO

  /// Inicia rastreamento automático de localização
  void startTracking() {
    if (!autoTrackingEnabled || _isTracking) return;

    _isTracking = true;
    
    // Envia localização imediatamente
    _sendCurrentLocation();

    // Configura timer para enviar a cada 5 minutos
    _locationTimer = Timer.periodic(updateInterval, (_) {
      _sendCurrentLocation();
    });
  }

  /// Para rastreamento automático
  void stopTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
    _isTracking = false;
  }

  /// Envia localização atual para o servidor
  Future<void> _sendCurrentLocation() async {
    try {
      // Verifica permissões
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        return;
      }

      // Verifica se GPS está ativo
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      // Obtém posição
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Geocodifica
      String locationText = '';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(const Duration(seconds: 5));

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          List<String> parts = [];
          if (place.street?.isNotEmpty == true) parts.add(place.street!);
          if (place.subLocality?.isNotEmpty == true) parts.add(place.subLocality!);
          if (place.locality?.isNotEmpty == true) parts.add(place.locality!);
          locationText = parts.join(', ');
        }
      } catch (e) {
        locationText = 'Lat: ${position.latitude.toStringAsFixed(6)}, Long: ${position.longitude.toStringAsFixed(6)}';
      }

      // TODO: Enviar para servidor quando endpoint estiver pronto
      // await _api.sendLocationUpdate(...)

      AppLogger.info('Localização obtida: $locationText');
    } catch (e) {
      AppLogger.error('Erro ao enviar localização', e);
    }
  }

  /// Envia localização manualmente (pode ser usado para testes)
  Future<bool> sendLocationNow() async {
    try {
      await _sendCurrentLocation();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Verifica se o rastreamento está ativo
  bool get isTracking => _isTracking;
}
