/// Exceção base da aplicação
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? context;

  AppException({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
    this.context,
  });

  @override
  String toString() {
    return '$runtimeType: $message${code != null ? ' (code: $code)' : ''}';
  }

  /// Mensagem amigável para o usuário
  String get userMessage => message;
}

/// Exceções de armazenamento local
class StorageException extends AppException {
  StorageException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
    super.context,
  });

  @override
  String get userMessage => 'Erro ao salvar dados localmente. Tente novamente.';
}

/// Exceções de câmera
class CameraException extends AppException {
  CameraException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
    super.context,
  });

  @override
  String get userMessage => 'Erro ao acessar a câmera. Verifique as permissões.';
}

/// Exceções de localização/GPS
class LocationException extends AppException {
  LocationException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
    super.context,
  });

  @override
  String get userMessage =>
      'Erro ao obter localização. Verifique se o GPS está ativado.';
}

/// Exceções de permissão
class PermissionException extends AppException {
  final String permissionName;

  PermissionException({
    required super.message,
    required this.permissionName,
    super.code,
    super.originalError,
    super.stackTrace,
    super.context,
  });

  @override
  String get userMessage =>
      'Permissão de $permissionName necessária. Por favor, conceda nas configurações.';
}

/// Exceções de rede (quando servidor for implementado)
class NetworkException extends AppException {
  final int? statusCode;
  final String? endpoint;

  NetworkException({
    required super.message,
    this.statusCode,
    this.endpoint,
    super.code,
    super.originalError,
    super.stackTrace,
    super.context,
  });

  @override
  String get userMessage {
    if (statusCode == null) {
      return 'Erro de conexão. Verifique sua internet.';
    }
    
    return switch (statusCode!) {
      401 => 'Sessão expirada. Faça login novamente.',
      403 => 'Você não tem permissão para esta ação.',
      404 => 'Recurso não encontrado.',
      500 => 'Erro no servidor. Tente novamente mais tarde.',
      503 => 'Serviço temporariamente indisponível.',
      _ => 'Erro de conexão (código: $statusCode)',
    };
  }
}

/// Exceções de validação
class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  ValidationException({
    required super.message,
    this.fieldErrors,
    super.code,
    super.originalError,
    super.stackTrace,
    super.context,
  });

  @override
  String get userMessage => message;
}

/// Exceções de exportação (PDF, Excel)
class ExportException extends AppException {
  final String format;

  ExportException({
    required super.message,
    required this.format,
    super.code,
    super.originalError,
    super.stackTrace,
    super.context,
  });

  @override
  String get userMessage => 'Erro ao exportar arquivo $format. Tente novamente.';
}

/// Exceções não esperadas
class UnknownException extends AppException {
  UnknownException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
    super.context,
  });

  @override
  String get userMessage => 'Erro inesperado. Por favor, tente novamente.';
}
