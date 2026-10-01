import 'package:flutter/material.dart';
import '../../services/farm_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/app_input.dart';
import '../../widgets/error_box.dart';

class CreateFarmScreen extends StatefulWidget {
  const CreateFarmScreen({super.key});

  @override
  State<CreateFarmScreen> createState() => _CreateFarmScreenState();
}

class _CreateFarmScreenState extends State<CreateFarmScreen> {
  final FarmService _farmService = FarmService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  bool _loading = false;
  String? _error;

  Future<void> _createFarm() async {
    if (_nameController.text.trim().isEmpty || _locationController.text.trim().isEmpty) {
      setState(() => _error = 'Please fill all fields');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _farmService.create(
        _nameController.text.trim(),
        _locationController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Farm created successfully!')),
        );
        Navigator.pop(context, true);
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
        title: const Text('Create New Farm'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AppCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text('🏠', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              const Text(
                'Create New Farm',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Fill in the details to create a new farm',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ErrorBox(message: _error),
              AppInput(
                controller: _nameController,
                label: 'Farm Name',
                hint: 'e.g., Green Valley Farm',
              ),
              const SizedBox(height: 16),
              AppInput(
                controller: _locationController,
                label: 'Location',
                hint: 'e.g., Abbottabad, Pakistan',
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                text: _loading ? 'Creating...' : 'Create Farm',
                loading: _loading,
                onPressed: _createFarm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}