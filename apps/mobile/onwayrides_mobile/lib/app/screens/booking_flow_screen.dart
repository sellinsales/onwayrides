import 'package:flutter/material.dart';

import '../auth/onway_auth_service.dart';
import '../onway_mock_data.dart';
import '../onway_models.dart';
import '../onway_theme.dart';
import '../onway_widgets.dart';

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

  @override
  void initState() {
    super.initState();
    _selectedService = widget.initialService ?? widget.services.first;
    _selectedFare = OnWayMockData.fareOptions.first;
    _pickupController = TextEditingController(text: 'Current location');
    _destinationController = TextEditingController();
    _offerController = TextEditingController(text: '600');
    _syncNegotiation();
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
      ServiceType.cityToCity,
      ServiceType.schoolOffice,
      ServiceType.prebooking,
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

    setState(() {
      if (pickup) {
        _pickupController.text = selected.title == 'Current location'
            ? 'Current location'
            : selected.title;
      } else {
        _destinationController.text = selected.title;
      }
    });

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
    if (suggestions.isEmpty) {
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

    final matched = widget.services.firstWhere(
      (service) => service.type == selectedType,
      orElse: () => _selectedService,
    );

    setState(() {
      _selectedService = matched;
      _isPrebooked = matched.type == ServiceType.prebooking;
      _syncNegotiation();
    });
  }

  void _applyShortcutPlace(OnWayPlaceSuggestion place) {
    setState(() {
      _destinationController.text = place.title;
    });
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

  String? _validateStep() {
    if (_currentStep == 0) {
      if (_pickupController.text.trim().isEmpty ||
          _destinationController.text.trim().isEmpty) {
        return 'Select both pickup and destination first.';
      }
    }
    if (_currentStep == 1) {
      if (_selectedService.title.isEmpty) {
        return 'Choose a service for this route.';
      }
      if (_isNegotiated && _offerController.text.trim().isEmpty) {
        return 'Enter your offered fare.';
      }
    }
    return null;
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
    return Scaffold(
      appBar: AppBar(title: const Text('Plan your booking')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const BrandHeader(caption: 'Route first. Service second.'),
          const SizedBox(height: 18),
          _StepHeader(currentStep: _currentStep),
          const SizedBox(height: 20),
          if (_currentStep == 0) _buildRouteStep(context),
          if (_currentStep == 1) _buildServiceStep(context),
          if (_currentStep == 2) _buildReviewStep(context),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.red.shade300),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Row(
          children: [
            if (_currentStep > 0) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting
                      ? null
                      : () => setState(() => _currentStep -= 1),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: FilledButton(
                onPressed: _submitting
                    ? null
                    : _currentStep == 2
                    ? _confirmBooking
                    : _continue,
                child: Text(
                  _submitting
                      ? 'Creating booking...'
                      : _currentStep == 2
                      ? 'Confirm booking'
                      : 'Continue',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(
          title: 'Choose your route',
          subtitle:
              'Select pickup, destination and timing before the app shows the best service options.',
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
              ? 'Where do you want to go?'
              : _destinationController.text,
          emphasized: true,
          onTap: () => _openLocationPicker(pickup: false),
        ),
        const SizedBox(height: 12),
        OnWayPanel(
          padding: const EdgeInsets.all(16),
          backgroundColor: OnWayTheme.slate,
          child: Row(
            children: [
              const Icon(Icons.schedule_rounded, color: OnWayTheme.yellow),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('When'),
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
        const SizedBox(height: 20),
        const SectionHeading(
          title: 'Saved and recent places',
          subtitle: 'Tap a common destination to move faster.',
        ),
        const SizedBox(height: 12),
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
        for (final place in OnWayMockData.recentPlaces.take(3)) ...[
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
        ],
      ],
    );
  }

  Widget _buildServiceStep(BuildContext context) {
    final services = _relevantServices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(
          title: 'Choose the right service',
          subtitle:
              'The route is set. Now choose the most relevant service and fare for this trip.',
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final service in services)
              SizedBox(
                width: (MediaQuery.sizeOf(context).width - 52) / 2,
                child: _CompactServiceTile(
                  service: service,
                  selected: service.type == _selectedService.type,
                  onTap: () {
                    setState(() {
                      _selectedService = service;
                      _syncNegotiation();
                    });
                  },
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Available fares', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        for (final fare in OnWayMockData.fareOptions) ...[
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => setState(() {
              _selectedFare = fare;
              _syncNegotiation();
            }),
            child: Ink(
              decoration: BoxDecoration(
                color: fare == _selectedFare
                    ? const Color(0x22FFC107)
                    : OnWayTheme.charcoal,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: fare == _selectedFare
                      ? OnWayTheme.yellow
                      : Colors.white10,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
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
                        ],
                      ),
                    ),
                    Text(
                      fare.priceLabel,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _maybeShowRouteSuggestions,
          icon: const Icon(Icons.tips_and_updates_outlined),
          label: const Text('See route suggestions'),
        ),
      ],
    );
  }

  Widget _buildReviewStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(
          title: 'Review and confirm',
          subtitle:
              'Keep the final step short: payment, fare and one last check.',
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
              _ReviewRow(label: 'Service', value: _selectedService.title),
              _ReviewRow(label: 'Fare', value: _selectedFare.priceLabel),
              _ReviewRow(label: 'When', value: _scheduleLabel),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SwitchListTile(
          value: _isNegotiated,
          activeThumbColor: OnWayTheme.yellow,
          contentPadding: EdgeInsets.zero,
          title: const Text('Offer a negotiated fare'),
          subtitle: const Text(
            'Use this only where local pricing or rider-driver negotiation makes sense.',
          ),
          onChanged: _selectedService.negotiable && _selectedFare.negotiable
              ? (value) => setState(() => _isNegotiated = value)
              : null,
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
        const SizedBox(height: 20),
        const SectionHeading(
          title: 'Payment method',
          subtitle: 'Cash first, then wallet or card as the platform expands.',
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
      ],
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    const labels = ['Route', 'Service', 'Review'];

    return Row(
      children: List.generate(labels.length, (index) {
        final active = currentStep == index;
        final complete = currentStep > index;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: index == labels.length - 1 ? 0 : 10,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0x29FFC107)
                    : complete
                    ? Colors.white10
                    : OnWayTheme.charcoal,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: active ? OnWayTheme.yellow : Colors.white10,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${index + 1}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: active ? OnWayTheme.yellow : Colors.white54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[index],
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
          ),
        );
      }),
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

class _CompactServiceTile extends StatelessWidget {
  const _CompactServiceTile({
    required this.service,
    required this.selected,
    required this.onTap,
  });

  final OnWayService service;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0x22FFC107) : OnWayTheme.charcoal,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? OnWayTheme.yellow : Colors.white10,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 1.4,
                child: Image.asset(service.imageAsset, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 10),
            Text(service.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              service.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
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
                'Suggestions for this route',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Show helpful alternatives without interrupting the rider’s main booking intent.',
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
