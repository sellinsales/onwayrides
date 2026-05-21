import 'package:flutter/material.dart';

import '../onway_models.dart';
import '../onway_theme.dart';
import '../onway_widgets.dart';

class DriverModeScreen extends StatefulWidget {
  const DriverModeScreen({
    super.key,
    required this.stats,
    required this.requests,
    required this.services,
    required this.onOpenFleetOwner,
  });

  final List<DriverStat> stats;
  final List<DriverRequest> requests;
  final List<OnWayService> services;
  final VoidCallback onOpenFleetOwner;

  @override
  State<DriverModeScreen> createState() => _DriverModeScreenState();
}

class _DriverModeScreenState extends State<DriverModeScreen> {
  bool _online = true;
  late final Set<ServiceType> _enabledServices = {
    ServiceType.taxi,
    ServiceType.bikeTaxi,
    ServiceType.courier,
    ServiceType.cityToCity,
  };

  @override
  Widget build(BuildContext context) {
    final driverServices = widget.services.where((service) {
      return {
        ServiceType.taxi,
        ServiceType.bikeTaxi,
        ServiceType.rickshawTaxi,
        ServiceType.courier,
        ServiceType.cityToCity,
        ServiceType.schoolOffice,
      }.contains(service.type);
    }).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
        children: [
          BrandHeader(
            caption: 'Driver mode with requests, earnings and wallet',
            trailing: Switch(
              value: _online,
              activeThumbColor: OnWayTheme.yellow,
              onChanged: (value) => setState(() => _online = value),
            ),
          ),
          const SizedBox(height: 22),
          OnWayPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _online ? const Color(0x29FFC107) : Colors.white10,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _online ? 'Live in Lahore' : 'Currently offline',
                        style: TextStyle(
                          color: _online ? OnWayTheme.yellow : Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _online ? '6 open requests' : 'Pause mode',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  _online ? 'You are online' : 'Go online for new requests',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _online
                      ? 'Taxi, courier, school, and intercity requests are available in your zone right now.'
                      : 'Stay visible only for the services you want to drive today.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => setState(() => _online = !_online),
                  child: Text(_online ? 'Pause driver mode' : 'Go online'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: widget.onOpenFleetOwner,
                  child: const Text('Open Fleet Owner module'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Performance today',
            subtitle: 'Simple operating view for earnings, requests and wallet.',
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth > 760
                  ? (constraints.maxWidth - 48) / 4
                  : (constraints.maxWidth - 16) / 2;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final stat in widget.stats)
                    SizedBox(
                      width: width,
                      child: MetricTile(
                        label: stat.label,
                        value: stat.value,
                        delta: stat.delta,
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Enabled services',
            subtitle: 'Choose what the driver profile accepts right now.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final service in driverServices)
                FilterChip(
                  label: Text(service.title),
                  selected: _enabledServices.contains(service.type),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _enabledServices.add(service.type);
                      } else {
                        _enabledServices.remove(service.type);
                      }
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Available requests',
            subtitle: 'Accept, reject or send a counter offer.',
          ),
          const SizedBox(height: 14),
          for (final request in widget.requests) ...[
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
                        child: Text(
                          request.serviceTitle,
                          style: const TextStyle(
                            color: OnWayTheme.yellow,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        request.fareLabel,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(request.riderName, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text('${request.pickup} -> ${request.dropoff}'),
                  const SizedBox(height: 6),
                  Text(
                    '${request.distanceLabel} | ${request.paymentLabel}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showAction(context, 'Request rejected'),
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: request.canCounter
                            ? FilledButton.tonal(
                                onPressed: () => _showAction(
                                  context,
                                  'TODO: counter-offer API to be wired next',
                                ),
                                child: const Text('Counter offer'),
                              )
                            : const SizedBox.shrink(),
                      ),
                      if (request.canCounter) const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _showAction(context, 'Request accepted'),
                          child: const Text('Accept'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
          const OnWayPanel(
            child: Text(
              'TODO: replace the mock request list with polling or socket-based nearby requests once backend APIs are available.',
            ),
          ),
        ],
      ),
    );
  }

  void _showAction(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
