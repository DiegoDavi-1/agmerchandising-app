import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class NoAnimationPageTransitionsBuilder extends PageTransitionsBuilder {
  const NoAnimationPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
    
    // Sincronizar com API
    try {
      final theme = _isDarkMode ? 'dark' : 'light';
      await ApiService.updateTheme(theme);
      print('✅ Tema sincronizado com API: $theme');
    } catch (e) {
      print('❌ Erro ao sincronizar tema com API: $e');
      // Não bloqueia a mudança de tema local
    }
    
    notifyListeners();
  }
  
  Future<void> setIsDarkMode(bool isDark) async {
    if (_isDarkMode == isDark) return;
    
    _isDarkMode = isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
    notifyListeners();
  }

  // Paleta oficial do Painel Admin (Merch Hub Design System)
  static const Color primaryBlue = Color(0xFF0F766E); // --primary (teal)
  static const Color primaryBlueDark = Color(0xFF115E59); // --primary-hover
  static const Color accentBlue = Color(0xFF2563EB); // --accent (azul)
  static const Color accentBlueHover = Color(0xFF1D4ED8); // --accent-hover
  static const Color dangerColor = Color(0xFFEF4444); // --danger
  static const Color warningColor = Color(0xFFF59E0B); // --warning
  static const Color successColor = Color(0xFF10B981); // --success
  static const Color infoColor = Color(0xFF0EA5E9); // --info
  static const Color sidebarDark = Color(0xFF0F172A); // --bg-sidebar
  static const Color pageBg = Color(0xFFF8FAFC); // --bg-page
  static const Color textMain = Color(0xFF0F172A); // --text-main
  static const Color textMuted = Color(0xFF64748B); // --text-muted

  ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.light,
      primary: primaryBlue,
      secondary: accentBlue,
      error: dangerColor,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: pageBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: sidebarDark,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryBlue, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    ),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: const NoAnimationPageTransitionsBuilder(),
        TargetPlatform.iOS: const NoAnimationPageTransitionsBuilder(),
        TargetPlatform.macOS: const NoAnimationPageTransitionsBuilder(),
        TargetPlatform.windows: const NoAnimationPageTransitionsBuilder(),
        TargetPlatform.linux: const NoAnimationPageTransitionsBuilder(),
        TargetPlatform.fuchsia: const NoAnimationPageTransitionsBuilder(),
      },
    ),
  );

  ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.dark,
      primary: accentBlue,
      secondary: primaryBlue,
      error: dangerColor,
    ),
    scaffoldBackgroundColor: sidebarDark,
    cardColor: const Color(0xFF1A2233),
    appBarTheme: const AppBarTheme(
      backgroundColor: sidebarDark,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1A2233),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[700]!, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[700]!, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: accentBlue, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    ),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: const NoAnimationPageTransitionsBuilder(),
        TargetPlatform.iOS: const NoAnimationPageTransitionsBuilder(),
        TargetPlatform.macOS: const NoAnimationPageTransitionsBuilder(),
        TargetPlatform.windows: const NoAnimationPageTransitionsBuilder(),
        TargetPlatform.linux: const NoAnimationPageTransitionsBuilder(),
        TargetPlatform.fuchsia: const NoAnimationPageTransitionsBuilder(),
      },
    ),
  );
}
