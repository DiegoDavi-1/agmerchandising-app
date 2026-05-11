import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/checklist_model.dart';

class ChecklistService {
  static final ChecklistService _instance = ChecklistService._internal();
  factory ChecklistService() => _instance;
  ChecklistService._internal();

  static const _keyTemplates = 'checklist_templates';
  static const _keyActive = 'active_checklists';

  /// Templates padrão
  List<ChecklistTemplate> get defaultTemplates => [
    ChecklistTemplate(
      id: 'default_opening',
      name: 'Abertura de Loja',
      brandName: null,
      items: [
        ChecklistItem(id: '1', title: 'Verificar temperatura de geladeiras'),
        ChecklistItem(id: '2', title: 'Conferir validades em destaque'),
        ChecklistItem(id: '3', title: 'Organizar gôndolas'),
        ChecklistItem(id: '4', title: 'Limpar prateleiras'),
        ChecklistItem(id: '5', title: 'Foto panorâmica da seção'),
      ],
      createdAt: DateTime.now(),
    ),
    ChecklistTemplate(
      id: 'default_closing',
      name: 'Fechamento de Loja',
      brandName: null,
      items: [
        ChecklistItem(id: '1', title: 'Contagem de estoque'),
        ChecklistItem(id: '2', title: 'Verificar produtos vencidos'),
        ChecklistItem(id: '3', title: 'Organizar estoque'),
        ChecklistItem(id: '4', title: 'Limpar área de trabalho'),
        ChecklistItem(id: '5', title: 'Foto final da seção'),
      ],
      createdAt: DateTime.now(),
    ),
    ChecklistTemplate(
      id: 'default_inspection',
      name: 'Inspeção de Qualidade',
      brandName: null,
      items: [
        ChecklistItem(id: '1', title: 'Conferir precificação'),
        ChecklistItem(id: '2', title: 'Verificar rupturas'),
        ChecklistItem(id: '3', title: 'Analisar exposição de produtos'),
        ChecklistItem(id: '4', title: 'Comparar com planograma'),
        ChecklistItem(id: '5', title: 'Registrar não conformidades'),
        ChecklistItem(id: '6', title: 'Fotos de evidências'),
      ],
      createdAt: DateTime.now(),
    ),
  ];

  /// Carregar templates salvos
  Future<List<ChecklistTemplate>> loadTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_keyTemplates);
    
    if (jsonList == null || jsonList.isEmpty) {
      return defaultTemplates;
    }

    return jsonList.map((e) => ChecklistTemplate.fromJson(jsonDecode(e))).toList();
  }

  /// Salvar template
  Future<void> saveTemplate(ChecklistTemplate template) async {
    final templates = await loadTemplates();
    final index = templates.indexWhere((t) => t.id == template.id);
    
    if (index >= 0) {
      templates[index] = template;
    } else {
      templates.add(template);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyTemplates,
      templates.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  /// Deletar template
  Future<void> deleteTemplate(String templateId) async {
    final templates = await loadTemplates();
    templates.removeWhere((t) => t.id == templateId);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _keyTemplates,
      templates.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  /// Carregar checklist ativo
  Future<ChecklistTemplate?> loadActiveChecklist(String brandName) async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString('${_keyActive}_$brandName');
    
    if (json == null) return null;

    final Map<String, dynamic> data = jsonDecode(json);
    return ChecklistTemplate.fromJson(data);
  }

  /// Salvar checklist ativo
  Future<void> saveActiveChecklist(String brandName, ChecklistTemplate checklist) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '${_keyActive}_$brandName',
      jsonEncode(checklist.toJson()),
    );
  }

  /// Limpar checklist
  Future<void> clearChecklist(String brandName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_keyActive}_$brandName');
  }
}
