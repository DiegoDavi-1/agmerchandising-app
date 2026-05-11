import 'package:flutter/material.dart';

/// Cores do Design System
class AppColors {
  AppColors._();

  // Cores principais
  static const primary = Color(0xFF9C3FE4);
  static const primaryDark = Color(0xFF7B32B3);
  static const primaryLight = Color(0xFFB666F0);

  // Cores de fundo
  static const backgroundDark = Color(0xFF2d1b4e);
  static const backgroundLight = Color(0xFFF5F5F5);
  static const cardDark = Color(0xFF3d2b5e);
  static const cardLight = Color(0xFFFFFFFF);

  // Cores de status
  static const success = Color(0xFF22C55E);
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFFF9800);
  static const info = Color(0xFF3B82F6);

  // Cores de texto
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFFB0B0B0);
  static const textTertiary = Color(0xFF808080);
  static const textLight = Color(0xFF1F2937);

  // Cores de categoria (para brand_page)
  static const categoryAbastecimento = Color(0xFF4CAF50);
  static const categoryPrecificacao = Color(0xFF2196F3);
  static const categoryRelatorio = Color(0xFFFF9800);
  static const categoryPendencias = Color(0xFFF44336);

  // Gradientes
  static const gradientPrimary = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientBackground = LinearGradient(
    colors: [backgroundDark, Color(0xFF1a0f2e)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

/// Espaçamentos padronizados
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

/// Border radius padronizados
class AppBorderRadius {
  AppBorderRadius._();

  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double round = 999.0;
}

/// Tamanhos de ícones
class AppIconSize {
  AppIconSize._();

  static const double xs = 16.0;
  static const double sm = 20.0;
  static const double md = 24.0;
  static const double lg = 32.0;
  static const double xl = 48.0;
}

/// Elevações/Sombras
class AppElevation {
  AppElevation._();

  static const double none = 0.0;
  static const double sm = 2.0;
  static const double md = 4.0;
  static const double lg = 8.0;
  static const double xl = 16.0;
}

/// Durações de animação
class AppDuration {
  AppDuration._();

  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 500);
}

/// Breakpoints responsivos
class AppBreakpoints {
  AppBreakpoints._();

  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}
