/// Configuração da API
class ApiConfig {
  // Servidor de Produção VPS (HTTPS com domínio)
  static const String baseUrl = 'https://merchhubapp.com/api';

  /// Converte caminhos relativos (/uploads/...) em URL absoluta do servidor.
  static String? resolveAssetUrl(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final origin = baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    return raw.startsWith('/') ? '$origin$raw' : '$origin/$raw';
  }
  
  // Alternativas para desenvolvimento:
  // Android emulador: http://10.0.2.2:5000/api
  // Dispositivo real (rede local): http://192.168.1.7:5000/api
  // Localhost: http://localhost:5000/api
  
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const int maxRetries = 3;
  
  // Endpoints
  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login';
  
  static const String clockIn = '/clock';
  static const String clockHistory = '/clock/history';
  static const String clockLast = '/clock/last';
  
  static const String photoPost = '/photo';
  static const String photoGet = '/photos';
  
  static const String reportPost = '/report';
  static const String reportGet = '/reports';
  
  static const String inventoryPost = '/inventory';
  static const String inventoryGet = '/inventory';
}
