import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/theme_service.dart';
import '../services/biometric_service.dart';
import '../services/export_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'help_center_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _themeService = ThemeService();
  final _biometricService = BiometricService();
  final _exportService = ExportService();

  bool _isDarkMode = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  bool _notificationsEnabled = true;
  late bool isDark;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    // Escutar mudanças de tema
    _themeService.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {
        _isDarkMode = _themeService.isDarkMode;
      });
    }
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  Future<void> _loadSettings() async {
    _isDarkMode = _themeService.isDarkMode;
    _biometricEnabled = await _biometricService.isBiometricEnabled();
    _biometricAvailable = await _biometricService.canCheckBiometrics();

    final prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1419) : Colors.white,
      appBar: AppBar(
        backgroundColor:
            isDark ? const Color(0xFF1A1F2E) : const Color(0xFF0F766E),
        elevation: 8,
        shadowColor: isDark
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.blue.withValues(alpha: 0.4),
        title: Text(
          'Configurações',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Aparência
          _buildSectionTitle('Aparência'),
          _buildSettingTile(
            icon: Icons.dark_mode,
            title: 'Modo Escuro',
            subtitle: _isDarkMode ? 'Ativado' : 'Desativado',
            trailing: Switch(
              value: _isDarkMode,
              onChanged: (value) async {
                await _themeService.toggleTheme();
              },
              activeColor: const Color(0xFF0F766E),
            ),
          ),

          const SizedBox(height: 24),

          // Segurança
          _buildSectionTitle('Segurança'),
          _buildSettingTile(
            icon: Icons.fingerprint,
            title: 'Autenticação Biométrica',
            subtitle:
                _biometricAvailable ? null : 'Não disponível neste dispositivo',
            trailing: _biometricAvailable
                ? Switch(
                    value: _biometricEnabled,
                    onChanged: (value) async {
                      if (value) {
                        final auth = await _biometricService.authenticate(
                          reason: 'Confirme para habilitar biometria',
                        );
                        if (auth) {
                          await _biometricService.setBiometricEnabled(true);
                          setState(() => _biometricEnabled = true);
                        }
                      } else {
                        await _biometricService.setBiometricEnabled(false);
                        setState(() => _biometricEnabled = false);
                      }
                    },
                    activeColor: const Color(0xFF0F766E),
                  )
                : null,
          ),

          const SizedBox(height: 24),

          // Notificações
          _buildSectionTitle('Notificações'),
          _buildSettingTile(
            icon: Icons.notifications,
            title: 'Notificações de Validade',
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (value) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('notifications_enabled', value);
                setState(() => _notificationsEnabled = value);
              },
              activeColor: const Color(0xFF0F766E),
            ),
          ),

          const SizedBox(height: 24),

          // Dados
          _buildSectionTitle('Dados'),
          _buildSettingTile(
            icon: Icons.file_download,
            title: 'Exportar Validades (CSV)',
            onTap: () => _exportValidadesCSV(),
          ),
          _buildSettingTile(
            icon: Icons.delete_sweep,
            title: 'Limpar Cache',
            subtitle: 'Liberar espaço em disco',
            onTap: () => _clearCache(),
          ),

          const SizedBox(height: 24),

          _buildSectionTitle('Ajuda'),
          _buildSettingTile(
            icon: Icons.support_agent,
            title: 'Suporte',
            subtitle: 'Manual de uso, treinamentos e relato de bugs',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HelpCenterPage()),
            ),
          ),

          const SizedBox(height: 24),

          // Informações
          _buildSectionTitle('Informações'),
          _buildSettingTile(
            icon: Icons.info,
            title: 'Versão',
            trailing: Text(
              '1.0.11',
              style: GoogleFonts.poppins(
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
                fontSize: 14,
              ),
            ),
          ),
          _buildSettingTile(
            icon: Icons.code,
            title: 'Sobre',
            subtitle: 'Merch Hub App',
          ),
          _buildSettingTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Política de Privacidade',
            subtitle: 'Conheça como seus dados são tratados',
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: _openPrivacyPolicy,
          ),
          _buildSettingTile(
            icon: Icons.description_outlined,
            title: 'Termos de Uso',
            subtitle: 'Regras para usar a plataforma',
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: _openTerms,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          color: const Color(0xFF0F766E),
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F2E) : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF0F766E)),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : Colors.grey[800],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: GoogleFonts.poppins(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 12,
                ),
              )
            : null,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  Future<void> _exportValidadesCSV() async {
    try {
      _showLoading('Exportando...');

      final prefs = await SharedPreferences.getInstance();
      final validadesJson = prefs.getStringList('validades') ?? [];
      final validades = validadesJson.map((e) => jsonDecode(e)).toList();

      if (validades.isEmpty) {
        Navigator.pop(context);
        _showMessage('Nenhuma validade para exportar');
        return;
      }

      final file = await _exportService.exportValidadesToCSV(validades);
      Navigator.pop(context);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Relatório de Validades (CSV)',
      );
    } catch (e) {
      Navigator.pop(context);
      _showMessage('Erro ao exportar: $e');
    }
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Limpar Cache?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Esta ação irá limpar dados temporários mas manterá seus registros',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
            ),
            child: Text(
              'Limpar',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _showMessage('Cache limpo com sucesso!');
    }
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(
      'https://merchhubapp.com/app/politica-de-privacidade',
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showMessage('Não foi possível abrir a Política de Privacidade');
    }
  }

  Future<void> _openTerms() async {
    final uri = Uri.parse('https://merchhubapp.com/app/termos-de-uso');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showMessage('Não foi possível abrir os Termos de Uso');
    }
  }

  void _showLoading(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1F2E) : Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF0F766E),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.poppins(
                  color: isDark ? Colors.white : Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
