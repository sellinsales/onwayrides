import 'package:flutter/material.dart';

import '../onway_map.dart';
import '../onway_mock_data.dart';
import '../onway_models.dart';
import '../onway_theme.dart';

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
    final mediaSize = MediaQuery.sizeOf(context);
    final markers = _markersForHome();
    final route =
        activeTrip?.pickupCoordinate != null &&
            activeTrip?.destinationCoordinate != null
        ? buildRoutePath(
            activeTrip!.pickupCoordinate!,
            activeTrip!.destinationCoordinate!,
          )
        : const <OnWayCoordinate>[];

    return SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: OnWayMapSurface(
              height: mediaSize.height,
              interactive: false,
              markers: markers,
              route: route,
              overlay: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.08),
                      Colors.black.withValues(alpha: 0.18),
                      Colors.black.withValues(alpha: 0.48),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 14,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _FloatingMapButton(icon: Icons.menu_rounded, onTap: () {}),
                const Spacer(),
                if (activeTrip == null)
                  _FloatingStatusPill(
                    icon: Icons.near_me_rounded,
                    label: 'Current location',
                  )
                else
                  _FloatingStatusPill(
                    icon: Icons.directions_car_rounded,
                    label: activeTrip!.statusLine,
                  ),
                const Spacer(),
                _FloatingMapButton(
                  icon: Icons.my_location_rounded,
                  onTap: () => onOpenBooking(),
                ),
              ],
            ),
          ),
          if (activeTrip == null)
            Positioned(
              left: 16,
              right: 16,
              bottom: mediaSize.height * 0.23,
              child: GestureDetector(
                onTap: () => onOpenBooking(_primaryService()),
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: OnWayTheme.black),
                      const SizedBox(width: 12),
                      Text(
                        'Where to?',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: OnWayTheme.black,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: OnWayTheme.black,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          DraggableScrollableSheet(
            initialChildSize: activeTrip == null ? 0.24 : 0.30,
            minChildSize: activeTrip == null ? 0.20 : 0.26,
            maxChildSize: activeTrip == null ? 0.56 : 0.50,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.96),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  border: Border.all(color: Colors.white12),
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (activeTrip == null)
                      _IdleRideSheet(
                        primaryService: _primaryService(),
                        services: services,
                        onOpenBooking: onOpenBooking,
                      )
                    else
                      _ActiveRideSheet(
                        trip: activeTrip!,
                        onOpenTracking: onOpenTracking,
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  OnWayService _primaryService() {
    return services.firstWhere(
      (service) => service.type == ServiceType.rideShare,
      orElse: () => services.first,
    );
  }

  List<OnWayMapMarkerSpec> _markersForHome() {
    if (activeTrip != null) {
      return [
        OnWayMapMarkerSpec(
          coordinate: activeTrip!.pickupCoordinate ?? OnWayMockData.joharTown,
          icon: Icons.trip_origin_rounded,
          label: 'Pickup',
          color: Colors.white,
        ),
        OnWayMapMarkerSpec(
          coordinate:
              activeTrip!.destinationCoordinate ?? OnWayMockData.packagesMall,
          icon: Icons.location_on_rounded,
          label: 'Dropoff',
        ),
        if (activeTrip!.driverCoordinate != null)
          OnWayMapMarkerSpec(
            coordinate: activeTrip!.driverCoordinate!,
            icon: Icons.directions_car_rounded,
            label: 'Driver',
            color: const Color(0xFF91F2C0),
          ),
      ];
    }

    return const [
      OnWayMapMarkerSpec(
        coordinate: OnWayMockData.joharTown,
        icon: Icons.my_location_rounded,
        label: 'You',
        color: Colors.white,
      ),
      OnWayMapMarkerSpec(
        coordinate: OnWayMockData.packagesMall,
        icon: Icons.local_mall_rounded,
        label: 'Mall',
        size: 34,
      ),
      OnWayMapMarkerSpec(
        coordinate: OnWayMockData.airport,
        icon: Icons.flight_takeoff_rounded,
        label: 'Airport',
        size: 34,
      ),
    ];
  }
}

class _IdleRideSheet extends StatelessWidget {
  const _IdleRideSheet({
    required this.primaryService,
    required this.services,
    required this.onOpenBooking,
  });

  final OnWayService primaryService;
  final List<OnWayService> services;
  final Future<void> Function([OnWayService? service]) onOpenBooking;

  @override
  Widget build(BuildContext context) {
    final airportService = services.firstWhere(
      (service) => service.type == ServiceType.airport,
      orElse: () => primaryService,
    );
    final courierService = services.firstWhere(
      (service) => service.type == ServiceType.courier,
      orElse: () => primaryService,
    );
    final rentalService = services.firstWhere(
      (service) => service.type == ServiceType.rentCar,
      orElse: () => primaryService,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Book a ride', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'Choose destination, then compare cars and prices.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        _NativeRouteRow(
          icon: Icons.my_location_rounded,
          title: 'Pickup',
          subtitle: 'Current location',
          onTap: () => onOpenBooking(primaryService),
        ),
        const SizedBox(height: 10),
        _NativeRouteRow(
          icon: Icons.location_on_outlined,
          title: 'Destination',
          subtitle: 'Search destination',
          emphasized: true,
          onTap: () => onOpenBooking(primaryService),
        ),
        const SizedBox(height: 18),
        Text(
          'Recent destinations',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final place in OnWayMockData.recentPlaces.take(3))
          _RecentPlaceRow(
            place: place,
            onTap: () => onOpenBooking(primaryService),
          ),
        const SizedBox(height: 16),
        Text('Other services', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _MinimalServicePill(
                label: airportService.title,
                icon: airportService.icon,
                onTap: () => onOpenBooking(airportService),
              ),
              const SizedBox(width: 8),
              _MinimalServicePill(
                label: courierService.title,
                icon: courierService.icon,
                onTap: () => onOpenBooking(courierService),
              ),
              const SizedBox(width: 8),
              _MinimalServicePill(
                label: rentalService.title,
                icon: rentalService.icon,
                onTap: () => onOpenBooking(rentalService),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActiveRideSheet extends StatelessWidget {
  const _ActiveRideSheet({required this.trip, required this.onOpenTracking});

  final ActiveTrip trip;
  final Future<void> Function([ActiveTrip? trip]) onOpenTracking;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(trip.statusLine, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(trip.routeLine, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 18),
        _NativeRouteRow(
          icon: Icons.trip_origin_rounded,
          title: 'Pickup',
          subtitle: trip.pickup,
          onTap: () => onOpenTracking(trip),
        ),
        const SizedBox(height: 10),
        _NativeRouteRow(
          icon: Icons.location_on_outlined,
          title: 'Destination',
          subtitle: trip.destination,
          emphasized: true,
          onTap: () => onOpenTracking(trip),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF171717),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.driver?.name ?? 'OnWay dispatch',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      trip.driver != null
                          ? '${trip.driver!.vehicle} • ${trip.driver!.eta}'
                          : 'Driver details will appear here.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                trip.fareLabel,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: OnWayTheme.yellow),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => onOpenTracking(trip),
          child: const Text('Open trip'),
        ),
      ],
    );
  }
}

class _FloatingMapButton extends StatelessWidget {
  const _FloatingMapButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.66),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _FloatingStatusPill extends StatelessWidget {
  const _FloatingStatusPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: OnWayTheme.yellow),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _NativeRouteRow extends StatelessWidget {
  const _NativeRouteRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: emphasized ? Colors.white : const Color(0xFF171717),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                        color: emphasized ? Colors.black54 : Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: emphasized ? OnWayTheme.black : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: emphasized ? OnWayTheme.black : Colors.white54,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentPlaceRow extends StatelessWidget {
  const _RecentPlaceRow({required this.place, required this.onTap});

  final OnWayPlaceSuggestion place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(place.icon, size: 18, color: OnWayTheme.yellow),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(place.title),
                    const SizedBox(height: 2),
                    Text(
                      place.addressLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MinimalServicePill extends StatelessWidget {
  const _MinimalServicePill({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF171717),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: OnWayTheme.yellow),
              const SizedBox(width: 8),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
