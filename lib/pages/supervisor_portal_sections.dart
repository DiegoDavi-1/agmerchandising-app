import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../services/api_service.dart';
import 'portal_messages.dart';

String portalDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

Widget portalError(String error, VoidCallback retry) => Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(error, textAlign: TextAlign.center),
        TextButton(onPressed: retry, child: const Text('Tentar novamente')),
      ]),
    );

class PortalBrandFilter extends StatefulWidget {
  const PortalBrandFilter({
    super.key,
    required this.onChanged,
    this.supervisor = false,
  });
  final ValueChanged<String?> onChanged;
  final bool supervisor;

  @override
  State<PortalBrandFilter> createState() => _PortalBrandFilterState();
}

class _PortalBrandFilterState extends State<PortalBrandFilter> {
  Map<String, String>? _brands;
  String? _error;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final brands = widget.supervisor
          ? await ApiService.getSupervisorBrands()
          : await ApiService.getBrands(limit: 200);
      if (!mounted) return;
      setState(() => _brands = {
            for (final brand in brands)
              if (brand['id'] != null)
                brand['id'].toString(): brand['name']?.toString() ?? 'Marca',
          });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return TextButton.icon(
        onPressed: _load,
        icon: const Icon(Icons.refresh),
        label: const Text('Erro ao carregar marcas. Tentar novamente'),
      );
    }
    if (_brands == null) return const CircularProgressIndicator();
    return DropdownButton<String>(
      value: _selected,
      items: [
        const DropdownMenuItem(value: null, child: Text('Todas as marcas')),
        ..._brands!.entries.map((entry) =>
            DropdownMenuItem(value: entry.key, child: Text(entry.value))),
      ],
      onChanged: (value) {
        setState(() => _selected = value);
        widget.onChanged(value);
      },
    );
  }
}

class SupervisorAttendances extends StatefulWidget {
  const SupervisorAttendances({super.key, required this.period});
  final DateTimeRange period;

  @override
  State<SupervisorAttendances> createState() => _SupervisorAttendancesState();
}

class _SupervisorAttendancesState extends State<SupervisorAttendances> {
  List<Map<String, dynamic>>? _items;
  String? _brandId;
  String? _status;
  String? _error;
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final version = ++_loadVersion;
    setState(() {
      _items = null;
      _error = null;
    });
    try {
      final result = await ApiService.fetchSupervisorAttendances(
        startDate: portalDate(widget.period.start),
        endDate: portalDate(widget.period.end),
        brandId: _brandId,
        status: _status,
      );
      final items = (result['data'] as List<dynamic>)
          .map((item) => item as Map<String, dynamic>)
          .toList();
      if (!mounted || version != _loadVersion) return;
      setState(() => _items = items);
    } catch (e) {
      if (mounted && version == _loadVersion) {
        setState(() => _error = e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                  '${portalDate(widget.period.start)} – ${portalDate(widget.period.end)}'),
              PortalBrandFilter(
                  supervisor: true,
                  onChanged: (value) {
                    _brandId = value;
                    _load();
                  }),
              DropdownButton<String>(
                value: _status,
                items: const [
                  DropdownMenuItem(value: null, child: Text('Todos os status')),
                  DropdownMenuItem(
                      value: 'completed', child: Text('Concluído')),
                  DropdownMenuItem(
                      value: 'in_progress', child: Text('Em andamento')),
                  DropdownMenuItem(
                      value: 'not_started', child: Text('Não iniciado')),
                ],
                onChanged: (value) {
                  _status = value;
                  _load();
                },
              ),
            ]),
      ),
      Expanded(
          child: _error != null
              ? portalError(_error!, _load)
              : _items == null
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        children: _items!.isEmpty
                            ? [
                                const ListTile(
                                    title:
                                        Text('Nenhum atendimento no período.'))
                              ]
                            : _items!.map((item) {
                                final status = item['status']?.toString();
                                final label = switch (status) {
                                  'completed' => 'Concluído',
                                  'in_progress' => 'Em andamento',
                                  _ => 'Não iniciado',
                                };
                                return Card(
                                  child: ListTile(
                                    title: Text(
                                        '${item['promoterName'] ?? 'Promotor'} · ${item['storeName'] ?? 'Loja'}'),
                                    subtitle: Text(
                                        '${item['brandName'] ?? 'Marca'} · ${item['plannedDate'] ?? ''}\n$label'),
                                    isThreeLine: true,
                                    trailing: Icon(
                                        item['completed'] == true
                                            ? Icons.check_circle
                                            : Icons.schedule,
                                        color: item['completed'] == true
                                            ? AppColors.success
                                            : AppColors.warning),
                                  ),
                                );
                              }).toList(),
                      ))),
    ]);
  }
}

class SupervisorPhotos extends StatefulWidget {
  const SupervisorPhotos({super.key, required this.period});
  final DateTimeRange period;

  @override
  State<SupervisorPhotos> createState() => _SupervisorPhotosState();
}

