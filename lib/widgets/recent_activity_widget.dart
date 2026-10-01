// lib/widgets/recent_activity_widget.dart

import 'package:flutter/material.dart';
import '../models/activity.dart';
import '../services/activity_service.dart';
import 'app_card.dart';
import 'package:intl/intl.dart';

class RecentActivityWidget extends StatefulWidget {
  const RecentActivityWidget({super.key});

  @override
  State<RecentActivityWidget> createState() => _RecentActivityWidgetState();
}

class _RecentActivityWidgetState extends State<RecentActivityWidget> {
  final ActivityService _service = ActivityService();
  late Future<List<ActivityLog>> _activitiesFuture;

  @override
  void initState() {
    super.initState();
    _activitiesFuture = _service.getRecentActivities(limit: 5);
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activities',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: () {
                  setState(() {
                    _activitiesFuture = _service.getRecentActivities(limit: 5);
                  });
                },
              ),
            ],
          ),
          const Divider(),
          FutureBuilder<List<ActivityLog>>(
            future: _activitiesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final logs = snapshot.data ?? [];
              if (logs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('No recent activities')),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: logs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _getIcon(log.actionType),
                    title: Text(log.description, style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      '${log.userAction} • ${DateFormat('MMM d, HH:mm').format(log.createdOn)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _getIcon(String actionType) {
    IconData icon;
    Color color;
    
    switch (actionType) {
      case 'SHED_CREATED': icon = Icons.home_work; color = Colors.blue; break;
      case 'BATCH_CREATED': icon = Icons.add_circle; color = Colors.green; break;
      case 'HENS_CULLED': icon = Icons.remove_circle; color = Colors.red; break;
      case 'HENS_SOLD': icon = Icons.sell; color = Colors.orange; break;
      case 'FEED_PURCHASED': icon = Icons.shopping_cart; color = Colors.purple; break;
      case 'FEED_USED': icon = Icons.grass; color = Colors.brown; break;
      case 'VACCINATION_DONE': icon = Icons.vaccines; color = Colors.teal; break;
      case 'EGG_GRADED': icon = Icons.egg; color = Colors.amber; break;
      default: icon = Icons.history; color = Colors.grey;
    }
    
    return CircleAvatar(
      radius: 16,
      backgroundColor: color.withOpacity(0.1),
      child: Icon(icon, size: 16, color: color),
    );
  }
}
