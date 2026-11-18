import 'dart:async';
import 'dart:io';
import 'dart:convert';

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
import '../services/photo_outbox.dart';
import '../services/offline_clock.dart';
import '../core/network/connectivity_service.dart';
import '../core/logging/app_logger_v2.dart';
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
  String? _submissionId;
  Map<String, dynamic>? _submissionRequest;
  Map<String, dynamic>? _submissionResult;
  List<Map<String, Object?>> _photoJobs = [];
  int _photoRevision = 0;

  @override
  void initState() {
    super.initState();
    if (PhotoOutbox.isSupported) {
      PhotoOutbox.instance.addListener(_photosChanged);
    }
    _loadBrandFields();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    if (PhotoOutbox.isSupported) {
      PhotoOutbox.instance.removeListener(_photosChanged);
      unawaited(PhotoOutbox.instance
          .closeAttendance(widget.brandId, widget.storeId)
          .catchError((Object error, StackTrace stack) {
        appLogger.error('Falha ao encerrar rota de recuperacao',
            error: error, stackTrace: stack);
      }));
    }
    if (_draftTimer?.isActive == true) {
      _draftTimer!.cancel();
      unawaited(_writeDraft().catchError((Object error, StackTrace stack) {
        appLogger.error('Falha ao gravar rascunho',
            error: error, stackTrace: stack);
      }));
    }
    super.dispose();
  }

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(_writeDraft().catchError((Object error, StackTrace stack) {
        appLogger.error('Falha ao gravar rascunho',
            error: error, stackTrace: stack);
        if (mounted) _snack('Nao foi possivel salvar o rascunho: $error');
      }));
    });
  }

  Future<void> _writeDraft() async {
    final key = _draftKey;
    if (key == null || _draftDone) return;
    await CollectionDraftStorage.save(
        key, Map<String, dynamic>.of(_collectedData),
        submissionId: _submissionId,
        submissionRequest: _submissionRequest,
        submissionResult: _submissionResult);
  }

  Future<void> _clearDraft({bool offline = false}) async {
    _draftTimer?.cancel();
    if (PhotoOutbox.isSupported) {
      final ids = List<String>.from(
          _submissionRequest?['photo_job_ids'] ?? const <String>[]);
      await PhotoOutbox.instance
          .submitJobs(ids, widget.brandId, widget.storeId);
      if (!offline) {
        await PhotoOutbox.instance.completeSubmitted(ids);
      }
    }
    final key = _draftKey;
    if (key != null) await CollectionDraftStorage.clear(key);
    _draftDone = true;
  }

  void _photosChanged() {
    unawaited(_refreshPhotoJobs().catchError((Object error, StackTrace stack) {
      appLogger.error('Falha ao atualizar fotos locais',
          error: error, stackTrace: stack);
      if (mounted) _snack('Nao foi possivel recuperar as fotos locais: $error');
    }));
  }

  Future<void> _refreshPhotoJobs() async {
    final revision = ++_photoRevision;
    final jobs =
        await PhotoOutbox.instance.jobs(widget.brandId, widget.storeId);
    if (!mounted ||
        _isLoading ||
        _submissionResult != null ||
        revision != _photoRevision) {
      return;
    }
    final names = _fields.map((field) => field.fieldName).toSet();
    final merged = PhotoOutbox.merge(_collectedData,
        jobs.where((job) => names.contains(job['field_name'])).toList());
    final changed = jsonEncode(merged) != jsonEncode(_collectedData);
    setState(() {
      _photoJobs = jobs;
      _collectedData = merged;
    });
    if (changed) await _writeDraft();
  }

  Future<void> _reviewRecoveredPhotos() async {
    final outbox = PhotoOutbox.instance;
    for (final job in await outbox.jobs(widget.brandId, widget.storeId)) {
      if (job['status'] != 'review' || job['local_path'] is! String) continue;
      if (!mounted) return;
      try {
        await outbox.ensureTimeProof(
            job['id'] as String, File(job['local_path'] as String));
      } catch (error) {
        if (!mounted) return;
        final redo = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Horário da foto não verificado'),
            content: Text('$error\n\nReconecte-se e tente novamente. '
                'Se a referência expirou, será necessário refazer a foto.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Manter foto')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Refazer foto')),
            ],
          ),
        );
        if (redo == true) {
          await outbox.cancel(job['id'] as String);
          if (mounted) _snack('Toque em Tirar Foto para refazer a foto.');
        }
        continue;
      }
      if (!mounted) return;
      final accepted = await PhotoQuality.reviewFile(context,
          File(job['local_path'] as String), job['field_label'] as String);
      if (!mounted) return;
      if (accepted == null) {
        await outbox.cancel(job['id'] as String);
        _snack('Toque em Tirar Foto para refazer a foto recuperada.');
      } else {
        await outbox.ready(job['id'] as String, accepted);
      }
    }
    await _refreshPhotoJobs();
    outbox.retry();
  }

  Widget _buildPhotoQueueStrip() {
    final hasReview = _photoJobs.any((job) => job['status'] == 'review');
    final pending = _photoJobs
        .where((job) => job['status'] == 'queued' || job['status'] == 'review')
        .length;
    final error = PhotoOutbox.instance.lastError;
    if (pending == 0 && error == null) return const SizedBox.shrink();
    return Material(
      color: Colors.amber.shade50,
      child: ListTile(
        leading: const Icon(Icons.cloud_upload_outlined, color: Colors.orange),
        title: Text(pending == 1
            ? '1 foto salva no aparelho, aguardando envio.'
            : '$pending fotos salvas no aparelho, aguardando envio.'),
        subtitle: error == null ? null : Text(error),
        trailing: TextButton(
          onPressed: hasReview
              ? () => unawaited(_reviewRecoveredPhotos())
              : PhotoOutbox.instance.retry,
          child: Text(hasReview ? 'Revisar' : 'Reenviar'),
        ),
      ),
    );
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
          final needsNote =
              selected != null && flag(selected!, 'requires_note');
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
          _snack('Este motivo exige uma foto de evidência.', color: Colors.red);
          return;
        }
        final upload =
            await ApiService.uploadPhoto(file, requireTimeProof: true);
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
      final user = await ApiService.getUserData();
      final draftKey = CollectionDraftStorage.key(
          user?['id'], widget.brandId, widget.storeId);
      final session = await CollectionDraftStorage.loadSession(draftKey);
      _draftKey = draftKey;
      _submissionId = session?.submissionId ?? ApiService.createSubmissionId();
      _submissionRequest = session?.submissionRequest;
      _submissionResult = session?.submissionResult;
      _draftDone = false;
      if (_submissionResult != null) {
        if (!mounted) return;
        setState(() {
          _collectedData = session!.data;
          _needsCheckIn = false;
          _isLoading = false;
        });
        return;
      }
      if (widget.storeId != null) {
        final visitStatus =
            await ApiService.fetchVisitStatus(widget.storeId!, widget.brandId);
        if (visitStatus['success'] != true) {
          throw Exception(visitStatus['error'] ??
              'Não foi possível validar a entrada desta loja.');
        }
        _requiresVisitClock = visitStatus['requires_check_in_out'] == true;
        _needsCheckIn = _submissionRequest == null &&
            _requiresVisitClock &&
            visitStatus['is_open'] != true;
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
      final draft = session?.data;
      final names = loadedFields.map((f) => f.fieldName).toSet();
      final restored = <String, dynamic>{
        for (final entry in (draft ?? const <String, dynamic>{}).entries)
          if (_submissionRequest != null || names.contains(entry.key))
            entry.key: entry.value,
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

      if (PhotoOutbox.isSupported) {
        await PhotoOutbox.instance
            .openAttendance(widget.brandId, widget.brandName, widget.storeId);
        await _reviewRecoveredPhotos();
      }

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
                !value.any(
                    (entry) => entry is Map && entry['facings'] != null)) ||
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
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      if (_submissionResult != null) {
        await _writeDraft();
        await _finishSavedCollection();
        return;
      }
      if (_submissionRequest == null) {
        if (!_validateRequiredFields() || !await _ensureLocationReady()) return;
        final eventTime = await OfflineClock.capture(ApiService.token);
        final online = await ConnectivityService().isOnline();
        if (PhotoOutbox.isSupported) {
          await _writeDraft();
          if (online) await PhotoOutbox.instance.sync();
          await _refreshPhotoJobs();
          if (_photoJobs.any((job) =>
              (online && job['status'] == 'queued') ||
              job['status'] == 'review' ||
              job['status'] == 'capturing')) {
            throw StateError(
                'As fotos estao salvas no aparelho. Aguarde o envio antes de concluir.');
          }
        }
        _submissionRequest = {
          'data': jsonDecode(jsonEncode(_collectedData)),
          'latitude': _currentPosition?.latitude,
          'longitude': _currentPosition?.longitude,
          'location_address': _resolvedAddress,
          'requires_visit_clock': _requiresVisitClock,
          'event_time': eventTime,
          'photo_job_ids':
              _photoJobs.map((job) => job['id'] as String).toList(),
        };
      }
      await _writeDraft();
      final request = _submissionRequest!;
      final result = await ApiService.saveCollection(
        brandId: widget.brandId,
        collectedData: Map<String, dynamic>.from(request['data'] as Map),
        brandName: widget.brandName,
        storeId: widget.storeId,
        latitude: (request['latitude'] as num?)?.toDouble(),
        longitude: (request['longitude'] as num?)?.toDouble(),
        locationAddress: request['location_address'] as String?,
        requiresVisitClock: request['requires_visit_clock'] == true,
        eventTime: Map<String, dynamic>.from(request['event_time'] as Map),
        photoJobIds: List<String>.from(request['photo_job_ids'] as List),
        submissionId: _submissionId,
      );

      if (result['success'] == true) {
        _submissionResult = Map<String, dynamic>.from(result);
        await _writeDraft();
        if (mounted) setState(() {});
        await _finishSavedCollection();
      } else {
        final status = result['status'];
        if (status is int &&
            status >= 400 &&
            status < 500 &&
            status != 408 &&
            status != 409) {
          _submissionRequest = null;
          await _writeDraft();
        }
        if (mounted) {
          _snack(result['error']?.toString() ??
              'Nao foi possivel confirmar o envio. Tente novamente; o rascunho foi preservado.');
        }
      }
    } catch (e, stack) {
      appLogger.error('Falha ao concluir atendimento',
          error: e, stackTrace: stack);
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

  Future<void> _finishSavedCollection() async {
    final result = _submissionResult!;
    if (result['offline'] != true &&
        result['requires_clock_out'] == true &&
        widget.storeId != null) {
      final status =
          await ApiService.fetchVisitStatus(widget.storeId!, widget.brandId);
      if (status['success'] != true) {
        throw StateError(status['error']?.toString() ??
            'Atendimento salvo. Nao foi possivel verificar a saida.');
      }
      final savedEntry = result['clock_in_id'];
      if (status['is_open'] == true &&
          (savedEntry == null || savedEntry == status['clock_in_id'])) {
        if (!mounted) return;
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
        if (!mounted || clockedOut != true) {
          if (mounted) {
            _snack(
                'Atendimento salvo. Falta registrar a saida; nao envie novamente.',
                color: Colors.orange);
          }
          return;
        }
      }
    }
    await _clearDraft(offline: result['offline'] == true);
    if (!mounted) return;
    _snack(
        result['offline'] == true
            ? 'Salvo offline. Sera sincronizado sem criar outro atendimento.'
            : 'Atendimento enviado com sucesso!',
        color: result['offline'] == true ? Colors.orange : Colors.green);
    Navigator.of(context).pop(true);
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
          if (!_isLoading &&
              !_isSaving &&
              _submissionRequest == null &&
              _submissionResult == null &&
              _fields.isNotEmpty)
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
                  : _submissionResult != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle,
                                    size: 64, color: Colors.green),
                                const SizedBox(height: 16),
                                const Text(
                                  'Atendimento salvo. Nao e necessario reenviar as fotos.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: _isSaving ? null : _saveCollection,
                                  child: Text(_isSaving
                                      ? 'Aguarde...'
                                      : _submissionResult?[
                                                  'requires_clock_out'] ==
                                              true
                                          ? 'Registrar saida'
                                          : 'Concluir'),
                                ),
                              ],
                            ),
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
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                if (_submissionRequest != null)
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text(
                                      'Envio aguardando confirmacao. Os dados estao protegidos; tente novamente sem criar outro atendimento.',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                if (PhotoOutbox.isSupported)
                                  _buildPhotoQueueStrip(),
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
                                        if (_submissionRequest != null) {
                                          return const SizedBox.shrink();
                                        }
                                        return _buildNonVisitButton();
                                      }
                                      final field = _fields[index];
                                      return AbsorbPointer(
                                        absorbing: _isSaving ||
                                            _submissionRequest != null,
                                        child: DynamicFieldWidget(
                                          key: ValueKey(field.fieldName),
                                          field: field,
                                          brandName: widget.brandName,
                                          storeId: widget.storeId,
                                          persistDraft: _writeDraft,
                                          initialValue:
                                              _collectedData[field.fieldName],
                                          onValueChanged: (fieldName, value) {
                                            _photoRevision++;
                                            setState(() {
                                              _collectedData[fieldName] = value;
                                            });
                                            _scheduleDraftSave();
                                          },
                                        ),
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
                                              onPressed: _isSaving
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
                                                  : Text(
                                                      _submissionRequest != null
                                                          ? 'Tentar envio novamente'
                                                          : 'Salvar Coleta',
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w600,
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
