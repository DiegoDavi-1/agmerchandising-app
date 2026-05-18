import 'package:flutter/material.dart';
import '../models/brand_field.dart';

class DynamicFieldWidget extends StatefulWidget {
  final BrandField field;
  final dynamic value;
  final Function(dynamic) onChanged;

  const DynamicFieldWidget({Key? key, required this.field, this.value, required this.onChanged}) : super(key: key);

  @override
  _DynamicFieldWidgetState createState() => _DynamicFieldWidgetState();
}

class _DynamicFieldWidgetState extends State<DynamicFieldWidget> {

  Widget _buildPhotoTextField() {
    final bool allowMultiple = widget.field.fieldConfig?.allowMultiple ?? false;
    final int maxPhotos = widget.field.fieldConfig?.maxPhotos ?? 1;
    final bool isRequired = widget.field.fieldConfig?.required ?? false;
    final bool requiredText = widget.field.fieldConfig?.requiredText ?? false;
    final primaryColor = Color(0xFF1E88E5);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final TextEditingController _photoTextController = TextEditingController(text: _currentValue is Map ? (_currentValue['text'] ?? '') : '');
    final List<dynamic> _photos = _currentValue is Map ? (_currentValue['photos'] ?? []) : [];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.photo_camera, color: primaryColor),
                SizedBox(width: 8),
                Text('Foto + Texto', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 12),
            _buildPhotoField(),
            SizedBox(height: 16),
            TextField(
              controller: _photoTextController,
              decoration: InputDecoration(
                labelText: requiredText ? 'Texto obrigatório' : 'Texto',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              onChanged: (val) {
                setState(() {
                  if (_currentValue is Map) {
                    _currentValue['text'] = val;
                  } else {
                    _currentValue = {'photos': _photos, 'text': val};
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.field.fieldType) {
      case 'checkbox':
        return _buildCheckboxField();
      case 'photo':
        return _buildPhotoField();
      case 'photo_text':
        return _buildPhotoTextField();
      case 'text':
      case 'textarea':
        return _buildTextField();
      case 'number':
        return _buildNumberField();
      case 'date':
        return _buildDateField();
      default:
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          color: Colors.orange[100],
          child: Text('Tipo de campo não suportado: ${widget.field.fieldType}'),
        );
    }
  }
}
