import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';

/// Validades registradas durante a visita: sempre vinculadas à loja e à marca
/// atendidas e salvas no servidor.
class StoreExpiriesPage extends StatefulWidget {
  final int storeId;
  final int brandId;
  final String brandName;

  const StoreExpiriesPage({
    super.key,
    required this.storeId,
    required this.brandId,
    required this.brandName,
  });

  @override
  State<StoreExpiriesPage> createState() => _StoreExpiriesPageState();

  @visibleForTesting
  static int daysUntilForTest(String isoDate, DateTime now) =>
      _StoreExpiriesPageState.daysUntil(isoDate, now: now);
}

class _StoreExpiriesPageState extends State<StoreExpiriesPage> {
  List<Map<String, dynamic>> _items = [];
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
      final items =
          await ApiService.fetchExpiries(widget.storeId, widget.brandId);
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static int daysUntil(String isoDate, {DateTime? now}) {
    final date = DateTime.parse(isoDate);
    final today = now ?? DateTime.now();
    return DateTime(date.year, date.month, date.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
  }

  Color _statusColor(int days) {
    if (days < 0) return Colors.red;
    if (days <= 7) return Colors.orange;
    if (days <= 30) return Colors.amber.shade700;
    return Colors.green;
  }

  String _statusText(int days) {
    if (days < 0) return 'Vencido há ${days.abs()} dia(s)';
    if (days == 0) return 'Vence hoje';
    if (days == 1) return 'Vence amanhã';
    return 'Vence em $days dias';
  }

  Future<void> _add() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ExpiryForm(
        storeId: widget.storeId,
        brandId: widget.brandId,
      ),
    );
    if (saved == true) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Validade registrada.')),
        );
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover validade?'),
        content: Text(item['product_name']?.toString() ?? ''),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remover')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.deleteExpiry((item['id'] as num).toInt());
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expired =
        _items.where((i) => daysUntil(i['expiry_date'].toString()) < 0).length;
    final soon = _items.where((i) {
      final d = daysUntil(i['expiry_date'].toString());
      return d >= 0 && d <= 7;
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Validades • ${widget.brandName}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Registrar validade'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: _load,
                          child: const Text('Tentar novamente')),
                    ]),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            'Anote aqui os produtos desta loja que estão perto do vencimento. '
                            'O registro fica salvo para a equipe e para a gestão acompanharem.',
                            style: GoogleFonts.poppins(fontSize: 13),
                          ),
                        ),
                      ),
                      if (expired > 0 || soon > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(spacing: 8, children: [
                            if (expired > 0)
                              Chip(
                                avatar: const Icon(Icons.error,
                                    color: Colors.red, size: 18),
                                label: Text('$expired vencido(s)'),
                              ),
                            if (soon > 0)
                              Chip(
                                avatar: const Icon(Icons.warning,
                                    color: Colors.orange, size: 18),
                                label: Text('$soon vence(m) em até 7 dias'),
                              ),
                          ]),
                        ),
                      const SizedBox(height: 8),
                      if (_items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'Nenhuma validade registrada para esta loja.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ..._items.map((item) {
                        final days = daysUntil(item['expiry_date'].toString());
                        final color = _statusColor(days);
                        final date = DateFormat('dd/MM/yyyy')
                            .format(DateTime.parse(item['expiry_date'].toString()));
                        final details = [
                          'Validade $date',
                          if (item['quantity'] != null) '${item['quantity']} un.',
                          if ((item['batch'] ?? '').toString().isNotEmpty)
                            'Lote ${item['batch']}',
                          if ((item['promoter_name'] ?? '').toString().isNotEmpty)
                            'por ${item['promoter_name']}',
                        ].join(' • ');
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.15),
                              child: Icon(Icons.event, color: color),
                            ),
                            title: Text(item['product_name']?.toString() ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text('${_statusText(days)}\n$details'),
                            isThreeLine: true,
                            trailing: IconButton(
                              tooltip: 'Remover',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(item),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}

class _ExpiryForm extends StatefulWidget {
  final int storeId;
  final int brandId;

  const _ExpiryForm({required this.storeId, required this.brandId});

  @override
  State<_ExpiryForm> createState() => _ExpiryFormState();
}

class _ExpiryFormState extends State<_ExpiryForm> {
  final _formKey = GlobalKey<FormState>();
  final _product = TextEditingController();
  final _quantity = TextEditingController();
  final _batch = TextEditingController();
  DateTime? _date;
  bool _saving = false;

  @override
  void dispose() {
    _product.dispose();
    _quantity.dispose();
    _batch.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Escolha a data de validade.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService.createExpiry(
        storeId: widget.storeId,
        brandId: widget.brandId,
        productName: _product.text.trim(),
        expiryDate: _date!,
        quantity: int.tryParse(_quantity.text.trim()),
        batch: _batch.text.trim().isEmpty ? null : _batch.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Registrar validade',
                style: GoogleFonts.poppins(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _product,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Produto', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Informe o produto'
                  : null,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event),
              label: Text(_date == null
                  ? 'Escolher data de validade'
                  : 'Validade: ${DateFormat('dd/MM/yyyy').format(_date!)}'),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _quantity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Quantidade (opcional)',
                      border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _batch,
                  decoration: const InputDecoration(
                      labelText: 'Lote (opcional)',
                      border: OutlineInputBorder()),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
