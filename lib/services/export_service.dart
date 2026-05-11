import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  /// Exporta validades para CSV
  Future<File> exportValidadesToCSV(List<dynamic> validades) async {
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/validades_$timestamp.csv');

    List<List<dynamic>> rows = [
      ['Produto', 'Data Validade', 'Dias Restantes', 'Categoria', 'Lote', 'Status'],
    ];

    for (var item in validades) {
      final dataValidade = DateTime.parse(item['dataValidade']);
      final diasRestantes = dataValidade.difference(DateTime.now()).inDays;
      String status;
      
      if (diasRestantes < 0) {
        status = 'Vencido';
      } else if (diasRestantes <= 7) {
        status = 'Crítico';
      } else if (diasRestantes <= 30) {
        status = 'Atenção';
      } else {
        status = 'Normal';
      }

      rows.add([
        item['produto'],
        DateFormat('dd/MM/yyyy').format(dataValidade),
        diasRestantes,
        item['categoria'] ?? '',
        item['lote'] ?? '',
        status,
      ]);
    }

    String csv = const ListToCsvConverter().convert(rows);
    await file.writeAsString(csv);

    return file;
  }

  /// Exporta validades para Excel
  Future<File> exportValidadesToExcel(List<dynamic> validades) async {
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];

    // Estilo do cabeçalho
    final headerStyle = workbook.styles.add('HeaderStyle');
    headerStyle.bold = true;
    headerStyle.backColor = '#9C3FE4';
    headerStyle.fontColor = '#FFFFFF';

    // Cabeçalhos
    sheet.getRangeByIndex(1, 1).setText('Produto');
    sheet.getRangeByIndex(1, 2).setText('Data Validade');
    sheet.getRangeByIndex(1, 3).setText('Dias Restantes');
    sheet.getRangeByIndex(1, 4).setText('Categoria');
    sheet.getRangeByIndex(1, 5).setText('Lote');
    sheet.getRangeByIndex(1, 6).setText('Status');

    // Aplicar estilo ao cabeçalho
    for (int i = 1; i <= 6; i++) {
      sheet.getRangeByIndex(1, i).cellStyle = headerStyle;
    }

    // Dados
    int row = 2;
    for (var item in validades) {
      final dataValidade = DateTime.parse(item['dataValidade']);
      final diasRestantes = dataValidade.difference(DateTime.now()).inDays;
      String status;
      String statusColor;

      if (diasRestantes < 0) {
        status = 'Vencido';
        statusColor = '#FF0000';
      } else if (diasRestantes <= 7) {
        status = 'Crítico';
        statusColor = '#FF5722';
      } else if (diasRestantes <= 30) {
        status = 'Atenção';
        statusColor = '#FFC107';
      } else {
        status = 'Normal';
        statusColor = '#4CAF50';
      }

      sheet.getRangeByIndex(row, 1).setText(item['produto']);
      sheet.getRangeByIndex(row, 2).setText(DateFormat('dd/MM/yyyy').format(dataValidade));
      sheet.getRangeByIndex(row, 3).setNumber(diasRestantes.toDouble());
      sheet.getRangeByIndex(row, 4).setText(item['categoria'] ?? '');
      sheet.getRangeByIndex(row, 5).setText(item['lote'] ?? '');
      sheet.getRangeByIndex(row, 6).setText(status);

      // Colorir status
      final statusCell = sheet.getRangeByIndex(row, 6);
      statusCell.cellStyle.backColor = statusColor;
      statusCell.cellStyle.fontColor = '#FFFFFF';

      row++;
    }

    // Auto-fit colunas
    for (int i = 1; i <= 6; i++) {
      sheet.autoFitColumn(i);
    }

    // Salvar
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/validades_$timestamp.xlsx');

    final bytes = workbook.saveAsStream();
    await file.writeAsBytes(bytes);

    workbook.dispose();

    return file;
  }

  /// Exporta relatório de ponto para Excel
  Future<File> exportTimeclockToExcel(Map<String, dynamic> pontoData) async {
    final workbook = xlsio.Workbook();
    final sheet = workbook.worksheets[0];

    // Estilo do cabeçalho
    final headerStyle = workbook.styles.add('HeaderStyle');
    headerStyle.bold = true;
    headerStyle.backColor = '#9C3FE4';
    headerStyle.fontColor = '#FFFFFF';

    // Cabeçalhos
    sheet.getRangeByIndex(1, 1).setText('Data/Hora');
    sheet.getRangeByIndex(1, 2).setText('Tipo');
    sheet.getRangeByIndex(1, 3).setText('Marca');
    sheet.getRangeByIndex(1, 4).setText('Localização');
    sheet.getRangeByIndex(1, 5).setText('Latitude');
    sheet.getRangeByIndex(1, 6).setText('Longitude');
    sheet.getRangeByIndex(1, 7).setText('Precisão');
    sheet.getRangeByIndex(1, 8).setText('Status Segurança');

    for (int i = 1; i <= 8; i++) {
      sheet.getRangeByIndex(1, i).cellStyle = headerStyle;
    }

    // Dados
    int row = 2;
    for (var brandEntry in pontoData.entries) {
      final brandName = brandEntry.key;
      final entries = brandEntry.value as List;

      for (var entry in entries) {
        sheet.getRangeByIndex(row, 1).setText(
          DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(entry['dateTime']))
        );
        sheet.getRangeByIndex(row, 2).setText(entry['type']);
        sheet.getRangeByIndex(row, 3).setText(brandName);
        sheet.getRangeByIndex(row, 4).setText(entry['location'] ?? '');
        sheet.getRangeByIndex(row, 5).setNumber(entry['latitude'] ?? 0);
        sheet.getRangeByIndex(row, 6).setNumber(entry['longitude'] ?? 0);
        sheet.getRangeByIndex(row, 7).setNumber(entry['accuracy'] ?? 0);
        
        final isMock = entry['isMockLocation'] ?? false;
        final accuracy = entry['accuracy'] ?? 0;
        String status = 'OK';
        String statusColor = '#4CAF50';

        if (isMock) {
          status = 'GPS Fake';
          statusColor = '#FF0000';
        } else if (accuracy > 100) {
          status = 'Baixa Precisão';
          statusColor = '#FFC107';
        }

        final statusCell = sheet.getRangeByIndex(row, 8);
        statusCell.setText(status);
        statusCell.cellStyle.backColor = statusColor;
        statusCell.cellStyle.fontColor = '#FFFFFF';

        row++;
      }
    }

    for (int i = 1; i <= 8; i++) {
      sheet.autoFitColumn(i);
    }

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/ponto_$timestamp.xlsx');

    final bytes = workbook.saveAsStream();
    await file.writeAsBytes(bytes);

    workbook.dispose();

    return file;
  }
}
