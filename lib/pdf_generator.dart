import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart' show rootBundle;
import 'models/brand_data.dart';

class PDFGenerator {
  // Cores do tema
  static const _primaryColor = PdfColor.fromInt(0xFF9C3FE4);
  // _secondaryColor disponível para uso futuro: 0xFF6B21A8
  static const _accentColor = PdfColor.fromInt(0xFFF59E0B);
  static const _successColor = PdfColor.fromInt(0xFF22C55E);
  static const _dangerColor = PdfColor.fromInt(0xFFEF4444);
  static const _bgLight = PdfColor.fromInt(0xFFF8F9FA);
  static const _textDark = PdfColor.fromInt(0xFF1F2937);
  static const _textMuted = PdfColor.fromInt(0xFF6B7280);

  static Future<File> generateBrandReport(BrandData brandData) async {
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
    );
    
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');
    final dataFormatada = brandData.dataRegistro != null
        ? dateFormat.format(brandData.dataRegistro!)
        : 'Não informado';
    final horaFormatada = brandData.dataRegistro != null
        ? timeFormat.format(brandData.dataRegistro!)
        : '';

    // Carregar logo do app
    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/images/logo_ag.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      // Se falhar ao carregar a logo, continua sem ela
      logoImage = null;
    }

    // Criar lista de fotos combinada (fotosComLocalizacao tem prioridade)
    final List<PhotoData> allPhotos;
    if (brandData.fotosComLocalizacao.isNotEmpty) {
      allPhotos = brandData.fotosComLocalizacao;
    } else {
      // Criar PhotoData a partir da lista simples de fotos
      allPhotos = brandData.fotos.map((path) => PhotoData(
        path: path,
        location: null,
        timestamp: brandData.dataRegistro ?? DateTime.now(),
      )).toList();
    }

    // Pré-processar imagens para melhor performance
    final processedPhotos = await _preprocessPhotos(allPhotos);

    // Calcular estatísticas
    final totalChecks = [
      brandData.abastecimento,
      brandData.precificacao,
      brandData.relatorio,
    ].where((e) => e).length;
    final checkPercentage = (totalChecks / 3 * 100).round();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => context.pageNumber == 1 
            ? _buildHeader(brandData.brandName, dataFormatada, horaFormatada, logoImage)
            : pw.SizedBox.shrink(),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          pw.SizedBox(height: 8),
          
          // Cards de resumo
          _buildSummaryCards(brandData, checkPercentage, processedPhotos.length),
          
          pw.SizedBox(height: 20),
          
          // Seção de localização
          if (brandData.localizacao != null && brandData.localizacao!.isNotEmpty)
            _buildLocationSection(brandData.localizacao!),
          
          pw.SizedBox(height: 20),
          
          // Seção de checklist
          _buildChecklistSection(brandData),
          
          // Seção de pendências
          if (brandData.pendencia && brandData.pendenciaDescricao.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _buildPendencySection(brandData.pendenciaDescricao),
          ],
          
          // Seção de ponto
          if (brandData.pontoEntradas.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _buildTimeClockSection(brandData.pontoEntradas),
          ],
          
          // Seção de fotos
          if (processedPhotos.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _buildPhotosSection(processedPhotos, allPhotos),
          ],
        ],
      ),
    );

    // Salvar PDF
    final output = await getTemporaryDirectory();
    final fileName = 'Relatorio_${brandData.brandName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${output.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    
    return file;
  }

  // Header elegante
  static pw.Widget _buildHeader(String brandName, String data, String hora, pw.MemoryImage? logo) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _primaryColor, width: 3)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Logo do app
              if (logo != null)
                pw.Container(
                  width: 50,
                  height: 50,
                  margin: const pw.EdgeInsets.only(right: 12),
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'AG MERCHANDISING',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: _primaryColor,
                      letterSpacing: 2,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    brandName.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: _textDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: _bgLight,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  data,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: _textDark,
                  ),
                ),
                if (hora.isNotEmpty)
                  pw.Text(
                    hora,
                    style: const pw.TextStyle(
                      fontSize: 11,
                      color: _textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Footer com paginação
  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Gerado em ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 8, color: _textMuted),
          ),
          pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _textMuted),
          ),
        ],
      ),
    );
  }

  // Cards de resumo
  static pw.Widget _buildSummaryCards(BrandData brandData, int percentage, int photoCount) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: _buildStatCard(
            'Conclusão',
            '$percentage%',
            _successColor,
            '$percentage% dos itens verificados',
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: _buildStatCard(
            'Fotos',
            '$photoCount',
            _primaryColor,
            'fotos registradas',
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: _buildStatCard(
            'Status',
            brandData.pendencia ? 'PENDENTE' : 'OK',
            brandData.pendencia ? _dangerColor : _successColor,
            brandData.pendencia ? 'Há pendências' : 'Sem pendências',
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildStatCard(String title, String value, PdfColor color, String subtitle) {
    return pw.ClipRRect(
      horizontalRadius: 8,
      verticalRadius: 8,
      child: pw.Container(
        decoration: const pw.BoxDecoration(
          color: PdfColors.grey100,
        ),
        child: pw.Row(
          children: [
            pw.Container(
              width: 4,
              height: 70,
              color: color,
            ),
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(12),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      title.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: _textMuted,
                        letterSpacing: 1,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      value,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: color,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      subtitle,
                      style: const pw.TextStyle(fontSize: 8, color: _textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Seção de localização
  static pw.Widget _buildLocationSection(String location) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _bgLight,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: _primaryColor,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              'LOC',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.white, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'LOCALIZAÇÃO',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _textMuted,
                    letterSpacing: 1,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  location,
                  style: const pw.TextStyle(fontSize: 11, color: _textDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Seção de checklist
  static pw.Widget _buildChecklistSection(BrandData brandData) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: const pw.BoxDecoration(
              color: _bgLight,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(8),
                topRight: pw.Radius.circular(8),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(
                    color: _primaryColor,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    'V',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Text(
                  'ITENS VERIFICADOS',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _textDark,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Column(
              children: [
                _buildCheckRow('Abastecimento', brandData.abastecimento, 'Produtos nas prateleiras'),
                pw.Divider(color: PdfColors.grey200, height: 16),
                _buildCheckRow('Precificação', brandData.precificacao, 'Preços atualizados'),
                pw.Divider(color: PdfColors.grey200, height: 16),
                _buildCheckRow('Relatório', brandData.relatorio, 'Documentação completa'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCheckRow(String title, bool checked, String description) {
    return pw.Row(
      children: [
        pw.Container(
          width: 24,
          height: 24,
          decoration: pw.BoxDecoration(
            color: checked ? _successColor : PdfColors.grey200,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Center(
            child: pw.Text(
              checked ? 'V' : '',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: checked ? _textDark : _textMuted,
                ),
              ),
              pw.Text(
                description,
                style: const pw.TextStyle(fontSize: 9, color: _textMuted),
              ),
            ],
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: pw.BoxDecoration(
            color: checked ? _successColor : PdfColors.grey400,
            borderRadius: pw.BorderRadius.circular(12),
          ),
          child: pw.Text(
            checked ? 'FEITO' : 'PENDENTE',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ),
      ],
    );
  }

  // Seção de pendências
  static pw.Widget _buildPendencySection(String description) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.red50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _dangerColor, width: 2),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                decoration: pw.BoxDecoration(
                  color: _dangerColor,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  '!',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                'PENDENCIA REGISTRADA',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: _dangerColor,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            description,
            style: const pw.TextStyle(fontSize: 11, color: _textDark),
          ),
        ],
      ),
    );
  }

  // Seção de ponto
  static pw.Widget _buildTimeClockSection(List<TimeClockEntry> entries) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    
    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: const pw.BoxDecoration(
              color: _bgLight,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(8),
                topRight: pw.Radius.circular(8),
              ),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(
                    color: _accentColor,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    'PT',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Text(
                  'REGISTRO DE PONTO',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _textDark,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey200),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _bgLight),
                  children: [
                    _buildTableHeader('Data/Hora'),
                    _buildTableHeader('Tipo'),
                    _buildTableHeader('Segurança'),
                  ],
                ),
                ...entries.map((e) => pw.TableRow(
                  children: [
                    _buildTableCell(dateFormat.format(e.dateTime)),
                    _buildTableCell(
                      e.type,
                      color: e.type == 'Entrada' ? _successColor : _accentColor,
                      bold: true,
                    ),
                    _buildTableCell(
                      e.securityStatus.replaceAll(RegExp(r'[✓⚠️❓]'), '').trim(),
                      fontSize: 8,
                    ),
                  ],
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: _textMuted,
        ),
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, {PdfColor? color, bool bold = false, double fontSize = 10}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : null,
          color: color ?? _textDark,
        ),
      ),
    );
  }

  // Seção de fotos
  static pw.Widget _buildPhotosSection(List<Uint8List> photos, List<PhotoData> photoData) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: _bgLight,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Row(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(4),
                decoration: pw.BoxDecoration(
                  color: _primaryColor,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'FT',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                'REGISTRO FOTOGRAFICO (${photos.length})',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: _textDark,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        ..._buildPhotoGrid(photos, photoData),
      ],
    );
  }

  static List<pw.Widget> _buildPhotoGrid(List<Uint8List> photos, List<PhotoData> photoData) {
    final List<pw.Widget> rows = [];
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    
    // 4 fotos por página (2x2)
    for (int i = 0; i < photos.length; i += 2) {
      final List<pw.Widget> rowChildren = [];
      
      // Primeira foto da linha
      rowChildren.add(
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(right: 6),
            child: _buildPhotoCard(
              photos[i],
              i + 1,
              i < photoData.length ? photoData[i].location : null,
              i < photoData.length ? dateFormat.format(photoData[i].timestamp) : null,
            ),
          ),
        ),
      );
      
      // Segunda foto da linha (se existir)
      if (i + 1 < photos.length) {
        rowChildren.add(
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(left: 6),
              child: _buildPhotoCard(
                photos[i + 1],
                i + 2,
                i + 1 < photoData.length ? photoData[i + 1].location : null,
                i + 1 < photoData.length ? dateFormat.format(photoData[i + 1].timestamp) : null,
              ),
            ),
          ),
        );
      } else {
        // Espaço vazio se número ímpar de fotos
        rowChildren.add(pw.Expanded(child: pw.SizedBox()));
      }
      
      rows.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: rowChildren,
          ),
        ),
      );
    }
    
    return rows;
  }

  static pw.Widget _buildPhotoCard(Uint8List imageBytes, int index, String? location, String? timestamp) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.ClipRRect(
            horizontalRadius: 6,
            verticalRadius: 6,
            child: pw.Container(
              height: 180,
              width: double.infinity,
              child: pw.Image(
                pw.MemoryImage(imageBytes),
                fit: pw.BoxFit.contain,
              ),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: const pw.BoxDecoration(
              color: _bgLight,
              borderRadius: pw.BorderRadius.only(
                bottomLeft: pw.Radius.circular(8),
                bottomRight: pw.Radius.circular(8),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Foto #$index',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: _textDark,
                      ),
                    ),
                    if (timestamp != null)
                      pw.Text(
                        timestamp,
                        style: const pw.TextStyle(fontSize: 8, color: _textMuted),
                      ),
                  ],
                ),
                if (location != null && location.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      pw.Icon(
                        pw.IconData(0xe55e),
                        size: 8,
                        color: _textMuted,
                      ),
                      pw.SizedBox(width: 3),
                      pw.Expanded(
                        child: pw.Text(
                          location,
                          style: const pw.TextStyle(fontSize: 8, color: _textMuted),
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Pré-processamento de fotos para performance
  static Future<List<Uint8List>> _preprocessPhotos(List<PhotoData> photos) async {
    final List<Uint8List> processed = [];
    
    for (final photo in photos) {
      try {
        final file = File(photo.path);
        if (!await file.exists()) continue;
        
        final bytes = await file.readAsBytes();
        
        // Decodificar e redimensionar para PDF
        final image = img.decodeImage(bytes);
        if (image == null) continue;
        
        // Redimensionar mantendo proporção (max 1200px para melhor qualidade)
        final maxDimension = 1200;
        img.Image resized;
        
        if (image.width > image.height) {
          // Paisagem - limitar largura
          resized = image.width > maxDimension 
              ? img.copyResize(image, width: maxDimension, interpolation: img.Interpolation.cubic)
              : image;
        } else {
          // Retrato - limitar altura
          resized = image.height > maxDimension 
              ? img.copyResize(image, height: maxDimension, interpolation: img.Interpolation.cubic)
              : image;
        }
        
        // Recodificar como JPEG com qualidade maior para melhor nitidez
        final compressed = img.encodeJpg(resized, quality: 88);
        processed.add(Uint8List.fromList(compressed));
      } catch (e) {
        // Se falhar, pular esta foto
        continue;
      }
    }
    
    return processed;
  }

  static Future<void> sharePDF(File pdfFile) async {
    await Share.shareXFiles(
      [XFile(pdfFile.path)],
      text: 'Relatório de Merchandising - AG Merchandising',
    );
  }
}
