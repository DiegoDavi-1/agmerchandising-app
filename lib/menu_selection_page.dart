import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'notes_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/settings_page.dart';
import 'pages/brands_server_page.dart';
import 'models/brand_data.dart';
import 'services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class MenuSelectionPage extends StatelessWidget {
  const MenuSelectionPage({super.key});

  static String routeName = 'MenuSelection';
  static String routePath = '/menu';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1419) : Colors.white,
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F1419) : Colors.white,
        ),
        child: Column(
          children: [
            // Header
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1F2E) : const Color(0xFF1E88E5),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? Colors.black : Colors.blue).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 20,
                left: 20,
                right: 20,
                bottom: 20,
              ),
              width: double.infinity,
              child: Text(
                'Selecione uma opção',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
              
              // Botões
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.1,
                    children: [
                      _buildMenuButton(
                        context,
                        'Marca',
                        Icons.cloud,
                        const Color(0xFF00BCD4),
                        () => _navigateToBrandsServer(context),
                      ),
                      _buildMenuButton(
                        context,
                        'Validades',
                        Icons.calendar_today,
                        const Color(0xFF1E88E5),
                        () => _navigateToNotes(context),
                      ),
                      _buildMenuButton(
                        context,
                        'Dashboard',
                        Icons.analytics,
                        const Color(0xFF4CAF50),
                        () => _navigateToDashboard(context),
                      ),
                      _buildMenuButton(
                        context,
                        'Configurações',
                        Icons.settings,
                        const Color(0xFF2196F3),
                        () => _navigateToSettings(context),
                      ),
                      _buildMenuButton(
                        context,
                        'Sair',
                        Icons.logout,
                        const Color(0xFFE91E63),
                        () => _logout(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback? onTap,
  ) {
    final isDisabled = onTap == null;
    
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color,
                color.withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: isDisabled ? [] : [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 60,
                color: Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToBrandsServer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BrandsServerPage(),
      ),
    );
  }

  void _navigateToNotes(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotesPage(),
      ),
    );
  }

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Tem certeza que deseja sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await ApiService.logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            child: const Text('Sair', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  Future<Map<String, BrandData>> _loadBrandsData() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, BrandData> brandsData = {};
    
    const brands = [
      'PepsiCo',
      'BRF',
      'Banana Brasil',
      'Coqueiros',
      'SC Johnson',
      'Lunã',
    ];
    
    for (var brand in brands) {
      final data = prefs.getString('brand_$brand');
      if (data != null) {
        brandsData[brand] = BrandData.fromJson(jsonDecode(data));
      }
    }
    
    return brandsData;
  }
  
  void _navigateToDashboard(BuildContext context) async {
    final brandsData = await _loadBrandsData();
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardPage(brandsData: brandsData),
        ),
      );
    }
  }
  
  void _navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsPage(),
      ),
    );
  }
}

