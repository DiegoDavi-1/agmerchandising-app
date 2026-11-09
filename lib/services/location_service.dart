import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';
import '../utils/app_logger.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  static const updateInterval = Duration(minutes: 1);
  final ValueNotifier<String> status =
      ValueNotifier('Localização compartilhada somente durante o atendimento.');
  StreamSubscription<Position>? _positions;
  Timer? _sessionTimer;
  int? _entryId;
  int _generation = 0;
  bool _syncing = false;
  bool _sending = false;
  DateTime? _lastAttempt;

  bool get isTracking => _positions != null;

  Future<void> synchronize() async {
    if (_syncing) return;
    if (!ApiService.isAuthenticated()) {
      await stopTracking();
      return;
    }
    _syncing = true;
    final generation = _generation;
    try {
      final session = await ApiService.fetchTrackingSession();
      if (generation != _generation) return;
      final visit = session['session'] as Map<String, dynamic>?;
      if (visit == null) {
        await stopTracking();
        return;
      }
      final entryId = (visit['id'] as num).toInt();
      if (entryId == _entryId && _positions != null) return;
      await stopTracking();
      final startGeneration = _generation;
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Ative o GPS para compartilhar a localização do atendimento.');
      }
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Permita a localização para compartilhar o ponto no mapa.');
      }
      if (startGeneration != _generation || !ApiService.isAuthenticated()) return;
      _entryId = entryId;
      _lastAttempt = null;
      final LocationSettings settings = Platform.isAndroid
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 0,
              intervalDuration: updateInterval,
              foregroundNotificationConfig: const ForegroundNotificationConfig(
                notificationTitle: 'Merch Hub — atendimento em andamento',
                notificationText:
                    'Localização compartilhada a cada minuto até o check-out.',
                notificationChannelName: 'Localização do atendimento',
                enableWakeLock: true,
                setOngoing: true,
              ),
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.high, distanceFilter: 0);
      status.value = 'Atendimento em andamento. Aguardando posição GPS.';
      _positions = Geolocator.getPositionStream(locationSettings: settings)
          .listen(_sendPosition, onError: (Object error) {
        AppLogger.error('Erro no GPS do atendimento', error);
        status.value = 'Falha no GPS. Reabra o app e verifique a localização.';
        unawaited(_cancelStream());
      });
      _sessionTimer = Timer.periodic(updateInterval, (_) => synchronize());
    } catch (error) {
      AppLogger.error('Erro ao iniciar rastreamento do atendimento', error);
      status.value = 'Não foi possível atualizar o rastreamento: $error';
    } finally {
      _syncing = false;
    }
  }

  Future<void> _sendPosition(Position position) async {
    final entryId = _entryId;
    if (entryId == null || _sending) return;
    final now = DateTime.now();
    if (_lastAttempt != null &&
        now.difference(_lastAttempt!) <
            updateInterval - const Duration(seconds: 1)) {
      return;
    }
    if (position.isMocked ||
        now.toUtc().difference(position.timestamp.toUtc()).abs() >
            const Duration(minutes: 2)) {
      status.value = 'Posição GPS antiga ou simulada. Aguardando uma posição válida.';
      return;
    }
    _sending = true;
    _lastAttempt = now;
    try {
      final result = await ApiService.sendTrackingLocation(
        clockEntryId: entryId,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        observedAt: position.timestamp,
        isMockLocation: position.isMocked,
      );
      if (result['tracking_stopped'] == true) {
        await stopTracking();
      } else if (_entryId == entryId) {
        status.value = 'Localização compartilhada durante o atendimento, a cada minuto.';
      }
    } catch (error) {
      AppLogger.error('Erro ao enviar localização do atendimento', error);
      status.value = 'Localização não enviada. Verifique GPS e internet: $error';
    } finally {
      _sending = false;
    }
  }

  Future<void> _cancelStream() async {
    final subscription = _positions;
    _positions = null;
    await subscription?.cancel();
  }

  Future<void> stopTracking() async {
    _generation++;
    _entryId = null;
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _lastAttempt = null;
    await _cancelStream();
    status.value = 'Sem atendimento aberto. Rastreamento desligado.';
  }
}
