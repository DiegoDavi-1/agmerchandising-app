import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/schedule_service.dart';
import 'dynamic_brand_collection_page.dart';
import 'store_brands_page.dart';
import 'week_schedule_page.dart';

/// Contagem de atendimentos concluídos/previstos de um dia da agenda.
class DayProgress {
  final String name;
  final String date;
  final bool isToday;
  final int done;
  final int total;

  const DayProgress({
    required this.name,
    required this.date,
    required this.isToday,
    required this.done,
    required this.total,
  });

  int get pending => total - done;
  double get ratio => total == 0 ? 0 : done / total;

  static DayProgress fromJson(Map<String, dynamic> day) {
    final assignments = List<Map<String, dynamic>>.from(
        day['assignments'] as List? ?? const []);
    return DayProgress(
      name: (day['name'] ?? '').toString(),
      date: (day['date'] ?? '').toString(),
      isToday: day['is_today'] == true,
      done: assignments.where((a) => a['is_completed'] == true).length,
      total: assignments.length,
    );
  }
}

/// "Meu dia": o que falta fazer hoje e como está a semana.
class MyDayPage extends StatefulWidget {
  const MyDayPage({super.key});

  @override
  State<MyDayPage> createState() => _MyDayPageState();
}

class _MyDayPageState extends State<MyDayPage> {
  late Future<Map<String, dynamic>> _schedule;

  @override
  void initState() {
    super.initState();
    _schedule = ScheduleService.getWeekSchedule();
  }

  Future<void> _refresh() async {
    final next = ScheduleService.getWeekSchedule();
    setState(() => _schedule = next);
    await next.catchError((_) => <String, dynamic>{});
  }

