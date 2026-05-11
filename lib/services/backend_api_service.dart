import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import '../utils/app_logger.dart';

/// Serviço para comunicação com a API backend
class ApiService {
  static final ApiService _instance = ApiService._internal();
  
  factory ApiService() {
    return _instance;
  }
  
  ApiService._internal();
  
  String? _token;
  
  /// Obtém o token salvo
  Future<String?> getToken() async {
    if (_token != null) return _token;
    
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    return _token;
  }
  
  /// Salva o token
  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }
  
  /// Limpa o token (logout)
  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }
  
  /// Obtém headers padronizados
  Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
  
  /// Faz uma requisição com retry automático
  Future<Map<String, dynamic>> _requestWithRetry(
    Future<http.Response> Function() request,
    String method,
    String endpoint, {
    int retryCount = 0,
  }) async {
    try {
      final response = await request().timeout(ApiConfig.connectTimeout);
      return _handleResponse(response);
    } catch (e) {
      if (retryCount < ApiConfig.maxRetries) {
        AppLogger.warning('⚠️ $method $endpoint falhou, tentando novamente... (${retryCount + 1}/${ApiConfig.maxRetries})');
        await Future.delayed(Duration(seconds: 2 * (retryCount + 1))); // Espera progressiva
        return _requestWithRetry(request, method, endpoint, retryCount: retryCount + 1);
      } else {
        AppLogger.error('❌ $method $endpoint falhou após ${ApiConfig.maxRetries} tentativas', e);
        return {'success': false, 'error': e.toString(), 'retriesExhausted': true};
      }
    }
  }
  
  /// Faz uma requisição GET
  Future<Map<String, dynamic>> get(String endpoint) async {
    return _requestWithRetry(
      () async => http.get(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: await _getHeaders(),
      ),
      'GET',
      endpoint,
    );
  }
  
  /// Faz uma requisição POST
  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body) async {
    return _requestWithRetry(
      () async => http.post(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      ),
      'POST',
      endpoint,
    );
  }
  
  /// Faz uma requisição PUT
  Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> body) async {
    return _requestWithRetry(
      () async => http.put(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: await _getHeaders(),
        body: jsonEncode(body),
      ),
      'PUT',
      endpoint,
    );
  }
  
  /// Faz uma requisição DELETE
  Future<Map<String, dynamic>> delete(String endpoint) async {
    return _requestWithRetry(
      () async => http.delete(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: await _getHeaders(),
      ),
      'DELETE',
      endpoint,
    );
  }
  
  /// Trata a resposta da API
  Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          ...body,
        };
      } else if (response.statusCode == 401) {
        clearToken();
        return {
          'success': false,
          'error': body['error'] ?? 'Não autorizado',
        };
      } else {
        return {
          'success': false,
          'error': body['error'] ?? 'Erro na API',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Erro ao processar resposta: $e',
      };
    }
  }
  
  /// Registrar novo usuário
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await post(ApiConfig.authRegister, {
      'name': name,
      'email': email,
      'password': password,
    });
    
    if (response['success'] == true && response['token'] != null) {
      await saveToken(response['token']);
    }
    
    return response;
  }
  
  /// Login
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await post(ApiConfig.authLogin, {
      'email': email,
      'password': password,
    });
    
    if (response['success'] == true && response['token'] != null) {
      await saveToken(response['token']);
    }
    
    return response;
  }
  
  /// Registrar entrada/saída
  Future<Map<String, dynamic>> clockInOut({
    required String type,
    required double latitude,
    required double longitude,
    String? location,
    double? accuracy,
    bool? isMockLocation,
  }) async {
    return post(ApiConfig.clockIn, {
      'type': type,
      'latitude': latitude,
      'longitude': longitude,
      'location': location,
      'accuracy': accuracy,
      'isMockLocation': isMockLocation ?? false,
    });
  }
  
  /// Registrar foto
  Future<Map<String, dynamic>> uploadPhoto({
    required String category,
    required String photoUrl,
    String? brandName,
    double? latitude,
    double? longitude,
    String? location,
    double? accuracy,
    String? description,
  }) async {
    return post(ApiConfig.photoPost, {
      'category': category,
      'photoUrl': photoUrl,
      'brandName': brandName,
      'latitude': latitude,
      'longitude': longitude,
      'location': location,
      'accuracy': accuracy,
      'description': description,
    });
  }
  
  /// Obter fotos do usuário
  Future<Map<String, dynamic>> getPhotos({String? category, String? startDate, String? endDate}) async {
    String endpoint = ApiConfig.photoGet;
    
    final params = <String>[];
    if (category != null) params.add('category=$category');
    if (startDate != null) params.add('startDate=$startDate');
    if (endDate != null) params.add('endDate=$endDate');
    
    if (params.isNotEmpty) {
      endpoint += '?${params.join('&')}';
    }
    
    return get(endpoint);
  }
  
  /// Registrar/atualizar relatório
  Future<Map<String, dynamic>> saveReport({
    required String brandName,
    required bool abastecimento,
    required bool precificacao,
    required bool relatorio,
    String? pendenciaDescricao,
    List<String>? photos,
    String? location,
    double? latitude,
    double? longitude,
    String? observations,
  }) async {
    return post(ApiConfig.reportPost, {
      'brandName': brandName,
      'abastecimento': abastecimento,
      'precificacao': precificacao,
      'relatorio': relatorio,
      'pendenciaDescricao': pendenciaDescricao,
      'photos': photos,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'observations': observations,
    });
  }
  
  /// Obter relatórios
  Future<Map<String, dynamic>> getReports({String? brandName, String? startDate, String? endDate}) async {
    String endpoint = ApiConfig.reportGet;
    
    final params = <String>[];
    if (brandName != null) params.add('brandName=$brandName');
    if (startDate != null) params.add('startDate=$startDate');
    if (endDate != null) params.add('endDate=$endDate');
    
    if (params.isNotEmpty) {
      endpoint += '?${params.join('&')}';
    }
    
    return get(endpoint);
  }
  
  /// Registrar abastecimento/precificação
  Future<Map<String, dynamic>> saveInventory({
    required String brandName,
    String? productName,
    int? quantity,
    double? price,
    String? priceStatus,
    String? location,
    double? latitude,
    double? longitude,
    String? observations,
  }) async {
    return post(ApiConfig.inventoryPost, {
      'brandName': brandName,
      'productName': productName,
      'quantity': quantity,
      'price': price,
      'priceStatus': priceStatus,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'observations': observations,
    });
  }
}
