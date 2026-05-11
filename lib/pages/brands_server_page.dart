import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/schedule_service.dart';
import '../core/logging/app_logger_v2.dart';
import 'dynamic_brand_collection_page.dart';

class BrandsServerPage extends StatefulWidget {
  const BrandsServerPage({super.key});

  @override
  State<BrandsServerPage> createState() => _BrandsServerPageState();
}

class _BrandsServerPageState extends State<BrandsServerPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<dynamic> _brands = [];
  List<dynamic> _filteredBrands = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  final int _limit = 20;
  String _searchQuery = '';
  String _todayName = '';
  int _todayNumber = 0;
  bool _showOnlyToday = true;
  bool _showCompleted = true; // seção concluídas expansível

  @override
  void initState() {
    super.initState();
    _loadBrands(reset: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadBrands();
    }
  }

  Future<void> _loadBrands({bool reset = false, bool forceRefresh = false}) async {
    if (_isLoadingMore) return;

    setState(() {
      if (reset) {
        _isLoading = true;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      if (reset) {
        _page = 1;
        _hasMore = true;
      }

      // Usar ScheduleService para buscar marcas do dia
      if (_showOnlyToday) {
        final result = await ScheduleService.getBrandsToday();
        setState(() {
          _brands = result['brands'] as List<dynamic>;
          _todayName = result['day_name'] as String;
          _todayNumber = result['today'] as int;
          _hasMore = false; // Não há paginação para marcas do dia
          _applyFilter();
        });
      } else {
        final list = await ApiService.getBrands(
          page: _page,
          limit: _limit,
          forceRefresh: forceRefresh && _page == 1,
        );

        setState(() {
          if (reset) {
            _brands = list;
          } else {
            _brands.addAll(list);
          }

          _hasMore = list.length == _limit;
          _page++;
          _applyFilter();
        });
      }
    } catch (e) {
      appLogger.error('Erro ao carregar marcas', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar marcas: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredBrands = List<dynamic>.from(_brands);
      return;
    }

    final query = _searchQuery.toLowerCase();
    _filteredBrands = _brands.where((brand) {
      final name = (brand['name'] ?? '').toString().toLowerCase();
      final description = (brand['description'] ?? '').toString().toLowerCase();
      return name.contains(query) || description.contains(query);
    }).toList();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() {
        _searchQuery = value.trim();
        _applyFilter();
      });
    });
  }

  void _refreshBrands() {
    _loadBrands(reset: true, forceRefresh: true);
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Tem certeza que deseja sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await ApiService.logout();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            child: const Text('Sair', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandList(bool isDark) {
    final pending = _filteredBrands.where((b) => !ScheduleService.isBrandCompletedToday(b)).toList();
    final completed = _filteredBrands.where((b) => ScheduleService.isBrandCompletedToday(b)).toList();

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // ── Seção Pendentes ──────────────────────────────────
        if (pending.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 4),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E88E5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Pendentes (${pending.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.grey[700],
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          ...pending.map((brand) => _buildBrandCard(brand, isDark, false)),
        ],

        // ── Seção Concluídas ─────────────────────────────────
        if (completed.isNotEmpty) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() => _showCompleted = !_showCompleted),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 16,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    'Concluídas hoje (${completed.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Colors.green,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _showCompleted ? Icons.expand_less : Icons.expand_more,
                    color: Colors.green,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_showCompleted)
            ...completed.map((brand) => _buildBrandCard(brand, isDark, true)),
        ],

        // Loading paginação
        if (_hasMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildBrandCard(dynamic brand, bool isDark, bool isCompleted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isCompleted
            ? (isDark ? const Color(0xFF1A2820) : const Color(0xFFF1FAF4))
            : (isDark ? const Color(0xFF1A1F2E) : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: isCompleted ? Border.all(color: Colors.green.withOpacity(0.5), width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isCompleted
                    ? Colors.green.withOpacity(0.12)
                    : (isDark ? Colors.blue[950] : Colors.blue[100]),
                borderRadius: BorderRadius.circular(8),
                image: brand['logo_url'] != null
                    ? DecorationImage(
                        image: NetworkImage(brand['logo_url']),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: brand['logo_url'] == null
                  ? Icon(
                      isCompleted ? Icons.check_circle_outline : Icons.shopping_bag,
                      color: isCompleted ? Colors.green : (isDark ? Colors.blue[400] : Colors.blue[400]),
                    )
                  : null,
            ),
            if (isCompleted)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF1A2820) : const Color(0xFFF1FAF4),
                      width: 2,
                    ),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                brand['name'] ?? 'Sem nome',
                style: TextStyle(
                  color: isCompleted
                      ? (isDark ? Colors.green[300] : Colors.green[800])
                      : (isDark ? Colors.white : Colors.grey[900]),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isCompleted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '✓ Concluída',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          brand['description'] ?? 'Sem descrição',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isCompleted
                ? Colors.green.withOpacity(0.7)
                : (isDark ? Colors.grey[500] : Colors.grey[600]),
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          isCompleted ? Icons.task_alt : Icons.chevron_right,
          color: isCompleted ? Colors.green : (isDark ? Colors.grey[600] : Colors.grey[400]),
        ),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DynamicBrandCollectionPage(
                brandId: brand['id'] as int,
                brandName: brand['name'] ?? 'Marca',
                brandHeaderColor: brand['header_color'] as String?,
                storeId: brand['assigned_store_id'] as int?,
              ),
            ),
          );

          if (result == true && mounted) {
            await _loadBrands(reset: true, forceRefresh: true);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Coleta registrada!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1419) : Colors.white,
      appBar: AppBar(
        title: Text('Marcas', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        elevation: 8,
        shadowColor: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.blue.withValues(alpha: 0.4),
        backgroundColor: isDark ? const Color(0xFF1A1F2E) : const Color(0xFF1E88E5),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshBrands,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                hintText: 'Buscar marca...',
                hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.grey[700] ?? Colors.grey : Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.grey[700] ?? Colors.grey : Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: isDark ? Colors.grey[600] ?? Colors.grey : Colors.grey[400]!, width: 2),
                ),
                fillColor: isDark ? const Color(0xFF1A1F2E) : Colors.grey[50],
                filled: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Filtro de dia
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: true,
                        label: Text('Hoje ${_todayName.isNotEmpty ? "($_todayName)" : ""}'),
                        icon: const Icon(Icons.today, size: 16),
                      ),
                      const ButtonSegment(
                        value: false,
                        label: Text('Todas'),
                        icon: Icon(Icons.calendar_month, size: 16),
                      ),
                    ],
                    selected: {_showOnlyToday},
                    onSelectionChanged: (Set<bool> newSelection) {
                      setState(() {
                        _showOnlyToday = newSelection.first;
                      });
                      _loadBrands(reset: true);
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredBrands.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_bag_outlined,
                                size: 64, color: isDark ? Colors.grey[700] : Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              _showOnlyToday 
                                ? 'Nenhuma marca agendada para hoje'
                                : 'Nenhuma marca encontrada',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.grey[700],
                              ),
                            ),
                            if (_showOnlyToday) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Tente ver "Todas as marcas"',
                                style: TextStyle(
                                  color: isDark ? Colors.grey[600] : Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _refreshBrands,
                              child: const Text('Recarregar'),
                            ),
                          ],
                        ),
                      )
                    : _buildBrandList(isDark),
          ),
        ],
      ),
    );
  }
}
