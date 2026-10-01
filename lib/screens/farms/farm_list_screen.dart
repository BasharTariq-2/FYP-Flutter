import 'package:flutter/material.dart';
import '../../services/farm_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../core/session_store.dart';
import '../auth/login_screen.dart';
import '../farm/farm_dashboard_screen.dart';
import 'create_farm_screen.dart';

class FarmListScreen extends StatefulWidget {
  const FarmListScreen({super.key});

  @override
  State<FarmListScreen> createState() => _FarmListScreenState();
}

class _FarmListScreenState extends State<FarmListScreen> {
  final FarmService _farmService = FarmService();
  List<dynamic> _farms = [];
  bool _loading = true;
  String? _error;
  String _username = 'Farmer';

  @override
  void initState() {
    super.initState();
    _loadFarms();
  }

  Future<void> _loadFarms() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _farms = await _farmService.getAll();
      final user = await SessionStore.getUser();
      _username = user?['username'] ?? 'Farmer';
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await SessionStore.clear();
    if (mounted) {
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen())
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('My Farms'),
          actions: [
            IconButton(
                icon: const Icon(Icons.logout),
                onPressed: _logout
            )
          ]
      ),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateFarmScreen())
            ).then((_) => _loadFarms());
          },
          icon: const Icon(Icons.add),
          label: const Text('Farm')
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadFarms,
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : _farms.isEmpty
          ? EmptyState(
          'No farms found. Create your first farm.',
          onAction: () {
            Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateFarmScreen())
            ).then((_) => _loadFarms());
          },
          actionText: 'Create Farm'
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _farms.length,
        itemBuilder: (context, index) {
          final farm = _farms[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              onTap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => FarmDashboardScreen(farm: farm)
                    )
                );
              },
              child: Row(
                children: [
                  const CircleAvatar(
                    child: Icon(Icons.agriculture),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          farm['farm_name'] ?? 'Unknown',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                        Text(
                          farm['location'] ?? 'No location',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}