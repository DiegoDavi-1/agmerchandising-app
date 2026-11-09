import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import 'route_change_request_page.dart';

const _teal = Color(0xFF0F766E);
const _appVersion = '1.0.11';

/// Central de suporte: cada assunto abre em sua própria tela.
class HelpCenterPage extends StatefulWidget {
  /// Quando nulo, a opção de alteração de atendimento aparece somente para
  /// quem não é supervisor (perfil promotor).
  final bool? showRouteChange;

  const HelpCenterPage({super.key, this.showRouteChange});

  @override
  State<HelpCenterPage> createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage> {
  late bool _showRouteChange = widget.showRouteChange ?? true;

  @override
  void initState() {
    super.initState();
    if (widget.showRouteChange == null) _resolveRole();
  }

  Future<void> _resolveRole() async {
    try {
      final supervisor = await ApiService.isSupervisor();
      if (mounted && supervisor) setState(() => _showRouteChange = false);
    } catch (_) {}
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar(context, 'Suporte'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _IntroCard(),
          const SizedBox(height: 16),
          if (_showRouteChange) ...[
            _sectionLabel('Minha rota'),
            _HubTile(
              icon: Icons.edit_calendar_outlined,
              title: 'Conferir meus atendimentos',
              subtitle:
                  'Veja lojas, marcas e dias. Solicite inclusão, alteração ou remoção.',
              onTap: () => _open(const RouteChangeRequestPage()),
            ),
            const SizedBox(height: 12),
          ],
          _sectionLabel('Fale com a equipe'),
          _HubTile(
            icon: Icons.chat_bubble_outline,
            title: 'Falar com o suporte',
            subtitle:
                'Tire dúvidas ou peça ajuda diretamente à equipe Merch Hub.',
            onTap: () => _open(const SupportMessagePage(category: 'support')),
          ),
          _HubTile(
            icon: Icons.forum_outlined,
            title: 'Minhas mensagens',
            subtitle: 'Acompanhe o que você enviou e as respostas da equipe.',
            onTap: () => _open(const MySupportMessagesPage()),
          ),
          _HubTile(
            icon: Icons.bug_report_outlined,
            title: 'Relatar bug',
            subtitle:
                'Avise sobre erros, travamentos ou algo que não funcionou.',
            onTap: () => _open(const SupportMessagePage(category: 'bug')),
          ),
          const SizedBox(height: 12),
          _sectionLabel('Aprenda a usar'),
          _HubTile(
            icon: Icons.menu_book_outlined,
            title: 'Manual de uso',
            subtitle: 'Passo a passo do dia de trabalho no aplicativo.',
            onTap: () => _open(const UserManualPage()),
          ),
          _HubTile(
            icon: Icons.play_circle_outline,
            title: 'Treinamentos',
            subtitle: 'Vídeos curtos explicando cada etapa.',
            onTap: () => _open(const TrainingsPage()),
          ),
        ],
      ),
    );
  }
}

class MySupportMessagesPage extends StatefulWidget {
  const MySupportMessagesPage({super.key});

  @override
  State<MySupportMessagesPage> createState() => _MySupportMessagesPageState();
}

class _MySupportMessagesPageState extends State<MySupportMessagesPage> {
  late Future<List<dynamic>> _future = _load();

  Future<List<dynamic>> _load() async {
    final result = await ApiService.fetchMySupportMessages();
    if (((result['unreadReplies'] as num?) ?? 0) > 0) {
      ApiService.markSupportRepliesSeen().catchError((_) => <String, dynamic>{});
    }
    return (result['data'] as List?) ?? [];
  }

  String _fmt(dynamic raw) {
    final dt = DateTime.tryParse('$raw')?.toLocal();
    if (dt == null) return '';
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(dt.day)}/${p(dt.month)} ${p(dt.hour)}:${p(dt.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar(context, 'Minhas mensagens'),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _future = _load());
          await _future;
        },
        child: FutureBuilder<List<dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Não foi possível carregar: ${snap.error}'),
                ),
              ]);
            }
            final items = snap.data ?? [];
            if (items.isEmpty) {
              return ListView(children: const [
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Você ainda não enviou mensagens ao suporte.'),
                ),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final m = items[i] as Map;
                final reply = m['admin_reply']?.toString();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${m['subject']}',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        Text(_fmt(m['created_at']),
                            style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 8),
                        Text('${m['message']}'),
                        const SizedBox(height: 10),
                        if (reply != null && reply.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _teal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Resposta da equipe · ${_fmt(m['replied_at'])}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _teal)),
                                const SizedBox(height: 4),
                                Text(reply),
                              ],
                            ),
                          )
                        else
                          const Text('Aguardando resposta…',
                              style: TextStyle(fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class UserManualPage extends StatelessWidget {
  const UserManualPage({super.key});

  static const _sections = [
    (
      '1. Entre e confira seu dia',
      'Acesse o aplicativo com seu usuário e senha. Em “Meu dia”, confira os atendimentos previstos, o que já foi concluído e o que ainda está pendente. Em “Atendimentos”, escolha a marca e a loja da rota.',
      Icons.today,
    ),
    (
      '2. Inicie a visita na loja',
      'Se a loja exigir registro de entrada e saída, o app solicitará a entrada antes de liberar as tarefas. Permita o acesso à localização e à câmera quando solicitado e faça o registro no local da visita. Se a loja não exigir esse controle, você seguirá diretamente para as tarefas.',
      Icons.login,
    ),
    (
      '3. Preencha as tarefas e auditorias',
      'Responda aos campos exibidos para aquela marca e loja. Alguns podem exigir texto, número, data ou foto. Confira as respostas antes de salvar e envie fotos nítidas que mostrem o produto, a gôndola ou a situação solicitada.',
      Icons.fact_check_outlined,
    ),
    (
      '4. Registre validades, quando necessário',
      'Dentro da visita, abra “Validades desta loja” para informar produtos vencidos ou próximos do vencimento. Preencha produto e data; quantidade e lote são opcionais. Esses registros ficam associados à loja e à marca atendidas.',
      Icons.event_busy,
    ),
    (
      '5. Finalize a visita',
      'Salve o atendimento. Se a loja exigir saída, registre-a para encerrar a visita. Se aparecer “Salvo offline”, o registro ficou no aparelho e será enviado quando a conexão voltar. Se não aparecer confirmação de salvamento, reconecte-se e confira “Meu dia” antes de tentar novamente; se continuar em dúvida, use o Suporte para evitar registros duplicados.',
      Icons.logout,
    ),
    (
      '6. Sua rota está diferente da realidade?',
      'Em Suporte › “Conferir meus atendimentos”, confira as lojas, marcas e dias. Use “Adicionar atendimento”, “Alterar dias” ou “Remover” para pedir uma correção. A rota só muda após aprovação da administração.',
      Icons.edit_calendar_outlined,
    ),
    (
      '7. Mensagens e configurações',
      'Consulte “Mensagens” para ler orientações ou responder às solicitações da equipe. Em “Configurações”, você pode ajustar o tema, a autenticação biométrica e as notificações disponíveis no aparelho.',
      Icons.mark_email_unread_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar(context, 'Manual de uso'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          for (final (title, body, icon) in _sections)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ExpansionTile(
                leading: Icon(icon, color: _teal),
                title: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(body)],
              ),
            ),
        ],
      ),
    );
  }
}

