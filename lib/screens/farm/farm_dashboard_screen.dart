import 'package:flutter/material.dart';
import '../../widgets/app_card.dart';
import 'sheds_screen.dart';
import 'batches_screen.dart';
import 'feed_screen.dart';
import 'egg_stock_screen.dart';
import 'egg_grading_screen.dart';
import 'monitoring_screen.dart';
import 'vaccination_screen.dart';
import '../../widgets/vaccination_alerts_widget.dart';
import '../../widgets/isolation_recheck_alerts_widget.dart';
import '../../widgets/recent_activity_widget.dart';

class FarmDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> farm;

  const FarmDashboardScreen({super.key, required this.farm});

  @override
  State<FarmDashboardScreen> createState() => _FarmDashboardScreenState();
}

class _FarmDashboardScreenState extends State<FarmDashboardScreen> {
  DateTime _selectedDate = DateTime.now();

  int get farmId => int.tryParse('${widget.farm['farm_id'] ?? widget.farm['id']}') ?? 0;

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.farm['farm_name'] ?? 'Farm Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Farm Info Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.farm['farm_name'] ?? 'Farm',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Location: ${widget.farm['location'] ?? '-'}'),
                Text('Farm ID: $farmId'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Date Selector Card
          AppCard(
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Color(0xFF0D9488)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dashboard Date Context',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        _formatDate(_selectedDate),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: _pickDate,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0D9488)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Change Date',
                    style: TextStyle(
                      color: Color(0xFF0D9488),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Vaccination alerts widget
          VaccinationAlertsWidget(farmId: farmId, selectedDate: _selectedDate),
          const SizedBox(height: 16),

          IsolationRecheckAlertsWidget(
            farmId: farmId,
            selectedDate: _selectedDate,
          ),
          const SizedBox(height: 16),

          // Module Tiles
          _buildModuleTile(
            context,
            'Sheds',
            'Create and view farm sheds',
            Icons.home_work,
            ShedsScreen(farm: widget.farm),
          ),
          _buildModuleTile(
            context,
            'Hen Batches',
            'Create, update, isolate, cull and sell hens',
            Icons.groups,
            BatchesScreen(farmId: farmId, selectedDate: _selectedDate),
          ),
          _buildModuleTile(
            context,
            'Feed Management',
            'Stock, usage and purchase records',
            Icons.grass,
            FeedScreen(farmId: farmId),
          ),
          _buildModuleTile(
            context,
            'Egg Stock',
            'Egg yield and sales management',
            Icons.egg,
            EggStockScreen(farmId: farmId),
          ),
          _buildModuleTile(
            context,
            'Egg Grading',
            'CV grading with image upload',
            Icons.image_search,
            EggGradingScreen(farmId: farmId),
          ),
          _buildModuleTile(
            context,
            'Health Monitor',
            'Monitor sensor weight/temp health',
            Icons.health_and_safety,
            MonitoringScreen(farmId: farmId),
          ),
          _buildModuleTile(
            context,
            'Vaccination',
            'Schedule and record vaccinations',
            Icons.vaccines,
            VaccinationScreen(farmId: farmId),
          ),
          const SizedBox(height: 24),
          const RecentActivityWidget(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildModuleTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Widget screen,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
        child: Row(
          children: [
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
