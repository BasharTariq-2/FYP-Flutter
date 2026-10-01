import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/batch_service.dart';
import '../../services/egg_service.dart';

class EggGradingHistoryScreen extends StatefulWidget {
  final int farmId;
  final int? batchId; // pre-selected batch, if navigated from a specific batch

  const EggGradingHistoryScreen({super.key, required this.farmId, this.batchId});

  @override
  State<EggGradingHistoryScreen> createState() => _EggGradingHistoryScreenState();
}

class _EggGradingHistoryScreenState extends State<EggGradingHistoryScreen> {
  final BatchService _batchService = BatchService();
  final EggService _eggService = EggService();

  List<dynamic> _batches = [];
  int? _selectedBatchId;
  List<dynamic> _history = [];
  bool _loadingBatches = true;
  bool _loadingHistory = false;

  int? _editingId;
  Map<String, int> _editValues = {'A': 0, 'B': 0, 'C': 0};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedBatchId = widget.batchId;
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    setState(() => _loadingBatches = true);
    try {
      final batches = await _batchService.getBatchesByFarm(widget.farmId);
      setState(() {
        _batches = batches;
        _loadingBatches = false;
      });
    } catch (_) {
      setState(() => _loadingBatches = false);
    }
    if (_selectedBatchId != null) _loadHistory();
  }

  Future<void> _loadHistory() async {
    final batchId = _selectedBatchId;
    if (batchId == null) {
      setState(() { _history = []; _loadingHistory = false; });
      return;
    }
    setState(() { _loadingHistory = true; _editingId = null; });
    try {
      final data = await _eggService.getBatchGradingHistory(batchId);
      if (!mounted) return;
      setState(() { _history = data; _loadingHistory = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _history = []; _loadingHistory = false; });
      _snack('Failed to load grading history');
    }
  }

  void _onBatchChange(int? value) {
    setState(() => _selectedBatchId = value);
    _loadHistory();
  }

  void _enterEdit(Map<String, dynamic> item) {
    setState(() {
      _editingId = item['grading_image_id'];
      _editValues = {
        'A': item['grade_a'] ?? 0,
        'B': item['grade_b'] ?? 0,
        'C': item['grade_c'] ?? 0,
      };
    });
  }

  void _cancelEdit() {
    setState(() => _editingId = null);
  }

  int _totalOriginal(Map<String, dynamic> item) =>
      (item['grade_a'] as int? ?? 0) + (item['grade_b'] as int? ?? 0) + (item['grade_c'] as int? ?? 0);

  int get _totalEntered => (_editValues['A'] ?? 0) + (_editValues['B'] ?? 0) + (_editValues['C'] ?? 0);

  Future<void> _saveEdit(Map<String, dynamic> item) async {
    final totalOriginal = _totalOriginal(item);
    final totalNew = _totalEntered;

    if (totalNew != totalOriginal) {
      _snack('Total must equal exactly $totalOriginal eggs. You entered $totalNew.');
      return;
    }

    setState(() => _saving = true);
    try {
      final res = await _eggService.updateGradingImage(
        item['grading_image_id'],
        gradeA: _editValues['A']!,
        gradeB: _editValues['B']!,
        gradeC: _editValues['C']!,
      );
      if (res == null) throw Exception('Failed to save corrections');

      setState(() {
        final idx = _history.indexWhere((h) => h['grading_image_id'] == item['grading_image_id']);
        if (idx != -1) {
          _history[idx] = {
            ..._history[idx],
            'grade_a': res['grade_a'],
            'grade_b': res['grade_b'],
            'grade_c': res['grade_c'],
          };
        }
        _editingId = null;
      });
      _snack('✅ Grading corrected successfully!', success: true);
    } catch (e) {
      _snack('Failed to save corrections');
    } finally {
      setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? Colors.green : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0D9488)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Egg Grading History',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
        ),
        centerTitle: false,
      ),
      body: _loadingBatches
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D9488)))
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Batch Selector Card ─────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Batch', style: TextStyle(fontSize: 14, color: Color(0xFF374151), fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFD1D5DB)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedBatchId,
                      hint: const Text('-- Select Batch --', style: TextStyle(color: Color(0xFF9CA3AF))),
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
                      items: _batches.map((batch) {
                        return DropdownMenuItem<int>(
                          value: batch['batch_id'],
                          child: Text('Batch #${batch['batch_id']} - ${batch['batch_type'] ?? 'N/A'}'),
                        );
                      }).toList(),
                      onChanged: _onBatchChange,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Content states ───────────────────────────────────────
          if (_selectedBatchId == null)
            _infoCard(icon: Icons.history, text: 'Select a batch to view its grading history.')
          else if (_loadingHistory)
            _infoCard(text: 'Loading history...')
          else if (_history.isEmpty)
              _infoCard(icon: Icons.history, text: 'No grading history found for this batch yet.')
            else
              ..._history.asMap().entries.map((entry) => _buildHistoryCard(entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _infoCard({IconData? icon, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 36, color: Colors.grey.shade300),
            const SizedBox(height: 12),
          ],
          Text(text, style: TextStyle(color: Colors.grey.shade500), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  String _getCrateQuality(Map<String, dynamic> item) {
    if (item['crate_quality'] != null && item['crate_quality'].toString().isNotEmpty) {
      return item['crate_quality'].toString();
    }
    final int a = item['grade_a'] as int? ?? 0;
    final int b = item['grade_b'] as int? ?? 0;
    final int c = item['grade_c'] as int? ?? 0;
    if (a >= b && a >= c && a > 0) return 'Excellent';
    if (b > a && b >= c) return 'Good';
    return 'Average';
  }

  Widget _buildCrateBadge(String quality) {
    Color color;
    IconData icon;
    switch (quality) {
      case 'Excellent':
        color = const Color(0xFF2E7D32); // #2E7D32
        icon = Icons.verified_rounded;
        break;
      case 'Good':
        color = const Color(0xFFF57F17); // #F57F17
        icon = Icons.thumb_up_rounded;
        break;
      case 'Average':
      default:
        color = const Color(0xFFD32F2F); // #D32F2F
        icon = Icons.info_rounded;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            quality,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(int index, Map<String, dynamic> item) {
    final bool isEditing = _editingId == item['grading_image_id'];
    final String crateQuality = _getCrateQuality(item);

    // Prefer annotated image, fall back to raw image, matching the web logic.
    final String? annotatedB64 = item['annotated_image_base64'];
    final String? rawB64 = item['image_base64'];
    final String? imageB64 = (annotatedB64 != null && annotatedB64.isNotEmpty)
        ? annotatedB64
        : (rawB64 != null && rawB64.isNotEmpty ? rawB64 : null);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Crate Quality Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Grading #${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                  const SizedBox(height: 2),
                  Text(item['created_at']?.toString() ?? 'Unknown date', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                ],
              ),
              _buildCrateBadge(crateQuality),
            ],
          ),

          const SizedBox(height: 12),

          // Image
          Container(
            width: double.infinity,
            height: 200,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: imageB64 != null
                ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(base64Decode(imageB64), fit: BoxFit.contain),
            )
                : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_outlined, size: 40, color: Colors.grey.shade300),
                  const SizedBox(height: 6),
                  Text('No image available', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Results header + edit controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Results', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF111827))),
              if (!isEditing)
                GestureDetector(
                  onTap: () => _enterEdit(item),
                  child: const Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 14, color: Color(0xFF0D9488)),
                      SizedBox(width: 4),
                      Text('Edit', style: TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    GestureDetector(
                      onTap: _saving ? null : () => _saveEdit(item),
                      child: Row(
                        children: [
                          if (_saving)
                            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D9488)))
                          else
                            Icon(Icons.save_outlined, size: 14, color: Colors.green.shade600),
                          const SizedBox(width: 4),
                          Text(_saving ? 'Saving...' : 'Save', style: TextStyle(color: Colors.green.shade600, fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: _saving ? null : _cancelEdit,
                      child: const Row(
                        children: [
                          Icon(Icons.close_rounded, size: 14, color: Color(0xFF9CA3AF)),
                          SizedBox(width: 4),
                          Text('Cancel', style: TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Grade A, B, C
          Row(
            children: [
              _gradeCell(label: 'Grade A', value: item['grade_a'] ?? 0, color: const Color(0xFF22C55E), grade: 'A', isEditing: isEditing),
              const SizedBox(width: 8),
              _gradeCell(label: 'Grade B', value: item['grade_b'] ?? 0, color: const Color(0xFFF59E0B), grade: 'B', isEditing: isEditing),
              const SizedBox(width: 8),
              _gradeCell(label: 'Grade C', value: item['grade_c'] ?? 0, color: const Color(0xFFEF4444), grade: 'C', isEditing: isEditing),
            ],
          ),

          if (isEditing) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total original:', style: TextStyle(fontSize: 13, color: Color(0xFF374151))),
                      Text('${_totalOriginal(item)} eggs', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1D4ED8))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total entered:', style: TextStyle(fontSize: 13, color: Color(0xFF374151))),
                      Text('$_totalEntered eggs', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1D4ED8))),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _gradeCell({
    required String label,
    required int value,
    required Color color,
    required String grade,
    required bool isEditing,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border(top: BorderSide(color: color, width: 4)),
        ),
        child: Column(
          children: [
            if (isEditing)
              TextFormField(
                initialValue: (_editValues[grade] ?? value).toString(),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: color)),
                ),
                onChanged: (v) {
                  final num = v.isEmpty ? 0 : (int.tryParse(v) ?? 0);
                  setState(() => _editValues[grade] = num < 0 ? 0 : num);
                },
              )
            else
              Text(value.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }
}