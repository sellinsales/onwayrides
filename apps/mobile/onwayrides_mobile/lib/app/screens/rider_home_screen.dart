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
    final heroMarkers = _mapMarkersForHome();
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
              markers: heroMarkers,
              route: route,
              overlay: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.18),
                      Colors.black.withValues(alpha: 0.36),
                      Colors.black.withValues(alpha: 0.72),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 14,
            left: 20,
            right: 20,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.66),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/brand/onwayrides_logo.png',
                          height: 20,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            activeTrip == null
                                ? 'Book a ride with the map first.'
                                : activeTrip!.statusLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.black.withValues(alpha: 0.66),
                  child: const Icon(Icons.notifications_none_rounded),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _RiderBottomSheet(
              activeTrip: activeTrip,
              services: services,
              onOpenBooking: onOpenBooking,
              onOpenTracking: onOpenTracking,
            ),
          ),
        ],
      ),
    );
  }

  List<OnWayMapMarkerSpec> _mapMarkersForHome() {
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
        size: 36,
      ),
      OnWayMapMarkerSpec(
        coordinate: OnWayMockData.airport,
        icon: Icons.flight_takeoff_rounded,
        label: 'Airport',
        size: 36,
      ),
      OnWayMapMarkerSpec(
        coordinate: OnWayMockData.gulberg,
        icon: Icons.business_center_rounded,
        label: 'City',
        size: 36,
      ),
    ];
  }
}

class _RiderBottomSheet extends StatelessWidget {
  const _RiderBottomSheet({
    required this.activeTrip,
    required this.services,
    required this.onOpenBooking,
    required this.onOpenTracking,
  });

  final ActiveTrip? activeTrip;
  final List<OnWayService> services;
  final Future<void> Function([OnWayService? service]) onOpenBooking;
  final Future<void> Function([ActiveTrip? trip]) onOpenTracking;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.92),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 24,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: activeTrip == null
              ? _IdleBottomSheet(
                  services: services,
                  onOpenBooking: onOpenBooking,
                )
              : _ActiveTripBottomSheet(
                  trip: activeTrip!,
                  onOpenTracking: onOpenTracking,
                ),
        ),
      ),
    );
  }
}

class _IdleBottomSheet extends StatelessWidget {
  const _IdleBottomSheet({required this.services, required this.onOpenBooking});

  final List<OnWayService> services;
  final Future<void> Function([OnWayService? service]) onOpenBooking;

  @override
  Widget build(BuildContext context) {
    final taxiService = services.firstWhere(
      (service) => service.type == ServiceType.rideShare,
      orElse: () => services.first,
    );
    final airportService = services.firstWhere(
      (service) => service.type == ServiceType.airport,
      orElse: () => services.first,
    );
    final courierService = services.firstWhere(
      (service) => service.type == ServiceType.courier,
      orElse: () => services.first,
    );
    final rentalService = services.firstWhere(
      (service) => service.type == ServiceType.rentCar,
      orElse: () => services.first,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text('Where to?', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(
          'Pick your destination first. Ride options appear after the route is set.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        InkWell(
          onTap: () => onOpenBooking(taxiService),
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: OnWayTheme.black),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Search destination',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: OnWayTheme.black),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: OnWayTheme.black,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _HomeRoutePreviewRow(
          icon: Icons.my_location_rounded,
          label: 'Pickup',
          value: 'Current location',
          onTap: () => onOpenBooking(taxiService),
        ),
        const SizedBox(height: 10),
        _HomeRoutePreviewRow(
          icon: Icons.location_on_outlined,
          label: 'Destination',
          value: 'Choose on map or search',
          emphasized: true,
          onTap: () => onOpenBooking(taxiService),
        ),
        const SizedBox(height: 18),
        Text('Recent places', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final place in OnWayMockData.recentPlaces.take(3))
          ListTile(
            onTap: () => onOpenBooking(taxiService),
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white10,
              child: Icon(place.icon, color: OnWayTheme.yellow, size: 18),
            ),
            title: Text(place.title),
            subtitle: Text(
              place.addressLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        const SizedBox(height: 10),
        Text(
          'More ways to use OnWay',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _SecondaryFlowChip(
              label: airportService.title,
              icon: airportService.icon,
              onTap: () => onOpenBooking(airportService),
            ),
            _SecondaryFlowChip(
              label: courierService.title,
              icon: courierService.icon,
              onTap: () => onOpenBooking(courierService),
            ),
            _SecondaryFlowChip(
              label: rentalService.title,
              icon: rentalService.icon,
              onTap: () => onOpenBooking(rentalService),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActiveTripBottomSheet extends StatelessWidget {
  const _ActiveTripBottomSheet({
    required this.trip,
    required this.onOpenTracking,
  });

  final ActiveTrip trip;
  final Future<void> Function([ActiveTrip? trip]) onOpenTracking;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Trip in progress',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(trip.statusLine, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 18),
        _HomeRoutePreviewRow(
          icon: Icons.my_location_rounded,
          label: 'Pickup',
          value: trip.pickup,
          onTap: () => onOpenTracking(trip),
        ),
        const SizedBox(height: 10),
        _HomeRoutePreviewRow(
          icon: Icons.location_on_outlined,
          label: 'Destination',
          value: trip.destination,
          emphasized: true,
          onTap: () => onOpenTracking(trip),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: OnWayTheme.charcoal,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
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
                      trip.driver?.name ?? 'OnWay dispatch',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trip.driver != null
                          ? '${trip.driver!.vehicle}\n${trip.driver!.eta}'
                          : 'Driver details appear after assignment.',
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
          child: const Text('Track on map'),
        ),
      ],
    );
  }
}

class _HomeRoutePreviewRow extends StatelessWidget {
  const _HomeRoutePreviewRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
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
          color: emphasized ? Colors.white : OnWayTheme.charcoal,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: emphasized ? Colors.white : Colors.white10),
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
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: emphasized ? Colors.black54 : Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
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
              Icons.chevron_right_rounded,
              color: emphasized ? OnWayTheme.black : Colors.white54,
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryFlowChip extends StatelessWidget {
  const _SecondaryFlowChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}
