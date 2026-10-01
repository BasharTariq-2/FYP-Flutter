import 'package:flutter/material.dart';
import '../../services/shed_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/app_input.dart';
import '../../widgets/error_box.dart';
import '../../core/app_theme.dart';
class CreateShedScreen extends StatefulWidget {
  final int farmId;
  final String farmName;

  const CreateShedScreen({
    super.key,
    required this.farmId,
    required this.farmName,
  });

  @override
  State<CreateShedScreen> createState() => _CreateShedScreenState();
}

class _CreateShedScreenState extends State<CreateShedScreen> {
  final ShedService _shedService = ShedService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();

  bool _loading = false;
  String? _error;

  Future<void> _createShed() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Please enter shed name');
      return;
    }

    final capacity = int.tryParse(_capacityController.text.trim());
    if (capacity == null || capacity <= 0) {
      setState(() => _error = 'Please enter valid capacity (minimum 1)');
      return;
    }

    if (capacity > 5000) {
      setState(() => _error = 'Capacity cannot exceed 5000 hens');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final success = await _shedService.createShed(
        farmId: widget.farmId,
        shedName: _nameController.text.trim(),
        hensCapacity: capacity,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shed created successfully!')),
        );
        Navigator.pop(context, true);
      } else {
        setState(() => _error = 'Failed to create shed');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Shed'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AppCard(
              child: Column(
                children: [
                  const Icon(Icons.home_work, size: 48, color: AppTheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    'Create Shed for ${widget.farmName}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ErrorBox(message: _error),
                  AppInput(
                    controller: _nameController,
                    label: 'Shed Name',
                    hint: 'e.g., Shed A, Broiler House 1',
                  ),
                  const SizedBox(height: 16),
                  AppInput(
                    controller: _capacityController,
                    label: 'Hens Capacity',
                    hint: 'Maximum number of hens (max 5000)',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    text: _loading ? 'Creating...' : 'Create Shed',
                    loading: _loading,
                    onPressed: _createShed,
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
                      'Each shed can have multiple batches. Capacity cannot exceed 5000 hens per shed.',
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