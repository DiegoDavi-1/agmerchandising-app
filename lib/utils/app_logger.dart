import 'package:flutter/foundation.dart';

/// Logger utilitário que só imprime em modo debug
class AppLogger {
  static void log(String message) {
    if (kDebugMode) {
      debugPrint('[AG] $message');
    }
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[AG ERROR] $message');
      if (error != null) debugPrint('$error');
      if (stackTrace != null) debugPrint('$stackTrace');
    }
  }

  static void info(String message) {
    if (kDebugMode) {
      debugPrint('[AG INFO] $message');
    }
  }

  static void warning(String message) {
    if (kDebugMode) {
      debugPrint('[AG WARN] $message');
    }
  }
}
