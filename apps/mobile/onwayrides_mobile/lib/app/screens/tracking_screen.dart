import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/onway_auth_service.dart';
import '../onway_map.dart';
import '../onway_mock_data.dart';
import '../onway_models.dart';
import '../onway_theme.dart';
import '../onway_widgets.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key, required this.trip, this.authService});

  final ActiveTrip trip;
  final OnWayAuthService? authService;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  static const _refreshInterval = Duration(seconds: 10);

  late ActiveTrip _trip;
  Timer? _refreshTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    if (widget.authService != null) {
      _refreshTimer = Timer.periodic(_refreshInterval, (_) {
        unawaited(_refreshTrip());
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshTrip() async {
    if (_refreshing || widget.authService == null) {
      return;
    }

    _refreshing = true;
    try {
      final feed = await widget.authService!.fetchTrips();
      final active = feed.activeTrip;
      if (!mounted || active == null) {
        return;
      }

      final sameBooking = active.bookingId != null && _trip.bookingId != null
          ? active.bookingId == _trip.bookingId
          : active.bookingReference == _trip.bookingReference;

      if (sameBooking) {
        setState(() => _trip = active);
      }
    } on OnWayAuthException {
      // Keep the last known rider view on screen.
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _cancelRide() async {
    final bookingId = _trip.bookingId;
    if (bookingId == null || widget.authService == null) {
      _showMessage('Ride cancellation is unavailable right now.');
      return;
    }

    try {
      final updatedTrip = await widget.authService!.updateBookingStatus(
        bookingId: bookingId,
        status: 'cancelled',
        note: 'Cancelled by rider from tracking screen.',
      );

      if (!mounted) {
        return;
      }

      setState(() => _trip = updatedTrip);
      _showMessage('Booking cancelled.');
    } on OnWayAuthException catch (error) {
      _showMessage(error.message);
    }
  }

  void _showTodo(String action) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$action will be available soon.')));
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final driver = _trip.driver;
    final pickupCoordinate =
        _trip.pickupCoordinate ??
        OnWayMockData.coordinateForAddress(_trip.pickup);
    final destinationCoordinate =
        _trip.destinationCoordinate ??
        OnWayMockData.coordinateForAddress(_trip.destination);
    final driverCoordinate =
        _trip.driverCoordinate ??
        OnWayMockData.midpointBetween(pickupCoordinate, destinationCoordinate);
    final route = buildRoutePath(pickupCoordinate, destinationCoordinate);

    return Scaffold(
      appBar: AppBar(title: const Text('Live tracking')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Stack(
            children: [
              OnWayMapSurface(
                height: 320,
                markers: [
                  OnWayMapMarkerSpec(
                    coordinate: pickupCoordinate,
                    icon: Icons.trip_origin_rounded,
                    label: 'Pickup',
                    color: Colors.white,
                  ),
                  OnWayMapMarkerSpec(
                    coordinate: destinationCoordinate,
                    icon: Icons.location_on_rounded,
                    label: 'Dropoff',
                  ),
                  OnWayMapMarkerSpec(
                    coordinate: driverCoordinate,
                    icon: Icons.directions_car_rounded,
                    label: 'Driver',
                    color: const Color(0xFF91F2C0),
                  ),
                ],
                route: route,
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: OnWayPanel(
                  backgroundColor: Colors.black.withValues(alpha: 0.76),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _trip.statusLine,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(_trip.routeLine),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          OnWayPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Driver details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white10,
                      backgroundImage: driver != null
                          ? AssetImage(driver.avatarAsset)
                          : null,
                      child: driver == null
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
                          Text(driver?.name ?? 'OnWay dispatch'),
                          const SizedBox(height: 4),
                          Text(
                            driver != null
                                ? '${driver.vehicle}\n${driver.plate} | ${driver.distanceAway}'
                                : 'Your booking is in the dispatch queue.\nDriver details will appear here once assigned.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      driver?.rating ?? '--',
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
                        onPressed: driver == null
                            ? null
                            : () => _showTodo('Call'),
                        icon: const Icon(Icons.call_rounded),
                        label: const Text('Call'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: driver == null
                            ? null
                            : () => _showTodo('Chat'),
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                        label: const Text('Chat'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _trip.status == 'cancelled' ? null : _cancelRide,
                  icon: const Icon(Icons.close_rounded),
                  label: Text(
                    _trip.status == 'cancelled'
                        ? 'Ride cancelled'
                        : 'Cancel ride',
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
                Text(
                  'Booking summary',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                _SummaryRow(label: 'Service', value: _trip.serviceTitle),
                if (_trip.bookingReference != null)
                  _SummaryRow(
                    label: 'Reference',
                    value: _trip.bookingReference!,
                  ),
                _SummaryRow(label: 'Pickup', value: _trip.pickup),
                _SummaryRow(label: 'Destination', value: _trip.destination),
                _SummaryRow(label: 'Payment', value: _trip.paymentLabel),
                _SummaryRow(label: 'Fare', value: _trip.fareLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

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
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
