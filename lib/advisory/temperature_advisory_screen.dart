import 'package:flutter/material.dart';
import '../../widgets/ui.dart';

class TemperatureAdvisoryScreen extends StatelessWidget {
  const TemperatureAdvisoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final summerTips = [
      'Increase ventilation immediately',
      'Provide cool and fresh water',
      'Use fans or cooling pads',
      'Feed during cooler hours',
      'Reduce stocking density',
    ];

    final winterTips = [
      'Provide adequate heating',
      'Use dry bedding material',
      'Avoid direct cold drafts',
      'Increase energy-rich feed',
      'Keep ventilation balanced',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Temperature Advisory'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Summer Advisory',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                ...summerTips.map(
                      (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '• $e',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Winter Advisory',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                ...winterTips.map(
                      (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '• $e',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}