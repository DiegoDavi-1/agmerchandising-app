import 'package:flutter/material.dart';
import '../services/schedule_service.dart';
import 'dynamic_brand_collection_page.dart';
import 'store_brands_page.dart';

class WeekSchedulePage extends StatefulWidget {
  const WeekSchedulePage({super.key});

  @override
  State<WeekSchedulePage> createState() => _WeekSchedulePageState();
}

class _WeekSchedulePageState extends State<WeekSchedulePage> {
  late Future<Map<String, dynamic>> _schedule;

  @override
  void initState() {
    super.initState();
    _schedule = ScheduleService.getWeekSchedule();
  }

  void _refresh() {
    setState(() => _schedule = ScheduleService.getWeekSchedule());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda semanal'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh)],
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
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(snapshot.error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _refresh, child: const Text('Tentar novamente')),
                ]),
              ),
            );
          }
          final days = List<Map<String, dynamic>>.from(snapshot.data?['days'] ?? []);
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: days.length,
            itemBuilder: (context, index) => _buildDay(context, days[index], isDark),
          );
        },
      ),
    );
  }

  Widget _buildDay(BuildContext context, Map<String, dynamic> day, bool isDark) {
    final assignments = List<Map<String, dynamic>>.from(day['assignments'] ?? []);
    final isToday = day['is_today'] == true;
    final label = '${day['name']} • ${_formatDate(day['date'])}${isToday ? ' • Hoje' : ''}';

    // Agrupar por loja
    final Map<String, List<Map<String, dynamic>>> storeGroups = {};
    for (final a in assignments) {
      final storeKey = (a['store_id'] != null)
          ? 'store_${a['store_id']}'
          : 'no_store_${a['brand_id']}';
      storeGroups.putIfAbsent(storeKey, () => []).add(a);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isToday ? Colors.blue.withValues(alpha: 0.12) : (isDark ? Colors.white10 : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(10),
          border: isToday ? Border.all(color: Colors.blue.shade300) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isToday ? Colors.blue.shade700 : null)),
            if (assignments.isNotEmpty)
              Text(
                '${storeGroups.length} ${storeGroups.length == 1 ? 'loja' : 'lojas'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isToday ? Colors.blue.shade700 : (isDark ? Colors.white60 : Colors.grey.shade600),
                ),
              ),
          ],
        ),
      ),
      if (assignments.isEmpty)
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Text('Nenhum atendimento programado.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ),
      ...storeGroups.values.map((group) => _buildStoreGroup(context, group, isToday, isDark)),
    ]);
  }

  Widget _buildStoreGroup(
    BuildContext context,
    List<Map<String, dynamic>> assignments,
    bool isToday,
    bool isDark,
  ) {
    if (assignments.isEmpty) return const SizedBox.shrink();
    final first = assignments.first;
    final storeName = (first['store_name'] ?? '').toString();
    final chain = (first['chain'] ?? '').toString();
    final storeNumber = first['store_number'] != null ? 'Loja ${first['store_number']}' : null;

    final storeTitle = [
      if (chain.isNotEmpty) chain,
      if (storeNumber != null) storeNumber,
      if (storeName.isNotEmpty) storeName,
    ].join(' • ');

    final displayTitle = storeTitle.isNotEmpty ? storeTitle : 'Atendimento Geral';

    final addressParts = [
      first['address'],
      first['city'],
      first['state'],
    ].whereType<String>().where((v) => v.isNotEmpty).join(', ');

    final totalBrands = assignments.length;
    final doneBrands = assignments.where((a) => a['is_completed'] == true).length;
    final isAllDone = totalBrands > 0 && doneBrands == totalBrands;
    final storeId = (first['store_id'] as num?)?.toInt();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isAllDone
              ? const Color(0xFF86EFAC)
              : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
        ),
      ),
      color: isAllDone
          ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.2) : const Color(0xFFF0FDF4))
          : (isDark ? const Color(0xFF1E293B) : Colors.white),
      child: ListTile(
        leading: Icon(
          isAllDone ? Icons.check_circle : Icons.storefront,
          color: isAllDone ? Colors.green : (isToday ? const Color(0xFF0F766E) : Colors.grey),
          size: 28,
        ),
        title: Text(
          displayTitle,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (addressParts.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                addressParts,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 4),
            Text(
              assignments.map((a) => a['brand_name'] ?? 'Marca').join(', '),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isAllDone
                ? const Color(0xFFDCFCE7)
                : (isToday ? const Color(0xFFE0F2FE) : Colors.grey.withValues(alpha: 0.15)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            isAllDone ? 'Concluída' : '$doneBrands/$totalBrands marcas',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isAllDone
                  ? const Color(0xFF15803D)
                  : (isToday ? const Color(0xFF0369A1) : Colors.grey.shade700),
            ),
          ),
        ),
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
      ),
    );
  }

  Widget _buildAssignment(BuildContext context, Map<String, dynamic> assignment, bool isToday) {
    final completed = assignment['is_completed'] == true;
    final canOpen = isToday;
    final store = [
      assignment['chain'],
      assignment['store_number'] != null ? 'Loja ${assignment['store_number']}' : null,
      assignment['store_name'],
    ].whereType<String>().where((value) => value.isNotEmpty).join(' • ');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(completed ? Icons.check_circle : Icons.storefront, color: completed ? Colors.green : Colors.blue),
        title: Text((assignment['brand_name'] ?? 'Marca').toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(store),
        trailing: Text(completed ? 'Concluído' : (isToday ? 'Atender' : 'Programado'), style: TextStyle(color: completed ? Colors.green : Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
        enabled: canOpen,
        onTap: !canOpen ? null : () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DynamicBrandCollectionPage(
              brandId: assignment['brand_id'] as int,
              brandName: assignment['brand_name'] as String? ?? 'Marca',
              storeId: assignment['store_id'] as int?,
            )),
          );
          if (result == true && mounted) _refresh();
        },
      ),
    );
  }

  String _formatDate(dynamic value) {
    final parts = value.toString().split('-');
    return parts.length == 3 ? '${parts[2]}/${parts[1]}' : value.toString();
  }
}
