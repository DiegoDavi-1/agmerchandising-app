import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';
import '../services/api_service.dart';
import '../core/theme/ui_palette.dart';

class PortalPhoto extends StatelessWidget {
  const PortalPhoto({super.key, required this.url, required this.height});

  final String? url;
  final double height;

  @override
  Widget build(BuildContext context) {
    final resolved = ApiService.resolvePhotoUrl(url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: height,
        child: resolved == null
            ? const Center(child: Text('Foto indisponível'))
            : Image.network(
                resolved,
                fit: BoxFit.contain,
                errorBuilder: (_, error, stack) =>
                    const Center(child: Text('Foto indisponível')),
              ),
      ),
    );
  }
}

class PromoterMessageNotice extends StatelessWidget {
  const PromoterMessageNotice({
    super.key,
    required this.count,
    required this.onOpen,
  });

  final int count;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF86EFAC)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F766E).withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onOpen,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F766E),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mark_email_unread_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            count == 1
                                ? '1 nova mensagem da gestão'
                                : '$count novas mensagens da gestão',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: const Color(0xFF065F46),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Toque para responder perguntas ou ver avisos',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Color(0xFF0F766E),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

Future<bool> showSupervisorCompose(
  BuildContext context, {
  Object? promoterId,
  String? promoterName,
  Object? collectionId,
  String? photoUrl,
  List<dynamic> promoters = const [],
}) async {
  final controller = TextEditingController();
  String type = 'notice';
  Object? selected = promoterId;
  bool sending = false;
  String? error;
  try {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
              builder: (context, update) => AlertDialog(
                    title: const Text('Enviar mensagem'),
                    content: SingleChildScrollView(
                        child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (promoterId != null)
                          Text('Para: ${promoterName ?? 'Promotor'}')
                        else
                          DropdownButtonFormField<Object>(
                            value: selected,
                            decoration:
                                const InputDecoration(labelText: 'Promotor'),
                            items: promoters.map((item) {
                              final promoter = item as Map<String, dynamic>;
                              return DropdownMenuItem<Object>(
                                value: promoter['id'] as Object,
                                child: Text(
                                    promoter['name']?.toString() ?? 'Promotor'),
                              );
                            }).toList(),
                            onChanged: (value) =>
                                update(() => selected = value),
                          ),
                        DropdownButtonFormField<String>(
                          value: type,
                          decoration: const InputDecoration(labelText: 'Tipo'),
                          items: const [
                            DropdownMenuItem(
                                value: 'notice', child: Text('Aviso')),
                            DropdownMenuItem(
                                value: 'request', child: Text('Solicitação')),
                          ],
                          onChanged: (value) =>
                              update(() => type = value ?? type),
                        ),
                        if (photoUrl != null) ...[
                          const SizedBox(height: 8),
                          const Text('Foto vinculada à mensagem'),
                          PortalPhoto(url: photoUrl, height: 100),
                        ],
                        TextField(
                          controller: controller,
                          maxLines: 3,
                          decoration:
                              const InputDecoration(labelText: 'Mensagem'),
                        ),
                        if (error != null)
                          Text(error!,
                              style: const TextStyle(color: AppColors.error)),
                      ],
                    )),
                    actions: [
                      TextButton(
                          onPressed: sending
                              ? null
                              : () => Navigator.pop(context, false),
                          child: const Text('Cancelar')),
                      FilledButton(
                        onPressed: sending
                            ? null
                            : () async {
                                if (selected == null ||
                                    controller.text.trim().isEmpty) {
                                  update(() => error =
                                      'Selecione um promotor e escreva a mensagem.');
                                  return;
                                }
                                update(() {
                                  sending = true;
                                  error = null;
                                });
                                try {
                                  await ApiService.sendSupervisorMessage(
                                    promoterId: selected!,
                                    type: type,
                                    message: controller.text.trim(),
                                    collectionId: collectionId,
                                    photoUrl: photoUrl,
                                  );
                                  if (context.mounted) {
                                    Navigator.pop(context, true);
                                  }
                                } catch (e) {
                                  update(() {
                                    sending = false;
                                    error = e.toString();
                                  });
                                }
                              },
                        child: const Text('Enviar'),
                      ),
                    ],
                  )),
        ) ??
        false;
  } finally {
    controller.dispose();
  }
}

class PortalMessages extends StatefulWidget {
  const PortalMessages({
    super.key,
    required this.supervisor,
    this.promoters = const [],
    this.fetchPromoterMessages,
    this.markPromoterMessageRead,
  });
  final bool supervisor;
  final List<dynamic> promoters;
  final Future<Map<String, dynamic>> Function()? fetchPromoterMessages;
  final Future<Map<String, dynamic>> Function(Object id)?
      markPromoterMessageRead;