class TrainingsPage extends StatelessWidget {
  const TrainingsPage({super.key});

  static const _titles = [
    'Primeiros passos no aplicativo',
    'Como realizar um atendimento',
    'Como registrar entrada e saída',
    'Como enviar fotos e responder auditorias',
    'Como registrar validades',
    'Como solicitar alteração na rota',
  ];

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7);
    return Scaffold(
      appBar: _appBar(context, 'Treinamentos'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text('Os vídeos serão adicionados aqui assim que forem publicados.',
              style: TextStyle(color: muted)),
          const SizedBox(height: 8),
          for (final title in _titles)
            Card(
              child: ListTile(
                leading: const Icon(Icons.play_circle_outline, color: _teal),
                title: Text(title),
                subtitle: const Text('Vídeo em preparação'),
                trailing: const Icon(Icons.lock_outline, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}

class SupportMessagePage extends StatefulWidget {
  /// 'support' ou 'bug'.
  final String category;

  const SupportMessagePage({super.key, required this.category});

  @override
  State<SupportMessagePage> createState() => _SupportMessagePageState();
}

class _SupportMessagePageState extends State<SupportMessagePage> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _sending = false;

  bool get _isBug => widget.category == 'bug';

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  String get _platform {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      await ApiService.sendSupportMessage(
        category: widget.category,
        subject: _subjectController.text.trim(),
        message: _messageController.text.trim(),
        appVersion: _appVersion,
        platform: _platform,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isBug
              ? 'Obrigado! O relato foi enviado à equipe Merch Hub.'
              : 'Mensagem enviada diretamente para a equipe Merch Hub.'),
          backgroundColor: _teal,
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Não foi possível enviar. Confira sua conexão e tente novamente. $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7);
    return Scaffold(
      appBar: _appBar(context, _isBug ? 'Relatar bug' : 'Falar com o suporte'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              _isBug
                  ? 'Conte o que você estava fazendo, o que esperava que acontecesse e o que apareceu na tela.'
                  : 'Sua mensagem chega diretamente à equipe Merch Hub pelo painel administrativo.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _subjectController,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 160,
              decoration: const InputDecoration(
                labelText: 'Assunto',
                border: OutlineInputBorder(),
              ),
              validator: (value) => (value?.trim().length ?? 0) < 3
                  ? 'Informe um assunto com pelo menos 3 caracteres.'
                  : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _messageController,
              textCapitalization: TextCapitalization.sentences,
              minLines: 5,
              maxLines: 10,
              maxLength: 5000,
              decoration: InputDecoration(
                labelText: _isBug ? 'O que aconteceu?' : 'Como podemos ajudar?',
                hintText: _isBug
                    ? 'Descreva os passos, o resultado esperado e o que apareceu.'
                    : 'Escreva sua dúvida ou solicitação.',
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
              validator: (value) => (value?.trim().length ?? 0) < 10
                  ? 'Escreva pelo menos 10 caracteres.'
                  : null,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: Text(_sending
                  ? 'Enviando...'
                  : _isBug
                      ? 'Enviar relato'
                      : 'Enviar mensagem'),
              style: FilledButton.styleFrom(
                  backgroundColor: _teal,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

PreferredSizeWidget _appBar(BuildContext context, String title) => AppBar(
      title:
          Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1A1F2E) : _teal,
      foregroundColor: Colors.white,
    );

Widget _sectionLabel(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
      child: Text(text,
          style:
              GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700)),
    );

class _HubTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: _teal.withValues(alpha: 0.12),
          child: Icon(icon, color: _teal),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: _teal,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.support_agent, color: Colors.white, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Como podemos ajudar?',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text(
                    'Escolha abaixo o que você precisa. Cada opção abre em uma tela própria.',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
