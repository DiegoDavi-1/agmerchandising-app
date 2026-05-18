import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/brand_field.dart';
import '../services/api_service.dart';
import '../services/collection_pdf_service.dart';
import '../widgets/dynamic_field_widget.dart';

/// Página para coleta dinâmica de dados baseado nos campos configurados da marca
class DynamicBrandCollectionPage extends StatefulWidget {
  final int brandId;
  final String brandName;
  final String? brandHeaderColor;
  final int? storeId;
  final String? storeName;

  const DynamicBrandCollectionPage({
    super.key,
    required this.brandId,
    required this.brandName,
    this.brandHeaderColor,
    this.storeId,
    this.storeName,
  });

  @override
  State<DynamicBrandCollectionPage> createState() => _DynamicBrandCollectionPageState();
}

class _DynamicBrandCollectionPageState extends State<DynamicBrandCollectionPage> {
  List<BrandField> _fields = [];
  Map<String, dynamic> _collectedData = {};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isGeneratingPdf = false;
  bool _isGettingLocation = false;
  String? _errorMessage;
  String? _locationError;
  Position? _currentPosition;
  String? _resolvedAddress;

  @override
  void initState() {
    super.initState();
    _loadBrandFields();
    _getCurrentLocation();
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
          final parts = [
            if ((p.street ?? '').isNotEmpty) p.street,
            if ((p.subLocality ?? '').isNotEmpty) p.subLocality,
            if ((p.locality ?? '').isNotEmpty) p.locality,
            if ((p.administrativeArea ?? '').isNotEmpty) p.administrativeArea,
          ];
          _resolvedAddress = parts.where((s) => s != null && s.isNotEmpty).join(', ');
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
          content: Text(_locationError ?? 'Localização obrigatória para salvar a coleta.'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return false;
  }

  Future<void> _loadBrandFields() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final fieldsJson = await ApiService.getBrandFields(widget.brandId, storeId: widget.storeId);
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
          _errorMessage = 'Configuração inválida: existem campos com nome técnico duplicado (${duplicateNames.join(', ')}). Corrija no painel admin antes de coletar.';
        });
        return;
      }
      
      setState(() {
        _fields = loadedFields;
        _isLoading = false;
      });

      // Inicializar valores padrão
      for (var field in _fields) {
        if (field.fieldType == 'checkbox') {
          _collectedData[field.fieldName] = false;
        } else if (field.fieldType == 'photo' && field.fieldConfig?.allowMultiple == true) {
          _collectedData[field.fieldName] = [];
        }
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
      if (field.fieldConfig?.required == true) {
        final value = _collectedData[field.fieldName];
        
        // Validar se campo obrigatório está preenchido
        if (value == null ||
            (value is String && value.isEmpty) ||
            (value is List && value.isEmpty) ||
            (value is bool && value == false && field.fieldType == 'checkbox')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Campo obrigatório não preenchido: ${field.fieldLabel}'),
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
      );

      if (mounted) {
        if (result['success'] == true) {
          final isOffline = result['offline'] == true;
          final collectionId = result['collection_id'] as int?;

          if (isOffline) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('📴 Salvo offline. Será enviado quando houver conexão.'),
                  backgroundColor: Colors.orange,
                ),
              );
              Navigator.of(context).pop(true);
            }
          } else {
            // Online — gera e faz upload do PDF automaticamente
            if (collectionId != null) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('⏳ Gerando e enviando PDF...'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
              final uploadResult = await CollectionPdfService.generateAndUploadDetailed(
                collectionId: collectionId,
                brandName: widget.brandName,
                fields: _fields,
                collectedData: _collectedData,
                latitude: _currentPosition?.latitude,
                longitude: _currentPosition?.longitude,
                address: _resolvedAddress,
                accuracy: _currentPosition?.accuracy,
              );
              final uploaded = uploadResult['success'] == true;
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(uploaded
                        ? '✅ Coleta e PDF enviados com sucesso!'
                        : '✅ Coleta salva! (PDF não pôde ser enviado agora)'),
                    backgroundColor: uploaded ? Colors.green : Colors.orange,
                  ),
                );

                if (uploaded) {
                  await _promptOpenUploadedPdf(
                    collectionId: collectionId,
                    directPdfUrl: uploadResult['pdf_url']?.toString(),
                  );
                }
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Coleta salva com sucesso!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            }
            if (mounted) Navigator.of(context).pop(true);
          }
        } else {
          final message = result['error']?.toString() ?? 'Erro ao salvar coleta';
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

  Future<void> _generatePdf() async {
    setState(() => _isGeneratingPdf = true);
    try {
      await CollectionPdfService.generateAndShare(
        brandName: widget.brandName,
        fields: _fields,
        collectedData: _collectedData,
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        address: _resolvedAddress,
        accuracy: _currentPosition?.accuracy,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao gerar PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  String _toAbsoluteUrl(String rawUrl) {
    final value = rawUrl.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    final apiUri = Uri.parse(ApiService.baseUrl);
    final origin = '${apiUri.scheme}://${apiUri.host}${apiUri.hasPort ? ':${apiUri.port}' : ''}';
    if (value.startsWith('/')) return '$origin$value';
    return '$origin/$value';
  }

  Future<void> _promptOpenUploadedPdf({
    required int collectionId,
    String? directPdfUrl,
  }) async {
    if (!mounted) return;

    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('PDF enviado com sucesso'),
          content: const Text('Deseja visualizar o PDF agora?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Depois'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(ctx).pop(true),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Ver PDF'),
            ),
          ],
        );
      },
    );

    if (shouldOpen != true) return;

    String? pdfUrl = directPdfUrl;
    if (pdfUrl == null || pdfUrl.trim().isEmpty) {
      final resolved = await ApiService.getReportPdfLink(collectionId);
      if (resolved['success'] == true) {
        pdfUrl = resolved['url']?.toString();
      }
    }

    if (pdfUrl == null || pdfUrl.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nao foi possivel localizar o PDF para visualizacao.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final uri = Uri.parse(_toAbsoluteUrl(pdfUrl));
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nao foi possivel abrir o PDF: ${uri.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Parse brand color from hex string, fallback to primary blue
    Color brandColor = const Color(0xFF1E88E5);
    if (widget.brandHeaderColor != null && widget.brandHeaderColor!.isNotEmpty) {
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
        title: Text(widget.brandName, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        backgroundColor: isDark ? const Color(0xFF1A1F2E) : brandColor,
        foregroundColor: Colors.white,
        elevation: 8,
        shadowColor: isDark ? Colors.black.withValues(alpha: 0.3) : brandColor.withValues(alpha: 0.4),
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
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
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
                          Icon(Icons.info_outline, size: 64, color: Colors.orange),
                          SizedBox(height: 16),
                          Text(
                            'Esta marca não tem campos configurados.',
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Configure campos no Admin Dashboard primeiro.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Header com informações
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                          decoration: BoxDecoration(
                            color: brandColor,
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.assignment_outlined,
                                      color: isDark ? Colors.white : Colors.black,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Preencha os campos:',
                                          style: TextStyle(
                                            color: isDark ? Colors.white : Colors.black,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_fields.length} ${_fields.length == 1 ? "campo" : "campos"} configurados',
                                          style: TextStyle(
                                            color: (isDark ? Colors.white : Colors.black).withOpacity(0.8),
                                            fontSize: 13,
                                          ),
                                        ),
                                        if ((widget.storeName ?? '').isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 6),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: (isDark ? Colors.white : Colors.black).withOpacity(0.18),
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                'Loja: ${widget.storeName}',
                                                style: TextStyle(
                                                  color: isDark ? Colors.white : Colors.black,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: (_currentPosition != null
                                            ? Colors.greenAccent
                                            : Colors.orangeAccent)
                                        .withOpacity(0.55),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _currentPosition != null
                                          ? Icons.my_location
                                          : Icons.location_off_outlined,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _currentPosition != null
                                                ? 'Localizacao atualizada'
                                                : (_locationError ?? 'Localizacao obrigatoria para enviar a coleta'),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if ((_resolvedAddress ?? '').isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Text(
                                                _resolvedAddress!,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          if (_currentPosition != null)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Text(
                                                'Precisao: ±${_currentPosition!.accuracy.toStringAsFixed(0)} m',
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _isGettingLocation ? null : _getCurrentLocation,
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                      child: _isGettingLocation
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : const Text('Atualizar'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Lista de campos
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.only(top: 12),
                            itemCount: _fields.length,
                            itemBuilder: (context, index) {
                              final field = _fields[index];
                              return DynamicFieldWidget(
                                field: field,
                                initialValue: _collectedData[field.fieldName],
                                onValueChanged: (fieldName, value) {
                                  setState(() {
                                    _collectedData[fieldName] = value;
                                  });
                                },
                              );
                            },
                          ),
                        ),

                        // Botão de salvar + PDF
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: SafeArea(
                            child: Row(
                              children: [
                                // Botão PDF
                                SizedBox(
                                  height: 52,
                                  child: OutlinedButton.icon(
                                    onPressed: (_isSaving || _isGeneratingPdf)
                                        ? null
                                        : _generatePdf,
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: brandColor),
                                      foregroundColor: brandColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                    icon: _isGeneratingPdf
                                        ? SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(brandColor),
                                            ),
                                          )
                                        : const Icon(Icons.picture_as_pdf_outlined, size: 20),
                                    label: const Text('PDF'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Botão Salvar
                                Expanded(
                                  child: SizedBox(
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: (_isSaving || _isGeneratingPdf)
                                          ? null
                                          : _saveCollection,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: brandColor,
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor: Colors.grey[300],
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: _isSaving
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
