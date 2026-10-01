import 'package:flutter/material.dart';
import '../../widgets/ui.dart';
import '../advisory/temperature_advisory_screen.dart';
import '../batches/batch_list_screen.dart';
import '../eggs/egg_dashboard_screen.dart';
import '../feed/feed_screen.dart';
import '../health/health_screen.dart';
import '../sheds/shed_list_screen.dart';
import '../account/profile_menu_screen.dart';
import '../screens/farm/vaccination_screen.dart';
import '../widgets/vaccination_alerts_widget.dart';
import '../widgets/isolation_recheck_alerts_widget.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> farm;

  const DashboardScreen({super.key, required this.farm});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime _selectedDate = DateTime.now();

  int get farmId => int.tryParse('${widget.farm['farm_id']}') ?? 0;

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
    final title = '${widget.farm['farm_name'] ?? 'Farm'}';

    return Scaffold(
      drawer: const ProfileMenuScreen(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        title: Text(title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          // Farm Info Card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
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

          _tile(
            context,
            'Sheds',
            'Create and view farm sheds',
            Icons.home_work,
            ShedListScreen(farm: widget.farm),
          ),
          _tile(
            context,
            'Hen Batches',
            'Create, update, isolate, cull and sell hens',
            Icons.groups,
            BatchListScreen(selectedDate: _selectedDate),
          ),
          _tile(
            context,
            'Feed Management',
            'Stock, usage and purchase records',
            Icons.grass,
            FeedDashboardScreen(farmId: farmId),
          ),
          _tile(
            context,
            'Eggs Management',
            'Yield, sales and CV grading',
            Icons.egg_alt,
            const EggDashboardScreen(),
          ),
          _tile(
            context,
            'Chick Health',
            'Monitor sensor weight/temp health',
            Icons.health_and_safety,
            const HealthScreen(),
          ),
          _tile(
            context,
            'Vaccination Tracking',
            'Track upcoming, overdue and vaccination history',
            Icons.vaccines,
            VaccinationScreen(farmId: farmId),
          ),
          _tile(
            context,
            'Temperature Advisory',
            'Seasonal poultry tips',
            Icons.thermostat,
            const TemperatureAdvisoryScreen(),
          ),
        ],
      ),
    );
  }

  Widget _tile(
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
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  Text(subtitle, style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
