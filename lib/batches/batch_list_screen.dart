import 'package:flutter/material.dart';

import '../../data/api_repository.dart';
import '../../widgets/ui.dart';
import 'batch_detail_screen.dart';

class BatchListScreen extends StatefulWidget {
  final DateTime? selectedDate;
  const BatchListScreen({super.key, this.selectedDate});

  @override
  State<BatchListScreen> createState() => _BatchListScreenState();
}

class _BatchListScreenState extends State<BatchListScreen> {
  final repo = ApiRepository();
  final TextEditingController _searchController = TextEditingController();
  bool loading = true;
  String? error;
  String _searchQuery = '';
  List<dynamic> sheds = [];
  List<dynamic> batches = [];
  Set<int> _readyToSellIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<dynamic> get _filteredBatches {
    if (_searchQuery.trim().isEmpty) return batches;
    final q = _searchQuery.trim().toLowerCase();
    return batches.where((batch) {
      final batchIdStr = (batch['batch_id'] ?? '').toString().toLowerCase();
      final batchTypeStr = (batch['batch_type'] ?? '').toString().toLowerCase();
      final statusStr = (batch['status'] ?? '').toString().toLowerCase();
      return batchIdStr.contains(q) || batchTypeStr.contains(q) || statusStr.contains(q);
    }).toList();
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _getAgeString(String? createdOnStr) {
    if (createdOnStr == null) return 'Unknown age';
    try {
      final created = DateTime.parse(createdOnStr);
      final today = DateTime.now();
      final diff = today.difference(created).inDays;
      if (diff < 0) return 'Future batch';
      final weeks = diff ~/ 7;
      final days = diff % 7;
      if (weeks == 0) return '$days d old';
      return '${weeks}w ${days}d old';
    } catch (_) {
      return 'Unknown age';
    }
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      // LOAD BATCHES
      batches = await repo.batches();

      // LOAD SHEDS FROM BACKEND
      sheds = await repo.sheds();

      // LOAD READY TO SELL IDS
      final selectedDateVal = widget.selectedDate ?? DateTime.now();
      final readyBatches = await repo.readyToSellBatches(
        _formatDate(selectedDateVal),
      );
      final Set<int> readyIds = {};
      for (final b in readyBatches) {
        final id = b['batch_id'];
        if (id != null) {
          readyIds.add(id is int ? id : int.tryParse(id.toString()) ?? 0);
        }
      }
      _readyToSellIds = readyIds;

      print(sheds);
    } catch (e) {
      error = e.toString();
      print(e);
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _add() async {
    final count = TextEditingController();

    String batchType = 'Free Range';
    int? selectedShedId;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Add Batch'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // SHED DROPDOWN
                DropdownButtonFormField<int>(
                  initialValue: selectedShedId,
                  decoration: const InputDecoration(
                    labelText: 'Select Shed',
                    border: OutlineInputBorder(),
                  ),
                  items: sheds.map<DropdownMenuItem<int>>((shed) {
                    return DropdownMenuItem<int>(
                      value: shed['shed_id'],
                      child: Text(
                        '${pretty(shed['shed_name'])} (ID: ${shed['shed_id']})',
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setLocal(() {
                      selectedShedId = value;
                    });
                  },
                ),

                const SizedBox(height: 14),

                // HEN COUNT
                AppInput(
                  controller: count,
                  label: 'Hen Count',
                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 14),

                // BATCH TYPE
                DropdownButtonFormField<String>(
                  initialValue: batchType,
                  decoration: const InputDecoration(
                    labelText: 'Batch Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Free Range',
                      child: Text('Free Range'),
                    ),
                    DropdownMenuItem(value: 'Caged', child: Text('Caged')),
                  ],
                  onChanged: (v) {
                    setLocal(() {
                      batchType = v ?? 'Free Range';
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    try {
      await repo.createBatch(
        shedId: selectedShedId ?? 0,
        henCount: int.tryParse(count.text.trim()) ?? 0,
        batchType: batchType,
      );

      await _load();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _open(Map<String, dynamic> batch) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BatchDetailScreen(
          batch: batch,
          selectedDate: widget.selectedDate ?? DateTime.now(),
          isReadyToSell: _readyToSellIds.contains(batch['batch_id']),
        ),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hen Batches')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Batch'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? ListView(
                padding: const EdgeInsets.all(18),
                children: [ErrorBox(message: error)],
              )
            : ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  // ── Search Bar ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search batch by number or type...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF0F7A6E)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.cancel_rounded, color: Colors.grey),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF0F7A6E), width: 1.8),
                        ),
                      ),
                    ),
                  ),

                  if (_readyToSellIds.isNotEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFA5D6A7)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF2E7D32),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${_readyToSellIds.length} batches ready to sell',
                              style: const TextStyle(
                                color: Color(0xFF2E7D32),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_filteredBatches.isEmpty)
                    EmptyState(_searchQuery.isNotEmpty ? 'No batches match "$_searchQuery"' : 'No batches found')
                  else
                    ..._filteredBatches.map((item) {
                      final batch = Map<String, dynamic>.from(item);
                      final int batchId =
                          int.tryParse(batch['batch_id'].toString()) ?? 0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppCard(
                          onTap: () => _open(batch),
                          child: Row(
                            children: [
                              const CircleAvatar(child: Icon(Icons.groups)),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Batch #$batchId',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                        if (_readyToSellIds.contains(batchId))
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE8F5E9),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: const Color(0xFFA5D6A7),
                                              ),
                                            ),
                                            child: const Text(
                                              'Ready to Sell',
                                              style: TextStyle(
                                                color: Color(0xFF2E7D32),
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    Text(
                                      '${pretty(batch['batch_type'])} • ${pretty(batch['status'])} • ${_getAgeString(batch['created_on'])}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    Text(
                                      'Hens: ${pretty(batch['hen_count'])} • Active: ${pretty(batch['active_hens'])} • Sold: ${pretty(batch['sold_hens'])}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                ],
              ),
      ),
    );
  }
}
