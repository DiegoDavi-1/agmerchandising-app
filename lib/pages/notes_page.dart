import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../core/theme/ui_palette.dart';

class NotesPage extends StatefulWidget {
  final int? initialStoreId;

  const NotesPage({super.key, this.initialStoreId});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Anotações
  List<Map<String, dynamic>> _notes = [];
  bool _loadingNotes = true;
  String? _notesError;

  // Validades
  List<Map<String, dynamic>> _expiries = [];
  bool _loadingExpiries = true;
  String? _expiriesError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadAll() {
    _loadNotes();
    _loadExpiries();
  }

  Future<void> _loadNotes() async {
    setState(() {
      _loadingNotes = true;
      _notesError = null;
    });
    try {
      final items = await ApiService.fetchPromoterNotes(storeId: widget.initialStoreId);
      if (!mounted) return;
      setState(() => _notes = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _notesError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingNotes = false);
    }
  }

  Future<void> _loadExpiries() async {
    setState(() {
      _loadingExpiries = true;
      _expiriesError = null;
    });
    try {
      final items = await ApiService.fetchExpiries(widget.initialStoreId);
      if (!mounted) return;
      setState(() => _expiries = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _expiriesError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingExpiries = false);
    }
  }

  // --- Helpers de Validade ---
  static int _daysUntil(String isoDate) {
    final date = DateTime.parse(isoDate);
    final today = DateTime.now();
    return DateTime(date.year, date.month, date.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
  }

  Color _statusColor(int days) {
    if (days < 0) return const Color(0xFFDC2626); // Vencido
    if (days <= 7) return const Color(0xFFEA580C); // Urgente
    if (days <= 30) return const Color(0xFFD97706); // Atenção
    return const Color(0xFF16A34A); // Normal
  }

  String _statusText(int days) {
    if (days < 0) return 'Vencido há ${days.abs()} dia(s)';
    if (days == 0) return 'Vence hoje!';
    if (days == 1) return 'Vence amanhã';
    return 'Vence em $days dias';
  }

  // --- Modal Nova Anotação ---
  Future<void> _openCreateNoteModal() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    bool isPinned = false;
    bool saving = false;
    String? modalError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_note, color: Color(0xFF0F766E), size: 26),
                  const SizedBox(width: 8),
                  Text(
                    'Nova Anotação',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.uiTextStrong,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  )
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Título ou Assunto (Opcional)',
                  hintText: 'Ex: Encarregado Carlos, Ponto Extra...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Conteúdo da Anotação *',
                  hintText: 'Escreva detalhes para lembrar na próxima visita...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: isPinned,
                    activeColor: const Color(0xFF0F766E),
                    onChanged: (v) => setModalState(() => isPinned = v ?? false),
                  ),
                  const Text('Fixar no topo como lembrete importante', style: TextStyle(fontSize: 13)),
                ],
              ),
              if (modalError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(modalError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          final text = contentController.text.trim();
                          if (text.isEmpty) {
                            setModalState(() => modalError = 'Escreva o texto da anotação.');
                            return;
                          }
                          setModalState(() {
                            saving = true;
                            modalError = null;
                          });
                          try {
                            await ApiService.createPromoterNote(
                              title: titleController.text.trim(),
                              content: text,
                              storeId: widget.initialStoreId,
                              isPinned: isPinned,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            _loadNotes();
                          } catch (e) {
                            setModalState(() {
                              saving = false;
                              modalError = e.toString().replaceFirst('Exception: ', '');
                            });
                          }
                        },
                  icon: const Icon(Icons.check),
                  label: Text(saving ? 'Salvando...' : 'Salvar Anotação'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Modal Nova Validade ---
  Future<void> _openCreateExpiryModal() async {
    final productController = TextEditingController();
    final batchController = TextEditingController();
    final qtyController = TextEditingController();
    DateTime? selectedDate;
    bool saving = false;
    String? modalError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.event_available, color: Color(0xFF0F766E), size: 26),
                  const SizedBox(width: 8),
                  Text(
                    'Apontar Validade',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.uiTextStrong,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  )
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: productController,
                decoration: const InputDecoration(
                  labelText: 'Produto / Descrição *',
                  hintText: 'Ex: Banana Brasil Barra Tradicional 25g',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: now.add(const Duration(days: 30)),
                          firstDate: now.subtract(const Duration(days: 365)),
                          lastDate: now.add(const Duration(days: 365 * 3)),
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        selectedDate == null
                            ? 'Escolher Data *'
                            : DateFormat('dd/MM/yyyy').format(selectedDate!),
                        style: TextStyle(
                          color: selectedDate == null ? context.uiTextMuted : const Color(0xFF0F766E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Qtd (Itens)',
                        hintText: 'Ex: 12',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: batchController,
                decoration: const InputDecoration(
                  labelText: 'Lote (Opcional)',
                  hintText: 'Ex: L-4092B',
                  border: OutlineInputBorder(),
                ),
              ),
              if (modalError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(modalError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          final prod = productController.text.trim();
                          if (prod.isEmpty || selectedDate == null) {
                            setModalState(() => modalError = 'Informe o produto e a data de validade.');
                            return;
                          }
                          setModalState(() {
                            saving = true;
                            modalError = null;
                          });
                          try {
                            final qty = int.tryParse(qtyController.text.trim());
                            await ApiService.createExpiry(
                              storeId: widget.initialStoreId ?? 1,
                              brandId: 1, // Fallback default
                              productName: prod,
                              expiryDate: selectedDate!,
                              quantity: qty,
                              batch: batchController.text.trim(),
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            _loadExpiries();
                          } catch (e) {
                            setModalState(() {
                              saving = false;
                              modalError = e.toString().replaceFirst('Exception: ', '');
                            });
                          }
                        },
                  icon: const Icon(Icons.check),
                  label: Text(saving ? 'Salvando...' : 'Registrar Validade'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteNote(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Anotação?'),
        content: const Text('Essa anotação será removida permanentemente.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ApiService.deletePromoterNote(id);
        _loadNotes();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1419) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Notas & Validades',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white),
        ),
        backgroundColor: isDark ? const Color(0xFF1A1F2E) : const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.edit_note), text: 'Anotações'),
            Tab(icon: Icon(Icons.event_busy), text: 'Validades'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNotesTab(),
          _buildExpiriesTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        onPressed: () {
          if (_tabController.index == 0) {
            _openCreateNoteModal();
          } else {
            _openCreateExpiryModal();
          }
        },
        icon: const Icon(Icons.add),
        label: Text(_tabController.index == 0 ? 'Nova Anotação' : 'Apontar Validade'),
      ),
    );
  }

  Widget _buildNotesTab() {
    if (_loadingNotes) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)));
    }
    if (_notesError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 10),
            Text(_notesError!, style: const TextStyle(color: Colors.red)),
            TextButton(onPressed: _loadNotes, child: const Text('Tentar novamente')),
          ],
        ),
      );
    }
    if (_notes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notes_outlined, size: 64, color: context.uiTextFaint),
              const SizedBox(height: 12),
              Text(
                'Nenhuma anotação ainda',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: context.uiTextMuted),
              ),
              const SizedBox(height: 6),
              Text(
                'Use este espaço para anotar contatos de encarregados, recados da loja e lembretes para suas próximas visitas.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: context.uiTextMuted),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: _notes.length,
      itemBuilder: (context, index) {
        final note = _notes[index];
        final isPinned = note['is_pinned'] == 1 || note['is_pinned'] == true;
        final dateStr = note['created_at'] != null
            ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(note['created_at'].toString()))
            : '';
        final storeName = [note['chain'], note['store_name']].whereType<String>().where((s) => s.isNotEmpty).join(' • ');

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: context.uiSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isPinned ? const Color(0xFF0F766E).withValues(alpha: 0.5) : context.uiBorder,
              width: isPinned ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isPinned) ...[
                      const Icon(Icons.push_pin, size: 16, color: Color(0xFF0F766E)),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        note['title']?.toString() ?? 'Lembrete',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: context.uiTextStrong,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                      onPressed: () => _deleteNote((note['id'] as num).toInt()),
                    )
                  ],
                ),
                if (storeName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '📍 $storeName',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F766E)),
                    ),
                  ),
                Text(
                  note['content']?.toString() ?? '',
                  style: TextStyle(fontSize: 13, color: context.uiTextBody, height: 1.4),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    dateStr,
                    style: TextStyle(fontSize: 11, color: context.uiTextFaint),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpiriesTab() {
    if (_loadingExpiries) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)));
    }
    if (_expiriesError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 10),
            Text(_expiriesError!, style: const TextStyle(color: Colors.red)),
            TextButton(onPressed: _loadExpiries, child: const Text('Tentar novamente')),
          ],
        ),
      );
    }
    if (_expiries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_available_outlined, size: 64, color: context.uiTextFaint),
              const SizedBox(height: 12),
              Text(
                'Nenhuma validade próxima apontada',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: context.uiTextMuted),
              ),
              const SizedBox(height: 6),
              Text(
                'Registre lotes com validade próxima para prevenir perdas e organizar o rodízio no PDV.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: context.uiTextMuted),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      itemCount: _expiries.length,
      itemBuilder: (context, index) {
        final item = _expiries[index];
        final days = _daysUntil(item['expiry_date'].toString());
        final color = _statusColor(days);
        final date = DateFormat('dd/MM/yyyy').format(DateTime.parse(item['expiry_date'].toString()));
        final details = [
          'Vencimento: $date',
          if (item['quantity'] != null) '${item['quantity']} un.',
          if ((item['batch'] ?? '').toString().isNotEmpty) 'Lote: ${item['batch']}',
        ].join(' • ');

        final storeName = [item['chain'], item['store_name']].whereType<String>().where((s) => s.isNotEmpty).join(' • ');

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: context.uiSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.event_busy, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['product_name']?.toString() ?? 'Produto',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: context.uiTextStrong,
                        ),
                      ),
                      if (storeName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            storeName,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF0F766E), fontWeight: FontWeight.w500),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        details,
                        style: TextStyle(fontSize: 12, color: context.uiTextMuted),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _statusText(days),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
