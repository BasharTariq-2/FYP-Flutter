import 'package:flutter/material.dart';
import '../../services/batch_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/app_input.dart';

class BatchDetailScreen extends StatefulWidget {
  final Map<String, dynamic> batch;
  final DateTime selectedDate;
  final bool isReadyToSell;

  const BatchDetailScreen({
    super.key,
    required this.batch,
    required this.selectedDate,
    required this.isReadyToSell,
  });

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen> {
  final BatchService _batchService = BatchService();

  late Map<String, dynamic> _batch;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _batch = widget.batch;
  }

  int get batchId => _batch['batch_id'] ?? 0;

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  int _calculateAgeInDays(String? createdOnStr, DateTime selectedDate) {
    if (createdOnStr == null) return 0;
    try {
      final created = DateTime.parse(createdOnStr);
      final date1 = DateTime(created.year, created.month, created.day);
      final date2 = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
      return date2.difference(date1).inDays;
    } catch (_) {
      return 0;
    }
  }

  String _getAgeAsOfSelectedDate(String? createdOnStr, DateTime selectedDate) {
    final diff = _calculateAgeInDays(createdOnStr, selectedDate);
    if (diff < 0) return '0w 0d';
    final weeks = diff ~/ 7;
    final days = diff % 7;
    return '${weeks}w ${days}d';
  }

  Future<void> _performAction(String title, Future<bool> Function() action) async {
    setState(() => _loading = true);
    try {
      final success = await action();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title completed successfully!')),
        );
        final updated = await _batchService.getBatchById(batchId);
        if (updated != null) {
          setState(() => _batch = updated);
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _isolateHens() async {
    final countController = TextEditingController();
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Isolate Hens'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppInput(
              controller: countController,
              label: 'Number of Hens',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            AppInput(
              controller: reasonController,
              label: 'Reason',
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Isolate')),
        ],
      ),
    );

    if (confirmed != true) return;

    final count = int.tryParse(countController.text);
    if (count == null || count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid number')),
      );
      return;
    }

    await _performAction(
      'Isolation',
      () => _batchService.isolateHens(batchId, count, reasonController.text),
    );
  }

  Future<void> _cullHens() async {
    final countController = TextEditingController();
    final reasonController = TextEditingController();
    String selectedSource = 'active';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Cull Hens'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedSource,
                decoration: InputDecoration(
                  labelText: 'Cull From',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'active',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                        SizedBox(width: 8),
                        Text('Active Batch'),
                      ],
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'isolated',
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                        SizedBox(width: 8),
                        Text('Isolated List'),
                      ],
                    ),
                  ),
                ],
                onChanged: (val) => setDialogState(() => selectedSource = val ?? 'active'),
              ),
              const SizedBox(height: 12),
              AppInput(
                controller: countController,
                label: 'Number of Hens',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              AppInput(
                controller: reasonController,
                label: 'Reason',
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cull')),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final count = int.tryParse(countController.text);
    if (count == null || count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid number')),
      );
      return;
    }

    await _performAction(
      'Culling',
      () => _batchService.cullHens(batchId, count, reasonController.text, source: selectedSource),
    );
  }

  Future<void> _sellHens() async {
    final countController = TextEditingController();
    final priceController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sell Hens (Partial)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppInput(
              controller: countController,
              label: 'Number of Hens',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            AppInput(
              controller: priceController,
              label: 'Price per Hen',
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sell')),
        ],
      ),
    );

    if (confirmed != true) return;

    final count = int.tryParse(countController.text);
    final price = double.tryParse(priceController.text);

    if (count == null || count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid number')),
      );
      return;
    }
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid price')),
      );
      return;
    }

    await _performAction(
      'Sale',
      () => _batchService.sellHens(batchId, count, price),
    );
  }

  Future<void> _sellAllHensDialog() async {
    final priceController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sell All Hens'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This will record a sale of all remaining hens in this batch.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            AppInput(
              controller: priceController,
              label: 'Price per Hen',
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sell All')),
        ],
      ),
    );

    if (confirmed != true) return;

    final price = double.tryParse(priceController.text);
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid price')),
      );
      return;
    }

    final formattedDate = _formatDate(widget.selectedDate);

    setState(() => _loading = true);
    try {
      // 1. If batch status is "Active", call ready-to-sell first to change status to Completed
      final status = _batch['status'] ?? 'Active';
      if (status.toString().toLowerCase() == 'active') {
        final readyRes = await _batchService.checkReadyToSell(batchId, formattedDate);
        if (readyRes == null) {
          throw Exception('Failed to set batch as ready to sell on backend.');
        }
      }

      // 2. Call sell-all
      final success = await _batchService.sellAllHens(
        batchId: batchId,
        hensSold: 0,
        pricePerHen: price,
        saleDate: formattedDate,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Full Batch Sale completed successfully!')),
        );
        final updated = await _batchService.getBatchById(batchId);
        if (updated != null) {
          setState(() => _batch = updated);
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ageInDays = _calculateAgeInDays(_batch['created_on'], widget.selectedDate);
    final ageFormatted = _getAgeAsOfSelectedDate(_batch['created_on'], widget.selectedDate);
    final isReady = ageInDays >= 28;

    return Scaffold(
      appBar: AppBar(title: Text('Batch #$batchId')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Batch #${_batch['batch_id']}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow('Type', _batch['batch_type']),
                        _buildInfoRow('Status', _batch['status']),
                        _buildInfoRow('Total Hens', _batch['hen_count']),
                        _buildInfoRow('Active Hens', _batch['active_hens']),
                        _buildInfoRow('Isolated', _batch['isolated_hens']),
                        _buildInfoRow('Culled', _batch['culled_hens']),
                        _buildInfoRow('Created By', _batch['created_by']),
                        _buildInfoRow('Created On', _batch['created_on']),
                        const SizedBox(height: 12),

                        if (isReady)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFA5D6A7)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Ready to Sell • Age: $ageFormatted • Tap SELL ALL to proceed',
                                    style: const TextStyle(
                                      color: Color(0xFF2E7D32),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFFB74D)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning, color: Color(0xFFE65100)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Not ready yet • Age: $ageFormatted • Need 4+ weeks',
                                    style: const TextStyle(
                                      color: Color(0xFFE65100),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    text: 'Isolate Hens',
                    onPressed: _isolateHens,
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    text: 'Cull Hens',
                    onPressed: _cullHens,
                  ),
                  const SizedBox(height: 12),
                  if (isReady)
                    PrimaryButton(
                      text: 'SELL ALL',
                      onPressed: _sellAllHensDialog,
                    )
                  else
                    PrimaryButton(
                      text: 'SELL',
                      onPressed: _sellHens,
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const Text(': '),
          Expanded(child: Text(value?.toString() ?? '-')),
        ],
      ),
    );
  }
}