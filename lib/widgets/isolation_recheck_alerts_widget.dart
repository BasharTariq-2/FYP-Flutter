import 'package:flutter/material.dart';
import '../screens/farm/monitoring_screen.dart';
import '../services/isolation_service.dart';
import '../services/batch_service.dart';
import 'app_card.dart';

class IsolationRecheckAlertsWidget extends StatefulWidget {
  final int farmId;
  final DateTime selectedDate;

  const IsolationRecheckAlertsWidget({
    super.key,
    required this.farmId,
    required this.selectedDate,
  });

  @override
  State<IsolationRecheckAlertsWidget> createState() =>
      _IsolationRecheckAlertsWidgetState();
}

class _IsolationRecheckAlertsWidgetState
    extends State<IsolationRecheckAlertsWidget> {
  final IsolationService _isolationService = IsolationService();
  final BatchService _batchService = BatchService();

  bool _loading = false;
  String? _error;
  List<_BatchRecheckGroup> _overdueGroups = [];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  @override
  void didUpdateWidget(covariant IsolationRecheckAlertsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      _loadAlerts(showDialog: true);
    }
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatDisplayDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _loadAlerts({bool showDialog = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final farmBatches = await _batchService.getBatchesByFarm(widget.farmId);
      final farmBatchIds = farmBatches
          .map((b) => int.tryParse('${b['batch_id']}') ?? 0)
          .where((id) => id > 0)
          .toSet();

      final records = await _isolationService.getIsolatedGroups();
      final overdue = <_BatchRecheckGroup>[];
      final selectedDateOnly = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
      );

      final grouped = <int, List<_IsolationRecheckItem>>{};

      for (final record in records) {
        final batchId = int.tryParse('${record['batch_id']}') ?? 0;

        // Strictly filter alerts so only batches belonging to this farm are shown
        if (farmBatchIds.isNotEmpty && !farmBatchIds.contains(batchId)) {
          continue;
        }

        final isolatedOn = record['isolated_on']?.toString();
        if (isolatedOn == null || isolatedOn.isEmpty) {
          continue;
        }

        final isoDate = DateTime.tryParse(isolatedOn);
        if (isoDate == null) {
          continue;
        }

        final isoDateOnly = DateTime(isoDate.year, isoDate.month, isoDate.day);
        final days = selectedDateOnly.difference(isoDateOnly).inDays;
        if (days >= 7) {
          final isolationId = int.tryParse('${record['isolation_id']}') ?? 0;
          final hensCount = int.tryParse('${record['hens_count']}') ?? 0;
          final reason = record['reason']?.toString() ?? 'Isolation';
          grouped
              .putIfAbsent(batchId, () => [])
              .add(
                _IsolationRecheckItem(
                  isolationId: isolationId,
                  hensCount: hensCount,
                  reason: reason,
                  isolatedOn: isoDateOnly,
                  daysAgo: days,
                ),
              );
        }
      }

      grouped.forEach((batchId, items) {
        final totalChicks = items.fold<int>(
          0,
          (sum, item) => sum + item.hensCount,
        );
        overdue.add(
          _BatchRecheckGroup(
            batchId: batchId,
            totalChicks: totalChicks,
            items: items..sort((a, b) => a.isolatedOn.compareTo(b.isolatedOn)),
          ),
        );
      });

      overdue.sort((a, b) => a.batchId.compareTo(b.batchId));

      if (mounted) {
        setState(() => _overdueGroups = overdue);
      }

      if (showDialog && mounted && overdue.isNotEmpty) {
        _showAlertDialog(overdue);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showAlertDialog(List<_BatchRecheckGroup> groups) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(child: Text('Isolation Recheck Alert')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Isolated chick groups requiring recheck (${_formatDisplayDate(widget.selectedDate)}):',
                ),
                const SizedBox(height: 12),
                ...groups.map((group) => _buildDialogGroup(group)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Dismiss'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _navigateToMonitoring(groups.first);
              },
              child: const Text('Recheck Now'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToMonitoring(_BatchRecheckGroup group) {
    final firstItem = group.items.first;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MonitoringScreen(
          farmId: widget.farmId,
          preselectBatchId: group.batchId,
          preselectMode: 'isolated',
          preselectIsolationId: firstItem.isolationId,
        ),
      ),
    );
  }

  Widget _buildDialogGroup(_BatchRecheckGroup group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Batch #${group.batchId}: ${group.totalChicks} chick(s) isolated. Please recheck them.',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Text(
                    'Isolation Recheck Alert',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (_overdueGroups.isNotEmpty)
                ElevatedButton(
                  onPressed: () => _navigateToMonitoring(_overdueGroups.first),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Recheck Now'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(color: Colors.orange),
              ),
            )
          else if (_error != null)
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            )
          else if (_overdueGroups.isEmpty)
            const Text(
              'No isolated groups require rechecking for this date.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            )
          else
            ..._overdueGroups.map((group) => _buildGroupCard(group)),
        ],
      ),
    );
  }

  Widget _buildGroupCard(_BatchRecheckGroup group) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.healing_rounded, color: Colors.orange, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Batch #${group.batchId}: ${group.totalChicks} chick(s) isolated — recheck required.',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF9A3412),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BatchRecheckGroup {
  final int batchId;
  final int totalChicks;
  final List<_IsolationRecheckItem> items;

  _BatchRecheckGroup({
    required this.batchId,
    required this.totalChicks,
    required this.items,
  });
}

class _IsolationRecheckItem {
  final int isolationId;
  final int hensCount;
  final String reason;
  final DateTime isolatedOn;
  final int daysAgo;

  _IsolationRecheckItem({
    required this.isolationId,
    required this.hensCount,
    required this.reason,
    required this.isolatedOn,
    required this.daysAgo,
  });
}
