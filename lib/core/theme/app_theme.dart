import 'package:flutter/material.dart';

/// Cores do Design System (paleta oficial do Painel Admin - Merch Hub)
class AppColors {
  AppColors._();

  // Cores principais
  static const primary = Color(0xFF0F766E); // --primary (teal)
  static const primaryDark = Color(0xFF115E59); // --primary-hover
  static const primaryLight = Color(0xFFCCFBF1); // --primary-light
  static const accent = Color(0xFF2563EB); // --accent (azul)
  static const accentDark = Color(0xFF1D4ED8); // --accent-hover

  // Cores de fundo
  static const backgroundDark = Color(0xFF0F172A); // --bg-sidebar
  static const backgroundLight = Color(0xFFF8FAFC); // --bg-page
  static const cardDark = Color(0xFF1A2233);
  static const cardLight = Color(0xFFFFFFFF);

  // Cores de status
  static const success = Color(0xFF10B981); // --success
  static const error = Color(0xFFEF4444); // --danger
  static const warning = Color(0xFFF59E0B); // --warning
  static const info = Color(0xFF0EA5E9); // --info

  // Cores de texto
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF94A3B8); // --text-light
  static const textTertiary = Color(0xFF64748B); // --text-muted
  static const textLight = Color(0xFF0F172A); // --text-main

  // Cores de categoria (para brand_page)
  static const categoryAbastecimento = Color(0xFF10B981);
  static const categoryPrecificacao = Color(0xFF2563EB);
  static const categoryRelatorio = Color(0xFFF59E0B);
  static const categoryPendencias = Color(0xFFEF4444);

  // Gradientes
  static const gradientPrimary = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientBackground = LinearGradient(
    colors: [backgroundDark, Color(0xFF060B16)],
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
