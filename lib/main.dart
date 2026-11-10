import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart' as provider_pkg;
import 'page_one.dart';
import 'pages/role_home_page.dart';
import 'biometric_auth_page.dart';
import 'pages/barcode_scanner_page.dart';
import 'pages/settings_page.dart';
import 'pages/terms_acceptance_page.dart';
import 'services/notification_service.dart';
import 'services/push_service.dart';
import 'services/theme_service.dart';
import 'services/api_service.dart';
import 'services/location_service.dart';
import 'services/biometric_service.dart';
import 'core/logging/app_logger_v2.dart';
import 'widgets/app_update_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiService.onTrackingStop = LocationService().stopTracking;
  ApiService.onAuthReady = PushService.instance.synchronize;
  ApiService.onBeforeLogout = PushService.instance.unregister;
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

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
    NotificationService.onMessageTap = PushService.instance.openMessages;
    await notificationService.initialize();
    await PushService.instance.initialize();
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
  bool _isAppReady = false;
  bool? _termsAccepted;

  @override
  void initState() {
    super.initState();
    TermsAcceptance.isAccepted().then((ok) {
      if (mounted) setState(() => _termsAccepted = ok);
    });
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
    try {
      final isAuthenticated = ApiService.isAuthenticated();
      final isBiometricEnabled = isAuthenticated
          ? await _biometricService.isBiometricEnabled()
          : false;

      if (!mounted) return;

      setState(() {
        _isBiometricEnabled = isBiometricEnabled;
        _isAppReady = true;
      });
    } catch (error, stackTrace) {
      appLogger.error(
        'Erro ao carregar status da biometria',
        error: error,
        stackTrace: stackTrace,
      );

      if (!mounted) return;

      setState(() {
        _isBiometricEnabled = false;
        _isAppReady = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return provider_pkg.ChangeNotifierProvider(
      create: (_) => ThemeService()..loadTheme(),
      child: provider_pkg.Consumer<ThemeService>(
        builder: (context, themeService, _) {
          return MaterialApp(
            navigatorKey: _navigatorKey,
            debugShowCheckedModeBanner: false,
            title: 'Merch Hub',
            locale: const Locale('pt', 'BR'),
            supportedLocales: const [Locale('pt', 'BR')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: themeService.lightTheme,
            darkTheme: themeService.darkTheme,
            themeMode:
                themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            builder: (context, child) =>
                AppUpdateGate(child: child ?? const SizedBox.shrink()),
            home: !_isAppReady || _termsAccepted == null
                ? const _AppBootstrapPage()
                : !_termsAccepted!
                ? TermsAcceptancePage(
                    onAccepted: () => setState(() => _termsAccepted = true),
                  )
                : ApiService.isAuthenticated()
                    ? (_isBiometricEnabled
                        ? BiometricAuthPage(
                            nextPage: const RoleHomePage(),
                          )
                        : const RoleHomePage())
                    : UmWidget(),
            routes: {
              '/login': (context) => UmWidget(),
              '/menu': (context) => const RoleHomePage(),
              '/barcode': (context) => const BarcodeScannerPage(),
              '/settings': (context) => const SettingsPage(),
            },
          );
        },
      ),
    );
  }
}

class _AppBootstrapPage extends StatelessWidget {
  const _AppBootstrapPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
