import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

/// Serviço para gerenciar agenda semanal de marcas
class ScheduleService {
  /// Buscar marcas agendadas para o dia de hoje
  static Future<Map<String, dynamic>> getBrandsToday() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/brands/today'),
        headers: ApiService.getHeaders(),
      );

      if (response.statusCode == 401) {
        await ApiService.checkTokenExpired(401);
        return getBrandsToday(); // Retry após refresh
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': data['success'] ?? false,
          'brands': List<Map<String, dynamic>>.from(data['brands'] ?? []),
          'today': data['today'] ?? DateTime.now().weekday % 7,
          'day_name': data['day_name'] ?? _getDayName(DateTime.now().weekday),
        };
      }

      throw Exception('Erro ao buscar marcas do dia: ${response.statusCode}');
    } catch (e) {
      print('❌ Erro getBrandsToday: $e');
      rethrow;
    }
  }

  /// Buscar todas as marcas (com informação de agendamento)
  static Future<List<Map<String, dynamic>>> getAllBrands() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/brands'),
        headers: ApiService.getHeaders(),
      );

      if (response.statusCode == 401) {
        await ApiService.checkTokenExpired(401);
        return getAllBrands();
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      }

      throw Exception('Erro ao buscar marcas: ${response.statusCode}');
    } catch (e) {
      print('❌ Erro getAllBrands: $e');
      rethrow;
    }
  }

  /// Verificar se marca está agendada para hoje
  static bool isBrandScheduledToday(Map<String, dynamic> brand) {
    final scheduledDays = brand['scheduled_days'];
    
    // null ou array vazio = todos os dias
    if (scheduledDays == null || 
        (scheduledDays is List && scheduledDays.isEmpty)) {
      return true;
    }

    if (scheduledDays is List) {
      final today = DateTime.now().weekday % 7; // Converter para 0=Domingo
      return scheduledDays.contains(today);
    }

    return true;
  }

  /// Verificar se marca foi concluída hoje
  static bool isBrandCompletedToday(Map<String, dynamic> brand) {
    return brand['is_completed_today'] == true || 
           brand['completed_today'] == 1;
  }

  /// Obter nome do dia da semana
  static String _getDayName(int weekday) {
    final days = [
      'Domingo',
      'Segunda-feira',
      'Terça-feira',
      'Quarta-feira',
      'Quinta-feira',
      'Sexta-feira',
      'Sábado'
    ];
    return days[weekday % 7];
  }

  /// Obter nome curto do dia
  static String getDayShortName(int day) {
    final days = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    return days[day % 7];
  }

  /// Obter emoji do dia
  static String getDayEmoji(int day) {
    final emojis = ['☀️', '💼', '📅', '🎯', '⚡', '🎉', '🌙'];
    return emojis[day % 7];
  }

  /// Formatar lista de dias agendados
  static String formatScheduledDays(List<dynamic>? scheduledDays) {
    if (scheduledDays == null || scheduledDays.isEmpty) {
      return 'Todos os dias';
    }

    final dayNames = scheduledDays
        .map((day) => getDayShortName(day as int))
        .join(', ');
    
    return dayNames;
  }
}
