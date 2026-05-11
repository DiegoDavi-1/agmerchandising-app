import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class ValidadeItem {
  String produto;
  DateTime dataValidade;
  String? categoria;
  String? lote;
  
  ValidadeItem({
    required this.produto,
    required this.dataValidade,
    this.categoria,
    this.lote,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'produto': produto,
      'dataValidade': dataValidade.toIso8601String(),
      'categoria': categoria,
      'lote': lote,
    };
  }
  
  factory ValidadeItem.fromJson(Map<String, dynamic> json) {
    return ValidadeItem(
      produto: json['produto'],
      dataValidade: DateTime.parse(json['dataValidade']),
      categoria: json['categoria'],
      lote: json['lote'],
    );
  }
  
  int diasRestantes() {
    final hoje = DateTime.now();
    final diferenca = dataValidade.difference(DateTime(hoje.year, hoje.month, hoje.day));
    return diferenca.inDays;
  }
  
  bool isVencido() => diasRestantes() < 0;
  bool isProximoVencimento() => diasRestantes() >= 0 && diasRestantes() <= 7;
  bool isAtencao() => diasRestantes() > 7 && diasRestantes() <= 30;
}

class NotesPage extends StatefulWidget {
  final String brandId;
  final String brandName;
  final String? headerColor;
  
  const NotesPage({
    super.key,
    this.brandId = 'default',
    this.brandName = 'Validades',
    this.headerColor,
  });

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  late List<ValidadeItem> _validades = [];
  bool _isLoading = false;
  String _filtro = 'todos';
  late bool _isDark;

  @override
  void initState() {
    super.initState();
    _loadValidades();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isDark = Theme.of(context).brightness == Brightness.dark;
  }

