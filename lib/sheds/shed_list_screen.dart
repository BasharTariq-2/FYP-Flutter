import 'package:flutter/material.dart';

import '../../data/api_repository.dart';
import '../../widgets/ui.dart';

class ShedListScreen extends StatefulWidget {
  final Map<String, dynamic> farm;

  const ShedListScreen({super.key, required this.farm});

  @override
  State<ShedListScreen> createState() => _ShedListScreenState();
}

class _ShedListScreenState extends State<ShedListScreen> {
  final repo = ApiRepository();
  bool loading = true;
  String? error;
  List<dynamic> sheds = [];

  int get farmId => int.tryParse('${widget.farm['farm_id']}') ?? 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      sheds = await repo.sheds(farmId: farmId);
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final cap = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Shed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppInput(controller: name, label: 'Shed Name'),
            AppInput(controller: cap, label: 'Hens Capacity', keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await repo.createShed(
        farmId: farmId,
        shedName: name.text.trim(),
        hensCapacity: int.tryParse(cap.text.trim()) ?? 0,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sheds'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Shed'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? ListView(padding: const EdgeInsets.all(18), children: [ErrorBox(message: error)])
                : sheds.isEmpty
                    ? ListView(padding: const EdgeInsets.all(18), children: const [EmptyState('No sheds found')])
                    : ListView(
                        padding: const EdgeInsets.all(18),
                        children: sheds.map((item) {
                          final shed = Map<String, dynamic>.from(item);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(pretty(shed['shed_name']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                                  Text('Capacity: ${pretty(shed['hens_capacity'])}'),
                                  Text('Batches: ${pretty(shed['no_of_batches'])}'),
                                  Text('Status: ${pretty(shed['status'])}'),
                                  Text('Shed ID: ${pretty(shed['shed_id'])}'),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
      ),
    );
  }
}