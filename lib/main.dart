import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart' as provider_pkg;
import 'page_one.dart';
import 'menu_selection_page.dart';
import 'biometric_auth_page.dart';
import 'notes_page.dart';
import 'pages/barcode_scanner_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/settings_page.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';
import 'services/api_service.dart';
import 'services/biometric_service.dart';
import 'core/logging/app_logger_v2.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar sistema de logging
  appLogger.initialize();
  appLogger.info('🚀 Aplicativo iniciando...');
  
  // Inicializar API Service
  try {
    await ApiService.init();
    appLogger.info('✓ Serviço API inicializado');
  } catch (e) {
    appLogger.error('Erro ao inicializar API', error: e);
  }

  // Modo offline desativado para coletas
  
  await initializeDateFormatting('pt_BR', null);
  
  // Inicializar notificações
  try {
    final notificationService = NotificationService();
    await notificationService.initialize();
    appLogger.info('✓ Notificações inicializadas');
  } catch (e, stackTrace) {
    appLogger.error('Erro ao inicializar notificações', 
      error: e, stackTrace: stackTrace);
  }
  
  runApp(
    // Envolver com ProviderScope para usar Riverpod
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _biometricService = BiometricService();
  bool _isBiometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricStatus();
    
    // Configurar callback para logout automático quando token expirar
    ApiService.setOnTokenExpired(() {
      appLogger.warning('⚠️ Token expirado - fazendo logout automático');
      
      // Navegar para tela de login
      _navigatorKey.currentState?.pushNamedAndRemoveUntil(
        '/login',
        (route) => false,
      );
    });
  }

  Future<void> _checkBiometricStatus() async {
    final isBiometricEnabled = await _biometricService.isBiometricEnabled();
    setState(() {
      _isBiometricEnabled = isBiometricEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return provider_pkg.ChangeNotifierProvider(
      create: (_) => ThemeService()..loadTheme(),
      child: provider_pkg.Consumer<ThemeService>(
        builder: (context, themeService, _) {
          return MaterialApp(
            navigatorKey: _navigatorKey,
            title: 'AG Merchandising',
            theme: themeService.lightTheme,
            darkTheme: themeService.darkTheme,
            themeMode: themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: ApiService.isAuthenticated()
                ? (_isBiometricEnabled
                    ? BiometricAuthPage(
                        nextPage: const MenuSelectionPage(),
                      )
                    : const MenuSelectionPage())
                : UmWidget(),
            routes: {
              '/login': (context) => UmWidget(),
              '/menu': (context) => const MenuSelectionPage(),
              '/notes': (context) => const NotesPage(),
              '/barcode': (context) => const BarcodeScannerPage(),
              '/dashboard': (context) => DashboardPage(brandsData: {}),
              '/settings': (context) => const SettingsPage(),
            },
          );
        },
      ),
    );
  }
}
