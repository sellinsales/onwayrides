import 'package:flutter/material.dart';

import '../onway_models.dart';
import '../onway_theme.dart';
import '../onway_widgets.dart';

class TripsScreen extends StatelessWidget {
  const TripsScreen({
    super.key,
    required this.activeTrip,
    required this.history,
    required this.onOpenTracking,
  });

  final ActiveTrip? activeTrip;
  final List<TripHistoryItem> history;
  final Future<void> Function([ActiveTrip? trip]) onOpenTracking;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
        children: [
          const BrandHeader(caption: 'Orders, rides and recurring bookings'),
          const SizedBox(height: 24),
          SectionHeading(
            title: 'Trips & orders',
            subtitle: 'Track live bookings and review recent activity.',
          ),
          const SizedBox(height: 16),
          if (activeTrip != null)
            OnWayPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x29FFC107),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Live now',
                          style: TextStyle(
                            color: OnWayTheme.yellow,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        activeTrip!.fareLabel,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    activeTrip!.serviceTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(activeTrip!.routeLine),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white10,
                        backgroundImage: AssetImage(
                          activeTrip!.driver.avatarAsset,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(activeTrip!.driver.name),
                            const SizedBox(height: 4),
                            Text(
                              activeTrip!.driver.vehicle,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () => onOpenTracking(activeTrip),
                        child: const Text('Track'),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            const OnWayPanel(
              child: Text(
                'No active booking yet. Start from Home to plan one.',
              ),
            ),
          const SizedBox(height: 24),
          SectionHeading(
            title: 'Recent activity',
            subtitle:
                'Rides, deliveries, airport and prebookings in one place.',
          ),
          const SizedBox(height: 14),
          for (final item in history) ...[
            OnWayPanel(
              padding: const EdgeInsets.all(16),
              backgroundColor: OnWayTheme.charcoal,
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.route_rounded,
                      color: OnWayTheme.yellow,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.dateLabel,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.route,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        item.amount,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.status,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: OnWayTheme.yellow,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
