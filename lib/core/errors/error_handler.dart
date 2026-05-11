import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../errors/app_exception.dart';
import '../logging/app_logger_v2.dart';

/// Handler centralizado de erros com feedback visual
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  /// Processa exceção e retorna mensagem de erro apropriada
  String handleError(dynamic error, {StackTrace? stackTrace}) {
    if (error is AppException) {
      appLogger.error(
        error.message,
        error: error.originalError ?? error,
        stackTrace: stackTrace ?? error.stackTrace,
        context: error.context,
      );
      return error.userMessage;
    }

    // Erro desconhecido
    appLogger.error(
      'Erro não tratado',
      error: error,
      stackTrace: stackTrace,
    );
    return 'Erro inesperado. Por favor, tente novamente.';
  }

  /// Mostra snackbar de erro
  void showErrorSnackBar(
    BuildContext context,
    dynamic error, {
    StackTrace? stackTrace,
    Duration duration = const Duration(seconds: 4),
  }) {
    final message = handleError(error, stackTrace: stackTrace);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          duration: duration,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  /// Mostra snackbar de sucesso
  void showSuccessSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF22C55E),
          duration: duration,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  /// Mostra snackbar de aviso
  void showWarningSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_outlined, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFFF9800),
          duration: duration,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  /// Mostra dialog de erro
  Future<void> showErrorDialog(
    BuildContext context,
    dynamic error, {
    StackTrace? stackTrace,
    VoidCallback? onRetry,
  }) async {
    final message = handleError(error, stackTrace: stackTrace);

    if (context.mounted) {
      return showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF2d1b4e),
          title: Row(
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFEF4444)),
              const SizedBox(width: 12),
              Text(
                'Erro',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: GoogleFonts.poppins(color: Colors.white70),
          ),
          actions: [
            if (onRetry != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onRetry();
                },
                child: Text(
                  'Tentar Novamente',
                  style: GoogleFonts.poppins(color: const Color(0xFF9C3FE4)),
                ),
              ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C3FE4),
              ),
              child: Text(
                'OK',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }
  }
}

// Instância global
final errorHandler = ErrorHandler();
