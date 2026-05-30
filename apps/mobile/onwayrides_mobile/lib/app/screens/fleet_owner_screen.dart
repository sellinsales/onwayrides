import 'package:flutter/material.dart';

import '../onway_mock_data.dart';
import '../onway_theme.dart';
import '../onway_widgets.dart';

class FleetOwnerScreen extends StatelessWidget {
  const FleetOwnerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Business & Fleet')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const BrandHeader(
            caption: 'Manage drivers, vehicles, and daily business activity',
          ),
          const SizedBox(height: 20),
          OnWayPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ONW-LHR-0001',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 10),
                Text(
                  'Keep your team organized, your vehicles active, and your daily operations moving smoothly.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () =>
                            _showPendingAction(context, 'Add driver'),
                        child: const Text('Add driver'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            _showPendingAction(context, 'Add vehicle'),
                        child: const Text('Add vehicle'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Fleet health',
            subtitle: 'A quick view of rides, earnings, and team performance.',
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth > 760
                  ? (constraints.maxWidth - 48) / 4
                  : (constraints.maxWidth - 16) / 2;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final metric in OnWayMockData.fleetMetrics)
                    SizedBox(
                      width: width,
                      child: MetricTile(
                        label: metric.label,
                        value: metric.value,
                        delta: metric.delta,
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Drivers',
            subtitle: 'See who is active, available, and ready for trips.',
          ),
          const SizedBox(height: 14),
          for (final driver in OnWayMockData.fleetDrivers) ...[
            OnWayPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          driver.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Text(
                        driver.status,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: OnWayTheme.yellow,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('${driver.vehicle} | Rating ${driver.rating}'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final service in driver.services)
                        Chip(
                          label: Text(service),
                          backgroundColor: Colors.white10,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          const SectionHeading(
            title: 'Vehicles & assignment',
            subtitle: 'Match drivers to vehicles and keep records up to date.',
          ),
          const SizedBox(height: 14),
          for (final vehicle in OnWayMockData.fleetVehicles) ...[
            OnWayPanel(
              padding: const EdgeInsets.all(16),
              backgroundColor: OnWayTheme.charcoal,
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.directions_car_rounded,
                      color: OnWayTheme.yellow,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.type,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text('${vehicle.plate} | ${vehicle.assignedDriver}'),
                      ],
                    ),
                  ),
                  Text(
                    vehicle.status,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: OnWayTheme.yellow),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          const OnWayPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Keep your fleet ready',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 12),
                Text('Keep driver documents and renewals up to date.'),
                Text(
                  'Make sure inspections, permits, and vehicle details stay current.',
                ),
                Text(
                  'Review assignments, payouts, and support issues regularly.',
                ),
                Text('Strong fleet response helps riders trust the service.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPendingAction(BuildContext context, String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action will be available here soon.')),
    );
  }
}
