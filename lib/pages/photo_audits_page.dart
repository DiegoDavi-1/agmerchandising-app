import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../core/theme/ui_palette.dart';

class PhotoAuditsPage extends StatefulWidget {
  const PhotoAuditsPage({super.key});

  @override
  State<PhotoAuditsPage> createState() => _PhotoAuditsPageState();
}

class _PhotoAuditsPageState extends State<PhotoAuditsPage> {
  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ApiService.fetchPhotoReviews();
      if (!mounted) return;
      setState(() => _reviews = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1419) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Revisão de Fotos',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: isDark ? const Color(0xFF1A1F2E) : const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }
    if (_reviews.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, size: 64, color: Color(0xFF10B981)),
              const SizedBox(height: 14),
              Text(
                'Nenhuma foto reprovada!',
                style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: context.uiTextStrong),
              ),
              const SizedBox(height: 6),
              Text(
                'Todas as suas evidências fotográficas foram aprovadas pela gestão ou não possuem pendências.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: context.uiTextMuted),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      itemCount: _reviews.length,
      itemBuilder: (context, index) {
        final item = _reviews[index];
        final isRejected = item['status'] == 'rejected';
        final photoUrl = ApiService.resolvePhotoUrl(item['photoUrl']?.toString());
        final storeName = [item['chain'], item['storeName']].whereType<String>().where((s) => s.isNotEmpty).join(' • ');
        final dateStr = item['reviewedAt'] != null
            ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(item['reviewedAt'].toString()))
            : '';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: context.uiSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isRejected ? const Color(0xFFFCA5A5) : const Color(0xFFFDE047),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagem da Foto
              if (photoUrl != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, stack) => Container(
                        color: context.uiSurfaceAlt,
                        child: const Center(child: Text('Foto indisponível')),
                      ),
                    ),
                  ),
                ),

              // Informações e Orientações
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isRejected ? const Color(0xFFFEE2E2) : const Color(0xFFFEF9C3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isRejected ? '❌ Foto Reprovada' : '⚠️ Observação da Gestão',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isRejected ? const Color(0xFFDC2626) : const Color(0xFFA16207),
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (dateStr.isNotEmpty)
                          Text(
                            dateStr,
                            style: TextStyle(fontSize: 11, color: context.uiTextMuted),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (storeName.isNotEmpty)
                      Text(
                        '📍 $storeName',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F766E)),
                      ),
                    if (item['brandName'] != null)
                      Text(
                        '🏷️ Marca: ${item['brandName']}',
                        style: TextStyle(fontSize: 12, color: context.uiTextMuted),
                      ),
                    const SizedBox(height: 10),

                    // Motivo / Orientação do Gestor
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.isDarkMode ? const Color(0xFF3A2E12) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.isDarkMode ? const Color(0xFF854D0E) : const Color(0xFFFDE68A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Orientação do Supervisor / Gestor:',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.isDarkMode ? const Color(0xFFFCD34D) : const Color(0xFF92400E)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['reviewMessage']?.toString() ?? 'Foto não atendeu aos critérios de conformidade da marca.',
                            style: TextStyle(fontSize: 13, color: context.isDarkMode ? const Color(0xFFFDE68A) : const Color(0xFF78350F), height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
