import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/batch_service.dart';
import '../../services/egg_service.dart';
import '../../core/app_theme.dart';
import 'egg_grading_history_screen.dart';

class EggGradingScreen extends StatefulWidget {
  final int farmId;
  const EggGradingScreen({super.key, required this.farmId});

  @override
  State<EggGradingScreen> createState() => _EggGradingScreenState();
}

class _EggGradingScreenState extends State<EggGradingScreen> {
  final BatchService _batchService = BatchService();
  final EggService _eggService = EggService();

  List<dynamic> _batches = [];
  int? _selectedBatchId;
  File? _selectedImage;
  Map<String, dynamic>? _gradingResult;
  Uint8List? _annotatedImageBytes;
  bool _loadingBatches = true;
  bool _processing = false;
  String? _error;

  bool _isEditing = false;
  bool _saving = false;
  List<dynamic> _yields = [];

  // Matches the web version: only A, B, C — no "Broken" grade.
  Map<String, int> _originalAICounts = {'A': 0, 'B': 0, 'C': 0};

  final TextEditingController _editAController = TextEditingController();
  final TextEditingController _editBController = TextEditingController();
  final TextEditingController _editCController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  @override
  void dispose() {
    _editAController.dispose();
    _editBController.dispose();
    _editCController.dispose();
    super.dispose();
  }

