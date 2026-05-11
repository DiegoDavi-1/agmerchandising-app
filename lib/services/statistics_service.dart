import '../models/brand_data.dart';

class StatisticsService {
  static final StatisticsService _instance = StatisticsService._internal();
  factory StatisticsService() => _instance;
  StatisticsService._internal();

  /// Calcula total de horas trabalhadas hoje
  Duration getTodayWorkHours(Map<String, BrandData> brandsData) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    Duration total = Duration.zero;

    for (var brand in brandsData.values) {
      final todayEntries = brand.pontoEntradas
          .where((e) => e.dateTime.isAfter(todayStart) && e.dateTime.isBefore(todayEnd))
          .toList();

      DateTime? lastEntrada;
      for (var entry in todayEntries) {
        if (entry.type == 'Entrada') {
          lastEntrada = entry.dateTime;
        } else if (entry.type == 'Saída' && lastEntrada != null) {
          total += entry.dateTime.difference(lastEntrada);
          lastEntrada = null;
        }
      }
    }

    return total;
  }

  /// Calcula horas trabalhadas em um período
  Map<String, Duration> getWorkHoursByBrand(
    Map<String, BrandData> brandsData,
    DateTime start,
    DateTime end,
  ) {
    Map<String, Duration> result = {};

    for (var entry in brandsData.entries) {
      final brandName = entry.key;
      final brand = entry.value;

      final periodEntries = brand.pontoEntradas
          .where((e) => e.dateTime.isAfter(start) && e.dateTime.isBefore(end))
          .toList();

      Duration brandTotal = Duration.zero;
      DateTime? lastEntrada;

      for (var entry in periodEntries) {
        if (entry.type == 'Entrada') {
          lastEntrada = entry.dateTime;
        } else if (entry.type == 'Saída' && lastEntrada != null) {
          brandTotal += entry.dateTime.difference(lastEntrada);
          lastEntrada = null;
        }
      }

      result[brandName] = brandTotal;
    }

    return result;
  }

  /// Total de check-ins esta semana
  int getWeeklyCheckIns(Map<String, BrandData> brandsData) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);

    int total = 0;
    for (var brand in brandsData.values) {
      total += brand.pontoEntradas
          .where((e) => e.dateTime.isAfter(weekStartDate) && e.type == 'Entrada')
          .length;
    }

    return total;
  }

  /// Total de fotos capturadas
  int getTotalPhotos(Map<String, BrandData> brandsData) {
    int total = 0;
    for (var brand in brandsData.values) {
      total += brand.fotosComLocalizacao.length;
    }
    return total;
  }

  /// Horas trabalhadas por dia nos últimos 7 dias
  Map<DateTime, Duration> getLastWeekHours(Map<String, BrandData> brandsData) {
    final now = DateTime.now();
    Map<DateTime, Duration> result = {};

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      Duration dayTotal = Duration.zero;

      for (var brand in brandsData.values) {
        final dayEntries = brand.pontoEntradas
            .where((e) => e.dateTime.isAfter(dayStart) && e.dateTime.isBefore(dayEnd))
            .toList();

        DateTime? lastEntrada;
        for (var entry in dayEntries) {
          if (entry.type == 'Entrada') {
            lastEntrada = entry.dateTime;
          } else if (entry.type == 'Saída' && lastEntrada != null) {
            dayTotal += entry.dateTime.difference(lastEntrada);
            lastEntrada = null;
          }
        }
      }

      result[dayStart] = dayTotal;
    }

    return result;
  }

  /// Marca mais trabalhada
  String? getMostWorkedBrand(Map<String, BrandData> brandsData) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);

    final hours = getWorkHoursByBrand(brandsData, weekStartDate, now);
    if (hours.isEmpty) return null;

    return hours.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }
}
