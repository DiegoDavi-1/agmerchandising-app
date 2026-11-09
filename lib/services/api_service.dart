import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/network/connectivity_service.dart';
import '../core/photo_quality.dart';
import 'cache_service.dart';
import 'collection_queue_storage.dart';

/// Serviço de comunicação com servidor Express.js
class ApiService {
  // URL do servidor - Produção VPS (HTTPS com domínio)
  static const String baseUrl = 'https://merchhubapp.com/api';
  static const Duration _requestTimeout = Duration(seconds: 25);

  static String? resolvePhotoUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    return Uri.parse(baseUrl).resolve(url).toString();
  }

  static String? _token;
  static String? _refreshToken;
  static Function()? _onTokenExpired;
  static Future<void> Function()? onTrackingStop;
  static Future<void> Function()? onAuthReady;
  static Future<void> Function()? onBeforeLogout;
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
  static Future<Map<String, dynamic>> login(
      String login, String password) async {
    try {
      final headers = await PhotoQuality.deviceHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json', ...headers},
        body: jsonEncode({'login': login.trim(), 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          _token = data['token'];
          _refreshToken = data['refreshToken'];

          // Salvar tokens com segurança
          await _storage.write(key: 'auth_token', value: _token);
          await _storage.write(key: 'refresh_token', value: _refreshToken);

          await onAuthReady?.call();
          return data;
        }
      }
      throw Exception(
          jsonDecode(response.body)['error'] ?? 'Erro ao fazer login');
    } catch (e) {
      throw Exception('Erro de conexão: $e');
    }
  }

  /// Renovar token usando refresh token
  static Future<bool>? _refreshInFlight;

  static Future<bool> refresh() {
    if (_refreshToken == null) return Future.value(false);
    // Chamadas simultâneas aguardam a mesma renovação em vez de falhar (e deslogar).
    return _refreshInFlight ??=
        _doRefresh().whenComplete(() => _refreshInFlight = null);
  }

  static Future<bool> _doRefresh() async {
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

          await onAuthReady?.call();
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Fazer logout
  static Future<void> logout() async {
    await onBeforeLogout?.call();
    await onTrackingStop?.call();
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
  static bool isAuthenticated() => _token != null || _refreshToken != null;

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
      final response =
          await _requestWithRetry(() => http.get(uri, headers: _getHeaders()));

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
      throw Exception(
          jsonDecode(response.body)['error'] ?? 'Erro ao criar marca');
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
      throw Exception(
          jsonDecode(response.body)['error'] ?? 'Erro ao atualizar marca');
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
      throw Exception(
          jsonDecode(response.body)['error'] ?? 'Erro ao criar pedido');
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
      throw Exception(
          jsonDecode(response.body)['error'] ?? 'Erro ao atualizar pedido');
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

    for (int attempt = 0;
        attempt < maxRetries && _shouldRetry(response.statusCode);
        attempt++) {
      final jitter = Random().nextInt(250);
      final delay = Duration(
          milliseconds: baseDelay.inMilliseconds * (2 << attempt) + jitter);
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

    for (int attempt = 0;
        attempt < maxRetries && _shouldRetry(response.statusCode);
        attempt++) {
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
    return lower.startsWith('/') ||
        lower.startsWith('file://') ||
        lower.contains(':\\');
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

  static Future<Map<String, dynamic>> normalizeCollectionItem(
      Map<String, dynamic> item) async {
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
      } else if (value is Map<String, dynamic>) {
        final updated = Map<String, dynamic>.from(value);
        final photo = updated['photo'];
        if (photo is String) {
          updated['photo'] = await _uploadIfLocal(photo);
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
  static Future<List<Map<String, dynamic>>> getBrandFields(int brandId,
      {int? storeId}) async {
    try {
      String? lastUpdated;
      final cached =
          await CacheService.getCachedBrandFields(brandId, storeId: storeId);
      if (cached != null) {
        lastUpdated = cached['meta']?['last_updated'] as String?;
      }

      final query = <String, String>{
        if (lastUpdated != null) 'if_updated_after': lastUpdated,
        if (storeId != null) 'store_id': storeId.toString(),
      };

      final uri = Uri.parse('$baseUrl/brands/$brandId/fields')
          .replace(queryParameters: query);
      final response =
          await _requestWithRetry(() => http.get(uri, headers: _getHeaders()));

      if (response.statusCode == 401) {
        await _checkTokenExpired(401);
        return getBrandFields(brandId, storeId: storeId);
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          if (data['not_modified'] == true && cached != null) {
            return List<Map<String, dynamic>>.from(
                cached['data'] as List<dynamic>);
          }

          final fields = List<Map<String, dynamic>>.from(data['fields'] ?? []);
          await CacheService.setCachedBrandFields(
            brandId: brandId,
            storeId: storeId,
            data: fields,
            lastUpdated: data['last_updated'] as String?,
          );
          return fields;
        }
      }

      throw Exception('Erro ao buscar campos da marca: ${response.statusCode}');
    } catch (e) {
      print('❌ Erro getBrandFields: $e');
      final cached =
          await CacheService.getCachedBrandFields(brandId, storeId: storeId);
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
    bool requiresVisitClock = false,
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
        if (requiresVisitClock) {
          return {
            'success': false,
            'error':
                'Esta loja exige entrada e saída online. Reconecte-se para concluir o atendimento.',
          };
        }
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
          storeId: storeId,
          latitude: latitude,
          longitude: longitude,
          locationAddress: locationAddress,
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      }

      String backendError = 'Erro ao salvar coleta: ${response.statusCode}';
      try {
        final parsed = jsonDecode(response.body);
        final message = parsed is Map<String, dynamic>
            ? (parsed['error'] ?? parsed['message'])
            : null;
        if (message != null && message.toString().trim().isNotEmpty) {
          backendError = message.toString();
        }
      } catch (_) {}

      return {
        'success': false,
        'status': response.statusCode,
        'error': backendError,
      };
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

        request.headers.addAll(await PhotoQuality.deviceHeaders());
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
  static Future<Map<String, dynamic>?> uploadPhotos(
      List<File> imageFiles) async {
    try {
      final response = await _sendMultipartWithRetry(() async {
        final uri = Uri.parse('$baseUrl/upload/photos');
        final request = http.MultipartRequest('POST', uri);

        if (_token != null) {
          request.headers['Authorization'] = 'Bearer $_token';
        }

        for (var imageFile in imageFiles) {
          request.headers.addAll(await PhotoQuality.deviceHeaders());
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

      final streamed =
          await request.send().timeout(const Duration(seconds: 60));
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

  // ===== USUÁRIO LOGADO (dados persistidos localmente) =====

  /// Salva os dados do usuário retornados no login (nome, papel/role, etc.)
  static Future<void> saveUserData(Map<String, dynamic> user) async {
    await _storage.write(key: 'user_data', value: jsonEncode(user));
  }

  /// Recupera os dados do usuário salvos localmente
  static Future<Map<String, dynamic>?> getUserData() async {
    final raw = await _storage.read(key: 'user_data');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Verifica se o usuário logado tem papel de supervisor
  static Future<bool> isSupervisor() async {
    final user = await getUserData();
    final role = user?['role']?.toString().toLowerCase();
    return role == 'supervisor';
  }

  // ===== PONTO (CLOCK IN/OUT) =====

  /// Lojas do roteiro de hoje, usadas para vincular o registro de ponto a uma loja
  static Future<Map<String, dynamic>> fetchClockTodayStores() async {
    try {
      final response = await _requestWithRetry(
        () => http.get(Uri.parse('$baseUrl/clock/today-stores'),
            headers: _getHeaders()),
      );
      await _checkTokenExpired(response.statusCode);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'stores': []};
    } catch (e) {
      return {'success': false, 'stores': [], 'error': e.toString()};
    }
  }

  /// Situação atual do ponto (aberto/fechado, última marcação)
  static Future<Map<String, dynamic>> fetchClockStatus() async {
    try {
      final response = await _requestWithRetry(
        () => http.get(Uri.parse('$baseUrl/clock/status'),
            headers: _getHeaders()),
      );
      await _checkTokenExpired(response.statusCode);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Estado da visita aberta e política de entrada/saída de uma loja.
  static Future<Map<String, dynamic>> fetchVisitStatus(
      int storeId, int brandId) async {
    try {
      final uri = Uri.parse('$baseUrl/clock/visit-status').replace(
        queryParameters: {
          'store_id': storeId.toString(),
          'brand_id': brandId.toString(),
        },
      );
      final response =
          await _requestWithRetry(() => http.get(uri, headers: _getHeaders()));
      await _checkTokenExpired(response.statusCode);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      return {
        'success': false,
        'error': body['error'] ?? 'Não foi possível verificar a visita.',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Validades registradas para a loja + marca da visita ou listagem geral.
  static Future<List<Map<String, dynamic>>> fetchExpiries(
      [int? storeId, int? brandId]) async {
    final queryParams = <String, String>{};
    if (storeId != null) queryParams['store_id'] = storeId.toString();
    if (brandId != null) queryParams['brand_id'] = brandId.toString();

    final uri = Uri.parse('$baseUrl/expiries')
        .replace(queryParameters: queryParams.isEmpty ? null : queryParams);
    final response =
        await _requestWithRetry(() => http.get(uri, headers: _getHeaders()));
    await _checkTokenExpired(response.statusCode);
    final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    if (response.statusCode == 200 && body['success'] == true) {
      return List<Map<String, dynamic>>.from(body['data'] ?? const []);
    }
    throw Exception(body['error'] ?? 'Não foi possível carregar as validades.');
  }

  static Future<void> createExpiry({
    required int storeId,
    required int brandId,
    required String productName,
    required DateTime expiryDate,
    int? quantity,
    String? batch,
    String? category,
  }) async {
    final date =
        '${expiryDate.year.toString().padLeft(4, '0')}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}';
    final response = await _requestWithRetry(() => http.post(
          Uri.parse('$baseUrl/expiries'),
          headers: _getHeaders(),
          body: jsonEncode({
            'store_id': storeId,
            'brand_id': brandId,
            'product_name': productName,
            'expiry_date': date,
            'quantity': quantity,
            'batch': batch,
            'category': category,
          }),
        ));
    await _checkTokenExpired(response.statusCode);
    final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    if (response.statusCode != 201 || body['success'] != true) {
      throw Exception(body['error'] ?? 'Não foi possível salvar a validade.');
    }
  }

  static Future<void> deleteExpiry(int id) async {
    final response = await _requestWithRetry(() => http.delete(
          Uri.parse('$baseUrl/expiries/$id'),
          headers: _getHeaders(),
        ));
    await _checkTokenExpired(response.statusCode);
    final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
    if (response.statusCode != 200 || body['success'] != true) {
      throw Exception(body['error'] ?? 'Não foi possível remover a validade.');
    }
  }

  /// Histórico de marcações de ponto
  static Future<Map<String, dynamic>> fetchClockHistory(
      {int perPage = 20}) async {
    try {
      final uri = Uri.parse('$baseUrl/clock/history').replace(
        queryParameters: {'perPage': perPage.toString()},
      );
      final response =
          await _requestWithRetry(() => http.get(uri, headers: _getHeaders()));
      await _checkTokenExpired(response.statusCode);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'data': []};
    } catch (e) {
      return {'success': false, 'data': [], 'error': e.toString()};
    }
  }

  /// Registrar marcação de ponto (entrada/saída) com foto e geolocalização
  static Future<Map<String, dynamic>> clockIn({
    required String type,
    double? latitude,
    double? longitude,
    String? location,
    double? accuracy,
    bool isMockLocation = false,
    File? photoFile,
    int? storeId,
  }) async {
    try {
      final response = await _sendMultipartWithRetry(() async {
        final uri = Uri.parse('$baseUrl/clock');
        final request = http.MultipartRequest('POST', uri);
        if (_token != null) {
          request.headers['Authorization'] = 'Bearer $_token';
        }
        request.fields['type'] = type;
        if (latitude != null) request.fields['latitude'] = latitude.toString();
        if (longitude != null) {
          request.fields['longitude'] = longitude.toString();
        }
        if (location != null) request.fields['location'] = location;
        if (accuracy != null) request.fields['accuracy'] = accuracy.toString();
        request.fields['is_mock_location'] = isMockLocation ? 'true' : 'false';
        if (storeId != null) request.fields['store_id'] = storeId.toString();
        if (photoFile != null) {
          request.files
              .add(await http.MultipartFile.fromPath('photo', photoFile.path));
        }
        final streamed = await request.send();
        return http.Response.fromStream(streamed);
      });

      await _checkTokenExpired(response.statusCode);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      return {
        'success': false,
        'error': body['error'] ?? 'Erro ao registrar ponto'
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ===== SUPERVISÃO (EQUIPE) =====
  static Future<Map<String, dynamic>> fetchTrackingSession() async {
    final response = await _requestWithRetry(() => http.get(
          Uri.parse('$baseUrl/promoter/tracking/session'),
          headers: _getHeaders(),
        ));
    await _checkTokenExpired(response.statusCode);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Erro ao consultar rastreamento');
    }
    return data;
  }

  static Future<Map<String, dynamic>> sendTrackingLocation({
    required int clockEntryId,
    required double latitude,
    required double longitude,
    required double accuracy,
    required DateTime observedAt,
    required bool isMockLocation,
  }) async {
    final response = await _requestWithRetry(() => http.post(
          Uri.parse('$baseUrl/promoter/tracking/location'),
          headers: _getHeaders(),
          body: jsonEncode({
            'clock_entry_id': clockEntryId,
            'latitude': latitude,
            'longitude': longitude,
            'accuracy': accuracy,
            'observed_at': observedAt.toUtc().toIso8601String(),
            'is_mock_location': isMockLocation,
          }),
        ));
    await _checkTokenExpired(response.statusCode);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 409 && data['tracking_stopped'] == true)
      return data;
    if (response.statusCode != 200) {
      throw Exception(data['error'] ?? 'Erro ao enviar localização');
    }
    return data;
  }

  /// Visão geral da equipe supervisionada
  static Future<Map<String, dynamic>> fetchSupervisorOverview({
    required String startDate,
    required String endDate,
  }) =>
      _portalRequest(
        'supervisor/overview',
        query: {'startDate': startDate, 'endDate': endDate},
      );

  static Future<List<dynamic>> getSupervisorBrands() async {
    final response = await _portalRequest('supervisor/brands');
    return response['data'] as List<dynamic>;
  }

  static Future<Map<String, dynamic>> fetchSupervisorAttendances({
    required String startDate,
    required String endDate,
    String? brandId,
    String? status,
  }) =>
      _portalRequest('supervisor/attendances', query: {
        'startDate': startDate,
        'endDate': endDate,
        if (brandId != null) 'brandId': brandId,
        if (status != null) 'status': status,
      });

  static Future<Map<String, dynamic>> fetchSupervisorPhotos({
    required String startDate,
    required String endDate,
    String? brandId,
    String status = 'pending',
  }) =>
      _portalRequest('supervisor/photos', query: {
        'status': status,
        'startDate': startDate,
        'endDate': endDate,
        if (brandId != null) 'brandId': brandId,
      });

  static Future<Map<String, dynamic>> reviewSupervisorPhoto(
    Object id, {
    required String status,
    String? message,
  }) =>
      _portalRequest('supervisor/photos/${Uri.encodeComponent('$id')}/review',
          body: {
            'status': status,
            if (message != null && message.isNotEmpty) 'message': message,
          });

  static Future<Map<String, dynamic>> fetchSupervisorMessages() =>
      _portalRequest('supervisor/messages');

  static Future<Map<String, dynamic>> sendSupervisorMessage({
    required Object promoterId,
    required String type,
    required String message,
    Object? collectionId,
    String? photoUrl,
  }) =>
      _portalRequest('supervisor/messages', body: {
        'promoterId': promoterId,
        'type': type,
        'message': message,
        if (collectionId != null) 'collectionId': collectionId,
        if (photoUrl != null && photoUrl.isNotEmpty) 'photoUrl': photoUrl,
      });

  static Future<Map<String, dynamic>> fetchPromoterMessages() =>
      _portalRequest('promoter/messages');

  static Future<Map<String, dynamic>> fetchNonVisitReasons() =>
      _portalRequest('non-visit-reasons');

  static Future<Map<String, dynamic>> saveNonVisit(
          Map<String, dynamic> payload) =>
      _portalRequest('non-visits', body: payload);

  static Future<Map<String, dynamic>> requestNonVisitReschedule(
          int nonVisitId, DateTime date) =>
      _portalRequest('non-visits/$nonVisitId/reschedule',
          body: {'date': '${date.year}-'
              '${date.month.toString().padLeft(2, '0')}-'
              '${date.day.toString().padLeft(2, '0')}'});

  static Future<Map<String, dynamic>> sendSupportMessage({
    required String category,
    required String subject,
    required String message,
    required String appVersion,
    required String platform,
  }) =>
      _portalRequest('support/messages', body: {
        'category': category,
        'subject': subject,
        'message': message,
        'app_version': appVersion,
        'platform': platform,
      });

  static Future<Map<String, dynamic>> fetchMySupportMessages() =>
      _portalRequest('support/messages/mine');

  static Future<Map<String, dynamic>> markSupportRepliesSeen() =>
      _portalRequest('support/messages/seen', body: {});

  static Future<Map<String, dynamic>> fetchRouteChangeOptions() =>
      _portalRequest('route-change-requests/options');

  static Future<Map<String, dynamic>> fetchMyRouteChangeRequests() =>
      _portalRequest('route-change-requests/mine');

  static Future<Map<String, dynamic>> sendRouteChangeRequest({
    required int storeId,
    required int brandId,
    required String action,
    required List<int> weekdays,
    String? note,
  }) =>
      _portalRequest('route-change-requests', body: {
        'store_id': storeId,
        'brand_id': brandId,
        'action': action,
        'weekdays': weekdays,
        if (note != null && note.isNotEmpty) 'note': note,
      });

  static Future<Map<String, dynamic>> markPromoterMessageRead(Object id) =>
      _portalRequest('promoter/messages/${Uri.encodeComponent('$id')}/read',
          body: {});

  static Future<Map<String, dynamic>> replyPromoterMessage(
    Object id,
    String message,
  ) =>
      _portalRequest('promoter/messages/${Uri.encodeComponent('$id')}/reply',
          body: {'message': message});

  // ===== ANOTAÇÕES DO PROMOTOR =====
  static Future<List<Map<String, dynamic>>> fetchPromoterNotes(
      {int? storeId}) async {
    final res = await _portalRequest('promoter/notes',
        query: storeId != null ? {'store_id': storeId.toString()} : null);
    return List<Map<String, dynamic>>.from(res['data'] ?? const []);
  }

  static Future<void> createPromoterNote({
    required String title,
    required String content,
    int? storeId,
    int? brandId,
    bool isPinned = false,
  }) async {
    await _portalRequest('promoter/notes', body: {
      'title': title,
      'content': content,
      if (storeId != null) 'store_id': storeId,
      if (brandId != null) 'brand_id': brandId,
      'is_pinned': isPinned,
    });
  }

  static Future<void> deletePromoterNote(int id) async {
    final uri = Uri.parse('$baseUrl/promoter/notes/$id');
    final response = await _requestWithRetry(
      () => http.delete(uri, headers: _getHeaders()),
    );
    await _checkTokenExpired(response.statusCode);
  }

  // ===== AUDITORIA / FEEDBACK DE FOTOS =====
  static Future<List<Map<String, dynamic>>> fetchPhotoReviews() async {
    final res = await _portalRequest('promoter/photo-reviews');
    return List<Map<String, dynamic>>.from(res['data'] ?? const []);
  }

  static Future<Map<String, dynamic>> _portalRequest(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl/$path').replace(queryParameters: query);
    Future<http.Response> send() => _requestWithRetry(
          () => body == null
              ? http.get(uri, headers: _getHeaders())
              : http.post(uri, headers: _getHeaders(), body: jsonEncode(body)),
          maxRetries: body == null ? 3 : 0,
        );
    var response = await send();
    if (response.statusCode == 401 && await ApiService.refresh()) {
      // Token renovado: refaz a chamada em vez de mostrar erro ao abrir o app.
      response = await send();
    }
    await _checkTokenExpired(response.statusCode);
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        result['success'] != true) {
      throw Exception(result['error']?.toString() ??
          'Falha na solicitação ($path): ${response.statusCode}');
    }
    return result;
  }

  /// Tarefas de supervisão pendentes
  static Future<Map<String, dynamic>> fetchSupervisorTasks() async {
    try {
      final response = await _requestWithRetry(
        () => http.get(Uri.parse('$baseUrl/supervisor/tasks'),
            headers: _getHeaders()),
      );
      await _checkTokenExpired(response.statusCode);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'data': []};
    } catch (e) {
      return {'success': false, 'data': [], 'error': e.toString()};
    }
  }
}
