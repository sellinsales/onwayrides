import 'package:flutter/material.dart';

import '../auth/onway_auth_service.dart';
import '../onway_map.dart';
import '../onway_mock_data.dart';
import '../onway_models.dart';
import '../onway_theme.dart';
import '../onway_widgets.dart';

enum _MapSelectionTarget { pickup, destination }

class BookingFlowScreen extends StatefulWidget {
  const BookingFlowScreen({
    super.key,
    required this.authService,
    required this.services,
    this.initialService,
    this.previewMode = false,
  });

  final OnWayAuthService authService;
  final List<OnWayService> services;
  final OnWayService? initialService;
  final bool previewMode;

  @override
  State<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends State<BookingFlowScreen> {
  late final TextEditingController _pickupController;
  late final TextEditingController _destinationController;
  late final TextEditingController _offerController;
  late OnWayService _selectedService;
  late FareOption _selectedFare;

  int _currentStep = 0;
  bool _isNegotiated = false;
  bool _isPrebooked = false;
  bool _submitting = false;
  bool _routeSuggestionShown = false;
  String _paymentMethod = 'Cash';
  String _scheduleLabel = 'Now';
  String? _errorMessage;
  OnWayCoordinate? _pickupCoordinate;
  OnWayCoordinate? _destinationCoordinate;
  _MapSelectionTarget _mapSelectionTarget = _MapSelectionTarget.destination;

  @override
  void initState() {
    super.initState();
    _selectedService = widget.initialService ?? widget.services.first;
    _selectedFare = OnWayMockData.fareOptions.first;
    _pickupController = TextEditingController(text: 'Current location');
    _destinationController = TextEditingController();
    _offerController = TextEditingController(text: '600');
    _pickupCoordinate = OnWayMockData.joharTown;
    _syncNegotiation();
    _hydrateCurrentLocation();
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _destinationController.dispose();
    _offerController.dispose();
    super.dispose();
  }

  void _syncNegotiation() {
    _isNegotiated = _selectedService.negotiable && _selectedFare.negotiable;
  }

  Future<void> _hydrateCurrentLocation() async {
    final current = await tryResolveCurrentLocation();
    if (!mounted || current == null) {
      return;
    }

    setState(() => _pickupCoordinate = current);
  }

  List<OnWayService> get _relevantServices {
    final destination = _destinationController.text.toLowerCase();
    if (destination.contains('airport') || destination.contains('terminal')) {
      return _filterServices([
        ServiceType.airport,
        ServiceType.rideShare,
        ServiceType.rentCar,
      ]);
    }
    if (destination.contains('school') || destination.contains('campus')) {
      return _filterServices([
        ServiceType.schoolOffice,
        ServiceType.rideShare,
        ServiceType.rickshawTaxi,
      ]);
    }
    if (destination.contains('cargo') ||
        destination.contains('parcel') ||
        destination.contains('market')) {
      return _filterServices([ServiceType.courier, ServiceType.rideShare]);
    }

    return _filterServices([
      ServiceType.rideShare,
      ServiceType.bikeTaxi,
      ServiceType.rickshawTaxi,
      ServiceType.airport,
      ServiceType.courier,
      ServiceType.rentCar,
    ]);
  }

  List<OnWayService> _filterServices(List<ServiceType> types) {
    return types
        .map(
          (type) => widget.services.firstWhere(
            (service) => service.type == type,
            orElse: () => widget.services.first,
          ),
        )
        .toList(growable: false);
  }

  String _labelForCoordinate(OnWayCoordinate coordinate) {
    OnWayPlaceSuggestion? nearest;
    var bestScore = double.infinity;
    for (final place in OnWayMockData.allKnownPlaces) {
      final latDelta = coordinate.latitude - place.coordinate.latitude;
      final lngDelta = coordinate.longitude - place.coordinate.longitude;
      final score = (latDelta * latDelta) + (lngDelta * lngDelta);
      if (score < bestScore) {
        bestScore = score;
        nearest = place;
      }
    }

    if (nearest != null && bestScore < 0.0004) {
      return nearest.title;
    }

    return 'Pinned location';
  }

  void _applyCoordinate({
    required bool pickup,
    required OnWayCoordinate coordinate,
    String? label,
  }) {
    setState(() {
      if (pickup) {
        _pickupCoordinate = coordinate;
        _pickupController.text = label ?? _labelForCoordinate(coordinate);
      } else {
        _destinationCoordinate = coordinate;
        _destinationController.text = label ?? _labelForCoordinate(coordinate);
      }
    });
  }

  void _selectOnMap(OnWayCoordinate coordinate) {
    _applyCoordinate(
      pickup: _mapSelectionTarget == _MapSelectionTarget.pickup,
      coordinate: coordinate,
      label: _mapSelectionTarget == _MapSelectionTarget.pickup
          ? 'Pickup pin'
          : 'Destination pin',
    );
  }

  Future<void> _openLocationPicker({required bool pickup}) async {
    final selected = await showModalBottomSheet<OnWayPlaceSuggestion>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LocationPickerSheet(
        title: pickup ? 'Choose pickup' : 'Choose destination',
        recentPlaces: OnWayMockData.recentPlaces,
        savedPlaces: OnWayMockData.savedPlaces,
        suggestions: OnWayMockData.locationSuggestions,
      ),
    );

    if (selected == null || !mounted) {
      return;
    }

    _applyCoordinate(
      pickup: pickup,
      coordinate: selected.coordinate,
      label: selected.title == 'Current location'
          ? 'Current location'
          : selected.title,
    );

    if (!pickup) {
      await _maybeShowRouteSuggestions();
    }
  }

