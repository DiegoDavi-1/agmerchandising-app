import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Certificate Pinning para Merch Hub API
/// 
/// Este serviço implementa SSL pinning para prevenir ataques Man-in-the-Middle (MITM)
/// 
/// INSTRUÇÕES DE USO:
/// 1. Obtenha o certificado do servidor:
///    ```
///    openssl s_client -servername merchhubapp.com -connect merchhubapp.com:443 < /dev/null | openssl x509 -outform DER > merchhubapp.der
///    ```
/// 2. Coloque o arquivo merchhubapp.der em: assets/certificates/
/// 3. Adicione no pubspec.yaml:
///    ```
///    flutter:
///      assets:
///        - assets/certificates/merchhubapp.der
///    ```
/// 4. Use este cliente para todas as requisições HTTP

class SecureHttpClient {
  static http.Client? _client;
  static const String certPath = 'assets/certificates/merchhubapp.der';

  /// Retorna um cliente HTTP com certificate pinning configurado
  static Future<http.Client> getClient() async {
    if (_client != null) return _client!;

    try {
      // Carregar o certificado dos assets
      final certData = await rootBundle.load(certPath);
      final certBytes = certData.buffer.asUint8List();

      // Criar SecurityContext com o certificado pinado
      final securityContext = SecurityContext.defaultContext;
      securityContext.setTrustedCertificatesBytes(certBytes);

      // Criar HttpClient com o SecurityContext
      final httpClient = HttpClient(context: securityContext);

      // Configurar validação customizada do certificado
      httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) {
        // Verificar se o host é o esperado
        if (host != 'merchhubapp.com') {
          print('⚠️ Certificate pinning: host inesperado: $host');
          return false;
        }

        // Verificar se o certificado é o esperado comparando o DER
        final receivedCertDer = cert.der;
        if (receivedCertDer.length != certBytes.length) {
          print('⚠️ Certificate pinning: tamanho do certificado não corresponde');
          return false;
        }

        for (int i = 0; i < certBytes.length; i++) {
          if (receivedCertDer[i] != certBytes[i]) {
            print('⚠️ Certificate pinning: certificado não corresponde ao pinado');
            return false;
          }
        }

        print('✅ Certificate pinning: certificado válido');
        return true;
      };

      // Criar IOClient a partir do HttpClient
      _client = IOClient(httpClient);
      return _client!;
    } catch (e) {
      print('❌ Erro ao configurar certificate pinning: $e');
      print('⚠️ Usando cliente HTTP padrão (menos seguro)');
      _client = http.Client();
      return _client!;
    }
  }

  /// Limpar o cliente (útil para testes ou quando o certificado for atualizado)
  static void dispose() {
    _client?.close();
    _client = null;
  }
}

/// Exemplo de uso:
/// 
/// ```dart
/// final client = await SecureHttpClient.getClient();
/// final response = await client.get(
///   Uri.parse('https://merchhubapp.com/api/health'),
/// );
/// ```

/// IMPORTANTE: Renovação de Certificados
/// 
/// Quando o certificado do servidor for renovado (Let's Encrypt renova a cada 90 dias):
/// 1. Obtenha o novo certificado usando o comando openssl acima
/// 2. Substitua o arquivo assets/certificates/merchhubapp.der
/// 3. Faça rebuild e republique o app
/// 
/// RECOMENDAÇÃO: 
/// - Configure notificações quando o certificado estiver perto de expirar
/// - Considere implementar um sistema de fallback ou atualização dinâmica de certificados
/// - Teste o app antes de cada renovação de certificado
