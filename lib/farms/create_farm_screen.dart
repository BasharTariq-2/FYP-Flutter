import 'package:flutter/material.dart';

import '../../data/api_repository.dart';
import '../../widgets/ui.dart';

class CreateFarmScreen extends StatefulWidget {
  const CreateFarmScreen({super.key});

  @override
  State<CreateFarmScreen> createState() => _CreateFarmScreenState();
}

class _CreateFarmScreenState extends State<CreateFarmScreen> {
  final repo = ApiRepository();
  final name = TextEditingController();
  final location = TextEditingController();
  final sheds = TextEditingController(text: '0');

  bool loading = false;
  String? error;

  Future<void> _save() async {
    if (name.text.trim().isEmpty || location.text.trim().isEmpty) {
      setState(() => error = 'Farm name and location required');
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      await repo.createFarm(
        farmName: name.text.trim(),
        location: location.text.trim(),
        noOfSheds: int.tryParse(sheds.text.trim()) ?? 0,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Farm'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          AppCard(
            child: Column(
              children: [
                ErrorBox(message: error),
                AppInput(controller: name, label: 'Farm Name'),
                AppInput(controller: location, label: 'Location'),
                AppInput(controller: sheds, label: 'Initial No. of Sheds', keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                PrimaryButton(text: 'Create Farm', loading: loading, onPressed: _save),
              ],
            ),
          ),
        ],
      ),
    );
  }
}