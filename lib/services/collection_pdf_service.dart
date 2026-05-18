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
  /// O arquivo fica disponível offline no dispositivo.
  static Future<File> generateCollectionPdf({
    required String brandName,
    required List<BrandField> fields,
    required Map<String, dynamic> collectedData,
    double? latitude,
    double? longitude,
    String? address,
    double? accuracy,
  }) async {
    final pdf = pw.Document();
    final addressInfo = _extractAddressInfo(address: address, collectedData: collectedData);
    final allPhotoEntries = _extractPhotoEntries(fields, collectedData);
    final photoEntries = allPhotoEntries.take(12).toList();
    final hiddenPhotoCount = allPhotoEntries.length - photoEntries.length;
    final photoImages = <_PhotoEntry, pw.MemoryImage>{};

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

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // ── Cabeçalho ──────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('1E88E5'),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Relatório de Coleta',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  brandName,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // ── Informações da Coleta ───────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('F7FAFC'),
              borderRadius: pw.BorderRadius.circular(10),
              border: pw.Border.all(color: PdfColor.fromHex('D7E3F2')),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Informacoes da Coleta',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('1F3B57'),
                  ),
                ),
                pw.SizedBox(height: 8),
                _infoRow('Data', dateStr),
                _infoRow('Hora', timeStr),
                if (addressInfo['street'] != null)
                  _infoRow('Rua', addressInfo['street']!),
                if (addressInfo['number'] != null)
                  _infoRow('Numero', addressInfo['number']!),
                if (addressInfo['district'] != null)
                  _infoRow('Bairro', addressInfo['district']!),
                if (addressInfo['cityUf'] != null)
                  _infoRow('Cidade/UF', addressInfo['cityUf']!),
                if (addressInfo['postalCode'] != null)
                  _infoRow('CEP', addressInfo['postalCode']!),
                if (addressInfo['complement'] != null)
                  _infoRow('Complemento', addressInfo['complement']!),
                if (addressInfo['street'] == null && addressInfo['full'] != null)
                  _infoRow('Endereco', addressInfo['full']!),
                if (latitude != null && longitude != null)
                  _infoRow(
                    'Coordenadas',
                    '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
                  ),
                if (accuracy != null)
                  _infoRow('Precisão GPS', '±${accuracy.toStringAsFixed(0)} m'),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // ── Título seção campos ─────────────────────────────
          pw.Text(
            'Dados Coletados',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('424242'),
            ),
          ),
          pw.SizedBox(height: 8),

          // ── Tabela de campos ────────────────────────────────
          pw.Table(
            border: pw.TableBorder.all(color: PdfColor.fromHex('E0E0E0'), width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(3),
            },
            children: [
              // Cabeçalho da tabela
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColor.fromHex('1E88E5')),
                children: [
                  _tableCell('Campo', isHeader: true),
                  _tableCell('Valor', isHeader: true),
                ],
              ),
              // Linhas de dados
              ...fields.map((field) {
                final rawValue = collectedData[field.fieldName];
                final displayValue = _formatValue(field.fieldType, rawValue);
                return pw.TableRow(
                  children: [
                    _tableCell(field.fieldLabel),
                    _tableCell(displayValue),
                  ],
                );
              }),
            ],
          ),

          if (photoEntries.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('E8F2FF'),
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColor.fromHex('BBD8FF')),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Evidencias Fotograficas',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('0D47A1'),
                    ),
                  ),
                  pw.Text(
                    '${photoImages.length} foto(s) no PDF',
                    style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('455A64')),
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
                    ? '📍 $address'
                    : (latitude != null && longitude != null)
                        ? '📍 ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}'
                        : null;
                final accuracyLabel = accuracy != null ? '  ±${accuracy.toStringAsFixed(0)} m' : '';
                final stampLine = '📅 $dateStr  🕐 $timeStr$accuracyLabel';

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
                      // Título do campo
                      pw.Text(
                        entry.label,
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('37474F'),
                        ),
                        maxLines: 2,
                      ),
                      pw.SizedBox(height: 6),
                      // Imagem
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
                            style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('607D8B')),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      pw.SizedBox(height: 5),
                      // Faixa de data, hora e localização
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('1E2A38'),
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              stampLine,
                              style: pw.TextStyle(
                                fontSize: 7.5,
                                color: PdfColors.white,
                              ),
                            ),
                            if (locationLine != null) ...[
                              pw.SizedBox(height: 2),
                              pw.Text(
                                locationLine,
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
                  style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('78909C')),
                ),
              ),
          ],

          pw.SizedBox(height: 24),

          // ── Rodapé ─────────────────────────────────────────
          pw.Divider(color: PdfColor.fromHex('BDBDBD')),
          pw.SizedBox(height: 8),
          pw.Text(
            'AG Merchandising · Gerado em $dateStr às $timeStr',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColor.fromHex('9E9E9E'),
            ),
          ),
        ],
      ),
    );

    // Salva em documentos do app (persistente, acessível offline)
    final dir = await getApplicationDocumentsDirectory();
    final safeBrand = brandName.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
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
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
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

        // Tenta sem token como fallback (foto pública)
        if (headers.isNotEmpty) {
          final pub = await http
              .get(uri)
              .timeout(const Duration(seconds: 30));
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
        // Se não conseguir decodificar, tenta usar bytes originais.
        return bytes;
      }

      // Limita resolução para reduzir risco de incompatibilidade/render branco.
      const maxSide = 2200;
      img.Image processed = decoded;
      if (decoded.width > maxSide || decoded.height > maxSide) {
        if (decoded.width >= decoded.height) {
          processed = img.copyResize(decoded, width: maxSide, interpolation: img.Interpolation.average);
        } else {
          processed = img.copyResize(decoded, height: maxSide, interpolation: img.Interpolation.average);
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
    final postalCode = pick([
          'postal_code',
          'cep',
          'zip',
          'zipcode',
          'endereco_cep'
        ]) ??
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
    // para capturar fotos mesmo que o campo não esteja marcado como 'photo'.
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
      final looksLikeImage =
          lower.contains('/uploads/') ||
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
      final candidate = value['photo_url'] ?? value['photoUrl'] ?? value['url'] ?? value['path'] ?? value['image'] ?? value['image_url'];
      if (candidate != null) {
        out.addAll(_extractUrlsFromValue(candidate));
      }

      // Percorre demais chaves (aninhamento livre)
      for (final entry in value.entries) {
        if (entry.key == 'photo_url' || entry.key == 'photoUrl' || entry.key == 'url' || entry.key == 'path' || entry.key == 'image' || entry.key == 'image_url') {
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
        text: 'Coleta AG Merchandising – $brandName',
      ),
    );
  }

  /// Gera PDF e faz upload automático para o servidor.
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

  // ── Helpers internos ──────────────────────────────────────

  static String _formatValue(String fieldType, dynamic value) {
    if (value == null) return '—';
    switch (fieldType) {
      case 'checkbox':
        return (value == true || value == 1) ? 'Sim' : 'Não';
      case 'photo':
        if (value is List) return '${value.length} foto(s)';
        return value.toString().isNotEmpty ? '1 foto' : '—';
      case 'date':
        try {
          final dt = DateTime.parse(value.toString());
          return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
        } catch (_) {
          return value.toString();
        }
      default:
        final str = value.toString();
        return str.isEmpty ? '—' : str;
    }
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Text(
            '$label: ',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  static pw.Widget _tableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: isHeader ? pw.FontWeight.bold : null,
          color: isHeader ? PdfColors.white : PdfColor.fromHex('212121'),
        ),
      ),
    );
  }
}

class _PhotoEntry {
  final String label;
  final String url;

  const _PhotoEntry(this.label, this.url);
}
