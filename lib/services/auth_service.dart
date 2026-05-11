import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Serviço de autenticação - PREPARADO PARA SERVIDOR
/// Status: Desativado - Funciona localmente até configuração do servidor
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _storage = const FlutterSecureStorage();
  
  // Chaves de armazenamento
  static const _keyToken = 'auth_token';
  static const _keyUserId = 'user_id';
  static const _keyUsername = 'username';
  static const _keyPermissions = 'permissions';

  // Estado atual
  String? _currentToken;
  String? _currentUserId;
  String? _currentUsername;
  List<String>? _userPermissions;

  // URL do servidor - CONFIGURAR QUANDO DISPONÍVEL
  static const String serverUrl = 'https://agmerchandising.com/api';
  static const bool serverEnabled = true; // ✅ SERVIDOR HABILITADO

  /// Verifica se o usuário está autenticado
  Future<bool> isAuthenticated() async {
    if (serverEnabled) {
      _currentToken = await _storage.read(key: _keyToken);
      return _currentToken != null;
    }
    // Modo local: sempre autenticado
    return true;
  }

  /// Login do usuário - PREPARADO PARA SERVIDOR
  Future<Map<String, dynamic>> login(String username, String password) async {
    if (serverEnabled) {
      // TODO: Implementar chamada HTTP para servidor
      // final response = await http.post(
      //   Uri.parse('$serverUrl/auth/login'),
      //   body: {'username': username, 'password': password},
      // );
      // final data = jsonDecode(response.body);
      // await _saveAuthData(data);
      return {'success': false, 'message': 'Servidor não configurado'};
    }

    // Modo local: aceita qualquer login
    await _storage.write(key: _keyUsername, value: username);
    await _storage.write(key: _keyUserId, value: 'local_user');
    await _storage.write(key: _keyPermissions, value: 'ALL_BRANDS');
    
    _currentUsername = username;
    _currentUserId = 'local_user';
    _userPermissions = ['ALL_BRANDS'];

    return {'success': true, 'message': 'Login local realizado'};
  }

  /// Logout do usuário
  Future<void> logout() async {
    if (serverEnabled) {
      // TODO: Notificar servidor sobre logout
    }

    await _storage.deleteAll();
    _currentToken = null;
    _currentUserId = null;
    _currentUsername = null;
    _userPermissions = null;
  }

  /// Verifica se usuário tem permissão para acessar uma marca
  Future<bool> hasPermissionForBrand(String brandName) async {
    if (!serverEnabled) {
      // Modo local: acesso a todas as marcas
      return true;
    }

    _userPermissions ??= await _loadPermissions();
    return _userPermissions?.contains(brandName) ?? false;
  }

  /// Carrega permissões do usuário
  Future<List<String>> _loadPermissions() async {
    final permissions = await _storage.read(key: _keyPermissions);
    if (permissions == null) return [];
    return permissions.split(',');
  }

  /// Salva dados de autenticação
  // ignore: unused_element
  Future<void> _saveAuthData(Map<String, dynamic> data) async {
    await _storage.write(key: _keyToken, value: data['token']);
    await _storage.write(key: _keyUserId, value: data['userId']);
    await _storage.write(key: _keyUsername, value: data['username']);
    await _storage.write(key: _keyPermissions, value: (data['permissions'] as List).join(','));
    
    _currentToken = data['token'];
    _currentUserId = data['userId'];
    _currentUsername = data['username'];
    _userPermissions = List<String>.from(data['permissions']);
  }

  /// Obtém nome do usuário atual
  Future<String?> getCurrentUsername() async {
    _currentUsername ??= await _storage.read(key: _keyUsername);
    return _currentUsername;
  }

  /// Obtém ID do usuário atual
  Future<String?> getCurrentUserId() async {
    _currentUserId ??= await _storage.read(key: _keyUserId);
    return _currentUserId;
  }

  /// Obtém token de autenticação
  Future<String?> getToken() async {
    _currentToken ??= await _storage.read(key: _keyToken);
    return _currentToken;
  }
}
