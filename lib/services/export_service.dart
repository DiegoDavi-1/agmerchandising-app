import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

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

}
