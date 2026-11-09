import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_config.dart';
import 'dynamic_brand_collection_page.dart';

class StoreBrandsPage extends StatefulWidget {
  final String storeTitle;
  final String? storeSubtitle;
  final int? storeId;
  final List<Map<String, dynamic>> brands;

  const StoreBrandsPage({
    super.key,
    required this.storeTitle,
    this.storeSubtitle,
    this.storeId,
    required this.brands,
  });

  @override
  State<StoreBrandsPage> createState() => _StoreBrandsPageState();
}

class _StoreBrandsPageState extends State<StoreBrandsPage> {
  late List<Map<String, dynamic>> _brands;

  @override
  void initState() {
    super.initState();
    _brands = List<Map<String, dynamic>>.from(widget.brands);
  }

  int get _completedCount =>
      _brands.where((b) => b['is_completed'] == true).length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1419) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          widget.storeTitle,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: Colors.white,
          ),
        ),
        backgroundColor:
            isDark ? const Color(0xFF1A1F2E) : const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header da Loja
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.storefront,
                        color: Color(0xFF0F766E),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.storeTitle,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          if (widget.storeSubtitle != null &&
                              widget.storeSubtitle!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.storeSubtitle!,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _brands.isEmpty ? 0 : _completedCount / _brands.length,
                    minHeight: 8,
                    backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    color: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_completedCount de ${_brands.length} marcas atendidas nesta loja',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Título da seção
          Text(
            'Marcas programadas para hoje',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),

          // Lista de marcas
          ..._brands.map((brand) => _buildBrandCard(brand, isDark)),
        ],
      ),
    );
  }

  Widget _buildBrandCard(Map<String, dynamic> brand, bool isDark) {
    final completed = brand['is_completed'] == true;
    final brandName = (brand['brand_name'] ?? 'Marca').toString();
    final logoUrl = ApiConfig.resolveAssetUrl(brand['logo_url']);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: completed
              ? const Color(0xFF86EFAC)
              : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
        ),
      ),
      color: completed
          ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.25) : const Color(0xFFF0FDF4))
          : (isDark ? const Color(0xFF1E293B) : Colors.white),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: completed
                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                : const Color(0xFF0F766E).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: logoUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(3),
                    child: Image.network(
                      logoUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        completed ? Icons.check_circle : Icons.shopping_bag_outlined,
                        color: completed ? const Color(0xFF10B981) : const Color(0xFF0F766E),
                      ),
                    ),
                  ),
                )
              : Icon(
                  completed ? Icons.check_circle : Icons.shopping_bag_outlined,
                  color: completed ? const Color(0xFF10B981) : const Color(0xFF0F766E),
                ),
        ),
        title: Text(
          brandName,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        subtitle: Text(
          completed
              ? 'Concluído • toque para fazer outro atendimento'
              : 'Toque para iniciar coleta',
          style: TextStyle(
            fontSize: 12,
            color: completed
                ? const Color(0xFF16A34A)
                : (isDark ? Colors.white60 : const Color(0xFF64748B)),
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: completed
                ? const Color(0xFFDCFCE7)
                : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            completed ? 'Concluído' : 'Atender',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: completed
                  ? const Color(0xFF15803D)
                  : const Color(0xFFB45309),
            ),
          ),
        ),
        onTap: () async {
                if (completed) {
                  final redo = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Fazer novo atendimento?'),
                      content: const Text(
                          'O atendimento já enviado continua salvo. Um novo atendimento será registrado separadamente.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Fazer novo'),
                        ),
                      ],
                    ),
                  );
                  if (redo != true || !context.mounted) return;
                }
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DynamicBrandCollectionPage(
                      brandId: (brand['brand_id'] as num).toInt(),
                      brandName: brandName,
                      storeId: (brand['store_id'] as num?)?.toInt() ?? widget.storeId,
                    ),
                  ),
                );
                if (result == true) {
                  setState(() {
                    brand['is_completed'] = true;
                  });
                  if (context.mounted) {
                    Navigator.pop(context, true);
                  }
                }
              },
      ),
    );
  }
}
