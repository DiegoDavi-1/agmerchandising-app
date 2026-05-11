import 'dart:io';
import 'package:image/image.dart' as img;
import '../utils/app_logger.dart';

class ImageCompressionService {
  static final ImageCompressionService _instance = ImageCompressionService._internal();
  factory ImageCompressionService() => _instance;
  ImageCompressionService._internal();

  /// Comprime uma imagem mantendo qualidade aceitável
  Future<File> compressImage(
    File file, {
    int maxWidth = 2560,
    int maxHeight = 1440,
    int quality = 92,
  }) async {
    try {
      // Ler imagem
      final bytes = await file.readAsBytes();
      img.Image? image = img.decodeImage(bytes);

      if (image == null) return file;

      // Redimensionar se necessário
      if (image.width > maxWidth || image.height > maxHeight) {
        image = img.copyResize(
          image,
          width: image.width > maxWidth ? maxWidth : null,
          height: image.height > maxHeight ? maxHeight : null,
          maintainAspect: true,
        );
      }

      // Comprimir
      final compressed = img.encodeJpg(image, quality: quality);

      // Salvar
      await file.writeAsBytes(compressed);

      return file;
    } catch (e) {
      AppLogger.error('Erro ao comprimir imagem', e);
      return file;
    }
  }

  /// Comprime e retorna novo arquivo
  Future<File> compressAndSave(
    File sourceFile,
    String destinationPath, {
    int maxWidth = 2560,
    int maxHeight = 1440,
    int quality = 92,
  }) async {
    try {
      final bytes = await sourceFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);

      if (image == null) {
        await sourceFile.copy(destinationPath);
        return File(destinationPath);
      }

      if (image.width > maxWidth || image.height > maxHeight) {
        image = img.copyResize(
          image,
          width: image.width > maxWidth ? maxWidth : null,
          height: image.height > maxHeight ? maxHeight : null,
          maintainAspect: true,
        );
      }

      final compressed = img.encodeJpg(image, quality: quality);
      final destFile = File(destinationPath);
      await destFile.writeAsBytes(compressed);

      return destFile;
    } catch (e) {
      AppLogger.error('Erro ao comprimir e salvar imagem', e);
      await sourceFile.copy(destinationPath);
      return File(destinationPath);
    }
  }

  /// Retorna tamanho do arquivo em MB
  Future<double> getFileSizeMB(File file) async {
    final bytes = await file.length();
    return bytes / (1024 * 1024);
  }
}
