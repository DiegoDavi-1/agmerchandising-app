import 'package:flutter/material.dart';

class NonVisitRescheduleDialog extends StatefulWidget {
  const NonVisitRescheduleDialog({super.key, required this.onSubmit});

  final Future<void> Function(DateTime date) onSubmit;

  @override
  State<NonVisitRescheduleDialog> createState() =>
      _NonVisitRescheduleDialogState();
}

class _NonVisitRescheduleDialogState extends State<NonVisitRescheduleDialog> {
  DateTime? _date;
  bool _sending = false;
  String? _error;

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: _date ?? today.add(const Duration(days: 1)),
      firstDate: today.add(const Duration(days: 1)),
      lastDate: DateTime(today.year + 5, today.month, today.day),
    );
    if (date != null && mounted) setState(() => _date = date);
  }

  Future<void> _send() async {
    if (_date == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_date!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = _date;
    return PopScope(
      canPop: !_sending,
      child: AlertDialog(
        title: const Text('Remarcar visita?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'O não atendimento já foi registrado. Se quiser, escolha outro '
                'dia para esta loja e marca. A nova visita só entra na agenda '
                'após a aprovação do administrador.',
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _sending ? null : _pickDate,
                icon: const Icon(Icons.calendar_month),
                label: Text(date == null
                    ? 'Escolher nova data'
                    : '${date.day.toString().padLeft(2, '0')}/'
                        '${date.month.toString().padLeft(2, '0')}/${date.year}'),
              ),
              if (_error != null)
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _sending ? null : () => Navigator.of(context).pop(false),
            child: const Text('Agora não'),
          ),
          FilledButton(
            onPressed: date == null || _sending ? null : _send,
            child: Text(_sending ? 'Enviando...' : 'Enviar para aprovação'),
          ),
        ],
      ),
    );
  }
}
