import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/notification_service.dart';
import 'services/push_service.dart';
import 'pages/my_day_page.dart';
import 'pages/settings_page.dart';
import 'pages/brands_server_page.dart';
import 'pages/portal_messages.dart';
import 'pages/help_center_page.dart';
import 'pages/notes_page.dart';
import 'pages/photo_audits_page.dart';
import 'services/api_service.dart';
import 'services/location_service.dart';

class MenuSelectionPage extends StatefulWidget {
  const MenuSelectionPage({super.key});

  static String routeName = 'MenuSelection';
  static String routePath = '/menu';

  @override
  State<MenuSelectionPage> createState() => _MenuSelectionPageState();
}

class _MenuSelectionPageState extends State<MenuSelectionPage>
    with WidgetsBindingObserver {
  int? _messageCount;
  int _supportReplies = 0;
  int _lastNotified = 0;
  Timer? _poll;
  String? _messageError;
  int _messageLoadVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PushService.instance.onMessageTap = _openMessages;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) PushService.instance.consumeMessageTap();
    });
    _loadMessages();
    LocationService().synchronize();
    _poll = Timer.periodic(const Duration(seconds: 60), (_) => _loadMessages());
  }

  @override
  void dispose() {
    _poll?.cancel();
    PushService.instance.onMessageTap = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      PushService.instance.synchronize();
      PushService.instance.consumeMessageTap();
      _loadMessages();
      LocationService().synchronize();
    }
  }

  Future<void> _loadMessages({bool quietRetry = true}) async {
    final version = ++_messageLoadVersion;
    try {
      final response = await ApiService.fetchPromoterMessages();
      final unreadCount = response['unreadCount'] as int;
      var replies = 0;
      try {
        final mine = await ApiService.fetchMySupportMessages();
        replies = (mine['unreadReplies'] as num?)?.toInt() ?? 0;
      } catch (_) {}
      if (!mounted || version != _messageLoadVersion) return;
      final total = unreadCount + replies;
      if (total > _lastNotified) {
        NotificationService().showMessageNotification(
          id: 7001,
          title: 'Merch Hub',
          body: replies > 0 && unreadCount == 0
              ? 'O suporte respondeu sua mensagem.'
              : 'Você tem novas mensagens da gestão.',
        );
      }
      _lastNotified = total;
      setState(() {
        _messageCount = unreadCount;
        _supportReplies = replies;
        _messageError = null;
      });
    } catch (error) {
      if (!mounted || version != _messageLoadVersion) return;
      if (quietRetry) {
        // Ao abrir/voltar ao app a rede pode ainda não estar pronta.
        await Future.delayed(const Duration(seconds: 3));
        if (!mounted || version != _messageLoadVersion) return;
        return _loadMessages(quietRetry: false);
      }
      setState(() {
        _messageCount = null;
        _messageError = error.toString();
      });
    }
  }

  Future<void> _openMessages() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PromoterMessagesPage()),
    );
    if (mounted) _loadMessages();
  }

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
                  color: isDark
                      ? const Color(0xFF1A1F2E)
                      : const Color(0xFF0F766E),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? Colors.black : Colors.blue)
                          .withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]),
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

            if (_messageCount != null && _messageCount! > 0)
              PromoterMessageNotice(
                count: _messageCount!,
                onOpen: _openMessages,
              ),
            if (_supportReplies > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.support_agent,
                        color: Color(0xFF0F766E)),
                    title: Text(_supportReplies == 1
                        ? 'O suporte respondeu sua mensagem'
                        : 'O suporte enviou $_supportReplies respostas'),
                    subtitle: const Text('Toque para ver'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const MySupportMessagesPage()),
                      );
                      if (mounted) _loadMessages();
                    },
                  ),
                ),
              ),
            if (_messageError != null)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title:
                        const Text('Não foi possível verificar as mensagens.'),
                    trailing: TextButton(
                      onPressed: _loadMessages,
                      child: const Text('Tentar novamente'),
                    ),
                  ),
                ),
              ),

            ValueListenableBuilder<String>(
              valueListenable: LocationService().status,
              builder: (context, status, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(status,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center),
              ),
            ),
            // Botões do Menu
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  children: [
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: 1.18,
                        children: [
                          _buildMenuButton(
                            context,
                            'Atendimentos',
                            Icons.assignment_turned_in_outlined,
                            const Color(0xFF0F766E),
                            () => _navigateToMyDay(context),
                          ),
                          _buildMenuButton(
                            context,
                            'Notas',
                            Icons.edit_note,
                            const Color(0xFF0284C7),
                            () => _navigateToNotes(context),
                          ),
                          _buildMenuButton(
                            context,
                            'Revisão de Fotos',
                            Icons.photo_library_outlined,
                            const Color(0xFFD97706),
                            () => _navigateToAudits(context),
                          ),
                          _buildMenuButton(
                            context,
                            'Mensagens',
                            Icons.chat_bubble_outline,
                            const Color(0xFF0D9488),
                            _openMessages,
                          ),
                          _buildMenuButton(
                            context,
                            'Suporte',
                            Icons.support_agent,
                            const Color(0xFF7C3AED),
                            () => _navigateToSupport(context),
                          ),
                          _buildMenuButton(
                            context,
                            'Configurações',
                            Icons.settings_outlined,
                            const Color(0xFF475569),
                            () => _navigateToSettings(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE11D48),
                          side: const BorderSide(color: Color(0xFFFDA4AF)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => _logout(context),
                        icon: const Icon(Icons.logout, size: 18),
                        label: Text(
                          'Sair da Conta',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 6),
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
            boxShadow: isDisabled
                ? []
                : [
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
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (route) => false);
              }
            },
            child: const Text('Sair', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _navigateToMyDay(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MyDayPage()),
    );
  }

  void _navigateToNotes(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotesPage()),
    );
  }

  void _navigateToAudits(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PhotoAuditsPage()),
    );
  }

  void _navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsPage(),
      ),
    );
  }

  void _navigateToSupport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HelpCenterPage()),
    );
  }
}
