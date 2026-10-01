import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/api_repository.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------
class EggYieldRecord {
  final int yieldId;
  final int batchId;
  final String grade;
  final String? eggDate;
  int produced;
  final int sold;

  EggYieldRecord({
    required this.yieldId,
    required this.batchId,
    required this.grade,
    required this.eggDate,
    required this.produced,
    required this.sold,
  });

  factory EggYieldRecord.fromJson(Map<String, dynamic> j) {
    return EggYieldRecord(
      yieldId: j['yield_id'] as int,
      batchId: j['batch_id'] as int,
      grade: j['grade'] as String,
      eggDate: j['egg_date']?.toString(),
      produced: (j['produced'] as num).toInt(),
      sold: (j['sold'] as num).toInt(),
    );
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class EggDashboardScreen extends StatefulWidget {
  const EggDashboardScreen({super.key});

  @override
  State<EggDashboardScreen> createState() => _EggDashboardScreenState();
}

class _EggDashboardScreenState extends State<EggDashboardScreen>
    with SingleTickerProviderStateMixin {
  final repo = ApiRepository();
  final _picker = ImagePicker();

  List<dynamic> batches = [];
  int? selectedBatchId;

  File? selectedImage;
  Uint8List? gradedImageBytes; // annotated image from backend (base64 decoded)

  // Grade results from CV (A, B, C counts)
  Map<String, int> cvResults = {};
  String? crateQuality;

  // Yield records returned/fetched from backend
  List<EggYieldRecord> yieldRecords = [];

  // Edit controllers — keyed by grade letter
  final Map<String, TextEditingController> _editCtrl = {
    'A': TextEditingController(),
    'B': TextEditingController(),
    'C': TextEditingController(),
  };

  bool loading = false;
  bool editMode = false;
  String? errorMsg;
  String? successMsg;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _loadBatches();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    for (final c in _editCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  int? _getBatchId() {
    if (selectedBatchId == null) {
      _setError('Select a batch first');
      return null;
    }
    return selectedBatchId;
  }

  void _setError(String msg) =>
      setState(() { errorMsg = msg; successMsg = null; });

  void _setSuccess(String msg) =>
      setState(() { successMsg = msg; errorMsg = null; });

  void _clearMessages() =>
      setState(() { errorMsg = null; successMsg = null; });

  /// Find a yield record for a given grade from the current list.
  EggYieldRecord? _recordForGrade(String grade) {
    try {
      return yieldRecords.firstWhere((r) => r.grade == grade);
    } catch (_) {
      return null;
    }
  }

  /// Populate edit controllers from the current yield records (or CV results).
  void _populateEditControllers() {
    for (final grade in ['A', 'B', 'C']) {
      final rec = _recordForGrade(grade);
      _editCtrl[grade]!.text =
          (rec?.produced ?? cvResults[grade] ?? 0).toString();
    }
  }

  // -------------------------------------------------------------------------
  // Data loading
  // -------------------------------------------------------------------------

  Future<void> _loadBatches() async {
    try {
      final data = await repo.batches();
      setState(() => batches = data);
    } catch (e) {
      _setError(e.toString());
    }
  }

  // -------------------------------------------------------------------------
  // CV Grading
  // -------------------------------------------------------------------------

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    setState(() {
      selectedImage = File(image.path);
      gradedImageBytes = null;
      cvResults = {};
      yieldRecords = [];
      editMode = false;
    });
  }

  Future<void> _runGrading() async {
    final id = _getBatchId();
    if (id == null) return;
    if (selectedImage == null) {
      _setError('Pick an image first');
      return;
    }

    setState(() { loading = true; });
    _clearMessages();

    try {
      final res = await repo.gradeEggBase64(
        batchId: id,
        imagePath: selectedImage!.path,
      );

      // Parse annotated image
      final imageB64 = res['image'] as String?;
      if (imageB64 != null && imageB64.isNotEmpty) {
        gradedImageBytes = base64Decode(imageB64);
      }

      // Parse CV counts
      final rawResults = res['results'] as Map<String, dynamic>? ?? {};
      cvResults = {
        'A': (rawResults['A'] as num? ?? 0).toInt(),
        'B': (rawResults['B'] as num? ?? 0).toInt(),
        'C': (rawResults['C'] as num? ?? 0).toInt(),
      };
      crateQuality = res['crate_quality'] as String?;

      // Parse yields
      final rawYields = res['yields'] as List<dynamic>? ?? [];
      yieldRecords =
          rawYields.map((y) => EggYieldRecord.fromJson(y as Map<String, dynamic>)).toList();

      _populateEditControllers();
      _fadeCtrl.forward(from: 0);
      _setSuccess('Grading complete! Review and save counts below.');
      setState(() { editMode = false; });
    } catch (e) {
      _setError('Grading failed: $e');
    } finally {
      setState(() { loading = false; });
    }
  }

  // -------------------------------------------------------------------------
  // Save edited yields
  // -------------------------------------------------------------------------

  Future<void> _saveEdits() async {
    final id = _getBatchId();
    if (id == null) return;

    setState(() { loading = true; });
    _clearMessages();

    try {
      for (final grade in ['A', 'B', 'C']) {
        final newCount = int.tryParse(_editCtrl[grade]!.text.trim()) ?? 0;
        final existing = _recordForGrade(grade);

        if (existing != null) {
          // Update existing record via PATCH
          if (newCount < existing.sold) {
            _setError(
                'Grade $grade: produced ($newCount) cannot be less than already sold (${existing.sold})');
            setState(() { loading = false; });
            return;
          }
          await repo.updateEggYield(
            yieldId: existing.yieldId,
            produced: newCount,
          );
        } else if (newCount > 0) {
          // Create new record via POST
          await repo.createEggYield(
            batchId: id,
            grade: grade,
            produced: newCount,
          );
        }
      }

      // Refresh yield records from backend
      final fresh = await repo.eggYields(id);
      yieldRecords = fresh
          .map((y) => EggYieldRecord.fromJson(y as Map<String, dynamic>))
          .toList();
      _populateEditControllers();

      _setSuccess('Egg yield records saved successfully ✓');
      setState(() { editMode = false; });
    } catch (e) {
      _setError('Save failed: $e');
    } finally {
      setState(() { loading = false; });
    }
  }

  // -------------------------------------------------------------------------
  // UI helpers
  // -------------------------------------------------------------------------

  Color _gradeColor(String grade) {
    switch (grade) {
      case 'A': return const Color(0xFF4CAF50);
      case 'B': return const Color(0xFF2196F3);
      case 'C': return const Color(0xFFFF9800);
      default:  return Colors.grey;
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Egg Grading Dashboard'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          if (yieldRecords.isNotEmpty || cvResults.isNotEmpty)
            IconButton(
              icon: Icon(editMode ? Icons.close : Icons.edit_outlined),
              tooltip: editMode ? 'Cancel Edit' : 'Edit Counts',
              onPressed: () => setState(() {
                editMode = !editMode;
                if (editMode) _populateEditControllers();
              }),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildBatchSelector(theme),
          const SizedBox(height: 16),
          _buildImageSection(),
          const SizedBox(height: 16),
          _buildActionButtons(),
          if (errorMsg != null) ...[
            const SizedBox(height: 12),
            _buildBanner(errorMsg!, isError: true),
          ],
          if (successMsg != null) ...[
            const SizedBox(height: 12),
            _buildBanner(successMsg!, isError: false),
          ],
          if (cvResults.isNotEmpty || yieldRecords.isNotEmpty) ...[
            const SizedBox(height: 20),
            FadeTransition(
              opacity: _fadeAnim,
              child: editMode ? _buildEditPanel() : _buildResultsPanel(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBatchSelector(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: DropdownButtonFormField<int>(
          value: selectedBatchId,
          decoration: const InputDecoration(
            labelText: 'Select Batch',
            border: InputBorder.none,
            prefixIcon: Icon(Icons.grid_view_rounded, color: Color(0xFF1A237E)),
          ),
          items: batches.map((b) {
            return DropdownMenuItem<int>(
              value: b['batch_id'] as int,
              child: Text('Batch #${b['batch_id']}'),
            );
          }).toList(),
          onChanged: (val) => setState(() {
            selectedBatchId = val;
            yieldRecords = [];
            cvResults = {};
            gradedImageBytes = null;
            editMode = false;
          }),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    final hasAnnotated = gradedImageBytes != null;
    final hasSelected = selectedImage != null;

    return GestureDetector(
      onTap: _pickImage,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasAnnotated
              ? const Color(0xFF4CAF50)
              : const Color(0xFF1A237E).withValues(alpha: 0.3),
            width: 2,
          ),
          color: Colors.white,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: hasAnnotated
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(gradedImageBytes!, fit: BoxFit.contain),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Graded',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                )
              : hasSelected
                  ? Image.file(selectedImage!, fit: BoxFit.contain)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 56, color: Color(0xFF1A237E)),
                        SizedBox(height: 8),
                        Text('Tap to pick an egg image',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.photo_library_outlined,
            label: 'Pick Image',
            color: const Color(0xFF5C6BC0),
            onPressed: loading ? null : _pickImage,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            icon: Icons.auto_awesome,
            label: loading ? 'Grading…' : 'Run Grading',
            color: const Color(0xFF1A237E),
            loading: loading,
            onPressed: loading ? null : _runGrading,
          ),
        ),
      ],
    );
  }

  Widget _buildBanner(String msg, {required bool isError}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isError
            ? const Color(0xFFFFEBEE)
            : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError ? const Color(0xFFEF9A9A) : const Color(0xFFA5D6A7),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? Colors.red : Colors.green,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg,
                style: TextStyle(
                    color: isError
                        ? const Color(0xFFC62828)
                        : const Color(0xFF2E7D32),
                    fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildCrateBadge(String quality) {
    Color color;
    IconData icon;
    switch (quality) {
      case 'Excellent':
        color = const Color(0xFF2E7D32); // Green #2E7D32
        icon = Icons.verified_rounded;
        break;
      case 'Good':
        color = const Color(0xFFF57F17); // Orange #F57F17
        icon = Icons.thumb_up_rounded;
        break;
      case 'Average':
      default:
        color = const Color(0xFFD32F2F); // Red #D32F2F
        icon = Icons.info_rounded;
        break;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Text('📦 Crate Quality: ', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800, fontSize: 14)),
          Text(quality, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildResultsPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (crateQuality != null) _buildCrateBadge(crateQuality!),
        const Text('Grading Results',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Color(0xFF1A237E))),
        const SizedBox(height: 12),
        Row(
          children: ['A', 'B', 'C'].map((grade) {
            final rec = _recordForGrade(grade);
            final produced = rec?.produced ?? cvResults[grade] ?? 0;
            final sold = rec?.sold ?? 0;
            return Expanded(
              child: _GradeCard(
                grade: grade,
                produced: produced,
                sold: sold,
                color: _gradeColor(grade),
              ),
            );
          }).toList(),
        ),
        if (yieldRecords.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Yield Records',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xFF1A237E))),
          const SizedBox(height: 8),
          ...yieldRecords.map((r) => _YieldTile(record: r, color: _gradeColor(r.grade))),
        ],
      ],
    );
  }

  Widget _buildEditPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Edit Produced Counts',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Color(0xFF1A237E))),
        const SizedBox(height: 4),
        const Text(
          'You can adjust counts for each grade. '
          'Produced cannot fall below already-sold eggs.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        ...['A', 'B', 'C'].map((grade) {
          final rec = _recordForGrade(grade);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              controller: _editCtrl[grade],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Grade $grade — Produced',
                helperText: rec != null
                    ? 'Already sold: ${rec.sold}'
                    : 'No existing record',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                prefixIcon: CircleAvatar(
                  radius: 14,
                  backgroundColor: _gradeColor(grade),
                  child: Text(grade,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: loading ? null : _saveEdits,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined),
            label: Text(loading ? 'Saving…' : 'Save Changes'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool loading;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      onPressed: onPressed,
      icon: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Icon(icon, size: 18),
      label: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}

class _GradeCard extends StatelessWidget {
  final String grade;
  final int produced;
  final int sold;
  final Color color;

  const _GradeCard({
    required this.grade,
    required this.produced,
    required this.sold,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(right: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
        child: Column(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color,
              child: Text(grade,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
            ),
            const SizedBox(height: 10),
            Text('$produced',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: color)),
            Text('produced',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 4),
            Text('$sold sold',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _YieldTile extends StatelessWidget {
  final EggYieldRecord record;
  final Color color;

  const _YieldTile({required this.record, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Text(record.grade,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        title: Text('Grade ${record.grade}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            record.eggDate != null ? 'Date: ${record.eggDate}' : 'No date set'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${record.produced} produced',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            Text('${record.sold} sold',
                style:
                    const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}