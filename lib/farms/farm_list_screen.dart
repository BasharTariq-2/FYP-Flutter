import 'package:flutter/material.dart';

import '../../core/session_store.dart';
import '../../data/api_repository.dart';
import '../../widgets/ui.dart';
import '../auth/login_screen.dart';
import '../debug/debug_screen.dart';
import 'create_farm_screen.dart';
import '../dashboard/dashboard_screen.dart';   // ✅ ADD THIS IMPORT

class FarmListScreen extends StatefulWidget {
  const FarmListScreen({super.key});

  @override
  State<FarmListScreen> createState() => _FarmListScreenState();
}

class _FarmListScreenState extends State<FarmListScreen> {
  final repo = ApiRepository();
  bool loading = true;
  String? error;
  List<dynamic> farms = [];
  String username = 'Farmer';

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
      username = await SessionStore.getUsername();
      farms = await repo.farms();
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _logout() async {
    await repo.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _createFarm() async {
    final created = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateFarmScreen()),
    );

    if (created == true) {
      _load();
    }
  }

  void _openFarm(Map<String, dynamic> farm) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DashboardScreen(farm: farm)), // ✅ now works
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Farms'),
        actions: [
          IconButton(
            tooltip: 'Debug API',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebugScreen())),
            icon: const Icon(Icons.bug_report),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createFarm,
        icon: const Icon(Icons.add),
        label: const Text('Farm'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? ListView(
          padding: const EdgeInsets.all(18),
          children: [
            ErrorBox(message: error),
            PrimaryButton(text: 'Retry', onPressed: _load),
          ],
        )
            : farms.isEmpty
            ? ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text('Welcome, $username', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 18),
            const EmptyState('No farms found. Create your first farm.'),
          ],
        )
            : ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text('Welcome, $username', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 18),
            ...farms.map((item) {
              final farm = Map<String, dynamic>.from(item);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  onTap: () => _openFarm(farm),
                  child: Row(
                    children: [
                      const CircleAvatar(child: Icon(Icons.agriculture)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(pretty(farm['farm_name']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                            Text(pretty(farm['location']), style: const TextStyle(color: Colors.black54)),
                            Text('Sheds: ${pretty(farm['no_of_sheds'])}', style: const TextStyle(color: Colors.black54)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}