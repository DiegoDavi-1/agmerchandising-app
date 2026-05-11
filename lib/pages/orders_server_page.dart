import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../core/logging/app_logger_v2.dart';

class OrdersServerPage extends StatefulWidget {
  const OrdersServerPage({super.key});

  @override
  State<OrdersServerPage> createState() => _OrdersServerPageState();
}

class _OrdersServerPageState extends State<OrdersServerPage> {
  late Future<List<dynamic>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _ordersFuture = ApiService.getOrders();
  }

  void _refreshOrders() {
    setState(() {
      _ordersFuture = ApiService.getOrders();
    });
  }

  String _getStatusLabel(String status) {
    const labels = {
      'pending': 'Pendente',
      'approved': 'Aprovado',
      'rejected': 'Rejeitado',
      'completed': 'Concluído',
    };
    return labels[status] ?? status;
  }

  Color _getStatusColor(String status) {
    const colors = {
      'pending': Colors.orange,
      'approved': Colors.blue,
      'rejected': Colors.red,
      'completed': Colors.green,
    };
    return colors[status] ?? Colors.grey;
  }

  void _showCreateOrderDialog() {
    showDialog(
      context: context,
      builder: (context) => _CreateOrderDialog(
        onOrderCreated: _refreshOrders,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshOrders,
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            appLogger.error('Erro ao carregar pedidos', error: snapshot.error);
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text('Erro ao carregar pedidos'),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _refreshOrders,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            );
          }

          final orders = snapshot.data ?? [];

          return orders.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('Nenhum pedido encontrado'),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pedido #${order['id']}',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Marca ID: ${order['brand_id']}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getStatusColor(order['status']).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              _getStatusLabel(order['status']),
                              style: TextStyle(
                                color: _getStatusColor(order['status']),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (order['description'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          order['description'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (order['total_value'] != null)
                            Text(
                              'R\$ ${(order['total_value'] as num).toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          Text(
                            order['created_at']?.toString().split(' ')[0] ?? '',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateOrderDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CreateOrderDialog extends StatefulWidget {
  final VoidCallback onOrderCreated;

  const _CreateOrderDialog({required this.onOrderCreated});

  @override
  State<_CreateOrderDialog> createState() => _CreateOrderDialogState();
}

class _CreateOrderDialogState extends State<_CreateOrderDialog> {
  final _brandIdController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _totalValueController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _brandIdController.dispose();
    _descriptionController.dispose();
    _totalValueController.dispose();
    super.dispose();
  }

  Future<void> _createOrder() async {
    if (_brandIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID da marca é obrigatório')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.createOrder(
        brandId: int.parse(_brandIdController.text),
        description: _descriptionController.text,
        totalValue: _totalValueController.text.isNotEmpty
            ? double.parse(_totalValueController.text)
            : null,
      );

      if (result['success'] && mounted) {
        Navigator.pop(context);
        widget.onOrderCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pedido criado com sucesso!')),
        );
      }
    } catch (e) {
      appLogger.error('Erro ao criar pedido', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Criar Pedido'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _brandIdController,
              decoration: const InputDecoration(
                labelText: 'ID da Marca',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _totalValueController,
              decoration: const InputDecoration(
                labelText: 'Valor Total',
                border: OutlineInputBorder(),
                prefixText: 'R\$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createOrder,
          child: _isLoading
              ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Criar'),
        ),
      ],
    );
  }
}
