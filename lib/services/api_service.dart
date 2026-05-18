import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/network/connectivity_service.dart';
import 'cache_service.dart';
import 'collection_queue_storage.dart';

/// Serviço de comunicação com servidor Express.js
class ApiService {
  // URL do servidor - Produção VPS (HTTPS com domínio)
  static const String baseUrl = 'https://agmerchandising.com/api';
  static const Duration _requestTimeout = Duration(seconds: 25);

  static String? _token;
  static String? _refreshToken;
  static Function()? _onTokenExpired;
  static bool _isRefreshing = false;
  static const _storage = FlutterSecureStorage();

  // Getter para token
  static String? get token => _token;

  // Inicializar e carregar tokens salvos
  static Future<void> init() async {
    _token = await _storage.read(key: 'auth_token');
    _refreshToken = await _storage.read(key: 'refresh_token');
  }

  // Registrar callback para token expirado
  static void setOnTokenExpired(Function() callback) {
    _onTokenExpired = callback;
  }

  // ===== AUTENTICAÇÃO =====
  /// Fazer login
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final looksLikeEmail = email.contains('@');
      final body = looksLikeEmail
          ? {'email': email, 'password': password}
          : {'login': email, 'password': password};

      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          _token = data['token'];
          _refreshToken = data['refreshToken'];
          
          // Salvar tokens com segurança
          await _storage.write(key: 'auth_token', value: _token);
          await _storage.write(key: 'refresh_token', value: _refreshToken);
          
