import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../models/brand_field.dart';
import 'api_service.dart';

class CollectionPdfService {
  /// Gera PDF da coleta e retorna o arquivo salvo em documentos do app.
  /// O arquivo fica disponivel offline no dispositivo.
  static Future<File> generateCollectionPdf({
    required String brandName,
    required List<BrandField> fields,
    required Map<String, dynamic> collectedData,
    double? latitude,
    double? longitude,
    String? address,
    double? accuracy,
  }) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
        boldItalic: pw.Font.helveticaBoldOblique(),
      ),
    );
    final addressInfo =
        _extractAddressInfo(address: address, collectedData: collectedData);
    final allPhotoEntries = _extractPhotoEntries(fields, collectedData);
    final photoEntries = allPhotoEntries.take(12).toList();
    final hiddenPhotoCount = allPhotoEntries.length - photoEntries.length;
    final photoImages = <_PhotoEntry, pw.MemoryImage>{};
    final fieldDisplays = fields
        .map(
          (field) => _FieldDisplay(
            label: _sanitizePdfText(field.fieldLabel),
            value:
                _formatValue(field.fieldType, collectedData[field.fieldName]),
            fieldType: field.fieldType,
          ),
        )
        .toList();
    final completedFieldCount =
        fieldDisplays.where((field) => field.hasValue).length;

    for (final entry in photoEntries) {
      final bytes = await _loadPhotoBytes(entry.url);
      if (bytes != null && bytes.isNotEmpty) {
        final normalized = _normalizeImageForPdf(bytes);
        if (normalized != null && normalized.isNotEmpty) {
          photoImages[entry] = pw.MemoryImage(normalized);
        }
      }
    }

    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final infoItems = <_InfoItem>[
      _InfoItem('Data da coleta', dateStr),
      _InfoItem('Horario', timeStr),
      if (addressInfo['street'] != null)
        _InfoItem('Rua', addressInfo['street']!),
      if (addressInfo['number'] != null)
        _InfoItem('Numero', addressInfo['number']!),
      if (addressInfo['district'] != null)
        _InfoItem('Bairro', addressInfo['district']!),
      if (addressInfo['cityUf'] != null)
        _InfoItem('Cidade / UF', addressInfo['cityUf']!),
      if (addressInfo['postalCode'] != null)
        _InfoItem('CEP', addressInfo['postalCode']!),
      if (addressInfo['complement'] != null)
        _InfoItem('Complemento', addressInfo['complement']!),
      if (addressInfo['street'] == null && addressInfo['full'] != null)
        _InfoItem('Endereco', addressInfo['full']!),
      if (latitude != null && longitude != null)
        _InfoItem(
          'Coordenadas',
          '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
        ),
      if (accuracy != null)
        _InfoItem('Precisao do GPS', '+/- ${accuracy.toStringAsFixed(0)} m'),
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          _buildHeroHeader(
            brandName: brandName,
            dateStr: dateStr,
            timeStr: timeStr,
            fieldCount: fieldDisplays.length,
            completedFieldCount: completedFieldCount,
            photoCount: photoEntries.length,
          ),
          pw.SizedBox(height: 18),
          _buildCollectionInfoSection(infoItems),
          pw.SizedBox(height: 18),
          ..._buildCollectedDataSection(fieldDisplays),
          if (photoEntries.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('EAF3FF'),
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: PdfColor.fromHex('B8D6FF')),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Evidencias fotograficas',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('0D47A1'),
                    ),
                  ),
                  pw.Text(
                    '${photoImages.length} foto(s) no PDF',
                    style: pw.TextStyle(
                        fontSize: 9, color: PdfColor.fromHex('455A64')),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Wrap(
              spacing: 10,
              runSpacing: 12,
              children: photoEntries.map((entry) {
                final image = photoImages[entry];
                final locationLine = address != null && address.isNotEmpty
                    ? 'Local: ${_sanitizePdfText(address, fallback: '')}'
                    : (latitude != null && longitude != null)
                        ? 'Local: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}'
                        : null;
                final accuracyLabel = accuracy != null
                    ? ' | Precisao: +/- ${accuracy.toStringAsFixed(0)} m'
                    : '';
                final stampLine = 'Data/Hora: $dateStr $timeStr$accuracyLabel';

                return pw.Container(
                  width: 245,
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('FAFAFA'),
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColor.fromHex('E0E0E0')),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        _sanitizePdfText(entry.label),
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('37474F'),
                        ),
                        maxLines: 2,
                      ),
                      pw.SizedBox(height: 6),
                      if (image != null)
                        pw.Image(
                          image,
                          width: 233,
                          height: 155,
                          fit: pw.BoxFit.cover,
                        )
                      else
                        pw.Container(
                          width: double.infinity,
                          height: 155,
                          alignment: pw.Alignment.center,
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('ECEFF1'),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            'Nao foi possivel carregar a foto',
                            style: pw.TextStyle(
                                fontSize: 9, color: PdfColor.fromHex('607D8B')),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      pw.SizedBox(height: 5),
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('1E2A38'),
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              _sanitizePdfText(stampLine),
                              style: pw.TextStyle(
                                fontSize: 7.5,
                                color: PdfColors.white,
                              ),
                            ),
                            if (locationLine != null) ...[
                              pw.SizedBox(height: 2),
                              pw.Text(
                                _sanitizePdfText(locationLine),
                                style: pw.TextStyle(
                                  fontSize: 7,
                                  color: PdfColor.fromHex('90CAF9'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            if (hiddenPhotoCount > 0)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 8),
                child: pw.Text(
                  '+$hiddenPhotoCount foto(s) nao incluida(s) para manter o PDF leve.',
                  style: pw.TextStyle(
                      fontSize: 9, color: PdfColor.fromHex('78909C')),
                ),
              ),
          ],
          pw.SizedBox(height: 24),
          pw.Divider(color: PdfColor.fromHex('BDBDBD')),
          pw.SizedBox(height: 8),
          pw.Text(
            'AG Merchandising | Gerado em $dateStr as $timeStr',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColor.fromHex('9E9E9E'),
            ),
          ),
        ],
      ),
    );

    // Salva em documentos do app (persistente, acessivel offline)
    final dir = await getApplicationDocumentsDirectory();
    final safeBrand =
        brandName.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    final file = File('${dir.path}/coleta_${safeBrand}_$timestamp.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static String _apiOrigin() {
    final uri = Uri.parse(ApiService.baseUrl);
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port';
  }

  static String _toAbsolutePhotoUrl(String raw) {
    final value = raw.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/')) return '${_apiOrigin()}$value';
    if (value.startsWith('uploads/')) return '${_apiOrigin()}/$value';
    return value;
  }

  static Future<Uint8List?> _loadPhotoBytes(String rawUrl) async {
    final url = _toAbsolutePhotoUrl(rawUrl);

    try {
      if (url.startsWith('http://') || url.startsWith('https://')) {
        final uri = Uri.parse(url);
        final token = ApiService.token;
        final headers = (token != null && token.isNotEmpty)
            ? {'Authorization': 'Bearer $token'}
            : <String, String>{};

        final response = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          return response.bodyBytes;
        }

        // Tenta sem token como fallback (foto publica)
        if (headers.isNotEmpty) {
          final pub = await http.get(uri).timeout(const Duration(seconds: 30));
          if (pub.statusCode == 200 && pub.bodyBytes.isNotEmpty) {
            return pub.bodyBytes;
          }
        }

        return null;
      }

      final file = File(url);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Uint8List? _normalizeImageForPdf(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        // Se nao conseguir decodificar, tenta usar bytes originais.
        return bytes;
      }

      // Limita resolucao para reduzir risco de incompatibilidade/render branco.
      const maxSide = 2200;
      img.Image processed = decoded;
      if (decoded.width > maxSide || decoded.height > maxSide) {
        if (decoded.width >= decoded.height) {
          processed = img.copyResize(decoded,
              width: maxSide, interpolation: img.Interpolation.average);
        } else {
          processed = img.copyResize(decoded,
              height: maxSide, interpolation: img.Interpolation.average);
        }
      }

      // Re-encode JPEG baseline melhora compatibilidade no Chrome/visualizadores embutidos.
      return Uint8List.fromList(img.encodeJpg(processed, quality: 88));
    } catch (_) {
      return bytes;
    }
  }

  static Map<String, String?> _extractAddressInfo({
    required String? address,
    required Map<String, dynamic> collectedData,
  }) {
    String? pick(List<String> keys) {
      for (final key in keys) {
        final value = collectedData[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return null;
    }

    final full = address?.trim().isNotEmpty == true ? address!.trim() : null;
    final postalFromAddress = full != null
        ? RegExp(r'\b\d{5}-?\d{3}\b').firstMatch(full)?.group(0)
        : null;
    final numberFromAddress = full != null
        ? RegExp(r',\s*(\d+[A-Za-z0-9\-]*)').firstMatch(full)?.group(1)
        : null;
    final streetFromAddress = full != null && full.contains(',')
        ? full.split(',').first.trim()
        : null;

    final street = pick([
          'street',
          'logradouro',
          'rua',
          'address_street',
          'endereco_rua'
        ]) ??
        streetFromAddress;
    final number = pick([
          'number',
          'numero',
          'address_number',
          'street_number',
          'endereco_numero'
        ]) ??
        numberFromAddress;
    final district = pick([
      'district',
      'bairro',
      'neighborhood',
      'endereco_bairro',
    ]);
    final city = pick([
      'city',
      'cidade',
      'locality',
      'municipio',
      'endereco_cidade',
    ]);
    final state = pick([
      'state',
      'uf',
      'region',
      'administrative_area',
      'endereco_uf',
    ]);
    final postalCode =
        pick(['postal_code', 'cep', 'zip', 'zipcode', 'endereco_cep']) ??
            postalFromAddress;
    final complement = pick([
      'complement',
      'complemento',
      'address_complement',
      'endereco_complemento',
    ]);

    String? cityUf;
    if ((city ?? '').isNotEmpty && (state ?? '').isNotEmpty) {
      cityUf = '$city/$state';
    } else if ((city ?? '').isNotEmpty) {
      cityUf = city;
    } else if ((state ?? '').isNotEmpty) {
      cityUf = state;
    }

    return {
      'full': full,
      'street': street,
      'number': number,
      'district': district,
      'cityUf': cityUf,
      'postalCode': postalCode,
      'complement': complement,
    };
  }

  static List<_PhotoEntry> _extractPhotoEntries(
    List<BrandField> fields,
    Map<String, dynamic> collectedData,
  ) {
    final entries = <_PhotoEntry>[];
    final seen = <String>{};

    void push(String label, String url) {
      final normalized = url.trim();
      if (normalized.isEmpty) return;
      if (seen.add(normalized)) {
        entries.add(_PhotoEntry(label, normalized));
      }
    }

    for (final field in fields.where((f) => f.fieldType == 'photo')) {
      final value = collectedData[field.fieldName];
      final urls = _extractUrlsFromValue(value);
      for (var i = 0; i < urls.length; i++) {
        final suffix = urls.length > 1 ? ' ${i + 1}' : '';
        push('${field.fieldLabel}$suffix', urls[i]);
      }
    }

    // Fotos de ponto, caso estejam no payload
    final clockIn = collectedData['clock_in_photo'];
    final clockOut = collectedData['clock_out_photo'];
    for (final url in _extractUrlsFromValue(clockIn)) {
      push('Ponto entrada', url);
    }
    for (final url in _extractUrlsFromValue(clockOut)) {
      push('Ponto saida', url);
    }

    // Fallback final: varredura recursiva em todo o payload da coleta
    // para capturar fotos mesmo que o campo nao esteja marcado como 'photo'.
    final genericUrls = _extractUrlsFromValue(collectedData);
    for (var i = 0; i < genericUrls.length; i++) {
      push('Foto ${i + 1}', genericUrls[i]);
    }

    return entries;
  }

  static List<String> _extractUrlsFromValue(dynamic value) {
    if (value == null) return const [];

    if (value is String) {
      final v = value.trim();
      if (v.isEmpty) return const [];
      final lower = v.toLowerCase();
      final looksLikeImage = lower.contains('/uploads/') ||
          lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.png') ||
          lower.endsWith('.webp') ||
          lower.contains('image');
      return looksLikeImage ? [v] : const [];
    }

    if (value is List) {
      final out = <String>[];
      for (final item in value) {
        out.addAll(_extractUrlsFromValue(item));
      }
      return out;
    }

    if (value is Map) {
      final out = <String>[];
      final candidate = value['photo_url'] ??
          value['photoUrl'] ??
          value['url'] ??
          value['path'] ??
          value['image'] ??
          value['image_url'];
      if (candidate != null) {
        out.addAll(_extractUrlsFromValue(candidate));
      }

      for (final entry in value.entries) {
        if (entry.key == 'photo_url' ||
            entry.key == 'photoUrl' ||
            entry.key == 'url' ||
            entry.key == 'path' ||
            entry.key == 'image' ||
            entry.key == 'image_url') {
          continue;
        }
        out.addAll(_extractUrlsFromValue(entry.value));
      }
      return out;
    }

    return const [];
  }

  /// Gera o PDF e abre o compartilhamento nativo (WhatsApp, e-mail, etc.)
  static Future<void> generateAndShare({
    required String brandName,
    required List<BrandField> fields,
    required Map<String, dynamic> collectedData,
    double? latitude,
    double? longitude,
    String? address,
    double? accuracy,
  }) async {
    final file = await generateCollectionPdf(
      brandName: brandName,
      fields: fields,
      collectedData: collectedData,
      latitude: latitude,
      longitude: longitude,
      address: address,
      accuracy: accuracy,
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'Coleta AG Merchandising - $brandName',
      ),
    );
  }

  /// Gera PDF e faz upload automatico para o servidor.
  /// Retorna true se o upload foi bem-sucedido.
  static Future<bool> generateAndUpload({
    required int collectionId,
    required String brandName,
    required List<BrandField> fields,
    required Map<String, dynamic> collectedData,
    double? latitude,
    double? longitude,
    String? address,
    double? accuracy,
  }) async {
    final result = await generateAndUploadDetailed(
      brandName: brandName,
      fields: fields,
      collectedData: collectedData,
      latitude: latitude,
      longitude: longitude,
      address: address,
      accuracy: accuracy,
      collectionId: collectionId,
    );

    return result['success'] == true;
  }

  /// Gera PDF, envia para o servidor e retorna dados do upload (incluindo pdf_url).
  static Future<Map<String, dynamic>> generateAndUploadDetailed({
    required int collectionId,
    required String brandName,
    required List<BrandField> fields,
    required Map<String, dynamic> collectedData,
    double? latitude,
    double? longitude,
    String? address,
    double? accuracy,
  }) async {
    final file = await generateCollectionPdf(
      brandName: brandName,
      fields: fields,
      collectedData: collectedData,
      latitude: latitude,
      longitude: longitude,
      address: address,
      accuracy: accuracy,
    );

    return await ApiService.uploadCollectionPdf(
      collectionId: collectionId,
      pdfFile: file,
    );
  }

  // Helpers internos

  static String _formatValue(String fieldType, dynamic value) {
    if (value == null) return 'Nao informado';
    switch (fieldType) {
      case 'checkbox':
        return (value == true || value == 1) ? 'Sim' : 'Nao';
      case 'photo':
        if (value is List) return '${value.length} foto(s)';
        return value.toString().isNotEmpty ? '1 foto' : 'Nao informado';
      case 'date':
        try {
          final dt = DateTime.parse(value.toString());
          return _sanitizePdfText(
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}',
          );
        } catch (_) {
          return _sanitizePdfText(value.toString());
        }
      default:
        final str = value is List
            ? value.map((item) => _sanitizePdfText(item.toString())).join(', ')
            : _sanitizePdfText(value.toString());
        return str.isEmpty ? 'Nao informado' : str;
    }
  }

  static pw.Widget _buildHeroHeader({
    required String brandName,
    required String dateStr,
    required String timeStr,
    required int fieldCount,
    required int completedFieldCount,
    required int photoCount,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('1565C0'),
        borderRadius: pw.BorderRadius.circular(16),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('42A5F5'),
                        borderRadius: pw.BorderRadius.circular(999),
                      ),
                      child: pw.Text(
                        'RELATORIO DE COLETA',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 12),
                    pw.Text(
                      _sanitizePdfText(brandName),
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Resumo visual da coleta com campos preenchidos e evidencias anexadas.',
                      style: pw.TextStyle(
                        color: PdfColor.fromHex('D9ECFF'),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Container(
                width: 148,
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('0E4E95'),
                  borderRadius: pw.BorderRadius.circular(14),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Gerado em',
                      style: pw.TextStyle(
                        color: PdfColor.fromHex('B7DCFF'),
                        fontSize: 8.5,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      dateStr,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      timeStr,
                      style: pw.TextStyle(
                        color: PdfColor.fromHex('D9ECFF'),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            children: [
              pw.Expanded(
                child:
                    _buildMetricCard('Campos', '$fieldCount', 'configurados'),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _buildMetricCard(
                    'Preenchidos', '$completedFieldCount', 'com valor'),
              ),
              pw.SizedBox(width: 10),
              pw.Expanded(
                child: _buildMetricCard('Fotos', '$photoCount', 'anexadas'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildMetricCard(
      String label, String value, String subtitle) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('D5E9FF'),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              color: PdfColor.fromHex('0E4E95'),
              fontSize: 8.5,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: PdfColor.fromHex('0C2D57'),
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            subtitle,
            style: pw.TextStyle(
              color: PdfColor.fromHex('305A87'),
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCollectionInfoSection(List<_InfoItem> items) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('F8FBFF'),
        borderRadius: pw.BorderRadius.circular(14),
        border: pw.Border.all(color: PdfColor.fromHex('D9E7F7')),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Informacoes da coleta',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('123B69'),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items
                .map(
                  (item) => pw.Container(
                    width: 235,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(10),
                      border: pw.Border.all(color: PdfColor.fromHex('E1ECF8')),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          _sanitizePdfText(item.label),
                          style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('5E7A96'),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          _sanitizePdfText(item.value),
                          style: pw.TextStyle(
                            fontSize: 11,
                            color: PdfColor.fromHex('223548'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  static List<pw.Widget> _buildCollectedDataSection(
      List<_FieldDisplay> fields) {
    final widgets = <pw.Widget>[
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('EEF5FC'),
          borderRadius: pw.BorderRadius.circular(12),
          border: pw.Border.all(color: PdfColor.fromHex('D2E4F5')),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Dados coletados',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('24476B'),
              ),
            ),
            pw.Text(
              '${fields.length} campo(s)',
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfColor.fromHex('5C738C'),
              ),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 10),
    ];

    for (var i = 0; i < fields.length; i++) {
      final field = fields[i];
      widgets.add(_buildCollectedFieldCard(field, isAlternate: i.isOdd));
      if (i != fields.length - 1) {
        widgets.add(pw.SizedBox(height: 10));
      }
    }

    return widgets;
  }

  static pw.Widget _buildCollectedFieldCard(_FieldDisplay field,
      {required bool isAlternate}) {
    final accent = _fieldTypeColor(field.fieldType);
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: isAlternate ? PdfColor.fromHex('FCFDFE') : PdfColors.white,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColor.fromHex('E1E8EF')),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Text(
                  field.label,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('243342'),
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              _buildFieldTypeChip(_fieldTypeLabel(field.fieldType), accent),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('F7FAFD'),
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: PdfColor.fromHex('E6EEF6')),
            ),
            child: pw.Text(
              field.value,
              style: pw.TextStyle(
                fontSize: 10.5,
                color: field.hasValue
                    ? PdfColor.fromHex('273746')
                    : PdfColor.fromHex('7B8B9A'),
                fontStyle: field.hasValue ? null : pw.FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFieldTypeChip(String label, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(999),
      ),
      child: pw.Text(
        label,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static PdfColor _fieldTypeColor(String fieldType) {
    switch (fieldType) {
      case 'checkbox':
        return PdfColor.fromHex('43A047');
      case 'photo':
        return PdfColor.fromHex('1E88E5');
      case 'date':
        return PdfColor.fromHex('8E24AA');
      case 'number':
        return PdfColor.fromHex('EF6C00');
      case 'textarea':
        return PdfColor.fromHex('546E7A');
      default:
        return PdfColor.fromHex('455A64');
    }
  }

  static String _fieldTypeLabel(String fieldType) {
    switch (fieldType) {
      case 'checkbox':
        return 'Sim/Nao';
      case 'photo':
        return 'Foto';
      case 'date':
        return 'Data';
      case 'number':
        return 'Numero';
      case 'textarea':
        return 'Texto longo';
      default:
        return 'Texto';
    }
  }

  static String _sanitizePdfText(String? input,
      {String fallback = 'Nao informado'}) {
    if (input == null) return fallback;

    final text = input
        .replaceAll('\r\n', '\n')
        .replaceAll('📍', 'Local: ')
        .replaceAll('📅', 'Data: ')
        .replaceAll('🕐', 'Hora: ')
        .replaceAll('•', '-')
        .replaceAll('·', '|')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('’', "'")
        .trim();

    if (text.isEmpty) return fallback;
    return text;
  }
}

class _PhotoEntry {
  final String label;
  final String url;

  const _PhotoEntry(this.label, this.url);
}

class _InfoItem {
  final String label;
  final String value;

  const _InfoItem(this.label, this.value);
}

class _FieldDisplay {
  final String label;
  final String value;
  final String fieldType;

  const _FieldDisplay({
    required this.label,
    required this.value,
    required this.fieldType,
  });

  bool get hasValue => value != 'Nao informado';
}
