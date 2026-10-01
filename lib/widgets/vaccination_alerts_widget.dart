import 'package:flutter/material.dart';
import '../services/vaccination_service.dart';
import 'app_card.dart';

class VaccinationAlertsWidget extends StatefulWidget {
  final int farmId;
  final int? shedId;
  final DateTime selectedDate;

  const VaccinationAlertsWidget({
    super.key,
    required this.farmId,
    this.shedId,
    required this.selectedDate,
  });

  @override
  State<VaccinationAlertsWidget> createState() => _VaccinationAlertsWidgetState();
}

class _VaccinationAlertsWidgetState extends State<VaccinationAlertsWidget> {
  final VaccinationService _vaccinationService = VaccinationService();

  List<dynamic> _dateAlerts = [];
  bool _loadingAlerts = false;
  String? _alertsError;

  @override
  void initState() {
    super.initState();
    _loadAlertsForDate();
  }

  @override
  void didUpdateWidget(covariant VaccinationAlertsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate) {
      _loadAlertsForDate();
    }
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _loadAlertsForDate() async {
    setState(() {
      _loadingAlerts = true;
      _alertsError = null;
    });
    try {
      final alerts = await _vaccinationService.getAlertsForDate(
        selectedDate: _formatDate(widget.selectedDate),
        shedId: widget.shedId,
      );
      setState(() => _dateAlerts = alerts);
    } catch (e) {
      setState(() => _alertsError = e.toString());
    } finally {
      setState(() => _loadingAlerts = false);
    }
  }

  Future<void> _markAsDone(Map<String, dynamic> item) async {
    final scheduleId = item['schedule_id'];
    if (scheduleId == null) return;
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
        await _loadAlertsForDate();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
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
                  Icon(Icons.vaccines, color: Color(0xFF0D9488)),
                  SizedBox(width: 8),
                  Text(
                    'Vaccination Alerts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _loadingAlerts ? null : _loadAlertsForDate,
                icon: const Icon(Icons.refresh, color: Color(0xFF0D9488), size: 20),
                tooltip: 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_loadingAlerts)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(color: Color(0xFF0D9488)),
              ),
            )
          else if (_alertsError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Text(
                _alertsError!,
                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
              ),
            )
          else if (_dateAlerts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No pending vaccinations for this date',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                ),
              ),
            )
          else
            ..._dateAlerts.map((alert) => _buildAlertCard(alert)),
        ],
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (alert['disease_name'] != null)
                      Text(
                        alert['disease_name'],
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  alert['status'] ?? 'Pending',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              if (alert['batch_id'] != null)
                _infoChip(Icons.tag, 'Batch #${alert['batch_id']}'),
              if (alert['batch_type'] != null)
                _infoChip(Icons.info_outline, alert['batch_type']),
              if (alert['hen_count'] != null)
                _infoChip(Icons.pets, 'Hens: ${alert['hen_count']}'),
              if (alert['method'] != null)
                _infoChip(Icons.healing, 'Method: ${alert['method']}'),
              if (alert['scheduled_date'] != null)
                _infoChip(Icons.event, 'Due: ${alert['scheduled_date']}'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton.icon(
              onPressed: () => _markAsDone(alert),
              icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
              label: const Text(
                'Mark Done',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }
}
