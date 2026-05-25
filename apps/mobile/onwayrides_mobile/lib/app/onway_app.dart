import 'dart:async';

import 'package:flutter/material.dart';

import 'auth/onway_auth_service.dart';
import 'auth/onway_auth_session.dart';
import 'auth/onway_firebase_bootstrap.dart';
import 'onway_mock_data.dart';
import 'onway_models.dart';
import 'onway_theme.dart';
import 'screens/auth_gate_screen.dart';
import 'screens/booking_flow_screen.dart';
import 'screens/driver_mode_screen.dart';
import 'screens/fleet_owner_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/rider_home_screen.dart';
import 'screens/tracking_screen.dart';
import 'screens/trips_screen.dart';

class OnWayApp extends StatelessWidget {
  const OnWayApp({
    super.key,
    required this.firebaseBootstrap,
    required this.authService,
  });

  final OnWayFirebaseBootstrap firebaseBootstrap;
  final OnWayAuthService authService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OnWay Rides',
      debugShowCheckedModeBanner: false,
      theme: OnWayTheme.darkTheme,
      home: AuthGateScreen(
        firebaseBootstrap: firebaseBootstrap,
        authService: authService,
      ),
    );
  }
}

class OnWayShell extends StatefulWidget {
  const OnWayShell({
    super.key,
    this.authService,
    this.session,
    this.onSignOut,
    this.previewMode = false,
  }) : assert(previewMode || authService != null);

  final OnWayAuthService? authService;
  final OnWayAuthSession? session;
  final Future<void> Function()? onSignOut;
  final bool previewMode;

  @override
  State<OnWayShell> createState() => _OnWayShellState();
}

class _OnWayShellState extends State<OnWayShell> {
  static const _tripRefreshInterval = Duration(seconds: 10);

  int _currentIndex = 0;
  ActiveTrip? _activeTrip;
  List<TripHistoryItem> _tripHistory = const [];
  Timer? _tripRefreshTimer;
  StreamSubscription<OnWayRealtimeEvent>? _realtimeSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.previewMode) {
      _activeTrip = OnWayMockData.activeTrip;
      _tripHistory = OnWayMockData.tripHistory;
    } else {
      _bindRealtimeUpdates();
      _startTripRefresh();
      unawaited(_refreshTrips());
    }
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _tripRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant OnWayShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.previewMode && !oldWidget.previewMode) {
      _realtimeSubscription?.cancel();
      _tripRefreshTimer?.cancel();
      setState(() {
        _activeTrip = OnWayMockData.activeTrip;
        _tripHistory = OnWayMockData.tripHistory;
      });
      return;
    }

    if (!widget.previewMode &&
        (oldWidget.previewMode ||
            oldWidget.session?.userId != widget.session?.userId)) {
      _bindRealtimeUpdates();
      _startTripRefresh();
      unawaited(_refreshTrips());
    }
  }

  void _bindRealtimeUpdates() {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = widget.authService?.realtimeEvents.listen((event) {
      if (!mounted) {
        return;
      }

      if (event.channel == 'rider_trip' || event.channel == 'trip_updates') {
        unawaited(_refreshTrips());
      }
    });
  }

  void _startTripRefresh() {
    _tripRefreshTimer?.cancel();
    _tripRefreshTimer = Timer.periodic(_tripRefreshInterval, (_) {
      if (!mounted || widget.previewMode) {
        return;
      }
      unawaited(_refreshTrips());
    });
  }

  Future<void> _refreshTrips() async {
    try {
      final feed = await widget.authService!.fetchTrips();
      if (!mounted) {
        return;
      }

      setState(() {
        _activeTrip = feed.activeTrip;
        _tripHistory = feed.history;
      });
    } on OnWayAuthException {
      if (!mounted) {
        return;
      }

      setState(() {
        _activeTrip = null;
        _tripHistory = const [];
      });
    }
  }

  Future<void> _openBooking([OnWayService? service]) async {
    final trip = await Navigator.of(context).push<ActiveTrip>(
      MaterialPageRoute(
        builder: (_) => BookingFlowScreen(
          authService: widget.authService!,
          services: OnWayMockData.services,
          initialService: service,
          previewMode: widget.previewMode,
        ),
      ),
    );

    if (trip != null && mounted) {
      setState(() => _activeTrip = trip);
      if (!widget.previewMode) {
        unawaited(_refreshTrips());
      }
      _openTracking(trip);
    }
  }

  Future<void> _openTracking([ActiveTrip? trip]) async {
    final currentTrip = trip ?? _activeTrip;
    if (currentTrip == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrackingScreen(
          trip: currentTrip,
          authService: widget.previewMode ? null : widget.authService,
        ),
      ),
    );
  }

  Future<void> _openFleetOwner() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const FleetOwnerScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      RiderHomeScreen(
        services: OnWayMockData.services,
        activeTrip: _activeTrip,
        onOpenBooking: _openBooking,
        onOpenTracking: _openTracking,
      ),
      TripsScreen(
        activeTrip: _activeTrip,
        history: _tripHistory,
        onOpenTracking: _openTracking,
      ),
      DriverModeScreen(
        authService: widget.authService,
        session: widget.session,
        previewMode: widget.previewMode,
        stats: OnWayMockData.driverStats,
        requests: OnWayMockData.driverRequests,
        services: OnWayMockData.services,
        onOpenFleetOwner: _openFleetOwner,
      ),
      ProfileScreen(
        onOpenFleetOwner: _openFleetOwner,
        session: widget.session,
        onSignOut: widget.onSignOut,
        previewMode: widget.previewMode,
      ),
    ];

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: pages[_currentIndex],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        backgroundColor: OnWayTheme.charcoal,
        indicatorColor: OnWayTheme.yellow,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (value) => setState(() => _currentIndex = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Trips',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_car_outlined),
            selectedIcon: Icon(Icons.directions_car_rounded),
            label: 'Driver Mode',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
