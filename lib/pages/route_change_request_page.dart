import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';

const _teal = Color(0xFF0F766E);

/// Ordem exibida começando na segunda-feira; valores seguem 0=domingo..6=sábado.
const _weekdayOrder = [1, 2, 3, 4, 5, 6, 0];
const _weekdayShort = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

String formatWeekdays(List<int> days) {
  if (days.isEmpty) return '—';
  final ordered = _weekdayOrder.where(days.contains);
  return ordered.map((d) => _weekdayShort[d]).join(', ');
}

final _storeNameNumber = RegExp(r'\bloja\s*(\d+)\b', caseSensitive: false);

String formatRouteStoreLabel(Map<String, dynamic> store) {
  final chain = '${store['chain'] ?? ''}'.trim();
  final name = '${store['store_name'] ?? ''}'.trim();
  final number = '${store['store_number'] ?? ''}'.trim();
  final namedNumber = _storeNameNumber.firstMatch(name)?.group(1);
  final repeatsNumber = int.tryParse(number) != null &&
      int.tryParse(number) == int.tryParse(namedNumber ?? '');
  final label = [
    if (chain.isNotEmpty && !name.toLowerCase().contains(chain.toLowerCase()))
      chain,
    if (number.isNotEmpty && !repeatsNumber) 'Loja $number',
    if (name.isNotEmpty) name,
  ].join(' · ');
  return label.isEmpty ? 'Loja ${store['id']}' : label;
}

int compareRouteStores(Map<String, dynamic> a, Map<String, dynamic> b) {
  final chain = '${a['chain'] ?? ''}'
      .toLowerCase()
      .compareTo('${b['chain'] ?? ''}'.toLowerCase());
  if (chain != 0) return chain;
  int? number(Map<String, dynamic> store) =>
      int.tryParse('${store['store_number'] ?? ''}'.trim()) ??
      int.tryParse(_storeNameNumber
              .firstMatch('${store['store_name'] ?? ''}')
              ?.group(1) ??
          '');
  final first = number(a);
  final second = number(b);
  if (first != null && second != null && first != second) {
    return first.compareTo(second);
  }
  return formatRouteStoreLabel(a).compareTo(formatRouteStoreLabel(b));
}

class RouteChangeRequestPage extends StatefulWidget {
  const RouteChangeRequestPage({super.key});

  @override
  State<RouteChangeRequestPage> createState() => _RouteChangeRequestPageState();
}

class _Option {
  final int id;
  final String label;
  final String? detail;
  const _Option(this.id, this.label, [this.detail]);
}

class _Assignment {
  final int storeId;
  final int brandId;
  final List<int> weekdays;
  const _Assignment(this.storeId, this.brandId, this.weekdays);
}

class _RouteChangeRequestPageState extends State<RouteChangeRequestPage> {
  final _noteController = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _loading = true;
  bool _sending = false;
  bool _showForm = false;
  String _query = '';
  String? _loadError;

  List<_Option> _stores = [];
  List<_Option> _brands = [];
  List<_Assignment> _assignments = [];
  List<Map<String, dynamic>> _history = [];

