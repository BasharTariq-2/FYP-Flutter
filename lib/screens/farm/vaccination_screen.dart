import 'package:flutter/material.dart';
import '../../services/batch_service.dart';
import '../../services/vaccination_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/empty_state.dart';

class VaccinationScreen extends StatefulWidget {
  final int farmId;

  // Optional: pass a shed id if you want the "for-date" alerts filtered
  // to a specific shed. Leave null to show alerts for all sheds.
  final int? shedId;

  const VaccinationScreen({super.key, required this.farmId, this.shedId});

  @override
  State<VaccinationScreen> createState() => _VaccinationScreenState();
}

class _VaccinationScreenState extends State<VaccinationScreen> {
  final BatchService _batchService = BatchService();
  final VaccinationService _vaccinationService = VaccinationService();

  // ── Batch-wise schedule / history (existing feature) ──────────────
  List<dynamic> _batches = [];
  int? _selectedBatchId;
  List<dynamic> _schedule = [];
  List<dynamic> _records = [];
  bool _loadingBatches = true;
  bool _loadingData = false;
  String? _error;

  // ── Dashboard date-picker alerts (new feature) ─────────────────────
  DateTime _selectedDate = DateTime.now();
  List<dynamic> _dateAlerts = [];
  bool _loadingAlerts = false;
  String? _alertsError;

  @override
  void initState() {
    super.initState();
    _loadBatches();
    _loadAlertsForDate();
  }

  Future<void> _loadBatches() async {
    setState(() {
      _loadingBatches = true;
      _error = null;
    });
    try {
      final batches = await _batchService.getBatchesByFarm(widget.farmId);
      setState(() {
        _batches = batches;
        _loadingBatches = false;
        if (_batches.isNotEmpty) {
          _selectedBatchId = _batches.first['batch_id'];
          _loadData();
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingBatches = false;
      });
    }
  }

  Future<void> _loadData() async {
    if (_selectedBatchId == null) return;
    setState(() {
      _loadingData = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _vaccinationService.getSchedule(_selectedBatchId!),
        _vaccinationService.getRecords(_selectedBatchId!),
      ]);
      setState(() {
        _schedule = results[0];
        _records = results[1];
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loadingData = false);
    }
  }

  // ── New: date-picker driven alerts ─────────────────────────────────

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      await _loadAlertsForDate();
    }
  }

  Future<void> _loadAlertsForDate() async {
    setState(() {
      _loadingAlerts = true;
      _alertsError = null;
    });
    try {
      final alerts = await _vaccinationService.getAlertsForDate(
        selectedDate: _formatDate(_selectedDate),
        shedId: widget.shedId,
      );
      setState(() => _dateAlerts = alerts);
    } catch (e) {
      setState(() => _alertsError = e.toString());
    } finally {
      setState(() => _loadingAlerts = false);
    }
  }

  // ── Mark as done (shared by both sections) ──────────────────────────

  Future<void> _markAsDone(Map<String, dynamic> item) async {
    final scheduleId = item['schedule_id'];
    final hensController = TextEditingController();
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Vaccination'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Vaccine: ${item['vaccine_name'] ?? 'Dose ${item['dose_number']}'}'),
            const SizedBox(height: 12),
            TextField(
              controller: hensController,
              decoration: const InputDecoration(
                labelText: 'Number of hens vaccinated *',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (confirmed != true) return;

    final hens = int.tryParse(hensController.text);
    if (hens == null || hens <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid number of hens')),
      );
      return;
    }

    // administered_date defaults to the item's scheduled_date (or today
    // if unknown) — adjust here if you want a separate date field in the dialog.
    final administeredDate = item['scheduled_date'] ?? _formatDate(DateTime.now());

    final payload = {
      'hens_vaccinated': hens,
      'administered_date': administeredDate,
      if (notesController.text.trim().isNotEmpty) 'notes': notesController.text.trim(),
    };

    try {
      final success = await _vaccinationService.recordVaccination(scheduleId, payload);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vaccination recorded successfully!')),
        );
        await _loadData();
        await _loadAlertsForDate();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  List<dynamic> get _pendingSchedule {
    return _schedule.where((item) => item['status'] == 'Pending').toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vaccination Management')),
      body: _loadingBatches
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── NEW: Dashboard vaccination alerts (date picker) ────────
            _buildAlertsSection(),

            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 12),

            // ── Existing batch-wise schedule / history ─────────────────
            if (_batches.isEmpty)
              const EmptyState('No batches available')
            else ...[
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'Select Batch *',
                  border: OutlineInputBorder(),
                ),
                value: _selectedBatchId,
                items: _batches.map((batch) {
                  return DropdownMenuItem<int>(
                    value: batch['batch_id'],
                    child: Text('Batch #${batch['batch_id']}'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedBatchId = value);
                  _loadData();
                },
              ),
              const SizedBox(height: 24),
              if (_loadingData)
                const Center(child: CircularProgressIndicator())
              else ...[
                const Text(
                  'Pending Schedule',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (_pendingSchedule.isEmpty)
                  const Text('No pending vaccinations')
                else
                  ..._pendingSchedule.map((item) => _buildScheduleCard(item)),
                const SizedBox(height: 24),
                const Text(
                  'History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (_records.isEmpty)
                  const Text('No vaccination history')
                else
                  ..._records.map((record) => _buildRecordCard(record)),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // ── NEW: Alerts-for-date section ─────────────────────────────────────
  Widget _buildAlertsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vaccination Alerts',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Date picker button
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(_formatDate(_selectedDate)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _loadingAlerts ? null : _loadAlertsForDate,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (_loadingAlerts)
          const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: CircularProgressIndicator(),
          ))
        else if (_alertsError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(_alertsError!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
          )
        else if (_dateAlerts.isEmpty)
            const Text('No pending vaccinations for this date')
          else
            ..._dateAlerts.map((alert) => _buildAlertCard(alert)),
      ],
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
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
                        alert['vaccine_name'] ?? 'Unknown Vaccine',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (alert['disease_name'] != null)
                        Text(
                          alert['disease_name'],
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    alert['status'] ?? 'Pending',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (alert['batch_id'] != null)
                  Text('Batch #${alert['batch_id']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if (alert['batch_type'] != null)
                  Text(alert['batch_type'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if (alert['hen_count'] != null)
                  Text('Hens: ${alert['hen_count']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if (alert['method'] != null)
                  Text('Method: ${alert['method']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if (alert['scheduled_date'] != null)
                  Text('Due: ${alert['scheduled_date']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _markAsDone(alert),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Mark Done'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Existing widgets (batch schedule / history) ──────────────────────

  Widget _buildScheduleCard(Map<String, dynamic> item) {
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
                        item['vaccine_name'] ?? 'Unknown Vaccine',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Due: ${item['scheduled_date'] ?? 'N/A'}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Pending',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _markAsDone(item),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Mark Done'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              record['vaccine_name'] ?? 'Vaccine',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Date: ${record['administered_date'] ?? 'N/A'} | Hens: ${record['hens_vaccinated'] ?? 'N/A'}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}