import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/batch_service.dart';
import '../../widgets/empty_state.dart';
import 'create_batch_screen.dart';
import 'batch_detail_screen.dart';

class BatchesScreen extends StatefulWidget {
  final int farmId;
  final DateTime selectedDate;

  const BatchesScreen({super.key, required this.farmId, required this.selectedDate});

  @override
  State<BatchesScreen> createState() => _BatchesScreenState();
}

class _BatchesScreenState extends State<BatchesScreen> {
  final BatchService _batchService = BatchService();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _batches = [];
  Set<int> _readyToSellIds = {};
  bool _loading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<dynamic> get _filteredBatches {
    if (_searchQuery.trim().isEmpty) return _batches;
    final q = _searchQuery.trim().toLowerCase();
    return _batches.where((batch) {
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

  Future<void> _loadBatches() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final batches = await _batchService.getBatchesByFarm(widget.farmId);
      final readyBatches = await _batchService.getReadyToSellBatches(_formatDate(widget.selectedDate));

      final Set<int> readyIds = {};
      for (final b in readyBatches) {
        final id = b['batch_id'];
        if (id != null) {
          readyIds.add(id is int ? id : int.tryParse(id.toString()) ?? 0);
        }
      }

      setState(() {
        _batches = batches;
        _readyToSellIds = readyIds;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _editBatchDate(dynamic batch) async {
    DateTime initialDate = DateTime.now();
    if (batch['created_on'] != null) {
      try {
        initialDate = DateTime.parse(batch['created_on']);
      } catch (_) {}
    }
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F7A6E),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formattedDate = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {
        _loading = true;
      });
      try {
        final success = await _batchService.updateBatch(
          batch['batch_id'],
          {'created_on': formattedDate},
        );
        if (!mounted) return;
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Batch start date updated successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Failed to update batch start date')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        _loadBatches();
      }
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return const Color(0xFFE8F5E9); // Light Green
      case 'completed':
        return const Color(0xFFE3F2FD); // Light Blue
      case 'discarded':
        return const Color(0xFFFFEBEE); // Light Red
      default:
        return const Color(0xFFF5F5F5); // Light Grey
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return const Color(0xFF2E7D32); // Dark Green
      case 'completed':
        return const Color(0xFF1565C0); // Dark Blue
      case 'discarded':
        return const Color(0xFFC62828); // Dark Red
      default:
        return const Color(0xFF616161); // Dark Grey
    }
  }

  Widget _buildStatCol(String label, int value, Color valColor, Color labelColor) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: valColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: labelColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F7A6E),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Chicken Batches',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateBatchScreen(farmId: widget.farmId),
            ),
          ).then((_) => _loadBatches());
        },
        backgroundColor: const Color(0xFF0F7A6E),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Batch'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : Column(
                  children: [
                    // ── Search Bar ─────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
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
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        padding: const EdgeInsets.all(16),
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
                    Expanded(
                      child: _filteredBatches.isEmpty
                          ? EmptyState(_searchQuery.isNotEmpty ? 'No batches match "$_searchQuery"' : 'No batches found')
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredBatches.length,
                              itemBuilder: (context, index) {
                                final batch = _filteredBatches[index];
                                final String batchType = batch['batch_type'] ?? 'N/A';
                                final String status = batch['status'] ?? 'Active';
                                final int batchId = batch['batch_id'] ?? 0;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: Colors.grey.withValues(alpha: 0.1),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Row 1: Type + ID, Age, Status + Ready to Sell Badge
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        '$batchType Batch #$batchId',
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.black87,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        _getAgeString(batch['created_on']),
                                                        style: const TextStyle(
                                                          color: Colors.black54,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    if (_readyToSellIds.contains(batchId))
                                                      Container(
                                                        margin: const EdgeInsets.only(right: 8),
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFE8F5E9),
                                                          borderRadius: BorderRadius.circular(12),
                                                          border: Border.all(color: const Color(0xFFA5D6A7)),
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
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: _getStatusBgColor(status),
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Text(
                                                        status,
                                                        style: TextStyle(
                                                          color: _getStatusTextColor(status),
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            // Row 2: Stats Row
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                                              children: [
                                                _buildStatCol(
                                                  'Total',
                                                  batch['hen_count'] ?? 0,
                                                  Colors.black87,
                                                  Colors.black54,
                                                ),
                                                _buildStatCol(
                                                  'Active',
                                                  batch['active_hens'] ?? 0,
                                                  const Color(0xFF2E7D32),
                                                  const Color(0xFF2E7D32),
                                                ),
                                                _buildStatCol(
                                                  'Isolated',
                                                  batch['isolated_hens'] ?? 0,
                                                  const Color(0xFFD84315),
                                                  const Color(0xFFD84315),
                                                ),
                                                _buildStatCol(
                                                  'Culled',
                                                  batch['culled_hens'] ?? 0,
                                                  const Color(0xFFC62828),
                                                  const Color(0xFFC62828),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            // Row 3: Start Date + Edit Date Button
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'Batch start date',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.black54,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      batch['created_on'] ?? '-',
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                OutlinedButton(
                                                  onPressed: () => _editBatchDate(batch),
                                                  style: OutlinedButton.styleFrom(
                                                    side: const BorderSide(
                                                      color: Color(0xFFB2DFDB),
                                                    ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8,
                                                    ),
                                                    backgroundColor: const Color(0xFFE0F2F1),
                                                  ),
                                                  child: const Text(
                                                    'Edit Date',
                                                    style: TextStyle(
                                                      color: Color(0xFF0F7A6E),
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Bottom bar button: View batch details
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => BatchDetailScreen(
                                                batch: batch,
                                                selectedDate: widget.selectedDate,
                                                isReadyToSell: _readyToSellIds.contains(batchId),
                                              ),
                                            ),
                                          ).then((_) => _loadBatches());
                                        },
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8F9FA),
                                            borderRadius: const BorderRadius.only(
                                              bottomLeft: Radius.circular(16),
                                              bottomRight: Radius.circular(16),
                                            ),
                                            border: Border(
                                              top: BorderSide(
                                                color: Colors.grey.withValues(alpha: 0.1),
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: const Text(
                                            'View batch details',
                                            style: TextStyle(
                                              color: Colors.black54,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}