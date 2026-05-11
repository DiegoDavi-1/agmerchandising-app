import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/brand_field.dart';
import '../services/api_service.dart';

/// Widget que renderiza campos dinamicamente baseado em BrandField
class DynamicFieldWidget extends StatefulWidget {
  final BrandField field;
  final Function(String fieldName, dynamic value) onValueChanged;
  final dynamic initialValue;

  const DynamicFieldWidget({
    super.key,
    required this.field,
    required this.onValueChanged,
    this.initialValue,
  });

  @override
  State<DynamicFieldWidget> createState() => _DynamicFieldWidgetState();
}

class _DynamicFieldWidgetState extends State<DynamicFieldWidget> {
  late dynamic _currentValue;
  final TextEditingController _textController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  List<String> _photoPaths = [];
  bool _isCapturingPhoto = false;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue;

    // Inicializar controller de texto se for campo de texto
    if (widget.field.fieldType == 'text' ||
        widget.field.fieldType == 'textarea' ||
        widget.field.fieldType == 'number') {
      _textController.text = _currentValue?.toString() ?? '';
    }

    // Inicializar lista de fotos se houver
    if (widget.field.fieldType == 'photo' && _currentValue is List) {
      _photoPaths = List<String>.from(_currentValue);
    } else if (widget.field.fieldType == 'photo' && _currentValue is String && _currentValue.isNotEmpty) {
      _photoPaths = [_currentValue];
    }
  }

  /// Pede permissões mínimas para câmera sem atrasar o fluxo de captura.
  Future<bool> _requestCameraPermission() async {
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) return false;

    // Em Android antigos, algumas ROMs ainda exigem storage para anexar mídia.
    if (Platform.isAndroid) {
      final storage = await Permission.storage.request();
      if (storage.isPermanentlyDenied) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _updateValue(dynamic newValue) {
    setState(() {
      _currentValue = newValue;
    });
    widget.onValueChanged(widget.field.fieldName, newValue);
  }

  Widget _buildCheckboxField() {
    final bool value = _currentValue is bool ? _currentValue : false;
    final bool isRequired = widget.field.fieldConfig?.required ?? false;
    final primaryColor = Color(0xFF1E88E5);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
      child: CheckboxListTile(
        title: Row(
          children: [
            Text(
              widget.field.fieldLabel,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 15,
                color: isDark ? Colors.white : Colors.grey[900],
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(color: Colors.red, fontSize: 18),
              ),
          ],
        ),
        subtitle: isRequired ? Text('Obrigatório', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[600])) : null,
        value: value,
        onChanged: (bool? newValue) {
          _updateValue(newValue ?? false);
        },
        activeColor: primaryColor,
        checkColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  Widget _buildPhotoField() {
    final bool allowMultiple = widget.field.fieldConfig?.allowMultiple ?? false;
    final int maxPhotos = widget.field.fieldConfig?.maxPhotos ?? 1;
    final bool isRequired = widget.field.fieldConfig?.required ?? false;
    final primaryColor = Color(0xFF1E88E5);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.camera_alt, color: primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.field.fieldLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.grey[900],
                    ),
                  ),
                ),
                if (isRequired)
                  const Text(
                    '*',
                    style: TextStyle(color: Colors.red, fontSize: 18),
                  ),
              ],
            ),
            if (allowMultiple)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Até $maxPhotos fotos',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            const SizedBox(height: 12),
            
            // Mostrar fotos existentes
            if (_photoPaths.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _photoPaths.map((path) {
                  final isUrl = path.startsWith('http') || path.startsWith('/uploads');
                  final imageUrl = isUrl && !path.startsWith('http') 
                      ? 'https://agmerchandising.com$path' 
                      : path;
                      
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: isUrl
                            ? Image.network(
                                imageUrl,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.error, color: Colors.red),
                                  );
                                },
                              )
                            : Image.file(
                                File(path),
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                      ),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _photoPaths.remove(path);
                              _updateValue(allowMultiple ? _photoPaths : (_photoPaths.isNotEmpty ? _photoPaths.first : null));
                            });
                          },
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(Icons.close, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            
            const SizedBox(height: 8),
            
            // Botão para tirar foto
            if (!allowMultiple && _photoPaths.isEmpty || allowMultiple && _photoPaths.length < maxPhotos)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isCapturingPhoto ? null : () async {
                    bool dialogOpen = false;

                    if (mounted) {
                      setState(() {
                        _isCapturingPhoto = true;
                      });
                    }

                    void closeDialog() {
                      if (dialogOpen && mounted) {
                        Navigator.of(context, rootNavigator: true).pop();
                        dialogOpen = false;
                      }
                    }

                    try {
                      // Pedir permissão da câmera
                      final hasCameraPermission = await _requestCameraPermission();
                      if (!hasCameraPermission) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Permissao de camera negada'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                        return;
                      }

                      // Tirar foto
                      final XFile? photo = await _picker.pickImage(
                        source: ImageSource.camera,
                        preferredCameraDevice: CameraDevice.rear,
                        maxWidth: 1280,
                        maxHeight: 960,
                        imageQuality: 78,
                        requestFullMetadata: false,
                      );
                      if (photo != null) {
                        // Mostrar loading enquanto faz upload
                        if (mounted) {
                          dialogOpen = true;
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                          );
                        }

                        // Fazer upload direto para evitar decodificacao pesada
                        final imageFile = File(photo.path);
                        final uploadResult = await ApiService.uploadPhoto(imageFile);

                        closeDialog();

                        if (uploadResult != null && uploadResult['success'] == true) {
                          final photoUrl = uploadResult['photo_url'] as String;
                          
                          setState(() {
                            if (allowMultiple) {
                              _photoPaths.add(photoUrl); // Salva URL do servidor
                              _updateValue(_photoPaths);
                            } else {
                              _photoPaths = [photoUrl]; // Salva URL do servidor
                              _updateValue(photoUrl);
                            }
                          });

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✅ Foto enviada com sucesso!'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        } else {
                          throw Exception('Falha no upload da foto');
                        }
                      }
                    } catch (e) {
                      closeDialog();

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('❌ Erro ao enviar foto: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } finally {
                      if (mounted) {
                        setState(() {
                          _isCapturingPhoto = false;
                        });
                      }
                    }
                  },
                  icon: _isCapturingPhoto
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.camera_alt),
                  label: Text(_isCapturingPhoto ? 'Abrindo camera...' : 'Tirar Foto'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField() {
    final bool isRequired = widget.field.fieldConfig?.required ?? false;
    final bool isTextarea = widget.field.fieldType == 'textarea';
    final primaryColor = Color(0xFF1E88E5);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        child: TextField(
          controller: _textController,
          maxLines: isTextarea ? 4 : 1,
          style: TextStyle(color: isDark ? Colors.white : Colors.grey[900]),
          decoration: InputDecoration(
            labelText: widget.field.fieldLabel + (isRequired ? ' *' : ''),
            labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
            hintText: 'Digite aqui...',
            hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          onChanged: (value) {
            _updateValue(value);
          },
        ),
      ),
    );
  }

  Widget _buildNumberField() {
    final bool isRequired = widget.field.fieldConfig?.required ?? false;
    final int? min = widget.field.fieldConfig?.min;
    final int? max = widget.field.fieldConfig?.max;
    final primaryColor = Color(0xFF1E88E5);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        child: TextField(
          controller: _textController,
          keyboardType: TextInputType.number,
          style: TextStyle(color: isDark ? Colors.white : Colors.grey[900]),
          decoration: InputDecoration(
            labelText: widget.field.fieldLabel + (isRequired ? ' *' : ''),
            labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
            hintText: min != null && max != null ? 'Entre $min e $max' : 'Digite um número',
            hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          onChanged: (value) {
            final number = int.tryParse(value);
            _updateValue(number);
          },
        ),
      ),
    );
  }

  Widget _buildDateField() {
    final bool isRequired = widget.field.fieldConfig?.required ?? false;
    final primaryColor = Color(0xFF1E88E5);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    DateTime? selectedDate = _currentValue is DateTime ? _currentValue : (_currentValue is String ? DateTime.tryParse(_currentValue) : null);

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
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.calendar_today, color: primaryColor),
        ),
        title: Text(
          widget.field.fieldLabel + (isRequired ? ' *' : ''),
          style: TextStyle(color: isDark ? Colors.white : Colors.grey[900]),
        ),
        subtitle: Text(
          selectedDate != null
              ? DateFormat('dd/MM/yyyy').format(selectedDate)
              : 'Selecione uma data',
          style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600]),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 18, color: isDark ? Colors.grey[500] : Colors.grey[600]),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () async {
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: selectedDate ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked != null) {
            _updateValue(picked.toIso8601String());
          }
        },
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
