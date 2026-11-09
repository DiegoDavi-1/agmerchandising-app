import 'dart:async';

import 'package:flutter/material.dart';
import '../widgets/non_visit_reschedule_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../core/photo_quality.dart';
import 'package:image_picker/image_picker.dart';
import '../models/brand_field.dart';
import '../services/api_service.dart';
import '../services/collection_draft_storage.dart';
import '../widgets/dynamic_field_widget.dart';
import 'ponto_page.dart';
import 'store_expiries_page.dart';

/// Página para coleta dinâmica de dados baseado nos campos configurados da marca
class DynamicBrandCollectionPage extends StatefulWidget {
  final int brandId;
  final String brandName;
  final String? brandHeaderColor;
  final int? storeId;

  const DynamicBrandCollectionPage({
    super.key,
    required this.brandId,
    required this.brandName,
    this.brandHeaderColor,
    this.storeId,
  });

  @override
  State<DynamicBrandCollectionPage> createState() =>
      _DynamicBrandCollectionPageState();
}

class _DynamicBrandCollectionPageState
    extends State<DynamicBrandCollectionPage> {
  List<BrandField> _fields = [];
  Map<String, dynamic> _collectedData = {};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isGettingLocation = false;
  String? _errorMessage;
  String? _locationError;
  Position? _currentPosition;
  String? _resolvedAddress;
  bool _requiresVisitClock = false;
  bool _needsCheckIn = false;
  String? _draftKey;
  Timer? _draftTimer;
  bool _draftDone = false;

  @override
  void initState() {
    super.initState();
    _loadBrandFields();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    if (_draftTimer?.isActive == true) {
      _draftTimer!.cancel();
      _writeDraft();
    }
    super.dispose();
  }

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 400), _writeDraft);
  }

  void _writeDraft() {
    final key = _draftKey;
    if (key == null || _draftDone) return;
    CollectionDraftStorage.save(key, Map<String, dynamic>.of(_collectedData));
  }

  Future<void> _clearDraft() async {
    _draftDone = true;
    _draftTimer?.cancel();
    final key = _draftKey;
    if (key != null) await CollectionDraftStorage.clear(key);
  }

  static bool _hasContent(dynamic value) {
    if (value == null || value == false) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is Iterable) return value.isNotEmpty;
    if (value is Map) return value.values.any(_hasContent);
    return true;
  }

  Future<void> _getCurrentLocation() async {
    if (mounted) {
      setState(() {
        _isGettingLocation = true;
        _locationError = null;
      });
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Ative a localização do aparelho para continuar');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Permissão de localização negada');
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20),
      );

      // Geocoding reverso: converte coordenadas em endereço legivel
      try {
        final placemarks = await placemarkFromCoordinates(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final street = (p.thoroughfare ?? p.street ?? '').trim();
          final nameToken = (p.name ?? '').trim();
          final number = (p.subThoroughfare ?? '').trim().isNotEmpty
              ? (p.subThoroughfare ?? '').trim()
              : (RegExp(r'^\d+[A-Za-z0-9\-]*$').hasMatch(nameToken)
                  ? nameToken
                  : '');
          final district = (p.subLocality ?? '').trim();
          final city = ((p.locality ?? '').trim().isNotEmpty
              ? (p.locality ?? '').trim()
              : (p.subAdministrativeArea ?? '').trim());
          final state = (p.administrativeArea ?? '').trim();
          final postalCode = (p.postalCode ?? '').trim();

          final line1 = [
            if (street.isNotEmpty) street,
            if (number.isNotEmpty) number,
          ].join(', ');

          final cityUf = [
            if (city.isNotEmpty) city,
            if (state.isNotEmpty) state,
          ].join(' - ');

          final parts = <String>[
            if (line1.isNotEmpty) line1,
            if (district.isNotEmpty) district,
            if (cityUf.isNotEmpty) cityUf,
            if (postalCode.isNotEmpty) 'CEP $postalCode',
          ];

          _resolvedAddress = parts.isNotEmpty ? parts.join(', ') : null;
        }
      } catch (_) {
        _resolvedAddress = null;
      }
    } catch (e) {
      _currentPosition = null;
      _locationError = e.toString().replaceFirst('Exception: ', '');
      print('Erro ao obter localização: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
    }
  }

  Future<bool> _ensureLocationReady() async {
    if (_currentPosition != null) return true;

    await _getCurrentLocation();
    if (_currentPosition != null) return true;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_locationError ??
              'Localização obrigatória para salvar a coleta.'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return false;
  }

  Widget _buildLocationStrip(bool isDark) {
    final ok = _currentPosition != null;
    final color = ok ? const Color(0xFF16A34A) : Colors.orange;
    final text = ok
        ? 'Localização ok · ±${_currentPosition!.accuracy.toStringAsFixed(0)} m'
        : (_isGettingLocation
            ? 'Obtendo localização...'
            : (_locationError ?? 'Localização obrigatória para salvar'));
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(children: [
        Icon(ok ? Icons.my_location : Icons.location_off_outlined,
            color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Tooltip(
            message: _resolvedAddress ?? text,
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          ),
        ),
        TextButton(
          onPressed: _isGettingLocation ? null : _getCurrentLocation,
          child: _isGettingLocation
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Atualizar'),
        ),
      ]),
    );
  }

  Widget _buildNonVisitButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: OutlinedButton.icon(
        onPressed: _isSaving ? null : _registerNonVisit,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.orange.shade800,
          side: BorderSide(color: Colors.orange.shade700),
          minimumSize: const Size.fromHeight(48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.block),
        label: const Text('Não foi possível atender esta loja'),
      ),
    );
  }

  void _snack(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  Future<void> _registerNonVisit() async {
    List<Map<String, dynamic>> reasons;
    try {
      final res = await ApiService.fetchNonVisitReasons();
      reasons = (res['data'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      _snack('Não foi possível carregar os motivos. Verifique a internet.',
          color: Colors.red);
      return;
    }
    if (!mounted) return;
    if (reasons.isEmpty) {
      _snack('Nenhum motivo de não atendimento está cadastrado.',
          color: Colors.red);
      return;
    }

    bool flag(Map<String, dynamic> r, String k) =>
        r[k] == true || r[k] == 1 || r[k] == '1';

    final noteCtrl = TextEditingController();
    Map<String, dynamic>? selected;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final needsNote = selected != null && flag(selected!, 'requires_note');
          final needsPhoto =
              selected != null && flag(selected!, 'requires_photo');
          return Padding(
            padding: EdgeInsets.fromLTRB(
                16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Por que não foi possível atender?',
                      style: GoogleFonts.poppins(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  ...reasons.map((r) {
                    final tags = [
                      if (flag(r, 'requires_note')) 'pede justificativa',
                      if (flag(r, 'requires_photo')) 'pede foto',
                    ];
                    return RadioListTile<Map<String, dynamic>>(
                      contentPadding: EdgeInsets.zero,
                      value: r,
                      groupValue: selected,
                      title: Text(r['name']?.toString() ?? ''),
                      subtitle: tags.isEmpty ? null : Text(tags.join(' · ')),
                      onChanged: (v) => setSheet(() => selected = v),
                    );
                  }),
                  if (selected != null) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: needsNote
                            ? 'Justificativa (obrigatória)'
                            : 'Observação (opcional)',
                        helperText: selected!['instructions']?.toString(),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (needsPhoto)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                            '📷 Ao confirmar, a câmera abre para a foto de evidência.'),
                      ),
                  ],
                  const SizedBox(height: 14),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange.shade800,
                        minimumSize: const Size.fromHeight(48)),
                    onPressed: selected == null
                        ? null
                        : () {
                            if (needsNote && noteCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Este motivo exige justificativa.')));
                              return;
                            }
                            Navigator.pop(ctx, true);
                          },
                    child: const Text('Registrar não atendimento'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    final note = noteCtrl.text.trim();
    noteCtrl.dispose();
    if (confirmed != true || selected == null || !mounted) return;
    final reason = selected!;

    if (!await _ensureLocationReady()) return;
    setState(() => _isSaving = true);
    try {
      String? photoUrl;
      if (flag(reason, 'requires_photo')) {
        final file = await PhotoQuality.captureChecked(
            context, ImagePicker(), 'Não atendimento');
        if (file == null) {
          _snack('Este motivo exige uma foto de evidência.',
              color: Colors.red);
          return;
        }
        final upload = await ApiService.uploadPhoto(file);
        photoUrl = upload?['photo_url']?.toString();
        if (photoUrl == null) throw Exception('Falha ao enviar a foto.');
      }
      final result = await ApiService.saveNonVisit({
        'brand_id': widget.brandId,
        'store_id': widget.storeId,
        'reason_id': reason['id'],
        'note': note,
        'photo_url': photoUrl,
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
        'location_address': _resolvedAddress ??
            '${_currentPosition!.latitude}, ${_currentPosition!.longitude}',
      });
      await _clearDraft();
      if (!mounted) return;
      final needsClockOut =
          result['requires_clock_out'] == true && widget.storeId != null;
      _snack(
          needsClockOut
              ? 'Não atendimento registrado. Agora registre a saída desta loja.'
              : '✅ Não atendimento registrado.',
          color: Colors.green);
      if (widget.storeId != null) {
        final sent = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => NonVisitRescheduleDialog(
            onSubmit: (date) async {
              await ApiService.requestNonVisitReschedule(
                  (result['id'] as num).toInt(), date);
            },
          ),
        );
        if (!mounted) return;
        if (sent == true) {
          _snack('Remarcação enviada. Aguarde a aprovação do administrador.',
              color: Colors.green);
        }
      }
      if (needsClockOut) {
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => PontoPage(
              initialStoreId: widget.storeId,
              initialBrandId: widget.brandId,
              requiredAction: 'saida',
            ),
          ),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _snack('❌ ${e.toString().replaceFirst('Exception: ', '')}',
          color: Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildExpiriesShortcut() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ListTile(
        leading: const Icon(Icons.event_busy, color: Colors.orange),
        title: const Text('Validades desta loja',
            style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text(
            'Opcional: anote produtos vencidos ou perto do vencimento.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoreExpiriesPage(
              storeId: widget.storeId!,
              brandId: widget.brandId,
              brandName: widget.brandName,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadBrandFields() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.storeId != null) {
        final visitStatus =
            await ApiService.fetchVisitStatus(widget.storeId!, widget.brandId);
        if (visitStatus['success'] != true) {
          throw Exception(visitStatus['error'] ??
              'Não foi possível validar a entrada desta loja.');
        }
        _requiresVisitClock = visitStatus['requires_check_in_out'] == true;
        _needsCheckIn = _requiresVisitClock && visitStatus['is_open'] != true;
        if (_needsCheckIn) {
          setState(() => _isLoading = false);
          return;
        }
      }

      final fieldsJson = await ApiService.getBrandFields(widget.brandId,
          storeId: widget.storeId);
      final loadedFields = fieldsJson
          .map((json) => BrandField.fromJson(json))
          .toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

      final seenNames = <String>{};
      final duplicateNames = <String>{};
      for (final field in loadedFields) {
        if (!seenNames.add(field.fieldName)) {
          duplicateNames.add(field.fieldName);
        }
      }

      if (duplicateNames.isNotEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Configuração inválida: existem campos com nome técnico duplicado (${duplicateNames.join(', ')}). Corrija no painel admin antes de coletar.';
        });
        return;
      }

      final defaults = <String, dynamic>{};
      for (var field in loadedFields) {
        if (field.fieldType == 'checkbox') {
          defaults[field.fieldName] = false;
        } else if (field.fieldType == 'photo' &&
            field.fieldConfig?.allowMultiple == true) {
          defaults[field.fieldName] = [];
        } else if (field.fieldType == 'product' &&
            field.fieldConfig?.allowMultiple == true) {
          defaults[field.fieldName] = [];
        }
      }

      // Recupera o atendimento em andamento (ex.: app fechado pelo Android na câmera).
      final user = await ApiService.getUserData();
      final draftKey = CollectionDraftStorage.key(
          user?['id'], widget.brandId, widget.storeId);
      final draft = await CollectionDraftStorage.load(draftKey);
      final names = loadedFields.map((f) => f.fieldName).toSet();
      final restored = <String, dynamic>{
        for (final entry in (draft ?? const <String, dynamic>{}).entries)
          if (names.contains(entry.key)) entry.key: entry.value,
      };
      if (!mounted) return;

      setState(() {
        _fields = loadedFields;
        _collectedData.addAll(defaults);
        _collectedData.addAll(restored);
        _draftKey = draftKey;
        _draftDone = false;
        _isLoading = false;
      });

      if (restored.values.any(_hasContent)) {
        _snack('Recuperamos o atendimento que estava em andamento.',
            color: Colors.teal.shade700);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro ao carregar campos: $e';
      });
    }
  }

  bool _validateRequiredFields() {
    for (var field in _fields) {
      final value = _collectedData[field.fieldName];

      if (field.fieldType == 'photo_text') {
        if (field.fieldConfig?.required == true) {
          final photo = (value is Map) ? value['photo'] : null;
          final hasPhoto = photo != null && photo.toString().trim().isNotEmpty;
          if (!hasPhoto) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Foto obrigatória não preenchida: ${field.fieldLabel}'),
                backgroundColor: Colors.red,
              ),
            );
            return false;
          }
        }

        if (field.fieldConfig?.requiredText == true) {
          final text = (value is Map) ? value['text'] : null;
          final hasText = text != null && text.toString().trim().isNotEmpty;
          if (!hasText) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Texto obrigatório não preenchido: ${field.fieldLabel}'),
                backgroundColor: Colors.red,
              ),
            );
            return false;
          }
        }

        continue;
      }

      if (field.fieldConfig?.required == true) {
        // Validar se campo obrigatório está preenchido
        if (value == null ||
            (value is String && value.isEmpty) ||
            (value is List && value.isEmpty) ||
            (field.fieldType == 'shelf_space' &&
                value is List &&
                !value.any((entry) => entry is Map && entry['facings'] != null)) ||
            (value is bool &&
                value == false &&
                field.fieldType == 'checkbox')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Campo obrigatório não preenchido: ${field.fieldLabel}'),
              backgroundColor: Colors.red,
            ),
          );
          return false;
        }
      }
    }
    return true;
  }

  Future<void> _saveCollection() async {
    if (!_validateRequiredFields()) {
      return;
    }

    if (!await _ensureLocationReady()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final result = await ApiService.saveCollection(
        brandId: widget.brandId,
        collectedData: _collectedData,
        brandName: widget.brandName,
        storeId: widget.storeId,
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        locationAddress: _resolvedAddress ??
            (_currentPosition != null
                ? '${_currentPosition!.latitude}, ${_currentPosition!.longitude}'
                : null),
        requiresVisitClock: _requiresVisitClock,
      );

      if (mounted) {
        if (result['success'] == true) {
          await _clearDraft();
          final isOffline = result['offline'] == true;

          if (isOffline) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      '📴 Salvo offline. Será enviado quando houver conexão.'),
                  backgroundColor: Colors.orange,
                ),
              );
              Navigator.of(context).pop(true);
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Atendimento enviado com sucesso!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
            if (mounted) {
              if (result['requires_clock_out'] == true &&
                  widget.storeId != null) {
                final clockedOut = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PontoPage(
                      initialStoreId: widget.storeId,
                      initialBrandId: widget.brandId,
                      requiredAction: 'saida',
                    ),
                  ),
                );
                if (!mounted) return;
                if (clockedOut != true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'O atendimento foi salvo, mas ainda falta registrar a saída.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
              }
              Navigator.of(context).pop(true);
            }
          }
        } else {
          final message =
              result['error']?.toString() ?? 'Erro ao salvar coleta';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ $message'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Parse brand color from hex string, fallback to primary blue
    Color brandColor = const Color(0xFF0F766E);
    if (widget.brandHeaderColor != null &&
        widget.brandHeaderColor!.isNotEmpty) {
      try {
        final hexColor = widget.brandHeaderColor!.replaceFirst('#', '');
        brandColor = Color(int.parse('FF$hexColor', radix: 16));
      } catch (e) {
        // Keep default color if parsing fails
      }
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1419) : Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.brandName,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        backgroundColor: isDark ? const Color(0xFF1A1F2E) : brandColor,
        foregroundColor: Colors.white,
        elevation: 8,
        shadowColor: isDark
            ? Colors.black.withValues(alpha: 0.3)
            : brandColor.withValues(alpha: 0.4),
        actions: [
          if (!_isLoading && _fields.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadBrandFields,
              tooltip: 'Recarregar campos',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Carregando campos da marca...'),
                ],
              ),
            )
          : _needsCheckIn
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_clock,
                            size: 64, color: Colors.orange),
                        const SizedBox(height: 16),
                        const Text(
                          'Registre a entrada para começar',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Esta loja exige entrada e saída para liberar o Plano de Tarefas.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final registered = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PontoPage(
                                  initialStoreId: widget.storeId,
                                  initialBrandId: widget.brandId,
                                  requiredAction: 'entrada',
                                ),
                              ),
                            );
                            if (registered == true && mounted) {
                              await _loadBrandFields();
                            }
                          },
                          icon: const Icon(Icons.login),
                          label: const Text('Registrar Entrada'),
                        ),
                      ],
                    ),
                  ),
                )
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadBrandFields,
                            child: const Text('Tentar Novamente'),
                          ),
                        ],
                      ),
                    )
                  : _fields.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.info_outline,
                                  size: 64, color: Colors.orange),
                              SizedBox(height: 16),
                              Text(
                                'Esta marca não tem campos configurados.',
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Configure campos no Admin Dashboard primeiro.',
                                style:
                                    TextStyle(fontSize: 12, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            // Lista de campos
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.only(bottom: 12),
                                itemCount: _fields.length +
                                    (widget.storeId != null ? 1 : 0) +
                                    2,
                                itemBuilder: (context, index) {
                                  if (index == 0) {
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: _buildLocationStrip(isDark),
                                    );
                                  }
                                  index -= 1;
                                  if (widget.storeId != null) {
                                    if (index == 0) {
                                      return _buildExpiriesShortcut();
                                    }
                                    index -= 1;
                                  }
                                  if (index == _fields.length) {
                                    return _buildNonVisitButton();
                                  }
                                  final field = _fields[index];
                                  return DynamicFieldWidget(
                                    field: field,
                                    initialValue:
                                        _collectedData[field.fieldName],
                                    onValueChanged: (fieldName, value) {
                                      setState(() {
                                        _collectedData[fieldName] = value;
                                      });
                                      _scheduleDraftSave();
                                    },
                                  );
                                },
                              ),
                            ),

                            // Botão de salvar
                            Container(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1A1F2E)
                                    : Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withOpacity(isDark ? 0.3 : 0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, -2),
                                  ),
                                ],
                              ),
                              child: SafeArea(
                                child: Row(
                                  children: [
                                    // Botão Salvar
                                    Expanded(
                                      child: SizedBox(
                                        height: 52,
                                        child: ElevatedButton(
                                          onPressed:
                                              _isSaving
                                                  ? null
                                                  : _saveCollection,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: brandColor,
                                            foregroundColor: Colors.white,
                                            disabledBackgroundColor:
                                                Colors.grey[300],
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: _isSaving
                                              ? const SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2.5,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                                Color>(
                                                            Colors.white),
                                                  ),
                                                )
                                              : const Text(
                                                  'Salvar Coleta',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
    );
  }
}