class _SupervisorPhotosState extends State<SupervisorPhotos> {
  List<Map<String, dynamic>>? _photos;
  String? _brandId;
  String? _error;
  bool _submitting = false;
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final version = ++_loadVersion;
    setState(() {
      _photos = null;
      _error = null;
    });
    try {
      final result = await ApiService.fetchSupervisorPhotos(
        startDate: portalDate(widget.period.start),
        endDate: portalDate(widget.period.end),
        brandId: _brandId,
      );
      final photos = (result['photos'] as List<dynamic>)
          .map((item) => item as Map<String, dynamic>)
          .toList();
      if (!mounted || version != _loadVersion) return;
      setState(() => _photos = photos);
    } catch (e) {
      if (mounted && version == _loadVersion) {
        setState(() => _error = e.toString());
      }
    }
  }

  Future<bool> _review(Map<String, dynamic> photo, String status) async {
    if (_submitting) return false;
    String? message;
    if (status == 'rejected') {
      final controller = TextEditingController();
      try {
        message = await showDialog<String>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Rejeitar foto?'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration:
                  const InputDecoration(labelText: 'Motivo / orientação'),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar')),
              FilledButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, controller.text.trim()),
                  child: const Text('Confirmar rejeição')),
            ],
          ),
        );
      } finally {
        controller.dispose();
      }
      if (message == null || !mounted) return false;
    }
    setState(() => _submitting = true);
    try {
      await ApiService.reviewSupervisorPhoto(photo['id']!,
          status: status, message: message);
      if (!mounted) return false;
      setState(() => _photos!.removeWhere((item) => item['id'] == photo['id']));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(status == 'approved' ? 'Foto aprovada.' : 'Foto rejeitada.'),
      ));
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Não foi possível revisar: $e')));
      }
      return false;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                  '${portalDate(widget.period.start)} – ${portalDate(widget.period.end)}'),
              PortalBrandFilter(
                  supervisor: true,
                  onChanged: (value) {
                    _brandId = value;
                    _load();
                  }),
            ],
          )),
      Expanded(
          child: _error != null
              ? portalError(_error!, _load)
              : _photos == null
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _photos!.isEmpty ? 1 : _photos!.length,
                        itemBuilder: (context, index) {
                          if (_photos!.isEmpty) {
                            return const ListTile(
                                title:
                                    Text('Nenhuma foto pendente de revisão.'));
                          }
                          final photo = _photos![index];
                          return Dismissible(
                            key: ValueKey(photo['id']),
                            direction: _submitting
                                ? DismissDirection.none
                                : DismissDirection.horizontal,
                            background: const ColoredBox(
                                color: AppColors.success,
                                child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Icon(Icons.check,
                                        color: Colors.white, size: 40))),
                            secondaryBackground: const ColoredBox(
                                color: AppColors.error,
                                child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Icon(Icons.close,
                                        color: Colors.white, size: 40))),
                            confirmDismiss: (direction) => _review(
                                    photo,
                                    direction == DismissDirection.startToEnd
                                        ? 'approved'
                                        : 'rejected')
                                .then((_) => false),
                            child: Card(
                                child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                PortalPhoto(
                                    url: photo['url']?.toString(), height: 240),
                                Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            photo['taskLabel']?.toString() ??
                                                'Foto',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium),
                                        Text(
                                            '${photo['promoterName'] ?? 'Promotor'} · ${photo['brandName'] ?? 'Marca'}'),
                                        Text(
                                            '${photo['storeName'] ?? 'Loja'} · ${photo['dateFormatted'] ?? ''}'),
                                        const SizedBox(height: 8),
                                        Wrap(spacing: 8, children: [
                                          OutlinedButton.icon(
                                            onPressed: _submitting
                                                ? null
                                                : () =>
                                                    _review(photo, 'rejected'),
                                            icon: const Icon(Icons.close),
                                            label: const Text('Rejeitar'),
                                          ),
                                          FilledButton.icon(
                                            onPressed: _submitting
                                                ? null
                                                : () =>
                                                    _review(photo, 'approved'),
                                            icon: const Icon(Icons.check),
                                            label: const Text('Aprovar'),
                                          ),
                                          TextButton.icon(
                                            onPressed: () =>
                                                showSupervisorCompose(
                                              context,
                                              promoterId: photo['promoterId'],
                                              promoterName:
                                                  photo['promoterName']
                                                      ?.toString(),
                                              collectionId:
                                                  photo['collectionId'],
                                              photoUrl:
                                                  photo['url']?.toString(),
                                            ),
                                            icon:
                                                const Icon(Icons.mail_outline),
                                            label: const Text('Enviar aviso'),
                                          ),
                                        ]),
                                      ],
                                    )),
                              ],
                            )),
                          );
                        },
                      ))),
    ]);
  }
}

class SupervisorMessages extends StatelessWidget {
  const SupervisorMessages({super.key, required this.promoters});
  final List<dynamic> promoters;

  @override
  Widget build(BuildContext context) =>
      PortalMessages(supervisor: true, promoters: promoters);
}
