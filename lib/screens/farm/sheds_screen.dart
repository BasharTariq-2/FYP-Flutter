// lib/screens/farm/sheds_screen.dart

import 'package:flutter/material.dart';
import '../../services/shed_service.dart';
import '../../services/assignment_service.dart';
import '../../services/auth_service.dart';
import '../../models/assignment.dart';
import '../../models/shed_performance_summary.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import 'create_shed_screen.dart';

class ShedsScreen extends StatefulWidget {
  final Map<String, dynamic> farm;

  const ShedsScreen({super.key, required this.farm});

  @override
  State<ShedsScreen> createState() => _ShedsScreenState();
}

class _ShedsScreenState extends State<ShedsScreen> {
  final ShedService _shedService = ShedService();
  final AssignmentService _assignmentService = AssignmentService();
  final AuthService _authService = AuthService();

  List<dynamic> _sheds = [];
  Map<int, ShedAssignment?> _assignments = {};
  Map<String, dynamic>? _currentUser;
  bool _loading = true;
  String? _error;

  int get farmId => int.tryParse('${widget.farm['farm_id'] ?? widget.farm['id']}') ?? 0;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _loading = true);
    try {
      _currentUser = await _authService.getCurrentUser();
      await _loadSheds();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadSheds() async {
    try {
      final sheds = await _shedService.getShedsByFarm(farmId);
      final Map<int, ShedAssignment?> assignments = {};

      for (var shed in sheds) {
        final id = shed['shed_id'];
        assignments[id] = await _assignmentService.getShedManager(id);
      }

      setState(() {
        _sheds = sheds;
        _assignments = assignments;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool get isOwner => _currentUser?['role'] == 'Owner';

  Future<void> _showAssignDialog(int shedId, String shedName) async {
    final managers = await _authService.listManagers();
    if (!mounted) return;

    if (managers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No managers found. Please register a manager first.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign Manager to $shedName'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: managers.length,
            itemBuilder: (context, index) {
              final manager = managers[index];
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(manager['username']),
                subtitle: Text(manager['email']),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await _assignmentService.assignManager(shedId, manager['username']);
                    _loadSheds();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Manager assigned successfully')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _loadShedSummary() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final summaryList = await _shedService.getShedPerformanceSummary(farmId);
      if (mounted) Navigator.pop(context); // Close loading dialog

      if (!mounted) return;

      if (summaryList.isEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Shed Performance Summary'),
            content: const Text('No performance data available for this farm.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (context) => _buildSummaryDialog(summaryList),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading if open
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading summary: $e')),
      );
    }
  }

  Widget _buildSummaryDialog(List<ShedPerformanceSummary> summaries) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Shed Performance Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: summaries.length,
                itemBuilder: (context, index) {
                  final summary = summaries[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: summary.isTopPerformer
                          ? const BorderSide(color: Colors.amber, width: 2)
                          : BorderSide.none,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (summary.isTopPerformer) ...[
                                const Text('🏆 ', style: TextStyle(fontSize: 20)),
                              ],
                              Expanded(
                                child: Text(
                                  summary.shedName + (summary.isTopPerformer ? ' (Top Performer)' : ''),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: summary.isTopPerformer ? Colors.amber[800] : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildSummaryRow(Icons.layers_outlined, 'Batches', '${summary.batchCount} (${summary.activeBatchCount} active)'),
                          _buildSummaryRow(Icons.pets_outlined, 'Total Hens', '${summary.totalHens}, Active: ${summary.activeHens}'),
                          _buildSummaryRow(Icons.egg_outlined, 'Egg Sales', '${summary.eggSalesCount} eggs (Rs. ${summary.eggSalesAmount.toStringAsFixed(2)})'),
                          _buildSummaryRow(Icons.shopping_bag_outlined, 'Chicken Sales', '${summary.chickenSalesCount} hens (Rs. ${summary.chickenSalesAmount.toStringAsFixed(2)})'),
                          _buildSummaryRow(Icons.restaurant_outlined, 'Feed Used', '${summary.feedUsageKg.toStringAsFixed(2)} kg'),
                          _buildSummaryRow(Icons.warning_amber_rounded, 'Culling | Isolation', '${summary.cullingCount} | ${summary.isolationCount}'),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Revenue:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                'Rs. ${summary.salesRevenue.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sheds'),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Show Performance Summary',
            onPressed: () => _loadShedSummary(),
          ),
        ],
      ),
      floatingActionButton: isOwner ? FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateShedScreen(
                farmId: farmId,
                farmName: widget.farm['farm_name'] ?? 'Farm',
              ),
            ),
          ).then((_) => _loadSheds());
        },
        icon: const Icon(Icons.add),
        label: const Text('Shed'),
      ) : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _sheds.isEmpty
          ? const EmptyState('No sheds found')
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sheds.length,
        itemBuilder: (context, index) {
          final shed = _sheds[index];
          final shedId = shed['shed_id'];
          final assignment = _assignments[shedId];

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
                        shed['shed_name'] ?? 'Unknown',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (isOwner)
                        TextButton.icon(
                          onPressed: () => _showAssignDialog(shedId, shed['shed_name']),
                          icon: const Icon(Icons.person_add, size: 16),
                          label: Text(assignment == null ? 'Assign' : 'Change'),
                        ),
                    ],
                  ),
                  const Divider(),
                  Text('Capacity: ${shed['hens_capacity'] ?? 0} hens'),
                  Text('Active Batches: ${shed['no_of_batches'] ?? 0}'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.badge, size: 14, color: Colors.blue),
                        const SizedBox(width: 6),
                        Text(
                          assignment == null
                            ? 'No Manager Assigned'
                            : 'Manager: ${assignment.managerUsername}',
                          style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}