  String _action = 'add';
  int? _storeId;
  int? _brandId;
  final Set<int> _days = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int? _int(dynamic v) => v is int ? v : int.tryParse('$v');

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([
        ApiService.fetchRouteChangeOptions(),
        ApiService.fetchMyRouteChangeRequests(),
      ]);
      final data = results[0]['data'] as Map<String, dynamic>;
      final stores = (data['stores'] as List)
          .cast<Map<String, dynamic>>()
          .toList()
        ..sort(compareRouteStores);
      final brands = (data['brands'] as List).cast<Map<String, dynamic>>();
      final assignments =
          (data['assignments'] as List).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _stores = stores.map((s) {
          final place = [s['city'], s['state']]
              .where((v) => v != null && '$v'.trim().isNotEmpty)
              .join('/');
          return _Option(
            _int(s['id'])!,
            formatRouteStoreLabel(s),
            place.isEmpty ? null : place,
          );
        }).toList();
        _brands =
            brands.map((b) => _Option(_int(b['id'])!, '${b['name']}')).toList();
        _assignments = assignments
            .map((a) => _Assignment(
                  _int(a['store_id'])!,
                  _int(a['brand_id'])!,
                  (a['weekdays'] as List).map((d) => _int(d)!).toList(),
                ))
            .toList();
        _history = (results[1]['data'] as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = '$error'.replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  String _storeLabel(int id) =>
      _stores.where((s) => s.id == id).map((s) => s.label).firstOrNull ??
      'Loja $id';
  String _brandLabel(int id) =>
      _brands.where((b) => b.id == id).map((b) => b.label).firstOrNull ??
      'Marca $id';

  void _setAction(String action) {
    setState(() {
      _action = action;
      _storeId = null;
      _brandId = null;
      _days.clear();
    });
  }

  void _openRequest(String action, [_Assignment? assignment]) {
    FocusScope.of(context).unfocus();
    _noteController.clear();
    _setAction(action);
    if (assignment != null) _selectAssignment(assignment);
    setState(() => _showForm = true);
    _scrollToTop();
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _selectAssignment(_Assignment a) {
    setState(() {
      _storeId = a.storeId;
      _brandId = a.brandId;
      _days
        ..clear()
        ..addAll(_action == 'change' ? a.weekdays : const []);
    });
  }

  Future<_Option?> _pick(String title, List<_Option> options) {
    return showModalBottomSheet<_Option>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SearchSheet(title: title, options: options),
    );
  }

  _Assignment? get _selectedAssignment => _assignments
      .where((a) => a.storeId == _storeId && a.brandId == _brandId)
      .firstOrNull;

  Future<void> _submit() async {
    if (_storeId == null || _brandId == null) {
      _snack('Selecione a loja e a marca.', error: true);
      return;
    }
    if (_action != 'remove' && _days.isEmpty) {
      _snack('Selecione pelo menos um dia da semana.', error: true);
      return;
    }
    setState(() => _sending = true);
    try {
      await ApiService.sendRouteChangeRequest(
        storeId: _storeId!,
        brandId: _brandId!,
        action: _action,
        weekdays: _days.toList()..sort(),
        note: _noteController.text.trim(),
      );
      if (!mounted) return;
      _noteController.clear();
      _setAction(_action);
      setState(() => _showForm = false);
      _snack(
          'Solicitação enviada. Você será avisado aqui quando for analisada.');
      await _load();
      _scrollToTop();
    } catch (error) {
      if (!mounted) return;
      _snack('$error'.replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _snack(String text, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? Colors.red : _teal,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Conferir meus atendimentos',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1F2E)
            : _teal,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _errorView()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      if (_showForm) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _sending
                                ? null
                                : () {
                                    setState(() => _showForm = false);
                                    _scrollToTop();
                                  },
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Voltar aos atendimentos'),
                          ),
                        ),
                        _explanation(),
                      ] else
                        _routeOverview(),
                      const SizedBox(height: 16),
                      if (_showForm) _form(),
                      const SizedBox(height: 24),
                      _historySection(),
                    ],
                  ),
                ),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(_loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: _load, child: const Text('Tentar novamente')),
          ]),
        ),
      );

  Widget _explanation() => Text(
        'Sua rota está diferente do que você realmente atende? Envie a correção. '
        'Depois que o administrador aprovar, a rota é atualizada automaticamente.',
        style: TextStyle(
            color: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.color
                ?.withValues(alpha: 0.75)),
      );

  Widget _routeOverview() {
    final query = _query.trim().toLowerCase();
    final grouped = <int, List<_Assignment>>{};
    for (final assignment in _assignments) {
      final text =
          '${_storeLabel(assignment.storeId)} ${_brandLabel(assignment.brandId)}';
      if (text.toLowerCase().contains(query)) {
        grouped.putIfAbsent(assignment.storeId, () => []).add(assignment);
      }
    }
    final storeOrder = {
      for (var index = 0; index < _stores.length; index++)
        _stores[index].id: index,
    };
    final storeIds = grouped.keys.toList()
      ..sort((a, b) {
        final order = (storeOrder[a] ?? _stores.length)
            .compareTo(storeOrder[b] ?? _stores.length);
        return order != 0 ? order : _storeLabel(a).compareTo(_storeLabel(b));
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Meus atendimentos semanais',
            style:
                GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Confira a loja, a marca e os dias dos vínculos semanais. '
            'Encontrou algo errado? Envie uma solicitação. '
            'Sua rota só muda após aprovação da administração.'),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _openRequest('add'),
          icon: const Icon(Icons.add),
          label: const Text('Adicionar atendimento'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            labelText: 'Buscar loja ou marca',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: 12),
        Text('${storeIds.length} loja(s) encontrada(s)',
            style: Theme.of(context).textTheme.bodySmall),
        if (_assignments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Nenhum atendimento semanal cadastrado. '
                'Se falta alguma loja ou marca, toque em Adicionar atendimento.'),
          )
        else if (storeIds.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Nenhuma loja ou marca encontrada para essa busca.'),
          ),
        for (final storeId in storeIds)
          Card(
            margin: const EdgeInsets.only(top: 12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_storeLabel(storeId),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  if (_stores
                          .where((store) => store.id == storeId)
                          .firstOrNull
                          ?.detail
                      case final String place)
                    Text(place),
                  for (final assignment in grouped[storeId]!) ...[
                    const Divider(height: 24),
                    Text(_brandLabel(assignment.brandId), style: _labelStyle),
                    const SizedBox(height: 6),
                    Text(
                        'Dias de atendimento: ${formatWeekdays(assignment.weekdays)}'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _openRequest('change', assignment),
                          icon: const Icon(Icons.edit_calendar_outlined),
                          label: const Text('Alterar dias'),
                        ),
                        TextButton.icon(
                          onPressed: () => _openRequest('remove', assignment),
                          icon: const Icon(Icons.remove_circle_outline),
                          label: const Text('Remover'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _form() {
    final usesCurrent = _action != 'add';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('O que deseja fazer?', style: _labelStyle),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                    value: 'add',
                    label: Text('Adicionar'),
                    icon: Icon(Icons.add)),
                ButtonSegment(
                    value: 'change',
                    label: Text('Alterar'),
                    icon: Icon(Icons.edit)),
                ButtonSegment(
                    value: 'remove',
                    label: Text('Remover'),
                    icon: Icon(Icons.remove)),
              ],
              selected: {_action},
              onSelectionChanged: _sending ? null : (s) => _setAction(s.first),
            ),
            const SizedBox(height: 16),
            if (usesCurrent) ..._currentPicker() else ..._newPickers(),
            if (_storeId != null && _brandId != null) ...[
              const SizedBox(height: 16),
              Text(_daysTitle, style: _labelStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final d in _weekdayOrder)
                    FilterChip(
                      label: Text(_weekdayShort[d]),
                      selected: _days.contains(d),
                      selectedColor: _teal.withValues(alpha: 0.2),
                      checkmarkColor: _teal,
                      onSelected: _sending
                          ? null
                          : (on) => setState(
                              () => on ? _days.add(d) : _days.remove(d)),
                    ),
                ],
              ),
              if (_action == 'remove')
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _days.isEmpty
                        ? 'Nenhum dia marcado: o atendimento será removido de todos os dias.'
                        : 'Somente os dias marcados serão removidos.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteController,
                maxLength: 1000,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Observação (opcional)',
                  hintText:
                      'Ex.: atendo essa marca nessa loja desde o mês passado.',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _sending ? null : _submit,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send),
                label: Text(_sending ? 'Enviando...' : 'Enviar solicitação'),
                style: FilledButton.styleFrom(
                    backgroundColor: _teal,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String get _daysTitle => switch (_action) {
        'add' => 'Em quais dias você atende?',
        'change' => 'Quais são os dias corretos?',
        _ => 'Quais dias devem sair da rota?',
      };

  TextStyle get _labelStyle => const TextStyle(fontWeight: FontWeight.w600);

  List<Widget> _newPickers() => [
        _PickerField(
          label: 'Loja',
          value: _storeId == null ? null : _storeLabel(_storeId!),
          icon: Icons.storefront_outlined,
          onTap: _sending
              ? null
              : () async {
                  final picked = await _pick('Escolha a loja', _stores);
                  if (picked != null) setState(() => _storeId = picked.id);
                },
        ),
        const SizedBox(height: 10),
        _PickerField(
          label: 'Marca',
          value: _brandId == null ? null : _brandLabel(_brandId!),
          icon: Icons.sell_outlined,
          onTap: _sending
              ? null
              : () async {
                  final picked = await _pick('Escolha a marca', _brands);
                  if (picked != null) setState(() => _brandId = picked.id);
                },
        ),
        if (_selectedAssignment != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Esse atendimento já está na sua rota (${formatWeekdays(_selectedAssignment!.weekdays)}). '
              'Os dias marcados serão somados aos atuais.',
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ];

  List<Widget> _currentPicker() {
    if (_assignments.isEmpty) {
      return [
        const Text(
            'Você ainda não tem atendimentos fixos na rota. Use “Adicionar”.'),
      ];
    }
    return [
      Text(
          _selectedAssignment == null
              ? 'Escolha o atendimento da sua rota'
              : 'Atendimento selecionado',
          style: _labelStyle),
      const SizedBox(height: 6),
      for (final a in _assignments)
        if (_selectedAssignment == null ||
            (a.storeId == _storeId && a.brandId == _brandId))
          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: '${a.storeId}:${a.brandId}',
            groupValue: _storeId == null ? null : '$_storeId:$_brandId',
            activeColor: _teal,
            title:
                Text('${_brandLabel(a.brandId)} — ${_storeLabel(a.storeId)}'),
            subtitle: Text('Hoje na rota: ${formatWeekdays(a.weekdays)}'),
            onChanged: _sending ? null : (_) => _selectAssignment(a),
          ),
      if (_selectedAssignment != null)
        TextButton(
          onPressed: _sending ? null : () => _setAction(_action),
          child: const Text('Escolher outro atendimento'),
        ),
    ];
  }

  Widget _historySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Minhas solicitações',
            style:
                GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (_history.isEmpty)
          const Text('Nenhuma solicitação enviada ainda.')
        else
          for (final item in _history) _HistoryCard(item: item),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _HistoryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final status = '${item['status']}';
    final (label, color) = switch (status) {
      'approved' => ('Aprovada', Colors.green.shade700),
      'rejected' => ('Reprovada', Colors.red.shade700),
      _ => ('Aguardando análise', Colors.orange.shade800),
    };
    final rescheduleDate = item['reschedule_date']?.toString();
    final action = rescheduleDate != null
        ? 'Remarcar visita'
        : switch ('${item['action']}') {
            'add' => 'Adicionar',
            'change' => 'Alterar dias',
            _ => 'Remover',
          };
    final days = (item['weekdays'] as List? ?? [])
        .map((d) => d is int ? d : int.tryParse('$d') ?? -1)
        .where((d) => d >= 0 && d <= 6)
        .toList();
    final store = [item['chain'], item['store_name']]
        .where((v) => v != null && '$v'.trim().isNotEmpty)
        .join(' · ');
    final adminNote = item['admin_note'];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text('$action · ${item['brand_name'] ?? 'Marca'}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(store.isEmpty ? 'Loja' : store),
            Text(
              rescheduleDate != null
                  ? 'Nova data: ${rescheduleDate.split('-').reversed.join('/')}'
                  : item['action'] == 'remove' && days.isEmpty
                      ? 'Dias: todos'
                      : 'Dias: ${formatWeekdays(days)}',
              style: const TextStyle(fontSize: 13),
            ),
            if (adminNote != null && '$adminNote'.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Resposta: $adminNote',
                  style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  final String label;
  final String? value;
  final IconData icon;
  final VoidCallback? onTap;

  const _PickerField(
      {required this.label,
      required this.value,
      required this.icon,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.arrow_drop_down),
          border: const OutlineInputBorder(),
        ),
        isEmpty: value == null,
        child: Text(value ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _SearchSheet extends StatefulWidget {
  final String title;
  final List<_Option> options;
  const _SearchSheet({required this.title, required this.options});

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final filtered = widget.options
        .where((o) => '${o.label} ${o.detail ?? ''}'.toLowerCase().contains(q))
        .toList();
    return SafeArea(
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(widget.title,
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Buscar',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('Nada encontrado.'))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final o = filtered[i];
                          return ListTile(
                            title: Text(o.label),
                            subtitle: o.detail == null ? null : Text(o.detail!),
                            onTap: () => Navigator.of(context).pop(o),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