  Future<void> _maybeShowRouteSuggestions() async {
    if (_routeSuggestionShown || _destinationController.text.trim().isEmpty) {
      return;
    }

    final suggestions = OnWayMockData.contextualSuggestionsFor(
      _destinationController.text,
    );
    if (suggestions.isEmpty || !mounted) {
      return;
    }

    _routeSuggestionShown = true;
    final selectedType = await showModalBottomSheet<ServiceType>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SuggestionSheet(suggestions: suggestions),
    );

    if (!mounted || selectedType == null) {
      return;
    }

    setState(() {
      _selectedService = widget.services.firstWhere(
        (service) => service.type == selectedType,
        orElse: () => _selectedService,
      );
      _syncNegotiation();
    });
  }

  void _applyShortcutPlace(OnWayPlaceSuggestion place) {
    _applyCoordinate(
      pickup: false,
      coordinate: place.coordinate,
      label: place.title,
    );
  }

  String? _validateStep() {
    if (_currentStep == 0) {
      if (_pickupController.text.trim().isEmpty ||
          _destinationController.text.trim().isEmpty) {
        return 'Select both pickup and destination first.';
      }
      if (_pickupCoordinate == null || _destinationCoordinate == null) {
        return 'Set both route points on the map first.';
      }
    }
    if (_currentStep == 1 && _selectedService.title.isEmpty) {
      return 'Choose a ride option first.';
    }
    return null;
  }

  void _continue() {
    final message = _validateStep();
    if (message != null) {
      setState(() => _errorMessage = message);
      return;
    }

    setState(() {
      _errorMessage = null;
      if (_currentStep < 2) {
        _currentStep += 1;
      }
    });
  }

  Future<void> _confirmBooking() async {
    final message = _validateStep();
    if (message != null) {
      setState(() => _errorMessage = message);
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      if (widget.previewMode) {
        final trip = OnWayMockData.tripForService(_selectedService);
        if (!mounted) {
          return;
        }

        Navigator.of(context).pop(
          ActiveTrip(
            serviceTitle: _selectedFare.title,
            pickup: _pickupController.text,
            destination: _destinationController.text,
            statusLine: _isPrebooked
                ? 'Booking scheduled for $_scheduleLabel'
                : trip.statusLine,
            routeLine:
                '${_pickupController.text} -> ${_destinationController.text}',
            paymentLabel: '$_paymentMethod payment',
            fareLabel: _isNegotiated
                ? 'PKR ${_offerController.text}'
                : _selectedFare.priceLabel,
            driver: trip.driver,
            pickupCoordinate: _pickupCoordinate,
            destinationCoordinate: _destinationCoordinate,
            driverCoordinate: OnWayMockData.midpointBetween(
              _pickupCoordinate!,
              _destinationCoordinate!,
            ),
          ),
        );
        return;
      }

      final scheduledFor = _isPrebooked
          ? DateTime.now().add(const Duration(days: 1, hours: 7, minutes: 30))
          : null;

      final trip = await widget.authService.createBooking(
        service: _selectedService,
        pickupAddress: _pickupController.text,
        destinationAddress: _destinationController.text,
        fare: _selectedFare,
        paymentMethod: _paymentMethod,
        negotiated: _isNegotiated,
        offeredFare: _offerController.text,
        pickupCoordinate: _pickupCoordinate,
        destinationCoordinate: _destinationCoordinate,
        scheduledFor: scheduledFor,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(trip);
    } on OnWayAuthException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final route = _pickupCoordinate != null && _destinationCoordinate != null
        ? buildRoutePath(_pickupCoordinate!, _destinationCoordinate!)
        : const <OnWayCoordinate>[];
    final markers = <OnWayMapMarkerSpec>[
      if (_pickupCoordinate != null)
        OnWayMapMarkerSpec(
          coordinate: _pickupCoordinate!,
          icon: Icons.trip_origin_rounded,
          label: _currentStep == 0 ? 'Pickup' : 'Start',
          color: Colors.white,
        ),
      if (_destinationCoordinate != null)
        OnWayMapMarkerSpec(
          coordinate: _destinationCoordinate!,
          icon: Icons.location_on_rounded,
          label: 'Dropoff',
        ),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: OnWayMapSurface(
              height: mediaSize.height,
              markers: markers,
              route: route,
              onTap: _currentStep == 0 ? _selectOnMap : null,
              overlay: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.14),
                      Colors.black.withValues(alpha: 0.24),
                      Colors.black.withValues(alpha: 0.68),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).maybePop(),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.64),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.64),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${_currentStep + 1}/3',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: OnWayTheme.yellow),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _currentStep == 0
                                  ? 'Set your route'
                                  : _currentStep == 1
                                  ? 'Choose your ride'
                                  : 'Confirm your trip',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BookingSheetShell(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey(_currentStep),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_currentStep == 0) _buildRouteStep(context),
                      if (_currentStep == 1) _buildServiceStep(context),
                      if (_currentStep == 2) _buildReviewStep(context),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.red.shade200),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SheetTitle(
          title: 'Where to?',
          subtitle:
              'Tap the map or search. Pickup and destination stay on one continuous trip sheet.',
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ChoiceChip(
              label: const Text('Set pickup'),
              selected: _mapSelectionTarget == _MapSelectionTarget.pickup,
              onSelected: (_) {
                setState(
                  () => _mapSelectionTarget = _MapSelectionTarget.pickup,
                );
              },
            ),
            ChoiceChip(
              label: const Text('Set destination'),
              selected: _mapSelectionTarget == _MapSelectionTarget.destination,
              onSelected: (_) {
                setState(
                  () => _mapSelectionTarget = _MapSelectionTarget.destination,
                );
              },
            ),
            _MiniStatusChip(
              icon: Icons.touch_app_rounded,
              label: _mapSelectionTarget == _MapSelectionTarget.pickup
                  ? 'Tap map for pickup'
                  : 'Tap map for destination',
            ),
          ],
        ),
        const SizedBox(height: 14),
        _RouteField(
          icon: Icons.my_location_rounded,
          title: 'Pickup',
          value: _pickupController.text.isEmpty
              ? 'Select pickup point'
              : _pickupController.text,
          onTap: () => _openLocationPicker(pickup: true),
        ),
        const SizedBox(height: 12),
        _RouteField(
          icon: Icons.location_on_outlined,
          title: 'Destination',
          value: _destinationController.text.isEmpty
              ? 'Search destination'
              : _destinationController.text,
          emphasized: true,
          onTap: () => _openLocationPicker(pickup: false),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: OnWayTheme.charcoal,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule_rounded, color: OnWayTheme.yellow),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ride time'),
                    const SizedBox(height: 4),
                    Text(
                      _scheduleLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Switch(
                value: _isPrebooked,
                onChanged: (value) {
                  setState(() {
                    _isPrebooked = value;
                    _scheduleLabel = value ? 'Tomorrow, 7:30 AM' : 'Now';
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('Saved places', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final place in OnWayMockData.savedPlaces.take(4))
              ActionChip(
                avatar: Icon(place.icon, size: 18),
                label: Text(place.title),
                onPressed: () => _applyShortcutPlace(place),
              ),
          ],
        ),
        const SizedBox(height: 12),
        for (final place in OnWayMockData.recentPlaces.take(3))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: Colors.white10,
              child: Icon(place.icon, color: OnWayTheme.yellow),
            ),
            title: Text(place.title),
            subtitle: Text(place.addressLine),
            onTap: () => _applyShortcutPlace(place),
          ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: _submitting ? null : _continue,
          child: const Text('See ride options'),
        ),
      ],
    );
  }

  Widget _buildServiceStep(BuildContext context) {
    final services = _relevantServices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SheetTitle(
          title: 'Choose your ride',
          subtitle:
              'Popular ride options come first. Alternate service flows stay available but secondary.',
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: OnWayTheme.charcoal,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_pickupController.text} -> ${_destinationController.text}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Current flow: ${_selectedService.title}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Change trip flow',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final service in services)
              FilterChip(
                avatar: Icon(service.icon, size: 18),
                label: Text(service.title),
                selected: service.type == _selectedService.type,
                onSelected: (_) {
                  setState(() {
                    _selectedService = service;
                    _syncNegotiation();
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Ride options', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        for (
          var index = 0;
          index < OnWayMockData.fareOptions.length;
          index++
        ) ...[
          _FareTile(
            fare: OnWayMockData.fareOptions[index],
            selected: OnWayMockData.fareOptions[index] == _selectedFare,
            icon: index == 1
                ? Icons.two_wheeler_rounded
                : index == 2
                ? Icons.airport_shuttle_rounded
                : Icons.local_taxi_rounded,
            onTap: () {
              setState(() {
                _selectedFare = OnWayMockData.fareOptions[index];
                _syncNegotiation();
              });
            },
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _submitting
                    ? null
                    : () => setState(() => _currentStep -= 1),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _submitting ? null : _continue,
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SheetTitle(
          title: 'Confirm your trip',
          subtitle:
              'Keep the last step light: check the route, choose payment, then request the ride.',
        ),
        const SizedBox(height: 14),
        OnWayPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ReviewRow(label: 'Pickup', value: _pickupController.text),
              _ReviewRow(
                label: 'Destination',
                value: _destinationController.text,
              ),
              _ReviewRow(label: 'Ride', value: _selectedFare.title),
              _ReviewRow(label: 'Flow', value: _selectedService.title),
              _ReviewRow(label: 'Price', value: _selectedFare.priceLabel),
              _ReviewRow(label: 'When', value: _scheduleLabel),
            ],
          ),
        ),
        if (_selectedService.negotiable && _selectedFare.negotiable) ...[
          const SizedBox(height: 18),
          SwitchListTile(
            value: _isNegotiated,
            activeThumbColor: OnWayTheme.yellow,
            contentPadding: EdgeInsets.zero,
            title: const Text('Send a custom fare'),
            subtitle: const Text(
              'Use this only when local rider-driver negotiation is expected.',
            ),
            onChanged: (value) => setState(() => _isNegotiated = value),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _offerController,
            enabled: _isNegotiated,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Your offered fare (PKR)',
              prefixIcon: Icon(Icons.price_change_outlined),
            ),
          ),
        ],
        const SizedBox(height: 20),
        const _SheetTitle(
          title: 'Payment',
          subtitle: 'Choose how the rider will pay for this trip.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final method in const ['Cash', 'Wallet', 'Card'])
              ChoiceChip(
                label: Text(method),
                selected: _paymentMethod == method,
                onSelected: (_) => setState(() => _paymentMethod = method),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _submitting
                    ? null
                    : () => setState(() => _currentStep -= 1),
                child: const Text('Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _submitting ? null : _confirmBooking,
                child: Text(
                  _submitting ? 'Requesting ride...' : 'Confirm ride',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BookingSheetShell extends StatelessWidget {
  const _BookingSheetShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.94),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 24,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Column(
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
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _MiniStatusChip extends StatelessWidget {
  const _MiniStatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: OnWayTheme.yellow),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _RouteField extends StatelessWidget {
  const _RouteField({
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: emphasized ? Colors.white : OnWayTheme.charcoal,
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
                      color: emphasized ? Colors.black54 : Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 4),
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

class _FareTile extends StatelessWidget {
  const _FareTile({
    required this.fare,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final FareOption fare;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: selected ? const Color(0x22FFC107) : OnWayTheme.charcoal,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? OnWayTheme.yellow : Colors.white10,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: selected ? const Color(0x29FFC107) : Colors.white10,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: selected ? OnWayTheme.yellow : Colors.white70,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fare.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text('${fare.capacity} • ${fare.eta} pickup'),
                    if (fare.recommended) ...[
                      const SizedBox(height: 8),
                      const _MiniStatusChip(
                        icon: Icons.star_rounded,
                        label: 'Recommended',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                fare.priceLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

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
            width: 90,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _LocationPickerSheet extends StatelessWidget {
  const _LocationPickerSheet({
    required this.title,
    required this.savedPlaces,
    required this.recentPlaces,
    required this.suggestions,
  });

  final String title;
  final List<OnWayPlaceSuggestion> savedPlaces;
  final List<OnWayPlaceSuggestion> recentPlaces;
  final List<OnWayPlaceSuggestion> suggestions;

  @override
  Widget build(BuildContext context) {
    var query = '';

    return StatefulBuilder(
      builder: (context, setSheetState) {
        final allPlaces = [...savedPlaces, ...recentPlaces, ...suggestions];
        final filtered = allPlaces
            .where((place) {
              final haystack =
                  '${place.title} ${place.addressLine} ${place.badge ?? ''}'
                      .toLowerCase();
              return haystack.contains(query.toLowerCase());
            })
            .toList(growable: false);

        return Container(
          decoration: const BoxDecoration(
            color: OnWayTheme.black,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (value) => setSheetState(() => query = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Search places, landmarks, airports, schools',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final place = filtered[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: Colors.white10,
                            child: Icon(place.icon, color: OnWayTheme.yellow),
                          ),
                          title: Text(place.title),
                          subtitle: Text(place.addressLine),
                          trailing: place.badge != null
                              ? Text(
                                  place.badge!,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: OnWayTheme.yellow),
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(place),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SuggestionSheet extends StatelessWidget {
  const _SuggestionSheet({required this.suggestions});

  final List<OnWayContextualSuggestion> suggestions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: OnWayTheme.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Better trip flow',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Switch only when the destination suggests a better match than a normal ride.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              for (final suggestion in suggestions) ...[
                OnWayPanel(
                  backgroundColor: OnWayTheme.slate,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0x29FFC107),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(suggestion.icon, color: OnWayTheme.yellow),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              suggestion.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              suggestion.description,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: () => Navigator.of(
                                context,
                              ).pop(suggestion.serviceType),
                              child: Text(suggestion.ctaLabel),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