  /// Remove atendimentos repetidos (mesma loja + marca) de uma lista de
  /// assignments de um dia, mantendo a versão concluída quando houver
  /// divergência entre as duplicatas.
  List<Map<String, dynamic>> _dedupeAssignments(
      List<Map<String, dynamic>> assignments) {
    final Map<String, Map<String, dynamic>> byKey = {};
    for (final a in assignments) {
      final key =
          '${a['store_id'] ?? 'no_store'}_${a['brand_id'] ?? 'no_brand'}';
      final existing = byKey[key];
      if (existing == null ||
          (a['is_completed'] == true && existing['is_completed'] != true)) {
        byKey[key] = a;
      }
    }
    return byKey.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0F1419) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(
            'Atendimentos & Rota',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          backgroundColor:
              isDark ? const Color(0xFF1A1F2E) : const Color(0xFF0F766E),
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            tabs: [
              Tab(icon: Icon(Icons.today), text: 'Hoje'),
              Tab(icon: Icon(Icons.calendar_month), text: 'Semana'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'Atualizar',
              onPressed: _refresh,
            ),
          ],
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _schedule,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      snapshot.error.toString().replaceFirst('Exception: ', ''),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                        onPressed: _refresh,
                        child: const Text('Tentar novamente')),
                  ]),
                ),
              );
            }
            final rawDays = List<Map<String, dynamic>>.from(
                snapshot.data?['days'] as List? ?? const []);
            // Remove atendimentos duplicados (mesma loja+marca) que a API possa
            // retornar, para não exibir o mesmo atendimento mais de uma vez.
            for (var i = 0; i < rawDays.length; i++) {
              final assignments = List<Map<String, dynamic>>.from(
                  rawDays[i]['assignments'] as List? ?? const []);
              rawDays[i] = {
                ...rawDays[i],
                'assignments': _dedupeAssignments(assignments),
              };
            }
            final days = rawDays.map(DayProgress.fromJson).toList();
            final todayIndex = rawDays.indexWhere((d) => d['is_today'] == true);
            final todayAssignments = todayIndex < 0
                ? <Map<String, dynamic>>[]
                : List<Map<String, dynamic>>.from(
                    rawDays[todayIndex]['assignments'] as List? ?? const []);
            final today = todayIndex < 0 ? null : days[todayIndex];
            final weekDone = days.fold<int>(0, (sum, d) => sum + d.done);
            final weekTotal = days.fold<int>(0, (sum, d) => sum + d.total);

            // Agrupar atendimentos de hoje por loja
            final Map<String, List<Map<String, dynamic>>> storeGroups = {};
            for (final a in todayAssignments) {
              final storeKey = (a['store_id'] != null)
                  ? 'store_${a['store_id']}'
                  : 'no_store_${a['brand_id']}';
              storeGroups.putIfAbsent(storeKey, () => []).add(a);
            }

            final showStoreCount = storeGroups.length > 1;

            return TabBarView(
              children: [
                RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      _TodayCard(progress: today),
                      const SizedBox(height: 16),
                      if (todayAssignments.isNotEmpty) ...[
                        Text(
                          'Lojas',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...storeGroups.values.map((g) =>
                            _buildStoreGroupCard(g, showCount: showStoreCount)),
                      ],
                    ],
                  ),
                ),
                RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      _WeekSummaryCard(done: weekDone, total: weekTotal),
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            children: days.map(_buildDayRow).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const WeekSchedulePage()),
                          );
                          if (mounted) _refresh();
                        },
                        icon: const Icon(Icons.calendar_month),
                        label: const Text('Agenda'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F766E),
                          side: const BorderSide(color: Color(0xFF0F766E)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStoreGroupCard(List<Map<String, dynamic>> assignments,
      {bool showCount = true}) {
    if (assignments.isEmpty) return const SizedBox.shrink();

    final first = assignments.first;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final storeName = (first['store_name'] ?? '').toString();
    final chain = (first['chain'] ?? '').toString();
    final storeNumber =
        first['store_number'] != null ? 'Loja ${first['store_number']}' : null;

    final storeTitle = [
      if (chain.isNotEmpty) chain,
      if (storeNumber != null) storeNumber,
      if (storeName.isNotEmpty) storeName,
    ].join(' • ');

    final displayTitle =
        storeTitle.isNotEmpty ? storeTitle : 'Atendimento Geral';

    final addressParts = [
      first['address'],
      first['city'],
      first['state'],
    ].whereType<String>().where((v) => v.isNotEmpty).join(', ');

    final totalBrands = assignments.length;
    final doneBrands =
        assignments.where((a) => a['is_completed'] == true).length;
    final isAllDone = totalBrands > 0 && doneBrands == totalBrands;
    final storeId = (first['store_id'] as num?)?.toInt();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isAllDone
              ? const Color(0xFF86EFAC)
              : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
        ),
      ),
      color: isAllDone
          ? (isDark
              ? const Color(0xFF064E3B).withValues(alpha: 0.2)
              : const Color(0xFFF0FDF4))
          : (isDark ? const Color(0xFF1E293B) : Colors.white),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StoreBrandsPage(
                storeTitle: displayTitle,
                storeSubtitle: addressParts.isNotEmpty ? addressParts : null,
                storeId: storeId,
                brands: assignments,
              ),
            ),
          );
          if (result == true && mounted) _refresh();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isAllDone
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : const Color(0xFF0F766E).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isAllDone ? Icons.check_circle : Icons.storefront,
                      color: isAllDone
                          ? const Color(0xFF10B981)
                          : const Color(0xFF0F766E),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayTitle,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        if (addressParts.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            addressParts,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white60
                                  : const Color(0xFF64748B),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isAllDone || showCount)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isAllDone
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isAllDone
                            ? 'Concluída'
                            : '$doneBrands/$totalBrands marcas',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isAllDone
                              ? const Color(0xFF15803D)
                              : const Color(0xFF0369A1),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              // Prévia das marcas na loja
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: assignments.map((a) {
                  final brandName = (a['brand_name'] ?? 'Marca').toString();
                  final completed = a['is_completed'] == true;
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: completed
                          ? const Color(0xFFDCFCE7)
                          : (isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: completed
                            ? const Color(0xFF86EFAC)
                            : (isDark
                                ? Colors.white12
                                : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          completed
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          size: 11,
                          color:
                              completed ? const Color(0xFF16A34A) : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          brandName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: completed
                                ? const Color(0xFF15803D)
                                : (isDark
                                    ? Colors.white70
                                    : const Color(0xFF334155)),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Ver marcas e atender',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2DD4BF) : const Color(0xFF0F766E),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssignment(Map<String, dynamic> assignment) {
    final completed = assignment['is_completed'] == true;
    final store = [
      assignment['chain'],
      assignment['store_number'] != null
          ? 'Loja ${assignment['store_number']}'
          : null,
      assignment['store_name'],
    ].whereType<String>().where((v) => v.isNotEmpty).join(' • ');
    return Card(
      child: ListTile(
        leading: Icon(
          completed ? Icons.check_circle : Icons.storefront,
          color: completed ? Colors.green : Colors.orange,
        ),
        title: Text((assignment['brand_name'] ?? 'Marca').toString(),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: store.isEmpty ? null : Text(store),
        trailing: Text(
          completed ? 'Concluído' : 'Atender',
          style: TextStyle(
            color: completed ? Colors.green : Colors.orange,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DynamicBrandCollectionPage(
                      brandId: (assignment['brand_id'] as num).toInt(),
                      brandName:
                          assignment['brand_name']?.toString() ?? 'Marca',
                      storeId: (assignment['store_id'] as num?)?.toInt(),
                    ),
                  ),
                );
                if (result == true && mounted) _refresh();
              },
      ),
    );
  }

  Widget _buildDayRow(DayProgress day) {
    final parts = day.date.split('-');
    final shortDate = parts.length == 3 ? '${parts[2]}/${parts[1]}' : day.date;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        SizedBox(
          width: 92,
          child: Text(
            '${day.name.split('-').first} $shortDate',
            style: TextStyle(
              fontSize: 12,
              fontWeight: day.isToday ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: day.total == 0 ? 0 : day.ratio,
              minHeight: 10,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              color: Colors.green,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 48,
          child: Text(
            day.total == 0 ? '—' : '${day.done}/${day.total}',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ]),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final DayProgress? progress;

  const _TodayCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final String headline;
    final String? detail;
    if (p == null || p.total == 0) {
      headline = 'Nenhum atendimento previsto hoje';
      detail = 'Confira a aba Semana.';
    } else if (p.pending == 0) {
      headline = 'Tudo concluído hoje! 🎉';
      detail = null;
    } else {
      headline = '${p.pending} atendimento(s) pendente(s)';
      detail = null;
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hoje',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text(headline,
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(detail, style: const TextStyle(color: Colors.white)),
          ],
          if (p != null && p.total > 0) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: p.ratio,
                minHeight: 12,
                backgroundColor: Colors.white24,
                color: Colors.lightGreenAccent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekSummaryCard extends StatelessWidget {
  final int done;
  final int total;

  const _WeekSummaryCard({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final pending = total - done;
    final headline = total == 0
        ? 'Nenhum atendimento na semana'
        : pending == 0
            ? 'Semana concluída! 🎉'
            : '$pending atendimento(s) pendente(s)';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Semana',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text(headline,
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          if (total > 0) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: done / total,
                minHeight: 12,
                backgroundColor: Colors.white24,
                color: Colors.lightGreenAccent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
