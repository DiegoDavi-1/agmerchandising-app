import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../core/theme/app_theme.dart';
import 'brands_server_page.dart';
import 'help_center_page.dart';
import 'supervisor_portal_sections.dart';

double promoterProgress(Map<String, dynamic> promoter) {
  final planned = (promoter['planned'] as num?)?.toInt() ?? 0;
  final completed = (promoter['completed'] as num?)?.toInt() ?? 0;
  final rawProgress = (promoter['progress'] as num?)?.toDouble() ??
      (planned == 0 ? 0 : completed / planned);
  return (rawProgress > 1 ? rawProgress / 100 : rawProgress).clamp(0.0, 1.0);
}

/// Tela "Equipe" — visível somente para usuários com papel de supervisor.
/// Equivalente à aba "Equipe" (rota /supervisao) do PWA do promotor (supervisor.js).
class SupervisorPage extends StatefulWidget {
  const SupervisorPage({super.key});

  @override
  State<SupervisorPage> createState() => _SupervisorPageState();
}

class _SupervisorPageState extends State<SupervisorPage> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic> _team = {};
  Map<String, dynamic> _summary = {};
  List<dynamic> _promoters = [];
  List<dynamic> _tasks = [];
  List<dynamic> _nonVisits = [];
  late DateTimeRange _period;
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _period = DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
    _load();
  }

  Future<void> _choosePeriod() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _period,
    );
    if (selected == null || !mounted) return;
    setState(() => _period = selected);
    _load();
  }

  Future<void> _load() async {
    final version = ++_loadVersion;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await ApiService.fetchSupervisorOverview(
        startDate: portalDate(_period.start),
        endDate: portalDate(_period.end),
      );
      if (!mounted || version != _loadVersion) return;
      if (response['success'] == true) {
        final data = response['data'] as Map<String, dynamic>? ?? {};
        _team = data['team'] as Map<String, dynamic>? ?? {};
        _summary = data['summary'] as Map<String, dynamic>? ?? {};
        _promoters = data['promoters'] as List<dynamic>? ?? [];
        _tasks = data['tasks'] as List<dynamic>? ?? [];
        _nonVisits = data['non_visits'] as List<dynamic>? ?? [];
      } else {
        _error = response['error']?.toString() ??
            'Não foi possível carregar a supervisão.';
      }
    } catch (e) {
      if (version == _loadVersion) _error = e.toString();
    } finally {
      if (mounted && version == _loadVersion) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Sem prazo';
    try {
      final date = DateTime.parse(value.toString());
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {
      return value.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
        length: 4,
        child: Scaffold(
          backgroundColor:
              isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
          appBar: AppBar(
            title: Text('Portal da equipe',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            backgroundColor: isDark ? AppColors.cardDark : AppColors.primary,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                tooltip: 'Selecionar período',
                onPressed: _choosePeriod,
                icon: const Icon(Icons.date_range),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opções do supervisor',
                onSelected: (action) {
                  if (action == 'logout') _confirmLogout();
                  if (action == 'support') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              const HelpCenterPage(showRouteChange: false)),
                    );
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                      value: 'support',
                      child: Row(children: [
                        Icon(Icons.support_agent),
                        SizedBox(width: 12),
                        Text('Suporte'),
                      ])),
                  PopupMenuItem(value: 'logout', child: Text('Sair')),
                ],
              ),
            ],
            bottom: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Visão geral'),
                Tab(text: 'Atendimentos'),
                Tab(text: 'Fotos'),
                Tab(text: 'Mensagens'),
              ],
            ),
          ),
          body: TabBarView(children: [
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError(isDark)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Text(
                              '${_formatDate(_period.start)} – ${_formatDate(_period.end)}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            _buildTeamSummary(isDark),
                            const SizedBox(height: 12),
                            _buildSummary(isDark),
                            const SizedBox(height: 20),
                            _sectionTitle('Promotores', isDark),
                            const SizedBox(height: 8),
                            if (_promoters.isEmpty)
                              _emptyCard('Nenhum promotor no período.', isDark)
                            else
                              ..._promoters
                                  .map((p) => _buildPromoterCard(p, isDark)),
                            const SizedBox(height: 20),
                            _sectionTitle('Minhas tarefas', isDark),
                            const SizedBox(height: 8),
                            if (_tasks.isEmpty)
                              _emptyCard(
                                  'Nenhuma tarefa de supervisão pendente.',
                                  isDark)
                            else
                              ..._tasks.map((t) => _buildTaskCard(t, isDark)),
                            const SizedBox(height: 20),
                            _sectionTitle('Pendências da equipe', isDark),
                            const SizedBox(height: 8),
                            if (_nonVisits.isEmpty)
                              _emptyCard(
                                  'Nenhuma pendência de não atendimento na equipe.',
                                  isDark)
                            else
                              ..._nonVisits
                                  .map((n) => _buildNonVisitCard(n, isDark)),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const BrandsServerPage()),
                                ),
                                icon: const Icon(Icons.route),
                                label: const Text(
                                    'Ver roteiro e assumir cobertura'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
            SupervisorAttendances(
                key: ValueKey('attendance-$_period'), period: _period),
            SupervisorPhotos(key: ValueKey('photos-$_period'), period: _period),
            SupervisorMessages(promoters: _promoters),
          ]),
        ));
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Tem certeza que deseja sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.logout();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível sair: $error')),
        );
      }
    }
  }

  Widget _buildSummary(bool isDark) {
    final items = [
      ('Promotores previstos', _summary['plannedPromoters']),
      ('Concluídos', _summary['fullyCompleted']),
      ('Parciais', _summary['partiallyCompleted']),
      ('Não iniciados', _summary['notStarted']),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map((item) => Chip(
                label: Text('${item.$1}: ${item.$2 ?? 0}'),
                backgroundColor:
                    isDark ? AppColors.cardDark : AppColors.primaryLight,
              ))
          .toList(),
    );
  }

  Widget _buildPromoterCard(dynamic value, bool isDark) {
    final promoter = value as Map<String, dynamic>;
    final planned = (promoter['planned'] as num?)?.toInt() ?? 0;
    final completed = (promoter['completed'] as num?)?.toInt() ?? 0;
    final open = (promoter['open'] as num?)?.toInt() ?? 0;
    final progress = promoterProgress(promoter);
    return Card(
      color: isDark ? AppColors.cardDark : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(promoter['name']?.toString() ?? 'Promotor',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 16)),
          Text('Supervisor: ${promoter['supervisor_name'] ?? 'Não informado'}'),
          const SizedBox(height: 8),
          Text(
              '$planned planejados  •  $completed concluídos  •  $open em aberto'),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            color: AppColors.success,
            backgroundColor: AppColors.success.withValues(alpha: 0.15),
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 4),
          Text('${(progress * 100).round()}% concluído'),
        ]),
      ),
    );
  }

  Widget _buildError(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _load, child: const Text('Tentar novamente')),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : AppColors.textLight,
      ),
    );
  }

  Widget _emptyCard(String text, bool isDark) {
    return Card(
      color: isDark ? AppColors.cardDark : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(text,
            style: TextStyle(
                fontSize: 13, color: isDark ? Colors.white60 : Colors.black54)),
      ),
    );
  }

  Widget _buildTeamSummary(bool isDark) {
    final total = _team['total'] ?? 0;
    final active = _team['active'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.groups, color: Colors.white, size: 36),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$total promotores na equipe',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('$active ativos para a operação',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(dynamic task, bool isDark) {
    final isCompleted = task['status'] == 'completed';
    return Card(
      color: isDark ? AppColors.cardDark : Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task['title']?.toString() ?? '',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            if ((task['description'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(task['description'].toString(),
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54)),
            ],
            const SizedBox(height: 6),
            Text(
              '${isCompleted ? 'Concluída' : 'Pendente'} · ${_formatDate(task['due_date'])}',
              style: TextStyle(
                  fontSize: 12,
                  color: isCompleted ? AppColors.success : AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNonVisitCard(dynamic item, bool isDark) {
    final isIrregular = item['status'] == 'irregular';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: AppColors.warning, width: 3)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${item['store_name'] ?? 'Loja não informada'} · ${item['brand_name'] ?? 'Marca'}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
              '${item['promoter_name'] ?? 'Promotor'}: ${item['reason_name'] ?? ''}',
              style: const TextStyle(fontSize: 13)),
          if ((item['note'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(item['note'].toString(),
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54)),
          ],
          const SizedBox(height: 6),
          Text(
            isIrregular ? 'Requer atenção' : 'Aguardando ação',
            style: TextStyle(fontSize: 11, color: AppColors.warning),
          ),
        ],
      ),
    );
  }
}
