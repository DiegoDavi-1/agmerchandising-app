import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../core/photo_standard.dart';
import '../core/theme/app_theme.dart';

/// Tela de "Ponto" — registro de entrada/saída com foto e geolocalização.
/// Equivalente à aba "Ponto" do PWA do promotor (ponto.js).
class PontoPage extends StatefulWidget {
  final int? initialStoreId;
  final int? initialBrandId;
  final String? requiredAction;

  const PontoPage({
    super.key,
    this.initialStoreId,
    this.initialBrandId,
    this.requiredAction,
  });

  @override
  State<PontoPage> createState() => _PontoPageState();
}

class _PontoPageState extends State<PontoPage> {
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isRegistering = false;
  bool _isClockedIn = false;
  Map<String, dynamic>? _lastEntry;
  List<dynamic> _history = [];
  List<dynamic> _todayStores;
  int? _selectedStoreId;
  bool _storesLoadFailed = false;

  _PontoPageState() : _todayStores = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        widget.initialStoreId != null && widget.initialBrandId != null
            ? ApiService.fetchVisitStatus(
                widget.initialStoreId!, widget.initialBrandId!)
            : ApiService.fetchClockStatus(),
        ApiService.fetchClockHistory(perPage: 5),
        ApiService.fetchClockTodayStores(),
      ]);

      final statusRes = results[0];
      final historyRes = results[1];
      final storesRes = results[2];

      if (statusRes['success'] == true) {
        _isClockedIn = widget.initialStoreId != null
            ? statusRes['is_open'] == true
            : statusRes['isClockedIn'] == true;
        _lastEntry = (widget.initialStoreId != null
            ? statusRes['last_entry']
            : statusRes['lastEntry']) as Map<String, dynamic>?;
      }
      if (historyRes['success'] == true && historyRes['data'] is List) {
        _history = historyRes['data'] as List<dynamic>;
      }
      if (storesRes['success'] == true && storesRes['stores'] is List) {
        _todayStores = storesRes['stores'] as List<dynamic>;
        if (widget.initialStoreId != null &&
            !_todayStores.any((store) =>
                (store['store_id'] as num?)?.toInt() ==
                widget.initialStoreId)) {
          _todayStores = [
            ..._todayStores,
            {
              'store_id': widget.initialStoreId,
              'store_name': statusRes['store_name'] ?? 'Loja do atendimento',
            }
          ];
        }
        _storesLoadFailed = false;
        _selectedStoreId = widget.initialStoreId ??
            (_todayStores.isNotEmpty
                ? (_todayStores.first['store_id'] as num?)?.toInt()
                : null);
      } else {
        // Falha real ao consultar a escala do dia — não tratamos como "sem
        // lojas escaladas", pois isso liberaria o ponto sem seleção de loja.
        _storesLoadFailed = true;
      }
    } catch (_) {
      // Mantém a tela utilizável mesmo se alguma chamada falhar, mas bloqueia
      // o registro caso a falha tenha impedido carregar a escala de hoje.
      _storesLoadFailed = true;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Position> _getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
          'Ative a localização do aparelho para registrar a entrada/saída.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Permissão de localização negada.');
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 20),
    );
  }

  Future<String> _reverseGeocode(double lat, double lon) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [
          p.thoroughfare ?? p.street ?? '',
          p.subLocality ?? '',
          p.locality ?? p.subAdministrativeArea ?? '',
        ].where((s) => s.trim().isNotEmpty).join(', ');
        if (parts.isNotEmpty) return parts;
      }
    } catch (_) {}
    return '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';
  }

  Future<void> _registerClock() async {
    setState(() => _isRegistering = true);
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: PhotoStandard.clockMaxSide,
        maxHeight: PhotoStandard.clockMaxSide,
        imageQuality: PhotoStandard.clockQuality,
      );
      if (photo == null) {
        setState(() => _isRegistering = false);
        return;
      }

      final position = await _getCurrentPosition();
      final address =
          await _reverseGeocode(position.latitude, position.longitude);
      final type = _isClockedIn ? 'saida' : 'entrada';

      final result = await ApiService.clockIn(
        type: type,
        latitude: position.latitude,
        longitude: position.longitude,
        location: address,
        accuracy: position.accuracy,
        isMockLocation: position.isMocked,
        photoFile: File(photo.path),
        storeId: _selectedStoreId,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        if (type == 'saida') await LocationService().stopTracking();
        await LocationService().synchronize();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(type == 'entrada'
                ? 'Entrada registrada com sucesso!'
                : 'Saída registrada com sucesso!'),
            backgroundColor: AppColors.success,
          ),
        );
        if (widget.requiredAction != null) {
          Navigator.of(context).pop(true);
        } else {
          await _loadData();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(result['error']?.toString() ?? 'Erro ao registrar entrada/saída'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(widget.requiredAction == 'saida' ? 'Saída da loja' : 'Entrada na loja',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: isDark ? AppColors.cardDark : AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatusCard(isDark),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Durante o atendimento, sua localização é compartilhada '
                      'com o administrador a cada minuto, inclusive com a tela '
                      'apagada no Android. O compartilhamento termina no check-out.',
                    ),
                  ),
                  ValueListenableBuilder<String>(
                    valueListenable: LocationService().status,
                    builder: (context, status, _) => Text(status),
                  ),
                  if (_storesLoadFailed) ...[
                    const SizedBox(height: 16),
                    _buildStoresLoadFailedCard(isDark),
                  ] else if (_todayStores.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildStoreSelector(isDark),
                  ],
                  const SizedBox(height: 20),
                  _buildRegisterButton(),
                  const SizedBox(height: 24),
                  Text(
                    'Suas últimas entradas e saídas',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_history.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Nenhuma entrada ou saída registrada ainda.',
                        style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54),
                      ),
                    )
                  else
                    ..._history.map((h) => _buildHistoryItem(h, isDark)),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isClockedIn
              ? [AppColors.success, AppColors.success.withValues(alpha: 0.7)]
              : [AppColors.primary, AppColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_isClockedIn ? Icons.timer : Icons.timer_off,
              color: Colors.white, size: 32),
          const SizedBox(height: 8),
          Text(
            _isClockedIn
                ? 'Visita em andamento nesta loja'
                : 'Visita ainda não iniciada',
            style: GoogleFonts.poppins(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          if (_lastEntry != null) ...[
            const SizedBox(height: 4),
            Text(
              'Última marcação: ${_lastEntry!['created_at'] ?? '-'}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStoreSelector(bool isDark) {
    return DropdownButtonFormField<int>(
      initialValue: _selectedStoreId,
      decoration: InputDecoration(
        labelText: 'Loja do roteiro de hoje',
        filled: true,
        fillColor: isDark ? AppColors.cardDark : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: _todayStores
          .map((s) => DropdownMenuItem<int>(
                value: (s['store_id'] as num?)?.toInt(),
                child: Text(
                  s['store_name']?.toString() ?? 'Loja',
                  overflow: TextOverflow.ellipsis,
                ),
              ))
          .toList(),
      onChanged: widget.initialStoreId != null
          ? null
          : (value) => setState(() => _selectedStoreId = value),
    );
  }

  Widget _buildStoresLoadFailedCard(bool isDark) {
    return Card(
      color: isDark ? AppColors.cardDark : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.error),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚠️ Não foi possível verificar sua escala de hoje',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'Não conseguimos confirmar em quais lojas você está escalado hoje. '
              'Por segurança, o registro de entrada/saída fica bloqueado até isso ser confirmado.',
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : AppColors.textLight),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed:
            (_isRegistering || _storesLoadFailed || _selectedStoreId == null)
                ? null
                : _registerClock,
        icon: _isRegistering
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.camera_alt),
        label: Text(_isClockedIn ? 'Registrar Saída' : 'Registrar Entrada'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isClockedIn ? AppColors.error : AppColors.primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(dynamic entry, bool isDark) {
    final type = entry['type']?.toString() ?? '';
    final isEntry = type == 'entrada';
    return Card(
      color: isDark ? AppColors.cardDark : Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          isEntry ? Icons.login : Icons.logout,
          color: isEntry ? AppColors.success : AppColors.warning,
        ),
        title: Text(isEntry ? 'Entrada' : 'Saída'),
        subtitle: Text(entry['location']?.toString() ??
            entry['created_at']?.toString() ??
            ''),
        trailing: Text(
          (entry['created_at']?.toString() ?? '')
              .split('T')
              .last
              .split('.')
              .first,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}