  Future<void> _loadValidades() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('validades_${widget.brandId}');
      if (data != null) {
        final List<dynamic> decoded = json.decode(data);
        setState(() {
          _validades = decoded.map((e) => ValidadeItem.fromJson(e as Map<String, dynamic>)).toList();
          _validades.sort((a, b) => a.dataValidade.compareTo(b.dataValidade));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveValidades() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(_validades.map((e) => e.toJson()).toList());
      await prefs.setString('validades_${widget.brandId}', encoded);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    }
  }

  void _addValidade() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ValidadeFormPage(
          onSave: (produto, data, categoria, lote) async {
            final newItem = ValidadeItem(
              produto: produto,
              dataValidade: data,
              categoria: categoria,
              lote: lote,
            );
            setState(() => _validades.add(newItem));
            await _saveValidades();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Validade adicionada!')),
              );
            }
          },
        ),
      ),
    );
  }

  void _deleteValidade(int index) {
    final deletedItem = _validades[index];
    setState(() => _validades.removeAt(index));
    _saveValidades();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Validade removida'),
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () async {
            setState(() => _validades.insert(index, deletedItem));
            await _saveValidades();
          },
        ),
      ),
    );
  }

  void _deleteValidadeSwipe(int index) {
    setState(() {
      _validades.removeAt(index);
    });
    _saveValidades();
  }

  List<ValidadeItem> _getValidadesFiltradas() {
    switch (_filtro) {
      case 'vencidos':
        return _validades.where((v) => v.isVencido()).toList();
      case 'proximos':
        return _validades.where((v) => v.isProximoVencimento()).toList();
      case 'atencao':
        return _validades.where((v) => v.isAtencao()).toList();
      default:
        return _validades;
    }
  }

  Color _getCorPorStatus(ValidadeItem validade) {
    if (validade.isVencido()) return Colors.red;
    if (validade.isProximoVencimento()) return Colors.orange;
    if (validade.isAtencao()) return Colors.yellow;
    return Colors.green;
  }

  String _getTextoStatus(ValidadeItem validade) {
    final dias = validade.diasRestantes();
    if (dias < 0) return 'VENCIDO há ${dias.abs()} dia(s)';
    if (dias == 0) return 'VENCE HOJE';
    if (dias == 1) return 'Vence amanhã';
    return 'Vence em $dias dias';
  }

  @override
  Widget build(BuildContext context) {
    final validadesFiltradas = _getValidadesFiltradas();
    final vencidos = _validades.where((v) => v.isVencido()).length;
    final proximos = _validades.where((v) => v.isProximoVencimento()).length;
    final atencao = _validades.where((v) => v.isAtencao()).length;
    
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final headerColor = widget.headerColor != null ? Color(int.parse('0xFF${widget.headerColor}')) : const Color(0xFF1E88E5);
    
    return Scaffold(
      body: Container(
        color: _isDark ? const Color(0xFF0F1419) : Colors.white,
        child: Column(
          children: [
            // Header com padding manual para não vazar acima do status bar
            Container(
              decoration: BoxDecoration(
                color: _isDark ? const Color(0xFF1A1F2E) : headerColor,
                boxShadow: [
                  BoxShadow(
                    color: (_isDark ? Colors.black : Colors.blue).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              ),
              padding: EdgeInsets.only(
                top: statusBarHeight + 12,
                left: 20,
                right: 20,
                bottom: 16,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Controle de Validades',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${_validades.length} produtos cadastrados',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.white, size: 32),
                    onPressed: _addValidade,
                  ),
                ],
              ),
            ),
            
            // Conteúdo scrollável
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Resumo com alertas
                    if (vencidos > 0 || proximos > 0 || atencao > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: (_isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: vencidos > 0 ? Colors.red : (proximos > 0 ? Colors.orange : Colors.yellow),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              if (vencidos > 0)
                                Row(
                                  children: [
                                    const Icon(Icons.error, color: Colors.red, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$vencidos produto(s) vencido(s)',
                                      style: GoogleFonts.poppins(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              if (proximos > 0) ...[
                                if (vencidos > 0) const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.warning, color: Colors.orange, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$proximos produto(s) vence(m) em até 7 dias',
                                      style: GoogleFonts.poppins(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (atencao > 0) ...[
                                if (vencidos > 0 || proximos > 0) const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.info, color: Colors.yellow, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$atencao produto(s) vence(m) em até 30 dias',
                                      style: GoogleFonts.poppins(
                                        color: Colors.yellow,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    
                    const SizedBox(height: 16),
                    
                    // Filtros
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFiltroChip('Todos', 'todos', _validades.length),
                            const SizedBox(width: 8),
                            _buildFiltroChip('Vencidos', 'vencidos', vencidos, Colors.red),
                            const SizedBox(width: 8),
                            _buildFiltroChip('Próximos 7 dias', 'proximos', proximos, Colors.orange),
                            const SizedBox(width: 8),
                            _buildFiltroChip('Até 30 dias', 'atencao', atencao, Colors.yellow),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Lista de validades
                    if (_isLoading)
                      Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(color: const Color(0xFF1E88E5)),
                      )
                    else if (validadesFiltradas.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _filtro == 'todos' ? Icons.calendar_today : Icons.check_circle,
                              size: 80,
                              color: _isDark ? Colors.grey[700] : Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _filtro == 'todos' 
                                  ? 'Nenhuma validade cadastrada'
                                  : 'Nenhum produto nesta categoria',
                              style: GoogleFonts.poppins(
                                color: _isDark ? Colors.white54 : Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _filtro == 'todos' 
                                  ? 'Toque no + para adicionar'
                                  : 'Selecione outro filtro',
                              style: GoogleFonts.poppins(
                                color: _isDark ? Colors.white38 : Colors.grey[500],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: validadesFiltradas.length,
                          itemBuilder: (context, index) {
                            final validade = validadesFiltradas[index];
                            final cor = _getCorPorStatus(validade);
                            
                            return Dismissible(
                              key: Key(validade.produto + validade.dataValidade.toString()),
                              background: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              direction: DismissDirection.endToStart,
                              onDismissed: (direction) => _deleteValidadeSwipe(_validades.indexOf(validade)),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: _isDark ? const Color(0xFF1A1F2E) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: cor.withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: cor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.calendar_today,
                                      color: cor,
                                      size: 24,
                                    ),
                                  ),
                                  title: Text(
                                    validade.produto,
                                    style: GoogleFonts.poppins(
                                      color: _isDark ? Colors.white : Colors.black,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        _getTextoStatus(validade),
                                        style: GoogleFonts.poppins(
                                          color: cor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (validade.categoria != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          validade.categoria!,
                                          style: GoogleFonts.poppins(
                                            color: _isDark ? Colors.white60 : Colors.grey[600],
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                      if (validade.lote != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'Lote: ${validade.lote}',
                                          style: GoogleFonts.poppins(
                                            color: _isDark ? Colors.white60 : Colors.grey[600],
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        DateFormat('dd/MM/yyyy').format(validade.dataValidade),
                                        style: GoogleFonts.poppins(
                                          color: _isDark ? Colors.white : Colors.black,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('EEE').format(validade.dataValidade),
                                        style: GoogleFonts.poppins(
                                          color: _isDark ? Colors.white60 : Colors.grey[600],
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltroChip(String label, String valor, int count, [Color? cor]) {
    final isSelected = _filtro == valor;
    final chipColor = cor ?? const Color(0xFF1E88E5);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: isSelected ? [
          BoxShadow(
            color: chipColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ] : [],
      ),
      child: FilterChip(
        label: Text(
          '$label${count > 0 ? " ($count)" : ""}',
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.white : (_isDark ? Colors.white70 : Colors.grey[700]),
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
            letterSpacing: 0.3,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _filtro = valor;
          });
        },
        backgroundColor: chipColor.withOpacity(0.15),
        selectedColor: chipColor,
        checkmarkColor: Colors.white,
        side: BorderSide(
          color: chipColor.withOpacity(isSelected ? 1.0 : 0.4),
          width: 2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}

class ValidadeFormPage extends StatefulWidget {
  final Function(String produto, DateTime data, String? categoria, String? lote) onSave;
  
  const ValidadeFormPage({super.key, required this.onSave});

  @override
  State<ValidadeFormPage> createState() => _ValidadeFormPageState();
}

class _ValidadeFormPageState extends State<ValidadeFormPage> {
  late TextEditingController _produtoController;
  late TextEditingController _categoriaController;
  late TextEditingController _loteController;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _produtoController = TextEditingController();
    _categoriaController = TextEditingController();
    _loteController = TextEditingController();
  }

  @override
  void dispose() {
    _produtoController.dispose();
    _categoriaController.dispose();
    _loteController.dispose();
    super.dispose();
  }

  void _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  void _save() {
    if (_produtoController.text.isEmpty || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha produto e data')),
      );
      return;
    }
    widget.onSave(
      _produtoController.text,
      _selectedDate!,
      _categoriaController.text.isEmpty ? null : _categoriaController.text,
      _loteController.text.isEmpty ? null : _loteController.text,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Adicionar Validade', style: GoogleFonts.poppins()),
        backgroundColor: isDark ? const Color(0xFF1A1F2E) : const Color(0xFF1E88E5),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _produtoController,
              decoration: InputDecoration(
                labelText: 'Produto',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _categoriaController,
              decoration: InputDecoration(
                labelText: 'Categoria (opcional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _loteController,
              decoration: InputDecoration(
                labelText: 'Lote (opcional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _selectedDate == null
                            ? 'Selecione a data'
                            : DateFormat('dd/MM/yyyy').format(_selectedDate!),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              ),
              child: Text('Salvar', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
