import 'package:flutter/material.dart';

import '../../data/api_repository.dart';
import '../../widgets/ui.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  final repo = ApiRepository();
  final batchId = TextEditingController();
  final weight = TextEditingController();
  final temp = TextEditingController();

  String? result;
  bool loading = false;

  int? _id() {
    final id = int.tryParse(batchId.text.trim());
    if (id == null || id <= 0) {
      setState(() => result = 'Enter valid Batch ID');
      return null;
    }
    return id;
  }

  Future<void> _init() async {
    final id = _id();
    if (id == null) return;

    setState(() => loading = true);
    try {
      final res = await repo.healthInit(id);
      setState(() => result = res.toString());
    } catch (e) {
      setState(() => result = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _assess() async {
    final id = _id();
    if (id == null) return;

    setState(() => loading = true);
    try {
      final res = await repo.assessHealth(
        batchId: id,
        weightGrams: double.tryParse(weight.text.trim()) ?? 0,
        temperatureC: double.tryParse(temp.text.trim()) ?? 0,
      );
      setState(() => result = res.toString());
    } catch (e) {
      setState(() => result = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chick Health Monitor'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          AppCard(
            child: Column(
              children: [
                AppInput(controller: batchId, label: 'Batch ID', keyboardType: TextInputType.number),
                AppInput(controller: weight, label: 'Weight grams', keyboardType: TextInputType.number),
                AppInput(controller: temp, label: 'Temperature C', keyboardType: TextInputType.number),
                PrimaryButton(text: 'Load Monitor Init', loading: loading, onPressed: _init),
                const SizedBox(height: 10),
                PrimaryButton(text: 'Assess Health', loading: loading, onPressed: _assess),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (result != null) AppCard(child: SelectableText(result!)),
        ],
      ),
    );
  }
}