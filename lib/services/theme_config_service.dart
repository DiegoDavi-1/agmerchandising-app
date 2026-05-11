import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Serviço para gerenciar configurações de tema sincronizando com API
class ThemeConfigService {
  static final ThemeConfigService _instance = ThemeConfigService._internal();

  factory ThemeConfigService() {
    return _instance;
  }

  ThemeConfigService._internal();

  // Preferências de cache local
  late SharedPreferences _prefs;
  
  // Callbacks para notificar mudanças
  final List<VoidCallback> _themeChangeListeners = [];

  /// Inicializar o serviço
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Registrar listener para mudanças de tema
  void addThemeChangeListener(VoidCallback callback) {
    _themeChangeListeners.add(callback);
  }

  /// Remover listener
  void removeThemeChangeListener(VoidCallback callback) {
    _themeChangeListeners.remove(callback);
  }

  /// Notificar todos os listeners sobre mudança
  void _notifyThemeChange() {
    for (final listener in _themeChangeListeners) {
      listener();
    }
  }

  /// Obter preferências da API e sincronizar localmente
  Future<Map<String, dynamic>> syncPreferences() async {
    try {
      final prefs = await ApiService.getPreferences();
      
      // Salvar theme localmente
      final theme = prefs['theme'] ?? 'light';
      await _prefs.setString('user_theme', theme);
      
      // Salvar cores localmente
      final colors = prefs['colors'] ?? {};
      await _prefs.setString('theme_colors', colors.toString());
      
      return prefs;
    } catch (e) {
      print('❌ Erro ao sincronizar preferências: $e');
      rethrow;
    }
  }

  /// Obter tema atual do cache local
  String getLocalTheme() {
    return _prefs.getString('user_theme') ?? 'light';
  }

  /// Atualizar tema e sincronizar com API
  Future<void> setTheme(String theme) async {
    try {
      // Validar tema
      if (!['light', 'dark'].contains(theme)) {
        throw Exception('Tema inválido: $theme');
      }

      // Atualizar na API
      await ApiService.updateTheme(theme);
      
      // Atualizar cache local
      await _prefs.setString('user_theme', theme);
      
      // Notificar listeners
      _notifyThemeChange();
      
      print('✅ Tema atualizado para: $theme');
    } catch (e) {
      print('❌ Erro ao atualizar tema: $e');
      rethrow;
    }
  }

  /// Atualizar cores personalizadas
  Future<void> updateColors({
    String? primaryColor,
    String? accentColor,
  }) async {
    try {
      await ApiService.updateColors(
        primaryColor: primaryColor,
        accentColor: accentColor,
      );

      // Salvar localmente
      if (primaryColor != null) {
        await _prefs.setString('primary_color', primaryColor);
      }
      if (accentColor != null) {
        await _prefs.setString('accent_color', accentColor);
      }

      _notifyThemeChange();
      print('✅ Cores atualizadas');
    } catch (e) {
      print('❌ Erro ao atualizar cores: $e');
      rethrow;
    }
  }

  /// Obter cor primária
  String getPrimaryColor() {
    return _prefs.getString('primary_color') ?? '#1E88E5';
  }

  /// Obter cor de accent
  String getAccentColor() {
    return _prefs.getString('accent_color') ?? '#FF6B35';
  }

  /// Converter string hex para Color
  static Color hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) {
      buffer.write('ff');
    }
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  /// Obter cores baseado no tema
  Map<String, Color> getThemeColors(String theme) {
    if (theme == 'dark') {
      return {
        'primary': hexToColor('#1E88E5'),
        'appBarBackground': hexToColor('#1A1F2E'),
        'scaffoldBackground': hexToColor('#0F1419'),
        'cardBackground': hexToColor('#1A1F2E'),
        'textPrimary': const Color(0xFFFFFFFF),
        'textSecondary': const Color(0xFFCCCCCC),
        'accent': hexToColor('#FF6B35'),
      };
    } else {
      return {
        'primary': hexToColor('#1E88E5'),
        'appBarBackground': hexToColor('#1E88E5'),
        'scaffoldBackground': const Color(0xFFFFFFFF),
        'cardBackground': const Color(0xFFFFFFFF),
        'textPrimary': const Color(0xFF000000),
        'textSecondary': const Color(0xFF666666),
        'accent': hexToColor('#FF6B35'),
      };
    }
  }

  /// Limpar cache local
  Future<void> clear() async {
    await _prefs.remove('user_theme');
    await _prefs.remove('theme_colors');
    await _prefs.remove('primary_color');
    await _prefs.remove('accent_color');
  }
}