  Future<void> _loadBatches() async {
    setState(() { _loadingBatches = true; _error = null; });
    try {
      final batches = await _batchService.getBatchesByFarm(widget.farmId);
      setState(() {
        _batches = batches;
        _loadingBatches = false;
        if (_batches.isNotEmpty) _selectedBatchId = _batches.first['batch_id'];
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loadingBatches = false; });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _gradingResult = null;
        _annotatedImageBytes = null;
        _yields = [];
        _isEditing = false;
        _error = null;
      });
    }
  }

  String _calculateCrateQuality(int cntA, int cntB, int cntC) {
    if (cntA >= cntB && cntA >= cntC && cntA > 0) {
      return "Excellent";
    } else if (cntB > cntA && cntB >= cntC) {
      return "Good";
    } else {
      return "Average";
    }
  }

  Future<void> _gradeEggs() async {
    if (_selectedBatchId == null) { setState(() => _error = 'Please select a batch'); return; }
    if (_selectedImage == null) { setState(() => _error = 'Please select an image'); return; }
    setState(() { _processing = true; _error = null; _gradingResult = null; _annotatedImageBytes = null; _isEditing = false; });
    try {
      final result = await _eggService.gradeEggsWithImage(batchId: _selectedBatchId!, imageFile: _selectedImage!);
      if (result != null && mounted) {
        final counts = result['results'] ?? {};
        final int cntA = counts['A'] ?? 0;
        final int cntB = counts['B'] ?? 0;
        final int cntC = counts['C'] ?? 0;
        final int total = cntA + cntB + cntC;

        Uint8List? bytes;
        final String? imgB64 = result['image'] ?? result['annotated_image_base64'];
        if (imgB64 != null && imgB64.isNotEmpty) {
          try {
            bytes = base64Decode(imgB64);
          } catch (_) {}
        }

        final crateQuality = result['crate_quality'] ?? _calculateCrateQuality(cntA, cntB, cntC);

        setState(() {
          _gradingResult = result;
          _gradingResult!['crate_quality'] = crateQuality;
          _annotatedImageBytes = bytes;
          _yields = result['yields'] ?? [];
          _isEditing = false;
          _originalAICounts = {'A': cntA, 'B': cntB, 'C': cntC};
          _editAController.text = cntA.toString();
          _editBController.text = cntB.toString();
          _editCController.text = cntC.toString();
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Egg grading completed! Quality: $crateQuality (A:$cntA B:$cntB C:$cntC)'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ));
      } else {
        setState(() => _error = 'Grading failed');
      }
    } catch (e) {
      setState(() => _error = 'Grading failed');
    } finally {
      setState(() => _processing = false);
    }
  }

  void _enterEditMode() {
    final counts = _gradingResult?['results'] ?? {};
    setState(() {
      _isEditing = true;
      _editAController.text = (counts['A'] ?? 0).toString();
      _editBController.text = (counts['B'] ?? 0).toString();
      _editCController.text = (counts['C'] ?? 0).toString();
    });
  }

  void _cancelEdit() {
    setState(() => _isEditing = false);
  }

  Future<void> _saveEdits() async {
    if (_selectedBatchId == null) return;
    final int newA = int.tryParse(_editAController.text.trim()) ?? 0;
    final int newB = int.tryParse(_editBController.text.trim()) ?? 0;
    final int newC = int.tryParse(_editCController.text.trim()) ?? 0;
    final Map<String, int> editValues = {'A': newA, 'B': newB, 'C': newC};
    final int totalDetected = (_originalAICounts['A'] ?? 0) + (_originalAICounts['B'] ?? 0) + (_originalAICounts['C'] ?? 0);
    final int newTotal = newA + newB + newC;
    if (newTotal != totalDetected) {
      setState(() => _error = 'Total must equal exactly $totalDetected eggs. You entered $newTotal.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final updatedYields = List<dynamic>.from(_yields);
      for (final grade in ['A', 'B', 'C']) {
        final newCount = editValues[grade]!;
        final existing = updatedYields.firstWhere((y) => y['grade'] == grade, orElse: () => null);
        if (existing != null) {
          final res = await _eggService.updateEggYieldWithResponse(existing['yield_id'], newCount);
          if (res == null) throw Exception('Failed to save corrections');
          if (newCount == 0) {
            updatedYields.remove(existing);
          } else {
            existing['produced'] = res['produced'];
          }
        } else if (newCount > 0) {
          final res = await _eggService.createEggYieldWithResponse(_selectedBatchId!, grade, newCount);
          if (res != null) {
            updatedYields.add({'yield_id': res['yield_id'], 'grade': res['grade'], 'produced': res['produced']});
          } else {
            throw Exception('Failed to save corrections');
          }
        }
      }

      final newQuality = _calculateCrateQuality(newA, newB, newC);

      setState(() {
        _yields = updatedYields;
        _gradingResult?['results'] = {'A': editValues['A'], 'B': editValues['B'], 'C': editValues['C']};
        _gradingResult?['crate_quality'] = newQuality;
        _isEditing = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Grading corrected successfully!'), backgroundColor: Colors.green));
    } catch (e) {
      setState(() => _error = 'Failed to save corrections');
    } finally {
      setState(() => _saving = false);
    }
  }

  int get _totalDetected => (_originalAICounts['A'] ?? 0) + (_originalAICounts['B'] ?? 0) + (_originalAICounts['C'] ?? 0);
  int get _totalEntered => (int.tryParse(_editAController.text.trim()) ?? 0) + (int.tryParse(_editBController.text.trim()) ?? 0) + (int.tryParse(_editCController.text.trim()) ?? 0);
  bool get _isValidTotal => _totalEntered == _totalDetected;

  // ── History navigation (mirrors the web app's History button) ──────────
  void _openHistory() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => EggGradingHistoryScreen(
        farmId: widget.farmId,
        batchId: _selectedBatchId,
      ),
    ));
  }

  Widget _buildCrateQualityBadge(String quality) {
    Color badgeColor;
    IconData icon;
    String description;

    switch (quality) {
      case 'Excellent':
        badgeColor = const Color(0xFF2E7D32); // Green #2E7D32
        icon = Icons.verified_rounded;
        description = 'Majority of eggs are Grade A';
        break;
      case 'Good':
        badgeColor = const Color(0xFFF57F17); // Orange #F57F17
        icon = Icons.thumb_up_rounded;
        description = 'Majority of eggs are Grade B';
        break;
      case 'Average':
      default:
        badgeColor = const Color(0xFFD32F2F); // Red #D32F2F
        icon = Icons.info_rounded;
        description = 'Majority of eggs are Grade C';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: badgeColor, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '📦 Crate Quality: ',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                    ),
                    Text(
                      quality,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: badgeColor),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
          'Egg Grading',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
        ),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: TextButton(
                onPressed: _openHistory,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: const Text('History', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
      body: _loadingBatches
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D9488)))
          : SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        child: Column(
          children: [
            // ── Main Card ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Batch Selector ─────────────────────────────────
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
                        onChanged: (value) => setState(() => _selectedBatchId = value),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Image Picker & Display ───────────────────────────
                  GestureDetector(
                    onTap: _pickImage,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 220,
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        border: Border.all(color: _annotatedImageBytes != null ? const Color(0xFF0D9488) : const Color(0xFFE5E7EB), width: 1.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: _annotatedImageBytes != null
                          ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(
                              _annotatedImageBytes!,
                              fit: BoxFit.contain,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D9488),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('Annotated', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      )
                          : _selectedImage == null
                          ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image_outlined, size: 52, color: Colors.grey.shade300),
                          const SizedBox(height: 10),
                          Text('Click to select egg image', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                        ],
                      )
                          : Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            _selectedImage!,
                            fit: BoxFit.contain,
                            height: double.infinity,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Grade Button ───────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_processing || _selectedBatchId == null || _selectedImage == null) ? null : _gradeEggs,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        disabledBackgroundColor: const Color(0xFFD1D5DB),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: _processing
                          ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                          SizedBox(width: 10),
                          Text('Grading...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                        ],
                      )
                          : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.upload_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text('Grade Eggs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                        ],
                      ),
                    ),
                  ),

                  // ── Results Section ────────────────────────────────
                  if (_gradingResult != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Crate Quality Badge
                          _buildCrateQualityBadge(_gradingResult!['crate_quality'] ?? 'Average'),

                          // Results header + edit controls
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Egg Grade Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF111827))),
                              if (!_isEditing)
                                GestureDetector(
                                  onTap: _enterEditMode,
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
                                      onTap: _saving ? null : (_isValidTotal ? _saveEdits : null),
                                      child: Row(
                                        children: [
                                          if (_saving)
                                            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D9488)))
                                          else
                                            Icon(Icons.save_outlined, size: 14, color: _isValidTotal ? Colors.green.shade600 : Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(_saving ? 'Saving...' : 'Save', style: TextStyle(color: _isValidTotal ? Colors.green.shade600 : Colors.grey, fontWeight: FontWeight.w600, fontSize: 13)),
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

                          const SizedBox(height: 14),

                          // Grade A, B, C — 3-column (matches web: no Broken)
                          Row(
                            children: [
                              _buildGradeCard(label: 'Grade A', count: _gradingResult?['results']?['A'] ?? 0, color: const Color(0xFF22C55E), controller: _editAController),
                              const SizedBox(width: 8),
                              _buildGradeCard(label: 'Grade B', count: _gradingResult?['results']?['B'] ?? 0, color: const Color(0xFFF59E0B), controller: _editBController),
                              const SizedBox(width: 8),
                              _buildGradeCard(label: 'Grade C', count: _gradingResult?['results']?['C'] ?? 0, color: const Color(0xFFEF4444), controller: _editCController),
                            ],
                          ),

                          // Edit info bar
                          if (_isEditing) ...[
                            const SizedBox(height: 12),
                            Container(
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
                                      const Text('Total detected:', style: TextStyle(fontSize: 13, color: Color(0xFF374151))),
                                      Text('$_totalDetected eggs', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1D4ED8))),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Total entered:', style: TextStyle(fontSize: 13, color: Color(0xFF374151))),
                                      Text(
                                        '$_totalEntered eggs',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _isValidTotal ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Center(
                              child: Text(
                                'Redistribute eggs across grades. Total cannot exceed detected amount.',
                                style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // ── Error ──────────────────────────────────────────
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Text(_error!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradeCard({
    required String label,
    required int count,
    required Color color,
    required TextEditingController controller,
  }) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                children: [
                  if (_isEditing)
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD1D5DB))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: color)),
                      ),
                    )
                  else
                    Text(count.toString(), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  const SizedBox(height: 6),
                  Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}