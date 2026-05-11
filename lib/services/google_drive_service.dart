import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/app_logger.dart';

class GoogleDriveService {
  static final GoogleDriveService _instance = GoogleDriveService._internal();
  factory GoogleDriveService() => _instance;
  GoogleDriveService._internal();

  final _storage = const FlutterSecureStorage();
  static const _scopes = [drive.DriveApi.driveFileScope];

  // TODO: Adicionar suas credenciais OAuth2
  static const _clientId = 'SEU_CLIENT_ID_AQUI';
  static const _clientSecret = 'SEU_CLIENT_SECRET_AQUI';

  drive.DriveApi? _driveApi;

  /// Autentica com Google Drive
  Future<bool> authenticate() async {
    try {
      // Verificar se já tem credenciais salvas
      final savedCreds = await _storage.read(key: 'google_drive_creds');
      
      if (savedCreds != null) {
        // Usar credenciais salvas
        // TODO: Implementar refresh token
      }

      // Nova autenticação
      final id = ClientId(_clientId, _clientSecret);
      final client = await clientViaUserConsent(id, _scopes, _prompt);
      
      _driveApi = drive.DriveApi(client);
      
      // Salvar credenciais
      // await _storage.write(key: 'google_drive_creds', value: ...);
      
      return true;
    } catch (e) {
      AppLogger.error('Erro ao autenticar com Google Drive', e);
      return false;
    }
  }

  void _prompt(String url) {
    AppLogger.info('Acesse: $url');
  }

  /// Faz upload de um arquivo
  Future<String?> uploadFile(
    File file,
    String fileName, {
    String? folderId,
  }) async {
    if (_driveApi == null) {
      final success = await authenticate();
      if (!success) return null;
    }

    try {
      final media = drive.Media(file.openRead(), file.lengthSync());
      
      final driveFile = drive.File()
        ..name = fileName
        ..parents = folderId != null ? [folderId] : null;

      final response = await _driveApi!.files.create(
        driveFile,
        uploadMedia: media,
      );

      return response.id;
    } catch (e) {
      AppLogger.error('Erro ao fazer upload', e);
      return null;
    }
  }

  /// Cria pasta no Drive
  Future<String?> createFolder(String folderName, {String? parentId}) async {
    if (_driveApi == null) {
      final success = await authenticate();
      if (!success) return null;
    }

    try {
      final folder = drive.File()
        ..name = folderName
        ..mimeType = 'application/vnd.google-apps.folder'
        ..parents = parentId != null ? [parentId] : null;

      final response = await _driveApi!.files.create(folder);
      return response.id;
    } catch (e) {
      AppLogger.error('Erro ao criar pasta', e);
      return null;
    }
  }

  /// Busca pasta por nome
  Future<String?> findFolder(String folderName) async {
    if (_driveApi == null) {
      final success = await authenticate();
      if (!success) return null;
    }

    try {
      final query = "name='$folderName' and mimeType='application/vnd.google-apps.folder'";
      final response = await _driveApi!.files.list(q: query);
      
      if (response.files != null && response.files!.isNotEmpty) {
        return response.files!.first.id;
      }
      
      return null;
    } catch (e) {
      AppLogger.error('Erro ao buscar pasta', e);
      return null;
    }
  }

  /// Backup completo
  Future<bool> backupData(File dataFile) async {
    try {
      // Buscar ou criar pasta AG Merchandising
      String? folderId = await findFolder('AG Merchandising Backup');
      folderId ??= await createFolder('AG Merchandising Backup');

      if (folderId == null) return false;

      // Upload do arquivo
      final fileName = 'backup_${DateTime.now().toIso8601String()}.json';
      final fileId = await uploadFile(dataFile, fileName, folderId: folderId);

      return fileId != null;
    } catch (e) {
      AppLogger.error('Erro no backup', e);
      return false;
    }
  }
}
