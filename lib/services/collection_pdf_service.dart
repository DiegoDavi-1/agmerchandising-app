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
    final photoEntries = allPhotoEntries;
    final photoImages = <_PhotoEntry, pw.MemoryImage>{};
    final fieldDisplays = fields
        .where((field) =>
            field.fieldType != 'photo_text' && field.fieldType != 'photo')
        .map(
          (field) => _FieldDisplay(
            label: _sanitizePdfText(field.fieldLabel),
            value: _formatFieldValue(field, collectedData[field.fieldName]),
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
      _InfoItem('Endereco', _formatAddressCompact(addressInfo)),
      _InfoItem('Rua', _addrOrDefault(addressInfo['street'])),
      _InfoItem('Numero', _addrOrDefault(addressInfo['number'])),
      _InfoItem('Bairro', _addrOrDefault(addressInfo['district'])),
      _InfoItem('Cidade / UF', _addrOrDefault(addressInfo['cityUf'])),
      _InfoItem('CEP', _addrOrDefault(addressInfo['postalCode'])),
      if (addressInfo['complement'] != null)
        _InfoItem('Complemento', addressInfo['complement']!),
      if (latitude != null && longitude != null)
        _InfoItem(
          'Coordenadas',
          '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
        ),
      if (accuracy != null)
        _InfoItem('Precisao do GPS', '+/- ${accuracy.toStringAsFixed(0)} m'),
    ];
    final photoLocationLine = _buildPhotoLocationLine(
      addressInfo: addressInfo,
      latitude: latitude,
      longitude: longitude,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('1565C0'),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'RELATORIO DE COLETA',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  _sanitizePdfText(brandName),
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Data: $dateStr  Hora: $timeStr',
                  style: pw.TextStyle(
                      fontSize: 10, color: PdfColor.fromHex('D6E9FF')),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              pw.Expanded(
                  child: _metricBox('Campos', '${fieldDisplays.length}')),
              pw.SizedBox(width: 8),
              pw.Expanded(
                  child: _metricBox('Preenchidos', '$completedFieldCount')),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _metricBox('Fotos', '${photoEntries.length}')),
            ],
          ),
          pw.SizedBox(height: 14),
          _sectionTitle(
              'Informacoes da coleta', 'DADOS DE LOCALIZACAO E HORARIO'),
          pw.SizedBox(height: 6),
          ...infoItems.map(
            (item) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Container(
                width: double.infinity,
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('F7FAFD'),
                  border: pw.Border.all(color: PdfColor.fromHex('D8E3EE')),
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: _infoLine(item.label, item.value),
              ),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Divider(),
          pw.SizedBox(height: 8),
          _sectionTitle('Dados coletados', 'RESUMO DOS CAMPOS PREENCHIDOS'),
          pw.SizedBox(height: 6),
          ...fieldDisplays.map(
            (field) => pw.Container(
              width: double.infinity,
              margin: const pw.EdgeInsets.only(bottom: 6),
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: field.hasValue
                    ? PdfColor.fromHex('FCFEFF')
                    : PdfColor.fromHex('F7F9FB'),
                border: pw.Border.all(color: PdfColor.fromHex('D0DCE8')),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          _sanitizePdfText(field.label),
                          style: pw.TextStyle(
                              fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: pw.BoxDecoration(
                          color: _fieldTypeColor(field.fieldType),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          _fieldTypeLabel(field.fieldType),
                          style: pw.TextStyle(
                            fontSize: 7.5,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    _sanitizePdfText(field.value),
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: field.hasValue
                          ? PdfColor.fromHex('233446')
                          : PdfColor.fromHex('6D7F93'),
                      fontStyle: field.hasValue ? null : pw.FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (fieldDisplays.isEmpty)
            pw.Container(
              width: double.infinity,
              margin: const pw.EdgeInsets.only(top: 6),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('F7F9FB'),
                border: pw.Border.all(color: PdfColor.fromHex('D0DCE8')),
                borderRadius: pw.BorderRadius.circular(5),
              ),
              child: pw.Text(
                'Nenhuma tarefa nao-foto preenchida nesta coleta.',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColor.fromHex('6D7F93'),
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ),
          pw.SizedBox(height: 16),
          pw.Divider(),
          pw.Text('Merch Hub | Gerado em $dateStr as $timeStr',
              style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );

    for (final entry in photoEntries) {
      final image = photoImages[entry];
      final locationLine = photoLocationLine;
      final accuracyLabel = accuracy != null
          ? ' | Precisao: +/- ${accuracy.toStringAsFixed(0)} m'
          : '';
      final stampLine = 'Data/Hora: $dateStr $timeStr$accuracyLabel';

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                  'Evidencia fotografica', 'PAGINA EXCLUSIVA DA FOTO'),
              pw.SizedBox(height: 8),
              pw.Text(
                _sanitizePdfText(entry.label),
                style:
                    pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Expanded(
                child: pw.Container(
                  width: double.infinity,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('F2F6FA'),
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColor.fromHex('D5E2EE')),
                  ),
                  child: image != null
                      ? pw.Image(image, fit: pw.BoxFit.contain)
                      : pw.Text('Nao foi possivel carregar a foto'),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                width: double.infinity,
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('EEF4FA'),
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: PdfColor.fromHex('D5E2EE')),
                ),
                child: pw.Text(
                  _sanitizePdfText(stampLine),
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
              if (locationLine != null)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4),
                  child: pw.Text(
                    _sanitizePdfText(locationLine),
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              if (entry.note != null && entry.note!.trim().isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4),
                  child: pw.Text(
                    _sanitizePdfText('Observacao: ${entry.note!}',
                        fallback: ''),
                    style: pw.TextStyle(
                        fontSize: 9, color: PdfColor.fromHex('334E68')),
                  ),
                ),
            ],
          ),
        ),
      );
    }

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
        // Fallback: se bytes parecem imagem valida, tenta embutir original.
        return _looksLikeImageBytes(bytes) ? bytes : null;
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
      return _looksLikeImageBytes(bytes) ? bytes : null;
    }
  }

  static bool _looksLikeImageBytes(Uint8List bytes) {
    if (bytes.length < 12) return false;

    final isJpeg = bytes[0] == 0xFF && bytes[1] == 0xD8;
    final isPng = bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
    final isWebp = bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;

    return isJpeg || isPng || isWebp;
  }

  static pw.Widget _metricBox(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('EAF3FF'),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColor.fromHex('C8DDF6')),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 8.5, color: PdfColor.fromHex('44617D'))),
          pw.SizedBox(height: 4),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('0E3D6B'))),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitle(String title, String subtitle) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('EDF4FB'),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColor.fromHex('D6E4F3')),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('173B63'),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            subtitle,
            style: pw.TextStyle(
              fontSize: 7.5,
              color: PdfColor.fromHex('5E7895'),
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoLine(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 108,
          child: pw.Text(
            _sanitizePdfText(label, fallback: ''),
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColor.fromHex('4C647E'),
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            _sanitizePdfText(value),
            style: pw.TextStyle(
              fontSize: 9.5,
              color: PdfColor.fromHex('223548'),
            ),
          ),
        ),
      ],
    );
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
    String? streetFromAddress;
    String? numberFromAddress;
    String? districtFromAddress;
    String? cityFromAddress;
    String? stateFromAddress;
    String? cityUfFromAddress;

    if (full != null && full.isNotEmpty) {
      // Remove sufixo de CEP para facilitar parse.
      final withoutCep = full
          .replaceAll(
              RegExp(r',?\s*CEP\s*\d{5}-?\d{3}', caseSensitive: false), '')
          .trim();
      final cleaned = withoutCep.replaceAll(RegExp(r'\s*-\s*$'), '').trim();
      final tokens = cleaned
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (tokens.isNotEmpty) {
        streetFromAddress = tokens[0];

        var idx = 1;
        if (tokens.length > idx &&
            RegExp(r'^\d+[A-Za-z0-9\-]*$').hasMatch(tokens[idx])) {
          numberFromAddress = tokens[idx];
          idx++;
        }

        if (tokens.length > idx) {
          districtFromAddress = tokens[idx];
          idx++;
        }

        if (tokens.length > idx) {
          final cityStateRaw = tokens.sublist(idx).join(', ').trim();
          final ufMatch =
              RegExp(r'\b([A-Za-z]{2})\b$').firstMatch(cityStateRaw);
          if (ufMatch != null) {
            stateFromAddress = ufMatch.group(1)!.toUpperCase();
            cityFromAddress = cityStateRaw.substring(0, ufMatch.start).trim();
          } else if (_looksLikeStateName(cityStateRaw)) {
            stateFromAddress = cityStateRaw;
          } else {
            cityFromAddress = cityStateRaw;
          }
        }
      }

      // Fallback: se numero vier no fim da rua "Rua X 822".
      if ((numberFromAddress ?? '').isEmpty &&
          (streetFromAddress ?? '').isNotEmpty) {
        final m = RegExp(r'^(.*?)(?:\s+(\d+[A-Za-z0-9\-]*))$')
            .firstMatch(streetFromAddress!);
        if (m != null) {
          streetFromAddress = m.group(1)?.trim();
          numberFromAddress = m.group(2)?.trim();
        }
      }

      if ((cityFromAddress ?? '').isNotEmpty ||
          (stateFromAddress ?? '').isNotEmpty) {
        cityUfFromAddress = [
          if ((cityFromAddress ?? '').isNotEmpty) cityFromAddress!.trim(),
          if ((stateFromAddress ?? '').isNotEmpty) stateFromAddress!.trim(),
        ].join('/');
      }
    }

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
        ]) ??
        ((districtFromAddress ?? '').isNotEmpty ? districtFromAddress : null);
    final city = pick([
          'city',
          'cidade',
          'locality',
          'municipio',
          'endereco_cidade',
        ]) ??
        cityFromAddress;
    final state = pick([
          'state',
          'uf',
          'region',
          'administrative_area',
          'endereco_uf',
        ]) ??
        stateFromAddress;
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
    } else if ((cityUfFromAddress ?? '').isNotEmpty) {
      cityUf = cityUfFromAddress!.replaceAll(' - ', '/');
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

    void push(String label, String url, {String? note}) {
      final normalized = url.trim();
      if (normalized.isEmpty) return;
      if (seen.add(normalized)) {
        entries.add(_PhotoEntry(label, normalized, note: note));
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

    // Campos photo_text: inclui a observacao junto da foto.
    for (final field in fields.where((f) => f.fieldType == 'photo_text')) {
      final value = collectedData[field.fieldName];

      String? note;
      dynamic photoValue = value;
      if (value is Map) {
        photoValue = value['photo'] ?? value['photo_url'] ?? value['url'];
        note = (value['text'] ?? value['description'] ?? value['caption'])
            ?.toString();
      }

      final urls = _extractUrlsFromValue(photoValue);
      for (var i = 0; i < urls.length; i++) {
        final suffix = urls.length > 1 ? ' ${i + 1}' : '';
        push('${field.fieldLabel}$suffix', urls[i], note: note);
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

  static String? _buildPhotoLocationLine({
    required Map<String, String?> addressInfo,
    required double? latitude,
    required double? longitude,
  }) {
    final compact = _formatAddressCompact(addressInfo);
    if (compact != 'Nao informado') {
      return 'Local: $compact';
    }

    if (latitude != null && longitude != null) {
      return 'Local: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)} | CEP: nao informado';
    }

    return null;
  }

  static String _addrOrDefault(String? value) {
    final v = (value ?? '').trim();
    return v.isEmpty ? 'Nao informado' : v;
  }

  static String _formatAddressCompact(Map<String, String?> addressInfo) {
    final street = (addressInfo['street'] ?? '').trim();
    final number = (addressInfo['number'] ?? '').trim();
    final district = (addressInfo['district'] ?? '').trim();
    final cityUfRaw = (addressInfo['cityUf'] ?? '').trim();

    String city = '';
    String uf = '';

    if (cityUfRaw.contains('/')) {
      final parts = cityUfRaw.split('/');
      city = parts.first.trim();
      uf = parts.length > 1 ? parts[1].trim() : '';
    } else if (cityUfRaw.contains(' - ')) {
      final parts = cityUfRaw.split(' - ');
      city = parts.first.trim();
      uf = parts.length > 1 ? parts[1].trim() : '';
    } else {
      city = cityUfRaw;
    }

    final left = [
      if (street.isNotEmpty)
        (RegExp(r'^(rua|av\.?|avenida|rodovia|travessa|r\.)\b',
                    caseSensitive: false)
                .hasMatch(street)
            ? street
            : 'Rua $street'),
      if (number.isNotEmpty) number,
    ].join(' ');

    final right = [
      if (district.isNotEmpty) district,
      if (city.isNotEmpty) city,
      if (uf.isNotEmpty) uf,
    ];

    if (left.isEmpty && right.isEmpty) return 'Nao informado';
    if (right.isEmpty) return left;
    if (left.isEmpty) return right.join(' ');

    final rightPrefix = district.isNotEmpty ? '$district - ' : '';
    final cityUfPart =
        [if (city.isNotEmpty) city, if (uf.isNotEmpty) uf].join(' ');
    return '$left, $rightPrefix$cityUfPart'.trim();
  }

  static bool _looksLikeStateName(String value) {
    final v = value.trim().toLowerCase();
    const stateNames = {
      'acre',
      'alagoas',
      'amapa',
      'amazonas',
      'bahia',
      'ceara',
      'distrito federal',
      'espirito santo',
      'goias',
      'maranhao',
      'mato grosso',
      'mato grosso do sul',
      'minas gerais',
      'para',
      'paraiba',
      'parana',
      'pernambuco',
      'piaui',
      'rio de janeiro',
      'rio grande do norte',
      'rio grande do sul',
      'rondonia',
      'roraima',
      'santa catarina',
      'sao paulo',
      'sergipe',
      'tocantins',
    };
    return stateNames.contains(v);
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
        text: 'Coleta Merch Hub - $brandName',
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

    final uploadResult = await ApiService.uploadCollectionPdf(
      collectionId: collectionId,
      pdfFile: file,
    );

    return {
      ...uploadResult,
      'local_file_path': file.path,
    };
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
      case 'photo_text':
        if (value is Map) {
          final photo = value['photo'];
          final text = value['text'];
          final photoPart = (photo != null && photo.toString().isNotEmpty)
              ? '1 foto'
              : 'Sem foto';
          final textPart = (text != null && text.toString().isNotEmpty)
              ? _sanitizePdfText(text.toString())
              : 'Sem descricao';
          return '$photoPart - $textPart';
        }
        return 'Nao informado';
      case 'shelf_space':
        if (value is List && value.isNotEmpty) {
          final facings = value
              .whereType<Map>()
              .map((entry) => entry['facings'])
              .whereType<num>()
              .fold<num>(0, (sum, item) => sum + item);
          return '${value.length} produto(s) contado(s) - $facings frentes';
        }
        return 'Nao informado';
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

  static String _formatFieldValue(BrandField field, dynamic value) {
    if (field.fieldType != 'product') {
      return _formatValue(field.fieldType, value);
    }
    final products = field.fieldConfig?.products ?? const [];
    final labelsById = <String, String>{};
    for (final product in products) {
      if (product is Map) {
        final id = product['value'] ?? product['id'];
        final label =
            product['label'] ?? product['name'] ?? product['sku'] ?? id;
        if (id != null) labelsById[id.toString()] = label.toString();
      }
    }
    final selected = value is List ? value : [value];
    final labels = selected
        .where((item) => item != null && item.toString().isNotEmpty)
        .map((item) => labelsById[item.toString()] ?? item.toString())
        .toList();
    return labels.isEmpty
        ? 'Nao informado'
        : _sanitizePdfText(labels.join(', '));
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
      case 'photo_text':
        return PdfColor.fromHex('00ACC1');
      case 'date':
        return PdfColor.fromHex('8E24AA');
      case 'number':
        return PdfColor.fromHex('EF6C00');
      case 'textarea':
        return PdfColor.fromHex('546E7A');
      case 'select':
        return PdfColor.fromHex('7E57C2');
      case 'product':
        return PdfColor.fromHex('00897B');
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
      case 'photo_text':
        return 'Foto e texto';
      case 'date':
        return 'Data';
      case 'number':
        return 'Numero';
      case 'textarea':
        return 'Texto longo';
      case 'select':
        return 'Selecao';
      case 'product':
        return 'Produtos';
      case 'shelf_space':
        return 'Espaco na gondola';
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

    // Mantem apenas caracteres seguros para as fontes base (Helvetica)
    // e evita glifos invalidos quebrando renderizacao do PDF.
    final safe = text
        .replaceAll(RegExp(r'[^\x09\x0A\x0D\x20-\x7E\xA0-\xFF]'), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();

    return safe.isEmpty ? fallback : safe;
  }
}

class _PhotoEntry {
  final String label;
  final String url;
  final String? note;

  const _PhotoEntry(this.label, this.url, {this.note});
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
