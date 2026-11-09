import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../core/logging/app_logger_v2.dart';
import 'api_service.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> handleBackgroundPush(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushService {
  static final PushService instance = PushService._();
  PushService._();

  static const _storage = FlutterSecureStorage();
  Future<void> _operations = Future.value();
  bool _ready = false;
  bool _pendingTap = false;
  void Function()? onMessageTap;

  Future<void> initialize() async {
    if (!Platform.isAndroid || _ready) return;
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(handleBackgroundPush);
    FirebaseMessaging.instance.onTokenRefresh.listen((_) => synchronize(),
        onError: (Object error) {
      appLogger.error('Erro ao renovar token push', error: error);
    });
    FirebaseMessaging.onMessage.listen((message) {
      if (!ApiService.isAuthenticated()) return;
      unawaited(_showForeground(message));
    });
    FirebaseMessaging.onMessageOpenedApp.listen((_) => openMessages());
    _ready = true;
    if (await FirebaseMessaging.instance.getInitialMessage() != null) {
      _pendingTap = true;
    }
    await synchronize();
  }

  Future<void> _showForeground(RemoteMessage message) async {
    try {
      await NotificationService().showMessageNotification(
        id: int.tryParse(message.data['reminder_id'] ?? '') ?? 7002,
        title: message.notification?.title ?? 'Merch Hub',
        body: message.notification?.body ?? 'Você tem uma nova mensagem.',
      );
    } catch (error, stackTrace) {
      appLogger.error('Erro ao mostrar push',
          error: error, stackTrace: stackTrace);
    }
  }

  void openMessages() {
    _pendingTap = true;
    consumeMessageTap();
  }

  void consumeMessageTap() {
    if (_pendingTap && ApiService.isAuthenticated() && onMessageTap != null) {
      _pendingTap = false;
      onMessageTap!();
    }
  }

  Future<String> _installationId() async {
    final saved = await _storage.read(key: 'push_installation_id');
    if (saved != null) return saved;
    final random = Random.secure();
    final chars =
        List.generate(32, (_) => random.nextInt(16).toRadixString(16));
    chars[12] = '4';
    chars[16] = (8 + random.nextInt(4)).toRadixString(16);
    final hex = chars.join();
    final id = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    await _storage.write(key: 'push_installation_id', value: id);
    return id;
  }

  Future<void> _serialized(Future<void> Function() operation) {
    _operations = _operations
        .then((_) => operation())
        .catchError((Object error, StackTrace stackTrace) {
      appLogger.error('Falha na sincronização de push',
          error: error, stackTrace: stackTrace);
    });
    return _operations;
  }

  Future<void> synchronize() => _serialized(() async {
        if (!_ready || !ApiService.isAuthenticated()) return;
        final permission = await FirebaseMessaging.instance.requestPermission();
        final id = await _installationId();
        if (permission.authorizationStatus != AuthorizationStatus.authorized &&
            permission.authorizationStatus != AuthorizationStatus.provisional) {
          await FirebaseMessaging.instance.setAutoInitEnabled(false);
          await _disableDevice(id);
          appLogger.warning('Notificações push sem permissão no celular.');
          return;
        }
        await FirebaseMessaging.instance.setAutoInitEnabled(true);
        final token = await FirebaseMessaging.instance
            .getToken()
            .timeout(const Duration(seconds: 15));
        if (token == null) {
          throw StateError('Firebase não forneceu token push.');
        }
        final response = await http
            .post(Uri.parse('${ApiService.baseUrl}/app/push-device'),
                headers: ApiService.getHeaders(),
                body: jsonEncode({'installationId': id, 'token': token}))
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 403) {
          appLogger.info('Registro push não disponível para este perfil.');
          return;
        }
        if (response.statusCode != 200) {
          throw StateError(
              'Registro push falhou: HTTP ${response.statusCode}.');
        }
      });

  Future<void> _disableDevice(String id) async {
    final response = await http
        .delete(Uri.parse('${ApiService.baseUrl}/app/push-device/$id'),
            headers: ApiService.getHeaders())
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200 && response.statusCode != 401) {
      throw StateError('Desvincular push falhou: HTTP ${response.statusCode}.');
    }
  }

  Future<void> unregister() => _serialized(() async {
        if (!_ready) return;
        _pendingTap = false;
        await FirebaseMessaging.instance.setAutoInitEnabled(false);
        // Invalidate the provider token even if unlinking the server is offline.
        try {
          await FirebaseMessaging.instance
              .deleteToken()
              .timeout(const Duration(seconds: 10));
        } finally {
          await _disableDevice(await _installationId());
          await NotificationService().cancelAllNotifications();
        }
      });
}