  @override
  State<PortalMessages> createState() => _PortalMessagesState();
}

class _PortalMessagesState extends State<PortalMessages>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>>? _messages;
  String? _error;
  int? _unreadCount;
  final _viewportKey = GlobalKey();
  final _messageKeys = <Object, GlobalKey>{};
  final _visibleMessages = <Object>{};
  bool _visibilityCheckScheduled = false;
  final _markingRead = <Object>{};
  final _confirmedRead = <Object>{};
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _scheduleVisibilityCheck();
  }

  void _scheduleVisibilityCheck() {
    if (widget.supervisor || _visibilityCheckScheduled) return;
    _visibilityCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityCheckScheduled = false;
      if (mounted) _checkVisibleMessages();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _checkVisibleMessages() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (ModalRoute.of(context)?.isCurrent == false ||
        (lifecycle != null && lifecycle != AppLifecycleState.resumed)) {
      _visibleMessages.clear();
      return;
    }
    final viewport = _viewportKey.currentContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return;
    final bounds = viewport.localToGlobal(Offset.zero) & viewport.size;
    _visibleMessages.removeWhere((id) {
      final box = _messageKeys[id]?.currentContext?.findRenderObject();
      return !_isMessageVisible(box, bounds);
    });
    for (final item in _messages ?? const <Map<String, dynamic>>[]) {
      final id = item['id'];
      if (id == null || item['readAt'] != null || _confirmedRead.contains(id)) {
        continue;
      }
      final box = _messageKeys[id]?.currentContext?.findRenderObject();
      if (_isMessageVisible(box, bounds) && _visibleMessages.add(id)) {
        _markRead(id);
      }
    }
  }

  bool _isMessageVisible(RenderObject? box, Rect viewport) {
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final size = box.size;
    if (size.isEmpty) return false;
    final start = box.localToGlobal(Offset.zero) &
        Size(size.width, size.height.clamp(0, 64).toDouble());
    final visible = start.intersect(viewport);
    return !visible.isEmpty && visible.height >= start.height / 2;
  }

  Future<void> _load() async {
    final version = ++_loadVersion;
    setState(() {
      _messages = null;
      _error = null;
      _unreadCount = null;
    });
    try {
      final result = widget.supervisor
          ? await ApiService.fetchSupervisorMessages()
          : await (widget.fetchPromoterMessages ??
              ApiService.fetchPromoterMessages)();
      final messages = (result['data'] as List<dynamic>)
          .map((item) => item as Map<String, dynamic>)
          .toList();
      if (mounted && version == _loadVersion) {
        setState(() {
          _visibleMessages.clear();
          _messageKeys.removeWhere(
              (id, _) => !messages.any((item) => item['id'] == id));
          _messages = messages;
          if (!widget.supervisor) {
            _unreadCount = (result['unreadCount'] as int) -
                messages
                    .where((item) =>
                        item['readAt'] == null &&
                        _confirmedRead.contains(item['id']))
                    .length;
          }
        });
      }
    } catch (e) {
      if (mounted && version == _loadVersion) {
        setState(() => _error = e.toString());
      }
    }
  }

  Future<void> _markRead(Object id) async {
    if (!_markingRead.add(id)) return;
    try {
      final result = await (widget.markPromoterMessageRead ??
          ApiService.markPromoterMessageRead)(id);
      if (result['success'] != true) {
        throw StateError('Leitura não confirmada pelo servidor.');
      }
      if (!mounted) return;
      setState(() {
        _confirmedRead.add(id);
        final stillUnread = _messages?.any(
            (message) => message['id'] == id && message['readAt'] == null);
        if (stillUnread == true && (_unreadCount ?? 0) > 0) {
          _unreadCount = _unreadCount! - 1;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Não foi possível registrar a leitura. Role a lista e volte à mensagem para tentar novamente.')),
        );
      }
    } finally {
      _markingRead.remove(id);
    }
  }

  Future<void> _reply(Map<String, dynamic> item) async {
    final controller = TextEditingController();
    String? error;
    bool sending = false;
    try {
      final sent = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                  title: const Text('Responder'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: controller,
                        autofocus: true,
                        maxLines: 3,
                        decoration:
                            const InputDecoration(labelText: 'Resposta')),
                    if (error != null)
                      Text(error!,
                          style: const TextStyle(color: AppColors.error)),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: sending
                            ? null
                            : () => Navigator.pop(context, false),
                        child: const Text('Cancelar')),
                    FilledButton(
                        onPressed: sending
                            ? null
                            : () async {
                                if (controller.text.trim().isEmpty) {
                                  update(() => error = 'Escreva uma resposta.');
                                  return;
                                }
                                update(() {
                                  sending = true;
                                  error = null;
                                });
                                try {
                                  await ApiService.replyPromoterMessage(
                                      item['id']!, controller.text.trim());
                                  if (context.mounted) {
                                    Navigator.pop(context, true);
                                  }
                                } catch (e) {
                                  update(() {
                                    sending = false;
                                    error = e.toString();
                                  });
                                }
                              },
                        child: const Text('Enviar')),
                  ],
                )),
      );
      if (sent == true && mounted) _load();
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ModalRoute.of(context)?.isCurrent != false) _scheduleVisibilityCheck();
    return Column(children: [
      if (!widget.supervisor && _unreadCount != null && _unreadCount! > 0)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Row(
              children: [
                const Icon(Icons.mark_email_unread_outlined,
                    color: Color(0xFF0F766E), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Você tem $_unreadCount mensagem(ns) não lida(s)',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF065F46),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      if (widget.supervisor)
        Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: widget.promoters.isEmpty
                    ? null
                    : () async {
                        if (await showSupervisorCompose(context,
                                promoters: widget.promoters) &&
                            mounted) {
                          _load();
                        }
                      },
                icon: const Icon(Icons.send),
                label: Text(widget.promoters.isEmpty
                    ? 'Nenhum promotor disponível'
                    : 'Nova pergunta ou aviso'),
              ),
            )),
      Expanded(
          child: _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                )
              : _messages == null
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF0F766E)),
                      ),
                    )
                  : RefreshIndicator(
                      color: const Color(0xFF0F766E),
                      onRefresh: _load,
                      child: NotificationListener<ScrollNotification>(
                          key: _viewportKey,
                          onNotification: (notification) {
                            if (notification.depth == 0) {
                              _scheduleVisibilityCheck();
                            }
                            return false;
                          },
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                            children: _messages!.isEmpty
                                ? [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 80),
                                      child: Center(
                                        child: Column(
                                          children: [
                                            Icon(Icons.mark_chat_read_outlined,
                                                size: 64,
                                                color: context.uiTextFaint),
                                            const SizedBox(height: 12),
                                            Text(
                                              'Nenhuma mensagem recebida',
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: context.uiTextMuted,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Perguntas e comunicados da gestão aparecerão aqui.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  color: context.uiTextMuted,
                                                  fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  ]
                                : _messages!
                                    .map((item) => _buildMessageCard(item))
                                    .toList(),
                          )))),
    ]);
  }

  Widget _buildMessageCard(Map<String, dynamic> item) {
    final isRequest = item['type'] == 'request';
    final isUnread = !widget.supervisor &&
        item['readAt'] == null &&
        !_confirmedRead.contains(item['id']);
    final id = item['id'];
    final messageKey = isUnread && id != null
        ? _messageKeys.putIfAbsent(id, GlobalKey.new)
        : null;
    final isAnswered = item['status'] == 'answered';
    final replies = (item['replies'] as List<dynamic>?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.uiSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread
              ? const Color(0xFF0F766E).withValues(alpha: 0.4)
              : context.uiBorder,
          width: isUnread ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linha superior: Tags de tipo, status e data
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isRequest
                        ? const Color(0xFFCCFBF1)
                        : const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isRequest ? '❓ Pergunta-chave' : '📢 Aviso',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isRequest
                          ? const Color(0xFF0F766E)
                          : const Color(0xFF0369A1),
                    ),
                  ),
                ),
                if (isUnread) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Nova',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
                if (isAnswered) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Respondida',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  _formatDate(item['createdAt']?.toString()),
                  style: TextStyle(fontSize: 11, color: context.uiTextMuted),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Column(
              key: messageKey,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['message']?.toString() ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.uiTextStrong,
                    height: 1.4,
                  ),
                ),
                if (item['photoUrl'] != null) ...[
                  const SizedBox(height: 10),
                  PortalPhoto(url: item['photoUrl'].toString(), height: 160),
                ],
              ],
            ),

            // Respostas / Diálogo
            if (replies.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.uiSurfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.uiBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: replies.map((reply) {
                    final data = reply as Map<String, dynamic>;
                    final isPromoter = data['senderRole'] == 'promoter';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPromoter
                                ? '👤 Sua Resposta'
                                : '🛡️ Mensagem da Gestão',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isPromoter
                                  ? const Color(0xFF0F766E)
                                  : const Color(0xFF0369A1),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            data['message']?.toString() ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.uiTextBody,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Botões de Ação
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!widget.supervisor) ...[
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () => _reply(item),
                    icon: const Icon(Icons.reply, size: 16),
                    label: Text(
                      isRequest ? 'Responder Pergunta' : 'Responder',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw.split('T').first;
    }
  }
}

class PromoterMessagesPage extends StatelessWidget {
  const PromoterMessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F1419) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Mensagens da Gestão',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor:
            isDark ? const Color(0xFF1A1F2E) : const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: const PortalMessages(supervisor: false),
    );
  }
}
