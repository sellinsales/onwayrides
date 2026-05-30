import 'package:flutter/material.dart';

import '../onway_mock_data.dart';
import '../onway_models.dart';
import '../onway_theme.dart';
import '../onway_widgets.dart';

class RiderHomeScreen extends StatelessWidget {
  const RiderHomeScreen({
    super.key,
    required this.services,
    required this.activeTrip,
    required this.onOpenBooking,
    required this.onOpenTracking,
  });

  final List<OnWayService> services;
  final ActiveTrip? activeTrip;
  final Future<void> Function([OnWayService? service]) onOpenBooking;
  final Future<void> Function([ActiveTrip? trip]) onOpenTracking;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BrandHeader(
                    caption: 'Where would you like to go today?',
                    trailing: CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white10,
                      child: Icon(Icons.notifications_none_rounded),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SearchFirstCard(onOpenBooking: onOpenBooking),
                  const SizedBox(height: 16),
                  _QuickIntentRow(
                    services: services,
                    onOpenBooking: onOpenBooking,
                  ),
                  const SizedBox(height: 24),
                  const SectionHeading(
                    title: 'Saved and recent places',
                    subtitle: 'Book faster from the places you use most.',
                  ),
                  const SizedBox(height: 14),
                  _PlaceShortcuts(
                    places: OnWayMockData.savedPlaces,
                    onTap: () => onOpenBooking(),
                  ),
                  const SizedBox(height: 12),
                  _RecentPlaceList(
                    places: OnWayMockData.recentPlaces,
                    onTap: () => onOpenBooking(),
                  ),
                  if (activeTrip != null) ...[
                    const SizedBox(height: 24),
                    SectionHeading(
                      title: 'Current trip',
                      subtitle: activeTrip!.statusLine,
                      action: TextButton(
                        onPressed: () => onOpenTracking(activeTrip),
                        child: const Text('Track'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _ActiveTripCard(
                      trip: activeTrip!,
                      onOpenTracking: onOpenTracking,
                    ),
                  ],
                  const SizedBox(height: 24),
                  const SectionHeading(
                    title: 'Popular ways to book',
                    subtitle: 'Choose the option that fits your trip best.',
                  ),
                  const SizedBox(height: 14),
                  _SuggestionStrip(
                    suggestions: OnWayMockData.riderContextualSuggestions,
                    onSelect: (serviceType) {
                      final service = services.firstWhere(
                        (item) => item.type == serviceType,
                        orElse: () => services.first,
                      );
                      onOpenBooking(service);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchFirstCard extends StatelessWidget {
  const _SearchFirstCard({required this.onOpenBooking});

  final Future<void> Function([OnWayService? service]) onOpenBooking;

  @override
  Widget build(BuildContext context) {
    return OnWayPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'One app for rides, rentals, and deliveries',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Start with your route and we will help you choose the right option for the trip.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          _SearchField(
            icon: Icons.my_location_rounded,
            title: 'Pickup',
            value: 'Current location',
            onTap: () => onOpenBooking(),
          ),
          const SizedBox(height: 10),
          _SearchField(
            icon: Icons.location_on_outlined,
            title: 'Destination',
            value: 'Where to?',
            emphasized: true,
            onTap: () => onOpenBooking(),
          ),
          const SizedBox(height: 10),
          _SearchField(
            icon: Icons.schedule_rounded,
            title: 'When',
            value: 'Now or schedule later',
            onTap: () => onOpenBooking(),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => onOpenBooking(),
            child: const Text('Search rides'),
          ),
        ],
      ),
    );
  }
}

class _QuickIntentRow extends StatelessWidget {
  const _QuickIntentRow({required this.services, required this.onOpenBooking});

  final List<OnWayService> services;
  final Future<void> Function([OnWayService? service]) onOpenBooking;

  @override
  Widget build(BuildContext context) {
    final primaryTypes = [
      ServiceType.rideShare,
      ServiceType.airport,
      ServiceType.courier,
      ServiceType.rentCar,
    ];

    final quickServices = primaryTypes
        .map(
          (type) => services.firstWhere(
            (service) => service.type == type,
            orElse: () => services.first,
          ),
        )
        .toList(growable: false);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: quickServices
          .map(
            (service) => ActionChip(
              avatar: Icon(service.icon, size: 18),
              label: Text(service.title),
              onPressed: () => onOpenBooking(service),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _PlaceShortcuts extends StatelessWidget {
  const _PlaceShortcuts({required this.places, required this.onTap});

  final List<OnWayPlaceSuggestion> places;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final place in places) ...[
            SizedBox(
              width: 156,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(20),
                child: Ink(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: OnWayTheme.charcoal,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0x29FFC107),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(place.icon, color: OnWayTheme.yellow),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        place.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        place.addressLine,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}

class _RecentPlaceList extends StatelessWidget {
  const _RecentPlaceList({required this.places, required this.onTap});

  final List<OnWayPlaceSuggestion> places;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: places
          .map(
            (place) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(20),
                child: Ink(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: OnWayTheme.charcoal,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(place.icon, color: OnWayTheme.yellow),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              place.addressLine,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (place.badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            place.badge!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ActiveTripCard extends StatelessWidget {
  const _ActiveTripCard({required this.trip, required this.onOpenTracking});

  final ActiveTrip trip;
  final Future<void> Function([ActiveTrip? trip]) onOpenTracking;

  @override
  Widget build(BuildContext context) {
    return OnWayPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.serviceTitle,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${trip.pickup} -> ${trip.destination}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x29FFC107),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  trip.fareLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: OnWayTheme.yellow),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white10,
                backgroundImage: trip.driver != null
                    ? AssetImage(trip.driver!.avatarAsset)
                    : null,
                child: trip.driver == null
                    ? const Icon(
                        Icons.support_agent_rounded,
                        color: OnWayTheme.yellow,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.driver?.name ??
                          'OnWay dispatch is assigning your driver',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trip.driver != null
                          ? '${trip.driver!.vehicle}\n${trip.driver!.eta}'
                          : 'Your booking is live in the dispatch queue.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonal(
                onPressed: () => onOpenTracking(trip),
                child: const Text('Open'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuggestionStrip extends StatelessWidget {
  const _SuggestionStrip({required this.suggestions, required this.onSelect});

  final List<OnWayContextualSuggestion> suggestions;
  final ValueChanged<ServiceType> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final suggestion in suggestions) ...[
            SizedBox(
              width: 250,
              child: OnWayPanel(
                backgroundColor: OnWayTheme.slate,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(suggestion.icon, color: OnWayTheme.yellow, size: 24),
                    const SizedBox(height: 12),
                    Text(
                      suggestion.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      suggestion.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: () => onSelect(suggestion.serviceType),
                      child: Text(suggestion.ctaLabel),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: emphasized ? Colors.white : OnWayTheme.slate,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: emphasized ? OnWayTheme.black : OnWayTheme.yellow,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: emphasized ? Colors.black54 : Colors.white60,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: emphasized ? OnWayTheme.black : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: emphasized ? OnWayTheme.black : Colors.white54,
            ),
          ],
        ),
      ),
    );
  }
}
