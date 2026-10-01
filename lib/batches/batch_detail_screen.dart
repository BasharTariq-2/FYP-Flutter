import 'package:flutter/material.dart';

import '../../data/api_repository.dart';
import '../../widgets/ui.dart';

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
  final repo = ApiRepository();

  bool _loading = false;
  late Map<String, dynamic> _batch;

  @override
  void initState() {
    super.initState();
    _batch = Map<String, dynamic>.from(widget.batch);
  }

  int get batchId => int.tryParse('${_batch['batch_id']}') ?? 0;

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

  Future<void> _simpleAction(String title, Future<void> Function(int count, String text) action) async {
    final count = TextEditingController();
    final text = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppInput(controller: count, label: 'Hens Count', keyboardType: TextInputType.number),
            AppInput(controller: text, label: title.contains('Sell') ? 'Price Per Hen' : 'Reason / Notes'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _loading = true);
    try {
      final hensVal = int.tryParse(count.text.trim()) ?? 0;
      await action(hensVal, text.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));

      // Local state update for smooth presentation
      setState(() {
        if (title.contains('Isolate')) {
          final isolated = int.tryParse('${_batch['isolated_hens']}') ?? 0;
          final active = int.tryParse('${_batch['active_hens']}') ?? 0;
          _batch['isolated_hens'] = isolated + hensVal;
          _batch['active_hens'] = active - hensVal;
        } else if (title.contains('Sell')) {
          final sold = int.tryParse('${_batch['sold_hens']}') ?? 0;
          final active = int.tryParse('${_batch['active_hens']}') ?? 0;
          _batch['sold_hens'] = sold + hensVal;
          _batch['active_hens'] = active - hensVal;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _cullHens() async {
    final countCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    String selectedSource = 'active';

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
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
                controller: countCtrl,
                label: 'Hens Count',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              AppInput(
                controller: reasonCtrl,
                label: 'Reason / Notes',
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

    if (ok != true) return;
    setState(() => _loading = true);
    try {
      final hensCount = int.tryParse(countCtrl.text.trim()) ?? 0;
      await repo.cullBatch(
        batchId: batchId,
        hensCount: hensCount,
        reason: reasonCtrl.text.trim(),
        source: selectedSource,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Culling recorded')));

      setState(() {
        final culled = int.tryParse('${_batch['culled_hens']}') ?? 0;
        _batch['culled_hens'] = culled + hensCount;
        if (selectedSource == 'active') {
          final active = int.tryParse('${_batch['active_hens']}') ?? 0;
          _batch['active_hens'] = active - hensCount;
        } else {
          final isolated = int.tryParse('${_batch['isolated_hens']}') ?? 0;
          _batch['isolated_hens'] = isolated - hensCount;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _sellAllHensDialog() async {
    final priceCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
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
              controller: priceCtrl,
              label: 'Price per Hen',
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sell All')),
        ],
      ),
    );

    if (ok != true) return;

    final price = double.tryParse(priceCtrl.text.trim());
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final formattedDate = _formatDate(widget.selectedDate);

      // 1. If batch status is "Active", call ready-to-sell first to change status to Completed
      final status = _batch['status'] ?? 'Active';
      if (status.toString().toLowerCase() == 'active') {
        final readyRes = await repo.checkReadyToSell(batchId, formattedDate);
        if (readyRes == null) {
          throw Exception('Failed to set batch as ready to sell on backend.');
        }
      }

      // 2. Call sell-all
      await repo.sellAllHens(
        batchId: batchId,
        hensSold: 0,
        pricePerHen: price,
        saleDate: formattedDate,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Full batch sale recorded!')));

      setState(() {
        _batch['status'] = 'Completed';
        final active = int.tryParse('${_batch['active_hens']}') ?? 0;
        final sold = int.tryParse('${_batch['sold_hens']}') ?? 0;
        _batch['sold_hens'] = sold + active;
        _batch['active_hens'] = 0;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _showHistory(String title, Future<List<dynamic>> Function() loader) async {
    try {
      final list = await loader();
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: list.isEmpty
                ? const Text('No records')
                : SingleChildScrollView(
                    child: Column(
                      children: list.map((e) {
                        final row = Map<String, dynamic>.from(e);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            child: Text(row.entries.map((x) => '${x.key}: ${x.value}').join('\n')),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _batch;
    final ageInDays = _calculateAgeInDays(b['created_on'], widget.selectedDate);
    final ageFormatted = _getAgeAsOfSelectedDate(b['created_on'], widget.selectedDate);
    final isReady = ageInDays >= 28;

    return Scaffold(
      appBar: AppBar(
        title: Text('Batch #${pretty(b['batch_id'])}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Batch #${pretty(b['batch_id'])}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Text('Type: ${pretty(b['batch_type'])}'),
                      Text('Status: ${pretty(b['status'])}'),
                      Text('Total Hens: ${pretty(b['hen_count'])}'),
                      Text('Active Hens: ${pretty(b['active_hens'])}'),
                      Text('Isolated: ${pretty(b['isolated_hens'])}'),
                      Text('Culled: ${pretty(b['culled_hens'])}'),
                      Text('Sold: ${pretty(b['sold_hens'])}'),
                      Text('Created By: ${pretty(b['created_by'])}'),
                      Text('Created On: ${pretty(b['created_on'])}'),
                      Text('Shed ID: ${pretty(b['shed_id'])}'),
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
                const SizedBox(height: 14),
                PrimaryButton(
                  text: 'Isolate Hens',
                  onPressed: () => _simpleAction('Isolate Hens', (count, reason) {
                    return repo.isolateBatch(batchId: batchId, hensCount: count, reason: reason);
                  }),
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  text: 'Cull Hens',
                  onPressed: _cullHens,
                ),
                const SizedBox(height: 10),
                if (isReady)
                  PrimaryButton(
                    text: 'SELL ALL',
                    onPressed: _sellAllHensDialog,
                  )
                else
                  PrimaryButton(
                    text: 'SELL',
                    onPressed: () => _simpleAction('Sell Hens (Partial)', (count, price) {
                      return repo.sellHens(batchId: batchId, hensSold: count, pricePerHen: double.tryParse(price) ?? 0);
                    }),
                  ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => _showHistory('Isolation History', () => repo.isolationHistory(batchId)),
                  child: const Text('Isolation History'),
                ),
                OutlinedButton(
                  onPressed: () => _showHistory('Culling History', () => repo.cullingHistory(batchId)),
                  child: const Text('Culling History'),
                ),
                OutlinedButton(
                  onPressed: () => _showHistory('Hen Sales', () => repo.henSales(batchId)),
                  child: const Text('Hen Sales History'),
                ),
              ],
            ),
    );
  }
}