/// Configuração da API
class ApiConfig {
  // Servidor de Produção VPS (HTTPS com domínio)
  static const String baseUrl = 'https://agmerchandising.com/api';
  
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
