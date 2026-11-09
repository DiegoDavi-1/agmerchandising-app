import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/brand_field.dart';

/// Tarefa "Espaço na gôndola": por produto, o promotor informa frentes,
/// unidades na gôndola ao chegar e unidades repostas. Tudo opcional.
/// Valor emitido: [{productId, facings, shelfUnits, restocked}].
class ShelfSpaceField extends StatefulWidget {
  final BrandField field;
  final dynamic initialValue;
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  const ShelfSpaceField({
    super.key,
    required this.field,
    required this.onChanged,
    this.initialValue,
  });

  @override
  State<ShelfSpaceField> createState() => _ShelfSpaceFieldState();
}

class _ShelfSpaceFieldState extends State<ShelfSpaceField> {
  static const _keys = ['facings', 'shelfUnits', 'restocked'];
  final Map<String, Map<String, TextEditingController>> _controllers = {};
  late final List<Map<String, String>> _products;

  @override
  void initState() {
    super.initState();
    _products = (widget.field.fieldConfig?.products ?? const [])
        .whereType<Map>()
        .map((option) {
          final id = option['id'] ?? option['value'];
          final label = option['name'] ?? option['label'] ?? id;
          return {'id': id.toString(), 'label': label.toString()};
        })
        .where((option) => int.tryParse(option['id']!) != null)
        .toList();

    final initial = <String, Map>{};
    if (widget.initialValue is List) {
      for (final entry in widget.initialValue as List) {
        if (entry is Map && entry['productId'] != null) {
          initial[entry['productId'].toString()] = entry;
        }
      }
    }
    for (final product in _products) {
      final saved = initial[product['id']];
      _controllers[product['id']!] = {
        for (final key in _keys)
          key: TextEditingController(text: saved?[key]?.toString() ?? ''),
      };
    }
  }

  @override
  void dispose() {
    for (final group in _controllers.values) {
      for (final controller in group.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void _emit() {
    final value = <Map<String, dynamic>>[];
    _controllers.forEach((productId, group) {
      final entry = <String, dynamic>{'productId': int.parse(productId)};
      var hasValue = false;
      for (final key in _keys) {
        final number = int.tryParse(group[key]!.text.trim());
        entry[key] = number;
        if (number != null) hasValue = true;
      }
      if (hasValue) value.add(entry);
    });
    widget.onChanged(value);
  }

  Widget _numberInput(TextEditingController controller, String label, bool isDark) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(5),
      ],
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : Colors.grey[900],
      ),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF0F766E), width: 2),
        ),
      ),
      onChanged: (_) => _emit(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRequired = widget.field.fieldConfig?.required ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.field.fieldLabel}${isRequired ? ' *' : ''}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: isDark ? Colors.white : Colors.grey[900],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Frentes: produtos visíveis na primeira fila. Na gôndola: unidades ao chegar. Repostas: quantas você colocou. Deixe em branco o que não conseguir contar.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          if (_products.isEmpty)
            const Text('Nenhum produto disponível no mix.',
                style: TextStyle(color: Colors.orange))
          else
            ..._products.map((product) {
              final group = _controllers[product['id']]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['label']!,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.grey[200] : Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _numberInput(group['facings']!, 'Frentes', isDark)),
                        const SizedBox(width: 8),
                        Expanded(child: _numberInput(group['shelfUnits']!, 'Na gôndola', isDark)),
                        const SizedBox(width: 8),
                        Expanded(child: _numberInput(group['restocked']!, 'Repostas', isDark)),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
