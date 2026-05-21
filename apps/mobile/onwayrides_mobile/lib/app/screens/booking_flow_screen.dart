import 'package:flutter/material.dart';

import '../onway_mock_data.dart';
import '../onway_models.dart';
import '../onway_theme.dart';
import '../onway_widgets.dart';

class BookingFlowScreen extends StatefulWidget {
  const BookingFlowScreen({
    super.key,
    required this.services,
    this.initialService,
  });

  final List<OnWayService> services;
  final OnWayService? initialService;

  @override
  State<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends State<BookingFlowScreen> {
  late final TextEditingController _pickupController;
  late final TextEditingController _destinationController;
  late final TextEditingController _offerController;
  late OnWayService _selectedService;
  late FareOption _selectedFare;
  bool _isNegotiated = false;
  bool _isPrebooked = false;
  String _paymentMethod = 'Cash';
  String _scheduleLabel = 'Today, ASAP';

  @override
  void initState() {
    super.initState();
    _selectedService = widget.initialService ?? widget.services.first;
    _selectedFare = OnWayMockData.fareOptions.first;
    _pickupController = TextEditingController(text: 'Johar Town, Lahore');
    _destinationController = TextEditingController(
      text: 'Packages Mall, Lahore',
    );
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

  void _confirmBooking() {
    // TODO: replace this mock booking confirmation with the real create-booking API.
    final trip = OnWayMockData.tripForService(_selectedService);
    Navigator.of(context).pop(
      ActiveTrip(
        serviceTitle: _selectedFare.title,
        pickup: _pickupController.text,
        destination: _destinationController.text,
        statusLine: _isPrebooked
            ? 'Booking scheduled for $_scheduleLabel'
            : trip.statusLine,
        routeLine: trip.routeLine,
        paymentLabel: '$_paymentMethod payment',
        fareLabel: _isNegotiated
            ? 'PKR ${_offerController.text}'
            : _selectedFare.priceLabel,
        driver: trip.driver,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plan your booking')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const BrandHeader(caption: 'Ride, food, courier and recurring trips'),
          const SizedBox(height: 20),
          const SectionHeading(
            title: 'Choose service',
            subtitle: 'All OnWay services stay in one booking flow.',
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final service in widget.services) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      label: Text(service.title),
                      selected: service.type == _selectedService.type,
                      onSelected: (_) {
                        setState(() {
                          _selectedService = service;
                          _syncNegotiation();
                          _isPrebooked = service.type == ServiceType.prebooking;
                        });
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeading(
            title: 'Trip details',
            subtitle: 'Pickup, destination and time.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pickupController,
            decoration: const InputDecoration(
              labelText: 'Pickup location',
              prefixIcon: Icon(Icons.my_location_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _destinationController,
            decoration: InputDecoration(
              labelText: _selectedService.type == ServiceType.foodDelivery
                  ? 'Delivery destination'
                  : 'Destination',
              prefixIcon: const Icon(Icons.location_on_outlined),
            ),
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
                      const Text('Schedule'),
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
                      _scheduleLabel = value
                          ? 'Tomorrow, 7:30 AM'
                          : 'Today, ASAP';
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeading(
            title: 'Vehicle & fare',
            subtitle: 'Offer-based booking is available on selected services.',
          ),
          const SizedBox(height: 12),
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
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: fare == _selectedFare
                                ? OnWayTheme.yellow
                                : Colors.white30,
                            width: 2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: fare == _selectedFare
                                  ? OnWayTheme.yellow
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  fare.title,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                if (fare.recommended) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: OnWayTheme.yellow,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'Best value',
                                      style: TextStyle(
                                        color: OnWayTheme.black,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
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
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          SwitchListTile(
            value: _isNegotiated,
            activeThumbColor: OnWayTheme.yellow,
            contentPadding: EdgeInsets.zero,
            title: const Text('Offer a negotiated fare'),
            subtitle: const Text('Keep it simple for cash-first local rides.'),
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
            subtitle: 'Cash first, wallet and cards later.',
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
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: FilledButton(
          onPressed: _confirmBooking,
          child: Text(
            _isNegotiated
                ? 'Confirm offer for PKR ${_offerController.text}'
                : 'Confirm ${_selectedFare.priceLabel}',
          ),
        ),
      ),
    );
  }
}