          return data;
        }
      }
      throw Exception(jsonDecode(response.body)['error'] ?? 'Erro ao fazer login');
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  /// Renovar token usando refresh token
  static Future<bool> refresh() async {
    if (_refreshToken == null || _isRefreshing) return false;
    
    _isRefreshing = true;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': _refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          _token = data['token'];
          _refreshToken = data['refreshToken'];
          
          // Atualizar tokens salvos
          await _storage.write(key: 'auth_token', value: _token);
          await _storage.write(key: 'refresh_token', value: _refreshToken);
          
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Fazer logout
  static Future<void> logout() async {
    // Enviar logout ao servidor se tiver refreshToken
    if (_refreshToken != null) {
      try {
        await http.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': _refreshToken}),
        );
      } catch (e) {
        // Ignora erros - limpa localmente mesmo se servidor falhar
      }
    }
    
    // Limpar tokens da memória e storage
    _token = null;
    _refreshToken = null;
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'refresh_token');
  }

  /// Verificar se está autenticado
  static bool isAuthenticated() => _token != null;

  // ===== MARCAS (BRANDS) =====
  /// Listar marcas com cache e paginação
  static Future<List<dynamic>> getBrands({
    int page = 1,
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    try {
      String? lastUpdated;

      if (page == 1 && !forceRefresh) {
        final cached = await CacheService.getCachedBrands();
        if (cached != null) {
          lastUpdated = cached['meta']?['last_updated'] as String?;
        }
      }

      final query = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (lastUpdated != null) 'if_updated_after': lastUpdated,
      };

      final uri = Uri.parse('$baseUrl/brands').replace(queryParameters: query);
      final response = await _requestWithRetry(() => http.get(uri, headers: _getHeaders()));

      await _checkTokenExpired(response.statusCode);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          if (data['not_modified'] == true && page == 1) {
            final cached = await CacheService.getCachedBrands();
            return cached?['data'] ?? [];
          }

          final list = data['data'] ?? [];
          if (page == 1) {
            await CacheService.setCachedBrands(
              data: List<dynamic>.from(list),
              lastUpdated: data['last_updated'] as String?,
            );
          }
          return List<dynamic>.from(list);
        }
      }

      throw Exception('Erro ao buscar marcas');
    } catch (e) {
      if (page == 1) {
        final cached = await CacheService.getCachedBrands();
        if (cached != null) {
          return List<dynamic>.from(cached['data'] as List<dynamic>);
        }
      }
      throw Exception('Erro de conexão: $e');
    }
  }

  /// Buscar marca por ID
  static Future<Map<String, dynamic>> getBrandById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/brands/$id'),
        headers: _getHeaders(),
      );

      await _checkTokenExpired(response.statusCode);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) return data['data'];
      }
      throw Exception('Erro ao buscar marca');
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  /// Buscar lojas de uma marca disponível para o usuário autenticado
  static Future<List<Map<String, dynamic>>> getBrandStores(int brandId) async {
    try {
      final response = await _requestWithRetry(
        () => http.get(
          Uri.parse('$baseUrl/brands/$brandId/stores'),
          headers: _getHeaders(),
        ),
      );

      if (response.statusCode == 401) {
        await _checkTokenExpired(401);
        return getBrandStores(brandId);
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final stores = data['data'] ?? data['stores'] ?? [];
          return List<Map<String, dynamic>>.from(stores);
        }
      }

      throw Exception('Erro ao buscar lojas da marca: ${response.statusCode}');
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  /// Criar nova marca
  static Future<Map<String, dynamic>> createBrand({
    required String name,
    String? description,
    String? logoUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/brands'),
        headers: _getHeaders(),
        body: jsonEncode({
          'name': name,
          'description': description,
          'logo_url': logoUrl,
        }),
      );

      await _checkTokenExpired(response.statusCode);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception(jsonDecode(response.body)['error'] ?? 'Erro ao criar marca');
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  /// Editar marca
  static Future<Map<String, dynamic>> updateBrand({
    required int id,
    required String name,
    String? description,
    String? logoUrl,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/brands/$id'),
        headers: _getHeaders(),
        body: jsonEncode({
          'name': name,
          'description': description,
          'logo_url': logoUrl,
        }),
      );

      await _checkTokenExpired(response.statusCode);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception(jsonDecode(response.body)['error'] ?? 'Erro ao atualizar marca');
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  // ===== PEDIDOS (ORDERS) =====
  /// Listar todos os pedidos do usuário
  static Future<List<dynamic>> getOrders() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders'),
        headers: _getHeaders(),
      );

      await _checkTokenExpired(response.statusCode);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) return data['data'];
      }
      throw Exception('Erro ao buscar pedidos');
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  /// Buscar pedido por ID
  static Future<Map<String, dynamic>> getOrderById(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders/$id'),
        headers: _getHeaders(),
      );

      await _checkTokenExpired(response.statusCode);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) return data['data'];
      }
      throw Exception('Erro ao buscar pedido');
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  /// Criar novo pedido
  static Future<Map<String, dynamic>> createOrder({
    required int brandId,
    String? description,
    double? totalValue,
    String? photoUrl,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/orders'),
        headers: _getHeaders(),
        body: jsonEncode({
          'brand_id': brandId,
          'description': description,
          'total_value': totalValue,
          'photo_url': photoUrl,
        }),
      );

      await _checkTokenExpired(response.statusCode);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception(jsonDecode(response.body)['error'] ?? 'Erro ao criar pedido');
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  /// Editar pedido
  static Future<Map<String, dynamic>> updateOrder({
    required int id,
    String? description,
    double? totalValue,
    String? status,
    String? photoUrl,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/orders/$id'),
        headers: _getHeaders(),
        body: jsonEncode({
          'description': description,
          'total_value': totalValue,
          'status': status,
          'photo_url': photoUrl,
        }),
      );

      await _checkTokenExpired(response.statusCode);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception(jsonDecode(response.body)['error'] ?? 'Erro ao atualizar pedido');
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  // ===== HELPERS =====
  static bool _shouldRetry(int statusCode) {
    return statusCode == 429 || (statusCode >= 500 && statusCode < 600);
  }

  static Future<http.Response> _requestWithRetry(
    Future<http.Response> Function() request, {
    int maxRetries = 3,
    Duration baseDelay = const Duration(milliseconds: 500),
    Duration timeout = _requestTimeout,
  }) async {
    http.Response response = await request().timeout(timeout);

    for (int attempt = 0; attempt < maxRetries && _shouldRetry(response.statusCode); attempt++) {
      final jitter = Random().nextInt(250);
      final delay = Duration(milliseconds: baseDelay.inMilliseconds * (2 << attempt) + jitter);
      await Future.delayed(delay);
      response = await request().timeout(timeout);
    }

    return response;
  }

  static Future<http.Response> _sendMultipartWithRetry(
    Future<http.Response> Function() sendRequest, {
    int maxRetries = 3,
    Duration timeout = _requestTimeout,
  }) async {
    http.Response response = await sendRequest().timeout(timeout);

    for (int attempt = 0; attempt < maxRetries && _shouldRetry(response.statusCode); attempt++) {
      final jitter = Random().nextInt(250);
      final delay = Duration(milliseconds: 500 * (2 << attempt) + jitter);
      await Future.delayed(delay);
      response = await sendRequest().timeout(timeout);
    }

    return response;
  }

  static bool _isLocalPath(String path) {
    final lower = path.toLowerCase();
    if (lower.startsWith('http') || lower.startsWith('/uploads')) return false;
    return lower.startsWith('/') || lower.startsWith('file://') || lower.contains(':\\');
  }

  static Future<String> _uploadIfLocal(String path) async {
    if (!_isLocalPath(path)) return path;
    try {
      final file = File(path.replaceFirst('file://', ''));
      final result = await uploadPhoto(file);
      if (result != null && result['success'] == true) {
        return result['photo_url'] as String;
      }
      return path;
    } catch (_) {
      return path;
    }
  }

  static Future<Map<String, dynamic>> normalizeCollectionItem(Map<String, dynamic> item) async {
    if (!item.containsKey('data')) return item;
    final data = Map<String, dynamic>.from(item['data'] as Map);

    for (final entry in data.entries.toList()) {
      final value = entry.value;
      if (value is String) {
        data[entry.key] = await _uploadIfLocal(value);
      } else if (value is List) {
        final updated = <dynamic>[];
        for (final v in value) {
          if (v is String) {
            updated.add(await _uploadIfLocal(v));
          } else {
            updated.add(v);
          }
        }
        data[entry.key] = updated;
      }
    }

    return {
      ...item,
      'data': data,
    };
  }

  /// Verificar se token expirou (401) e tentar refresh automático
  static Future<void> _checkTokenExpired(int statusCode) async {
    if (statusCode == 401) {
      // Tentar renovar token antes de deslogar
      final refreshed = await ApiService.refresh();
      
      if (!refreshed) {
        // Refresh falhou - fazer logout
        await logout();
        if (_onTokenExpired != null) {
          _onTokenExpired!();
        }
      }
      // Se refresh funcionou, a próxima requisição usará o novo token
    }
  }

  /// Construir headers com autenticação
  static Map<String, String> _getHeaders() {
    final headers = {'Content-Type': 'application/json'};
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  /// Headers públicos para outros serviços
  static Map<String, String> getHeaders() {
    return _getHeaders();
  }

  /// Verificação pública de expiração de token
  static Future<void> checkTokenExpired(int statusCode) async {
    await _checkTokenExpired(statusCode);
  }

  // ===== CAMPOS CUSTOMIZÁVEIS DE MARCA =====
  
  /// Buscar campos customizáveis de uma marca com cache
  static Future<List<Map<String, dynamic>>> getBrandFields(int brandId, {int? storeId}) async {
    try {
      String? lastUpdated;
      final cached = await CacheService.getCachedBrandFields(brandId);
      if (cached != null) {
        lastUpdated = cached['meta']?['last_updated'] as String?;
      }

      final query = <String, String>{
        if (lastUpdated != null) 'if_updated_after': lastUpdated,
        if (storeId != null) 'store_id': storeId.toString(),
      };

      final uri = Uri.parse('$baseUrl/brands/$brandId/fields').replace(queryParameters: query);
      final response = await _requestWithRetry(() => http.get(uri, headers: _getHeaders()));

      if (response.statusCode == 401) {
        await _checkTokenExpired(401);
        return getBrandFields(brandId, storeId: storeId);
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          if (data['not_modified'] == true && cached != null) {
            return List<Map<String, dynamic>>.from(cached['data'] as List<dynamic>);
          }

          final fields = List<Map<String, dynamic>>.from(data['fields'] ?? []);
          await CacheService.setCachedBrandFields(
            brandId: brandId,
            data: fields,
            lastUpdated: data['last_updated'] as String?,
          );
          return fields;
        }
      }

      throw Exception('Erro ao buscar campos da marca: ${response.statusCode}');
    } catch (e) {
      print('❌ Erro getBrandFields: $e');
      final cached = await CacheService.getCachedBrandFields(brandId);
      if (cached != null) {
        return List<Map<String, dynamic>>.from(cached['data'] as List<dynamic>);
      }
      rethrow;
    }
  }

  /// Buscar templates de marcas disponíveis
  static Future<List<Map<String, dynamic>>> getBrandTemplates() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/brand-templates'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 401) {
        await _checkTokenExpired(401);
        return getBrandTemplates();
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return List<Map<String, dynamic>>.from(data['templates'] ?? []);
        }
      }

      throw Exception('Erro ao buscar templates: ${response.statusCode}');
    } catch (e) {
      print('❌ Erro getBrandTemplates: $e');
      rethrow;
    }
  }

  /// Salvar coleta de dados de uma marca (retry limitado)
  static Future<Map<String, dynamic>> saveCollection({
    required int brandId,
    required Map<String, dynamic> collectedData,
    String? brandName,
    int? storeId,
    double? latitude,
    double? longitude,
    String? locationAddress,
  }) async {
    final body = {
      'brand_id': brandId,
      'brandName': brandName,
      if (storeId != null) 'store_id': storeId,
      'data': collectedData,
      'latitude': latitude,
      'longitude': longitude,
      'location_address': locationAddress,
      'collected_at': DateTime.now().toIso8601String(),
    };

    try {
      final isOnline = await ConnectivityService().isOnline();
      if (!isOnline) {
        // Sem internet: salva na fila local para sincronizar depois
        await CollectionQueueStorage.enqueue(body);
        return {'success': true, 'offline': true};
      }

      final normalizedBody = await normalizeCollectionItem(body);

      final response = await _requestWithRetry(
        () => http.post(
          Uri.parse('$baseUrl/collections'),
          headers: _getHeaders(),
          body: jsonEncode(normalizedBody),
        ),
        maxRetries: 3,
      );

      if (response.statusCode == 401) {
        await _checkTokenExpired(401);
        return saveCollection(
          brandId: brandId,
          collectedData: collectedData,
          brandName: brandName,
          storeId: storeId,
          latitude: latitude,
          longitude: longitude,
          locationAddress: locationAddress,
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }

      throw Exception('Erro ao salvar coleta: ${response.statusCode}');
    } catch (e) {
      print('❌ Erro saveCollection: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Salvar coletas em lote
  static Future<Map<String, dynamic>> saveCollectionsBatch(
    List<Map<String, dynamic>> items,
  ) async {
    try {
      final response = await _requestWithRetry(() => http.post(
        Uri.parse('$baseUrl/collections/batch'),
        headers: _getHeaders(),
        body: jsonEncode({'items': items}),
      ));

      if (response.statusCode == 401) {
        await _checkTokenExpired(401);
        return saveCollectionsBatch(items);
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }

      return {'success': false, 'status': response.statusCode};
    } catch (e) {
      print('❌ Erro saveCollectionsBatch: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Upload de foto para o servidor
  static Future<Map<String, dynamic>?> uploadPhoto(File imageFile) async {
    try {
      final response = await _sendMultipartWithRetry(() async {
        final uri = Uri.parse('$baseUrl/upload/photo');
        final request = http.MultipartRequest('POST', uri);

        if (_token != null) {
          request.headers['Authorization'] = 'Bearer $_token';
        }

        request.files.add(
          await http.MultipartFile.fromPath('photo', imageFile.path),
        );

        final streamedResponse = await request.send();
        return http.Response.fromStream(streamedResponse);
      });

      if (response.statusCode == 401) {
        await _checkTokenExpired(401);
        return uploadPhoto(imageFile);
      }

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      throw Exception('Erro ao fazer upload: ${response.statusCode}');
    } catch (e) {
      print('❌ Erro uploadPhoto: $e');
      rethrow;
    }
  }

  /// Upload de múltiplas fotos
  static Future<Map<String, dynamic>?> uploadPhotos(List<File> imageFiles) async {
    try {
      final response = await _sendMultipartWithRetry(() async {
        final uri = Uri.parse('$baseUrl/upload/photos');
        final request = http.MultipartRequest('POST', uri);

        if (_token != null) {
          request.headers['Authorization'] = 'Bearer $_token';
        }

        for (var imageFile in imageFiles) {
          request.files.add(
            await http.MultipartFile.fromPath('photos', imageFile.path),
          );
        }

        final streamedResponse = await request.send();
        return http.Response.fromStream(streamedResponse);
      });

      if (response.statusCode == 401) {
        await _checkTokenExpired(401);
        return uploadPhotos(imageFiles);
      }

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }

      throw Exception('Erro ao fazer upload: ${response.statusCode}');
    } catch (e) {
      print('❌ Erro uploadPhotos: $e');
      rethrow;
    }
  }

  /// Upload de PDF de coleta para o servidor
  static Future<Map<String, dynamic>> uploadCollectionPdf({
    required int collectionId,
    required File pdfFile,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/collections/$collectionId/pdf');
      final request = http.MultipartRequest('POST', uri);

      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }

      request.files.add(
        await http.MultipartFile.fromPath('pdf', pdfFile.path,
        filename: 'relatorio_$collectionId.pdf',
        contentType: MediaType('application', 'pdf')),
      );

      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {
        'success': false,
        'error': 'Status ${response.statusCode}: ${response.body}'
      };
    } catch (e) {
      print('❌ Erro uploadCollectionPdf: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Resolver melhor link de PDF para um relatório/coleta.
  static Future<Map<String, dynamic>> getReportPdfLink(int reportId) async {
    try {
      final response = await _requestWithRetry(() => http.get(
        Uri.parse('$baseUrl/reports/$reportId/pdf-link'),
        headers: _getHeaders(),
      ));

      if (response.statusCode == 401) {
        await _checkTokenExpired(401);
        return getReportPdfLink(reportId);
      }

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      return {
        'success': false,
        'error': 'Status ${response.statusCode}: ${response.body}'
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ===== CONFIGURAÇÕES DE TEMA =====
  
  /// Obter preferências de tema do usuário
  static Future<Map<String, dynamic>> getPreferences() async {
    try {
      final response = await _requestWithRetry(
        () => http.get(
          Uri.parse('$baseUrl/config/preferences'),
          headers: _getHeaders(),
        ),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      if (response.statusCode == 401) {
        await _checkTokenExpired(response.statusCode);
      }

      throw Exception('Erro ao obter preferências: ${response.statusCode}');
    } catch (e) {
      print('❌ Erro getPreferences: $e');
      rethrow;
    }
  }

  /// Atualizar tema do usuário
  static Future<Map<String, dynamic>> updateTheme(String theme) async {
    try {
      if (!['light', 'dark'].contains(theme)) {
        throw Exception('Tema inválido. Use "light" ou "dark"');
      }

      final response = await _requestWithRetry(
        () => http.put(
          Uri.parse('$baseUrl/config/preferences/theme'),
          headers: _getHeaders(),
          body: jsonEncode({'theme': theme}),
        ),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      if (response.statusCode == 401) {
        await _checkTokenExpired(response.statusCode);
      }

      throw Exception('Erro ao atualizar tema: ${response.statusCode}');
    } catch (e) {
      print('❌ Erro updateTheme: $e');
      rethrow;
    }
  }

  /// Atualizar cores personalizadas
  static Future<Map<String, dynamic>> updateColors({
    String? primaryColor,
    String? accentColor,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (primaryColor != null) body['primaryColor'] = primaryColor;
      if (accentColor != null) body['accentColor'] = accentColor;

      final response = await _requestWithRetry(
        () => http.put(
          Uri.parse('$baseUrl/config/preferences/colors'),
          headers: _getHeaders(),
          body: jsonEncode(body),
        ),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      if (response.statusCode == 401) {
        await _checkTokenExpired(response.statusCode);
      }

      throw Exception('Erro ao atualizar cores: ${response.statusCode}');
    } catch (e) {
      print('❌ Erro updateColors: $e');
      rethrow;
    }
  }

  /// Obter temas disponíveis
  static Future<Map<String, dynamic>> getAvailableThemes() async {
    try {
      final response = await _requestWithRetry(
        () => http.get(
          Uri.parse('$baseUrl/config/themes'),
          headers: _getHeaders(),
        ),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      if (response.statusCode == 401) {
        await _checkTokenExpired(response.statusCode);
      }

      throw Exception('Erro ao obter temas: ${response.statusCode}');
    } catch (e) {
      print('❌ Erro getAvailableThemes: $e');
      rethrow;
    }
  }
}
