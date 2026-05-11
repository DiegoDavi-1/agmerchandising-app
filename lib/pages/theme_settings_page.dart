import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/theme_config_service.dart';
import '../../services/api_service.dart';

class ThemeSettingsPage extends StatefulWidget {
  const ThemeSettingsPage({super.key});

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  late String _currentTheme;
  bool _isLoading = false;
  bool _isLoadingThemes = false;
  Map<String, dynamic> _availableThemes = {};

  @override
  void initState() {
    super.initState();
    _currentTheme = ThemeConfigService().getLocalTheme();
    _loadAvailableThemes();
  }

  Future<void> _loadAvailableThemes() async {
    setState(() => _isLoadingThemes = true);
    try {
      final themes = await ApiService.getAvailableThemes();
      setState(() {
        _availableThemes = themes;
      });
    } catch (e) {
      print('❌ Erro ao carregar temas: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar temas: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingThemes = false);
    }
  }

  void _changeTheme(String theme) async {
    if (theme == _currentTheme) return;

    setState(() => _isLoading = true);

    try {
      await ThemeConfigService().setTheme(theme);
      setState(() {
        _currentTheme = theme;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              theme == 'dark'
                  ? '🌙 Tema escuro ativado'
                  : '☀️ Tema claro ativado',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _currentTheme = ThemeConfigService().getLocalTheme();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao alterar tema: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Configurações de Tema',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        backgroundColor: isDark ? const Color(0xFF1A1F2E) : const Color(0xFF1E88E5),
        elevation: 0,
      ),
      backgroundColor: isDark ? const Color(0xFF0F1419) : Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Seção: Seleção de Tema
            Text(
              'Modo de Exibição',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            
            if (_isLoading)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Column(
                children: [
                  _ThemeOptionCard(
                    title: 'Tema Claro',
                    description: 'Cores vibrantes e claras',
                    icon: Icons.light_mode,
                    isSelected: _currentTheme == 'light',
                    isDark: isDark,
                    onTap: () => _changeTheme('light'),
                  ),
                  const SizedBox(height: 12),
                  _ThemeOptionCard(
                    title: 'Tema Escuro',
                    description: 'Cores escuras para melhor conforto',
                    icon: Icons.dark_mode,
                    isSelected: _currentTheme == 'dark',
                    isDark: isDark,
                    onTap: () => _changeTheme('dark'),
                  ),
                ],
              ),

            const SizedBox(height: 32),

            // Seção: Visualização de Cores
            Text(
              'Paleta de Cores do Tema Atual',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 12),

            if (_isLoadingThemes)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              _buildColorPalette(isDark),

            const SizedBox(height: 32),

            // Seção: Informações
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1F2E) : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ℹ️ Informações',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sua preferência de tema é sincronizada com a nuvem. Ao fazer login em outro dispositivo, o tema será restaurado automaticamente.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPalette(bool isDark) {
    if (_availableThemes.isEmpty) {
      return const SizedBox.shrink();
    }

    final themeName = _currentTheme == 'dark' ? 'dark' : 'light';
    final themeData = _availableThemes['current']?[themeName];

    if (themeData == null) {
      return const SizedBox.shrink();
    }

    final colors = (themeData['colors'] as Map<String, dynamic>?) ?? {};

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: colors.entries.map((entry) {
        try {
          final color = ThemeConfigService.hexToColor(entry.value as String);
          return Tooltip(
            message: entry.key,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.white24 : Colors.black12,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  entry.key.substring(0, 1).toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _getContrastColor(color),
                  ),
                ),
              ),
            ),
          );
        } catch (e) {
          return const SizedBox.shrink();
        }
      }).toList(),
    );
  }

  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}

class _ThemeOptionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _ThemeOptionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? const Color(0xFF1E88E5).withOpacity(0.2)
                    : const Color(0xFF1E88E5).withOpacity(0.1))
                : (isDark ? const Color(0xFF1A1F2E) : Colors.grey[100]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF1E88E5)
                  : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E88E5).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF1E88E5),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E88E5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
