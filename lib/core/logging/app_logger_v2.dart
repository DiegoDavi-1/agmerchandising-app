import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

/// Sistema de logging estruturado e robusto
class AppLoggerV2 {
  static final AppLoggerV2 _instance = AppLoggerV2._internal();
  factory AppLoggerV2() => _instance;
  AppLoggerV2._internal();

  late final Logger _logger;

  void initialize() {
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        printTime: true,
      ),
      level: kDebugMode ? Level.debug : Level.info,
    );
  }

  /// Log de debug
  void debug(String message, {dynamic data, StackTrace? stackTrace}) {
    _logger.d(message, error: data, stackTrace: stackTrace);
  }

  /// Log de informação
  void info(String message, {dynamic data}) {
    _logger.i(message, error: data);
  }

  /// Log de warning
  void warning(String message, {dynamic data, StackTrace? stackTrace}) {
    _logger.w(message, error: data, stackTrace: stackTrace);
  }

  /// Log de erro
  void error(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    final errorDetails = {
      'message': message,
      'error': error?.toString(),
      'context': context,
    };
    _logger.e(errorDetails, error: error, stackTrace: stackTrace);
  }

  /// Log de erro fatal
  void fatal(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    final errorDetails = {
      'message': message,
      'error': error?.toString(),
      'context': context,
    };
    _logger.f(errorDetails, error: error, stackTrace: stackTrace);
  }

  /// Log de operação de banco de dados
  void database(String operation, {Map<String, dynamic>? params}) {
    debug('Database: $operation', data: params);
  }

  /// Log de navegação
  void navigation(String route, {Map<String, dynamic>? params}) {
    debug('Navigation: $route', data: params);
  }

  /// Log de API/Network
  void network(
    String endpoint, {
    String method = 'GET',
    int? statusCode,
    dynamic data,
  }) {
    info('Network [$method] $endpoint', data: {
      'statusCode': statusCode,
      'data': data,
    });
  }

  /// Log de performance
  void performance(String operation, Duration duration) {
    info('Performance: $operation completed in ${duration.inMilliseconds}ms');
  }
}

// Instância global
final appLogger = AppLoggerV2();
