import 'package:flutter/material.dart';
import '../../services/batch_service.dart';
import '../../services/feed_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/app_input.dart';
import '../../widgets/empty_state.dart';
import '../../core/constants.dart';
import '../../core/app_theme.dart';

class FeedScreen extends StatefulWidget {
  final int farmId;

  const FeedScreen({super.key, required this.farmId});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final FeedService _feedService = FeedService();
  final BatchService _batchService = BatchService();

  List<dynamic> _stock = [];
  List<dynamic> _purchases = [];
  List<dynamic> _usageHistory = [];
  List<dynamic> _batches = [];

  bool _loadingStock = true;
  bool _loadingUsage = false;
  bool _loadingPurchases = false;
  bool _addingUsage = false;
  bool _addingPurchase = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _loadStock();
    await _loadBatches();
    await _loadUsageHistory();
    await _loadPurchaseHistory();
  }

  Future<void> _loadStock() async {
    setState(() {
      _loadingStock = true;
      _error = null;
    });
    try {
      final stock = await _feedService.getStock(widget.farmId);
      if (mounted) {
        setState(() => _stock = stock);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loadingStock = false);
      }
    }
  }

  Future<void> _loadBatches() async {
    try {
      final batches = await _batchService.getBatchesByFarm(widget.farmId);
      if (mounted) {
        setState(() => _batches = batches);
      }
    } catch (e) {
      print('Error loading batches: $e');
    }
  }

  Future<void> _loadUsageHistory() async {
    if (_batches.isEmpty) return;

    setState(() => _loadingUsage = true);
    try {
      List<dynamic> allUsage = [];
      for (var batch in _batches) {
        final batchId = batch['batch_id'];
        final usage = await _feedService.getUsage(batchId);
        allUsage.addAll(usage);
      }
      if (mounted) {
        setState(() => _usageHistory = allUsage);
      }
    } catch (e) {
      print('Error loading usage: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingUsage = false);
      }
    }
  }

  Future<void> _loadPurchaseHistory() async {
    setState(() => _loadingPurchases = true);
    try {
      final purchases = await _feedService.getPurchases(widget.farmId);
      if (mounted) {
        setState(() => _purchases = purchases);
      }
    } catch (e) {
      print('Error loading purchases: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingPurchases = false);
      }
    }
  }

  Future<void> _addUsage() async {
    if (_batches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No batches available. Create a batch first.')),
      );
      return;
    }

    int? selectedBatchId;
    int selectedFeedType = 1;
    final quantityController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Feed Usage'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'Select Batch *',
                  border: OutlineInputBorder(),
                ),
                value: selectedBatchId,
                items: _batches.map((batch) {
                  return DropdownMenuItem<int>(
                    value: batch['batch_id'],
                    child: Text('Batch #${batch['batch_id']} - ${batch['batch_type']}'),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() => selectedBatchId = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'Feed Type *',
                  border: OutlineInputBorder(),
                ),
                value: selectedFeedType,
                items: AppConstants.feedTypes.map((feed) {
                  return DropdownMenuItem<int>(
                    value: feed['id'],
                    child: Text(feed['name']),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() => selectedFeedType = value!);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity (KG) *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedBatchId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a batch')),
                  );
                  return;
                }
                final quantity = double.tryParse(quantityController.text);
                if (quantity == null || quantity <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter valid quantity')),
                  );
                  return;
                }
                
                final stockItem = _stock.firstWhere(
                  (item) => item['feed_type_id'] == selectedFeedType,
                  orElse: () => null,
                );
                final availableStock = stockItem != null ? (stockItem['quantity_kg'] as num?)?.toDouble() ?? 0.0 : 0.0;
                if (quantity > availableStock) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Insufficient stock! Available: ${availableStock.toStringAsFixed(1)} KG')),
                  );
                  return;
                }
                
                Navigator.pop(ctx);
                setState(() => _addingUsage = true);
                try {
                  final success = await _feedService.recordUsage(
                    selectedBatchId!,
                    selectedFeedType,
                    quantity,
                  );
                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Feed usage recorded!')),
                    );
                    await _loadStock();
                    await _loadUsageHistory();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => _addingUsage = false);
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addPurchase() async {
    int selectedFeedType = 1;
    final quantityController = TextEditingController();
    final priceController = TextEditingController();
    final supplierController = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Feed Purchase'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(
                labelText: 'Feed Type *',
                border: OutlineInputBorder(),
              ),
              value: selectedFeedType,
              items: AppConstants.feedTypes.map((feed) {
                return DropdownMenuItem<int>(
                  value: feed['id'],
                  child: Text(feed['name']),
                );
              }).toList(),
              onChanged: (value) {
                selectedFeedType = value!;
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity (KG) *',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'Price per KG *',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: supplierController,
              decoration: const InputDecoration(
                labelText: 'Supplier (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final quantity = double.tryParse(quantityController.text);
              final price = double.tryParse(priceController.text);
              if (quantity == null || quantity <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter valid quantity')),
                );
                return;
              }
              if (price == null || price <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter valid price')),
                );
                return;
              }
              Navigator.pop(ctx);
              setState(() => _addingPurchase = true);
              try {
                final success = await _feedService.createPurchase(
                  widget.farmId,
                  selectedFeedType,
                  quantity,
                  price,
                  supplier: supplierController.text.isNotEmpty ? supplierController.text : null,
                );
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Purchase recorded!')),
                  );
                  await _loadStock();
                  await _loadPurchaseHistory();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _addingPurchase = false);
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _getFeedName(int? feedTypeId) {
    if (feedTypeId == 1) return 'Starter Feed';
    if (feedTypeId == 2) return 'Grower Feed';
    if (feedTypeId == 3) return 'Finisher Feed';
    return 'Unknown Feed';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Stock', icon: Icon(Icons.inventory)),
            Tab(text: 'Usage', icon: Icon(Icons.history)),
            Tab(text: 'Purchases', icon: Icon(Icons.shopping_cart)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStockTab(),
          _buildUsageHistoryTab(),
          _buildPurchaseHistoryTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: _addUsage,
            heroTag: 'usage',
            icon: const Icon(Icons.feed),
            label: const Text('Add Usage'),
            backgroundColor: Colors.blue,
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            onPressed: _addPurchase,
            heroTag: 'purchase',
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Add Purchase'),
            backgroundColor: Colors.green,
          ),
        ],
      )
          : null,
    );
  }

  Widget _buildStockTab() {
    if (_loadingStock) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_stock.isEmpty) {
      return const EmptyState('No feed stock found');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _stock.length,
      itemBuilder: (context, index) {
        final item = _stock[index];
        final feedTypeId = item['feed_type_id'];
        final feedName = _getFeedName(feedTypeId);
        final quantity = (item['quantity_kg'] as num?)?.toDouble() ?? 0.0;
        final maxCapacity = (item['max_capacity_kg'] as num?)?.toDouble() ?? 1000.0;
        final isLow = quantity < 100;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      feedName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (isLow)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Low Stock',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Stock: ${quantity.toStringAsFixed(1)} KG'),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (quantity / maxCapacity).clamp(0.0, 1.0),
                  backgroundColor: Colors.grey.shade200,
                  color: isLow ? Colors.red : Colors.green,
                ),
                const SizedBox(height: 4),
                Text(
                  '${((quantity / maxCapacity) * 100).toStringAsFixed(1)}% of capacity',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUsageHistoryTab() {
    if (_loadingUsage) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_usageHistory.isEmpty) {
      return const EmptyState('No feed usage records found');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _usageHistory.length,
      itemBuilder: (context, index) {
        final usage = _usageHistory[index];
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
                    Text(
                      _getFeedName(usage['feed_type_id']),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Batch #${usage['batch_id']}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Quantity: ${usage['quantity_used_kg']} KG'),
                Text('Date: ${usage['usage_date'] ?? 'N/A'}'),
                if (usage['recorded_by'] != null)
                  Text('Recorded by: ${usage['recorded_by']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPurchaseHistoryTab() {
    if (_loadingPurchases) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_purchases.isEmpty) {
      return const EmptyState('No purchase records found');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _purchases.length,
      itemBuilder: (context, index) {
        final purchase = _purchases[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getFeedName(purchase['feed_type_id']),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text('Quantity: ${purchase['quantity_kg']} KG'),
                Text('Price: PKR ${purchase['price_per_kg']}/KG'),
                Text('Total: PKR ${(purchase['quantity_kg'] * purchase['price_per_kg']).toStringAsFixed(2)}'),
                Text('Date: ${purchase['purchase_date'] ?? 'N/A'}'),
                if (purchase['supplier'] != null)
                  Text('Supplier: ${purchase['supplier']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }
}