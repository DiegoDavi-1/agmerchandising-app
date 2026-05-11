import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/statistics_service.dart';
import '../models/brand_data.dart';

class DashboardPage extends StatefulWidget {
  final Map<String, BrandData> brandsData;

  const DashboardPage({super.key, required this.brandsData});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _stats = StatisticsService();
  late bool isDark;

  @override
  Widget build(BuildContext context) {
    isDark = Theme.of(context).brightness == Brightness.dark;
    final todayHours = _stats.getTodayWorkHours(widget.brandsData);
    final weeklyCheckIns = _stats.getWeeklyCheckIns(widget.brandsData);
    final totalPhotos = _stats.getTotalPhotos(widget.brandsData);
    final mostWorkedBrand = _stats.getMostWorkedBrand(widget.brandsData);
    final lastWeekData = _stats.getLastWeekHours(widget.brandsData);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1419) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A1F2E) : const Color(0xFF1E88E5),
        elevation: 8,
        shadowColor: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.blue.withValues(alpha: 0.4),
        title: Text(
          'Dashboard',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Estatísticas resumidas
            Text(
              'Resumo de Hoje',
              style: GoogleFonts.poppins(
                color: isDark ? Colors.white : Colors.grey[800],
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Cards de estatísticas
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.access_time,
                    title: 'Horas Hoje',
                    value: _formatDuration(todayHours),
                    color: const Color(0xFF1E88E5),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.check_circle,
                    title: 'Check-ins',
                    value: '$weeklyCheckIns',
                    subtitle: 'Esta semana',
                    color: const Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.photo_camera,
                    title: 'Fotos',
                    value: '$totalPhotos',
                    subtitle: 'Total',
                    color: const Color(0xFFFF9800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.trending_up,
                    title: 'Mais Trabalhada',
                    value: mostWorkedBrand ?? 'N/A',
                    subtitle: 'Esta semana',
                    color: const Color(0xFF2196F3),
                    smallText: true,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Gráfico de horas
            Text(
              'Últimos 7 Dias',
              style: GoogleFonts.poppins(
                color: isDark ? Colors.white : Colors.grey[800],
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            Container(
              height: 250,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1F2E) : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: _buildWeekChart(lastWeekData),
            ),
            
            const SizedBox(height: 32),
            
            // Horas por marca
            Text(
              'Horas por Marca (Esta Semana)',
              style: GoogleFonts.poppins(
                color: isDark ? Colors.white : Colors.grey[800],
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            ..._buildBrandHoursList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
    required Color color,
    bool smallText = false,
  }) {
    return Container(
      height: 140, // Altura aumentada para evitar overflow
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: isDark ? Colors.white70 : Colors.grey[600],
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                color: isDark ? Colors.white : Colors.black,
                fontSize: smallText ? 14 : 22,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                color: isDark ? Colors.white60 : Colors.grey[600],
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeekChart(Map<DateTime, Duration> data) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          'Sem dados para exibir',
          style: GoogleFonts.poppins(color: isDark ? Colors.white70 : Colors.grey[600]),
        ),
      );
    }

    final spots = data.entries.map((e) {
      final index = data.keys.toList().indexOf(e.key);
      final hours = e.value.inMinutes / 60.0;
      return FlSpot(index.toDouble(), hours);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (value) => FlLine(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}h',
                style: GoogleFonts.poppins(
                  color: isDark ? Colors.white70 : Colors.grey[600],
                  fontSize: 10,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= data.length) return const SizedBox();
                final date = data.keys.toList()[value.toInt()];
                return Text(
                  DateFormat('E', 'pt_BR').format(date),
                  style: GoogleFonts.poppins(
                    color: isDark ? Colors.white70 : Colors.grey[600],
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF1E88E5),
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF1E88E5).withValues(alpha: 0.2),
            ),
          ),
        ],
        minY: 0,
      ),
    );
  }

  List<Widget> _buildBrandHoursList() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
    
    final brandHours = _stats.getWorkHoursByBrand(
      widget.brandsData,
      weekStartDate,
      now,
    );

    if (brandHours.isEmpty) {
      return [
        Center(
          child: Text(
            'Nenhum registro esta semana',
            style: GoogleFonts.poppins(color: isDark ? Colors.white70 : Colors.grey[600]),
          ),
        ),
      ];
    }

    final sorted = brandHours.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.map((entry) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                entry.key,
                style: GoogleFonts.poppins(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              _formatDuration(entry.value),
              style: GoogleFonts.poppins(
                color: const Color(0xFF1E88E5),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    return '${minutes}min';
  }
}
