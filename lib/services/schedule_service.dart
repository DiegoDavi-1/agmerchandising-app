import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

/// Serviço para gerenciar agenda semanal de marcas
class ScheduleService {
  /// Busca os atendimentos programados por dia na semana atual.
  static Future<Map<String, dynamic>> getWeekSchedule() async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}/schedule/week'),
      headers: ApiService.getHeaders(),
    );
    if (response.statusCode == 401) {
      await ApiService.checkTokenExpired(401);
      return getWeekSchedule();
    }
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Não foi possível carregar a agenda semanal.');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Buscar visão de agenda das marcas (hoje e amanhã)
  static Future<Map<String, dynamic>> getBrandsScheduleOverview() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/brands/schedule-overview'),
        headers: ApiService.getHeaders(),
      );

      if (response.statusCode == 401) {
        await ApiService.checkTokenExpired(401);
        return getBrandsScheduleOverview();
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'success': data['success'] ?? false,
          'today': data['today'] ?? DateTime.now().weekday % 7,
          'tomorrow': data['tomorrow'] ?? ((DateTime.now().weekday % 7) + 1) % 7,
          'today_name': data['today_name'] ?? _getDayName(DateTime.now().weekday % 7),
          'tomorrow_name': data['tomorrow_name'] ?? _getDayName(((DateTime.now().weekday % 7) + 1) % 7),
          'brands': List<Map<String, dynamic>>.from(data['brands'] ?? []),
        };
      }

      // Fallback para servidores que ainda não têm a rota de overview.
      if (response.statusCode == 404) {
        return _buildFallbackOverview();
      }

      Map<String, dynamic>? body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      } catch (_) {}
      final code = body?['code'];
      final message = body?['error'] ?? body?['message'];
      throw Exception(
        'Erro ao buscar overview da agenda: ${message ?? response.statusCode}'
        '${code != null ? ' [$code]' : ''}',
      );
    } catch (e) {
      // Se o erro vier da rota nova indisponível, tenta fallback também.
      final message = e.toString();
      if (message.contains('404')) {
        return _buildFallbackOverview();
      }
      print('❌ Erro getBrandsScheduleOverview: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> _buildFallbackOverview() async {
    final todayResult = await getBrandsToday();
    final allBrands = await getAllBrands();
    final todayBrands = List<Map<String, dynamic>>.from(todayResult['brands'] ?? []);

    final todayIds = todayBrands
        .map((b) => b['id'])
        .where((id) => id != null)
        .toSet();

    final merged = allBrands.map((brand) {
      final id = brand['id'];
      final scheduledToday = todayIds.contains(id);
      return {
        ...brand,
        // Sem endpoint novo, não temos dados completos de amanhã/loja.
        'assigned_store_id': null,
        'can_collect_today': scheduledToday,
        'scheduled_for_tomorrow': false,
        'tomorrow_assignment': null,
        'store_assignments': const [],
      };
    }).toList();

    return {
      'success': true,
      'today': todayResult['today'] ?? DateTime.now().weekday % 7,
      'tomorrow': ((todayResult['today'] ?? DateTime.now().weekday % 7) + 1) % 7,
      'today_name': todayResult['day_name'] ?? _getDayName(DateTime.now().weekday % 7),
      'tomorrow_name': _getDayName(((todayResult['today'] ?? DateTime.now().weekday % 7) + 1) % 7),
      'brands': merged,
    };
  }

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

      Map<String, dynamic>? body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      } catch (_) {}
      final code = body?['code'];
      final message = body?['error'] ?? body?['message'];
      throw Exception(
        'Erro ao buscar marcas do dia: ${message ?? response.statusCode}'
        '${code != null ? ' [$code]' : ''}',
      );
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

      Map<String, dynamic>? body;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      } catch (_) {}
      final code = body?['code'];
      final message = body?['error'] ?? body?['message'];
      throw Exception(
        'Erro ao buscar marcas: ${message ?? response.statusCode}'
        '${code != null ? ' [$code]' : ''}',
      );
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
