import 'package:flutter/material.dart';
import '../models/checklist_model.dart';
import '../services/checklist_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ChecklistPage extends StatefulWidget {
  final String brandName;
  
  const ChecklistPage({super.key, required this.brandName});

  @override
  State<ChecklistPage> createState() => _ChecklistPageState();
}

class _ChecklistPageState extends State<ChecklistPage> {
  final ChecklistService _checklistService = ChecklistService();
  ChecklistTemplate? _activeChecklist;
  List<ChecklistTemplate> _templates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    _templates = await _checklistService.loadTemplates();
    _activeChecklist = await _checklistService.loadActiveChecklist(widget.brandName);
    
    setState(() => _isLoading = false);
  }

  Future<void> _startNewChecklist(ChecklistTemplate template) async {
    final newChecklist = ChecklistTemplate(
      id: DateTime.now().toString(),
      name: template.name,
      brandName: widget.brandName,
      items: template.items.map((item) => ChecklistItem(
        id: item.id,
        title: item.title,
        description: item.description,
      )).toList(),
      createdAt: DateTime.now(),
    );
    
    await _checklistService.saveActiveChecklist(widget.brandName, newChecklist);
    await _loadData();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Checklist iniciado!')),
      );
    }
  }

  Future<void> _toggleItem(int index) async {
    if (_activeChecklist == null) return;
    
    setState(() {
      _activeChecklist!.items[index].isCompleted = !_activeChecklist!.items[index].isCompleted;
      if (_activeChecklist!.items[index].isCompleted) {
        _activeChecklist!.items[index].completedAt = DateTime.now();
      } else {
        _activeChecklist!.items[index].completedAt = null;
      }
    });
    
    await _checklistService.saveActiveChecklist(widget.brandName, _activeChecklist!);
  }

  Future<void> _addPhoto(int index) async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);
    
    if (photo != null && _activeChecklist != null) {
      setState(() {
        _activeChecklist!.items[index].photoPath = photo.path;
      });
      
      await _checklistService.saveActiveChecklist(widget.brandName, _activeChecklist!);
    }
  }

  Future<void> _addNotes(int index) async {
    final controller = TextEditingController(text: _activeChecklist?.items[index].notes ?? '');
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar Observação'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Digite suas observações...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_activeChecklist != null) {
                setState(() {
                  _activeChecklist!.items[index].notes = controller.text;
                });
                await _checklistService.saveActiveChecklist(widget.brandName, _activeChecklist!);
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> _finishChecklist() async {
    final allCompleted = _activeChecklist!.items.every((item) => item.isCompleted);
    
    if (!allCompleted) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Checklist Incompleto'),
          content: const Text('Nem todos os itens foram concluídos. Deseja finalizar mesmo assim?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Finalizar'),
            ),
          ],
        ),
      );
      
      if (confirm != true) return;
    }
    
    await _checklistService.clearChecklist(widget.brandName);
    await _loadData();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checklist finalizado com sucesso!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Checklist - ${widget.brandName}'),
        actions: [
          if (_activeChecklist != null)
            IconButton(
              icon: const Icon(Icons.check_circle),
              onPressed: _finishChecklist,
              tooltip: 'Finalizar Checklist',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activeChecklist == null
              ? _buildTemplateSelector()
              : _buildActiveChecklist(),
    );
  }

  Widget _buildTemplateSelector() {
    return _templates.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.checklist, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Nenhum template disponível',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _createDefaultChecklist,
                  icon: const Icon(Icons.add),
                  label: const Text('Criar Checklist'),
                ),
              ],
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Selecione um template de checklist:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ..._templates.map((template) => Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.checklist),
                  ),
                  title: Text(template.name),
                  subtitle: Text('${template.items.length} itens'),
                  trailing: ElevatedButton(
                    onPressed: () => _startNewChecklist(template),
                    child: const Text('Iniciar'),
                  ),
                ),
              )).toList(),
            ],
          );
  }

  Future<void> _createDefaultChecklist() async {
    final defaultChecklist = ChecklistTemplate(
      id: DateTime.now().toString(),
      name: 'Checklist Rápido',
      brandName: widget.brandName,
      items: [
        ChecklistItem(id: '1', title: 'Item 1'),
        ChecklistItem(id: '2', title: 'Item 2'),
        ChecklistItem(id: '3', title: 'Item 3'),
      ],
      createdAt: DateTime.now(),
    );
    
    await _checklistService.saveActiveChecklist(widget.brandName, defaultChecklist);
    await _loadData();
  }

  Widget _buildActiveChecklist() {
    final completed = _activeChecklist!.items.where((item) => item.isCompleted).length;
    final total = _activeChecklist!.items.length;
    final progress = completed / total;
    
    return Column(
      children: [
        // Header com progresso
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _activeChecklist!.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$completed/$total',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),
        
        // Lista de itens
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _activeChecklist!.items.length,
            itemBuilder: (context, index) {
              final item = _activeChecklist!.items[index];
              
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: ExpansionTile(
                  leading: Checkbox(
                    value: item.isCompleted,
                    onChanged: (_) => _toggleItem(index),
                  ),
                  title: Text(
                    item.title,
                    style: TextStyle(
                      decoration: item.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: (item.description != null && item.description!.isNotEmpty)
                      ? Text(item.description!)
                      : null,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Foto
                          if (item.photoPath != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(item.photoPath!),
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          
                          // Botões de ação
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => _addPhoto(index),
                                icon: const Icon(Icons.camera_alt),
                                label: Text(item.photoPath != null
                                    ? 'Alterar Foto'
                                    : 'Adicionar Foto'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => _addNotes(index),
                                icon: const Icon(Icons.note_add),
                                label: const Text('Observações'),
                              ),
                            ],
                          ),
                          
                          // Observações
                          if (item.notes != null && item.notes!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Observações:',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(item.notes ?? ''),
                                ],
                              ),
                            ),
                          ],
                          
                          // Data de conclusão
                          if (item.completedAt != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Concluído em: ${item.completedAt!.day}/${item.completedAt!.month}/${item.completedAt!.year} às ${item.completedAt!.hour}:${item.completedAt!.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
