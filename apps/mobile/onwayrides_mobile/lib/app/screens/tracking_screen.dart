import 'package:flutter/material.dart';

import '../onway_models.dart';
import '../onway_theme.dart';
import '../onway_widgets.dart';

class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key, required this.trip});

  final ActiveTrip trip;

  void _showTodo(BuildContext context, String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action will connect to live APIs next.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live tracking')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Stack(
              children: [
                Image.asset(
                  'assets/showcase/rider_navigation.png',
                  height: 280,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.26),
                          Colors.black.withValues(alpha: 0.78),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.statusLine,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(trip.routeLine),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          OnWayPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Driver details', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white10,
                      backgroundImage: AssetImage(trip.driver.avatarAsset),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(trip.driver.name),
                          const SizedBox(height: 4),
                          Text(
                            '${trip.driver.vehicle}\n${trip.driver.plate} • ${trip.driver.distanceAway}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      trip.driver.rating,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: OnWayTheme.yellow,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _showTodo(context, 'Call'),
                        icon: const Icon(Icons.call_rounded),
                        label: const Text('Call'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showTodo(context, 'Chat'),
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                        label: const Text('Chat'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _showTodo(context, 'Cancel ride'),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cancel ride'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          OnWayPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Booking summary', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 14),
                _SummaryRow(label: 'Service', value: trip.serviceTitle),
                _SummaryRow(label: 'Pickup', value: trip.pickup),
                _SummaryRow(label: 'Destination', value: trip.destination),
                _SummaryRow(label: 'Payment', value: trip.paymentLabel),
                _SummaryRow(label: 'Fare', value: trip.fareLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
