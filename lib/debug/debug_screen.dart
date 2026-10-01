import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/api_config.dart';
import '../../data/api_repository.dart';
import '../../widgets/ui.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final repo = ApiRepository();
  String output = 'No test yet.';
  bool loading = false;

  Future<void> _health() async {
    setState(() => loading = true);
    final ok = await ApiClient.pingHealth();
    setState(() {
      loading = false;
      output = ok ? 'Backend /health OK' : 'Backend /health failed';
    });
  }

  Future<void> _me() async {
    setState(() => loading = true);
    try {
      final res = await repo.me();
      setState(() => output = res.toString());
    } catch (e) {
      setState(() => output = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _farms() async {
    setState(() => loading = true);
    try {
      final res = await repo.farms();
      setState(() => output = res.toString());
    } catch (e) {
      setState(() => output = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Debug'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Current API Config', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                SelectableText('Base URL: ${ApiConfig.baseUrl}\nHealth URL: ${ApiConfig.healthUrl}'),
                const SizedBox(height: 16),
                PrimaryButton(text: 'Test /health', loading: loading, onPressed: _health),
                const SizedBox(height: 10),
                PrimaryButton(text: 'Test /users/me', loading: loading, onPressed: _me),
                const SizedBox(height: 10),
                PrimaryButton(text: 'Test /farms', loading: loading, onPressed: _farms),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(child: SelectableText(output)),
        ],
      ),
    );
  }
}