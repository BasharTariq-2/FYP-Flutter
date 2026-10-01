import 'package:flutter/material.dart';
import '../../services/shed_service.dart';
import '../../services/batch_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/app_input.dart';
import '../../widgets/error_box.dart';
import '../../core/constants.dart';
import '../../core/app_theme.dart';  // ✅ ADD THIS IMPORT

class CreateBatchScreen extends StatefulWidget {
  final int farmId;

  const CreateBatchScreen({super.key, required this.farmId});

  @override
  State<CreateBatchScreen> createState() => _CreateBatchScreenState();
}

class _CreateBatchScreenState extends State<CreateBatchScreen> {
  final ShedService _shedService = ShedService();
  final BatchService _batchService = BatchService();

  List<dynamic> _sheds = [];
  int? _selectedShedId;
  String _selectedBatchType = 'Caged';  // ✅ Default value instead of AppConstants
  final TextEditingController _henCountController = TextEditingController();

  bool _loadingSheds = true;
  bool _creating = false;
  String? _error;

  // ✅ Batch types list
  final List<String> _batchTypes = ['Caged', 'Free Range'];

  @override
  void initState() {
    super.initState();
    _loadSheds();
  }

  Future<void> _loadSheds() async {
    setState(() {
      _loadingSheds = true;
      _error = null;
    });

    try {
      final sheds = await _shedService.getShedsByFarm(widget.farmId);
      setState(() {
        _sheds = sheds;
        _loadingSheds = false;
        if (_sheds.isNotEmpty) {
          _selectedShedId = _sheds.first['shed_id'];
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingSheds = false;
      });
    }
  }

  Future<void> _createBatch() async {
    if (_selectedShedId == null) {
      setState(() => _error = 'Please select a shed');
      return;
    }

    final henCount = int.tryParse(_henCountController.text.trim());
    if (henCount == null || henCount <= 0) {
      setState(() => _error = 'Please enter valid hen count (minimum 1)');
      return;
    }

    if (henCount > 5000) {
      setState(() => _error = 'Hen count cannot exceed 5000 per batch');
      return;
    }

    setState(() {
      _creating = true;
      _error = null;
    });

    try {
      final batch = await _batchService.createBatch(
        shedId: _selectedShedId!,
        henCount: henCount,
        batchType: _selectedBatchType,
      );

      if (batch != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Batch created successfully!')),
        );
        Navigator.pop(context, true);
      } else {
        setState(() => _error = 'Failed to create batch');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Batch'),
      ),
      body: _loadingSheds
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AppCard(
              child: Column(
                children: [
                  const Icon(Icons.groups, size: 48, color: AppTheme.primary),
                  const SizedBox(height: 12),
                  const Text(
                    'Create New Batch',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  ErrorBox(message: _error),

                  // Shed Dropdown
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Select Shed *',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedShedId,
                    items: _sheds.map((shed) {
                      final shedId = shed['shed_id'];
                      final shedName = shed['shed_name'];
                      final capacity = shed['hens_capacity'];
                      return DropdownMenuItem<int>(
                        value: shedId,
                        child: Text('$shedName (Capacity: $capacity)'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedShedId = value);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Batch Type Dropdown
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Batch Type *',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedBatchType,
                    items: _batchTypes.map((type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedBatchType = value!);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Hen Count Input
                  AppInput(
                    controller: _henCountController,
                    label: 'Hen Count *',
                    hint: 'Number of hens (min 1, max 5000)',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),

                  PrimaryButton(
                    text: _creating ? 'Creating...' : 'Create Batch',
                    loading: _creating,
                    onPressed: _createBatch,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Batches can be Caged or Free Range. The system will automatically create vaccination schedules based on batch type.',
                      style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}