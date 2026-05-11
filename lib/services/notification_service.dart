import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Callback quando o usuário toca na notificação
      },
    );

    // Solicitar permissões (Android 13+)
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Solicitar permissões no iOS
    await _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    _initialized = true;
  }

  Future<void> showValidadeProximaNotification({
    required String produto,
    required int diasRestantes,
    required DateTime dataValidade,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'validades_channel',
      'Validades',
      channelDescription: 'Notificações de validades próximas',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    String title;
    String body;

    if (diasRestantes < 0) {
      title = '⚠️ Produto Vencido!';
      body = '$produto venceu há ${diasRestantes.abs()} dia(s)';
    } else if (diasRestantes == 0) {
      title = '🔴 Vence Hoje!';
      body = '$produto vence hoje';
    } else if (diasRestantes <= 3) {
      title = '🔴 Validade Crítica!';
      body = '$produto vence em $diasRestantes dia(s)';
    } else if (diasRestantes <= 7) {
      title = '🟠 Atenção: Validade Próxima';
      body = '$produto vence em $diasRestantes dia(s)';
    } else if (diasRestantes <= 30) {
      title = '🟡 Validade em Breve';
      body = '$produto vence em $diasRestantes dia(s) - ${DateFormat('dd/MM/yyyy').format(dataValidade)}';
    } else {
      return; // Não notifica se ainda tem mais de 30 dias
    }

    await _notifications.show(
      produto.hashCode, // ID único baseado no produto
      title,
      body,
      notificationDetails,
    );
  }

  Future<void> checkAndNotifyValidades(List<dynamic> validades) async {
    final now = DateTime.now();
    final hoje = DateTime(now.year, now.month, now.day);

    for (var item in validades) {
      final dataValidade = DateTime.parse(item['dataValidade']);
      final validadeDate = DateTime(dataValidade.year, dataValidade.month, dataValidade.day);
      final diasRestantes = validadeDate.difference(hoje).inDays;

      // Notifica se vencido, vence hoje, ou vence em até 7 dias
      if (diasRestantes <= 7) {
        await showValidadeProximaNotification(
          produto: item['produto'],
          diasRestantes: diasRestantes,
          dataValidade: dataValidade,
        );
      }
    }
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
