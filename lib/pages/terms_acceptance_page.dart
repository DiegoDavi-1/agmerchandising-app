import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class TermsAcceptance {
  static const version = '2026-10-05';
  static const _key = 'terms_accepted_version';

  static Future<bool> isAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) == version;
  }

  static Future<void> accept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, version);
  }
}

class TermsAcceptancePage extends StatefulWidget {
  const TermsAcceptancePage({super.key, required this.onAccepted});

  final VoidCallback onAccepted;

  @override
  State<TermsAcceptancePage> createState() => _TermsAcceptancePageState();
}

class _TermsAcceptancePageState extends State<TermsAcceptancePage> {
  bool _checked = false;
  bool _saving = false;

  Future<void> _open(String url) async {
    final ok =
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o documento.')),
      );
    }
  }

  Future<void> _accept() async {
    setState(() => _saving = true);
    await TermsAcceptance.accept();
    if (mounted) widget.onAccepted();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: constraints.maxHeight - 48),
              child: SizedBox(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_user_outlined,
                        size: 56, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text('Bem-vindo ao Merch Hub',
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    const Text(
                      'Leia e aceite os Termos de Uso e a Política de Privacidade. Durante um atendimento, do check-in ao check-out, sua localização é compartilhada com o administrador a cada minuto, inclusive em segundo plano no Android com uma notificação persistente. Fora do atendimento, o rastreamento fica desligado. O mapa guarda somente o último ponto por até 24 horas, sem histórico de trajeto.',
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.description_outlined),
                      title: const Text('Termos de Uso'),
                      trailing: const Icon(Icons.open_in_new, size: 18),
                      onTap: () =>
                          _open('https://merchhubapp.com/app/termos-de-uso'),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: const Text('Política de Privacidade'),
                      trailing: const Icon(Icons.open_in_new, size: 18),
                      onTap: () => _open(
                          'https://merchhubapp.com/app/politica-de-privacidade'),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _checked,
                      onChanged: (v) => setState(() => _checked = v ?? false),
                      title: const Text(
                          'Li e aceito os Termos de Uso e a Política de Privacidade.'),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _checked && !_saving ? _accept : null,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text('Continuar'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
