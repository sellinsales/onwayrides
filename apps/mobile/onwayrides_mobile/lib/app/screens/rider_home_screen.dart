import 'package:flutter/material.dart';

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
                    trailing: CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white10,
                      child: Icon(Icons.notifications_none_rounded),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _HeroCard(onOpenBooking: onOpenBooking),
                  const SizedBox(height: 16),
                  const _SignalRow(),
                  const SizedBox(height: 24),
                  SectionHeading(
                    title: 'Quick services',
                    subtitle:
                        'Book fast, negotiate where needed, and keep every service inside one premium flow.',
                    action: TextButton(
                      onPressed: () => onOpenBooking(),
                      child: const Text('Plan a trip'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ServiceGrid(
                    services: services,
                    onTap: onOpenBooking,
                  ),
                  const SizedBox(height: 24),
                  if (activeTrip != null) ...[
                    SectionHeading(
                      title: 'Active booking',
                      subtitle: activeTrip!.statusLine,
                      action: TextButton(
                        onPressed: () => onOpenTracking(activeTrip),
                        child: const Text('Track ride'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    OnWayPanel(
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
                                      activeTrip!.serviceTitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${activeTrip!.pickup} -> ${activeTrip!.destination}',
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
                                  activeTrip!.fareLabel,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(color: OnWayTheme.yellow),
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
                                backgroundImage:
                                    AssetImage(activeTrip!.driver.avatarAsset),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(activeTrip!.driver.name),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${activeTrip!.driver.vehicle}\n${activeTrip!.driver.eta}',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.tonal(
                                onPressed: () => onOpenTracking(activeTrip),
                                child: const Text('Open'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  SectionHeading(
                    title: 'Built for local travel',
                    subtitle:
                        'Affordable pricing, familiar vehicles, and service design tuned for local markets.',
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: const [
                      _ShowcaseCard(
                        width: 340,
                        title: 'School, office and family routines',
                        subtitle:
                            'Set recurring pickups, trusted drivers, and simple cash-first checkout.',
                        imageAsset: 'assets/showcase/rider_passenger.png',
                      ),
                      _ShowcaseCard(
                        width: 340,
                        title: 'One app for rides, food and courier',
                        subtitle:
                            'Scale from a quick ride to intercity bookings without changing apps.',
                        imageAsset: 'assets/showcase/app_mockup.png',
                      ),
                    ],
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onOpenBooking});

  final Future<void> Function([OnWayService? service]) onOpenBooking;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        image: const DecorationImage(
          image: AssetImage('assets/showcase/hero_banner.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.black.withValues(alpha: 0.82),
              Colors.black.withValues(alpha: 0.38),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text('Lahore | Cash first | Driver offers'),
            ),
            const Spacer(),
            Text(
              'Your ride.\nYour way.',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Modern local mobility for rides, food, rentals, courier, airport, school transport, and prebookings.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            InkWell(
              onTap: () => onOpenBooking(),
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: OnWayTheme.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: OnWayTheme.black),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Where to?',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: OnWayTheme.black,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_rounded, color: OnWayTheme.black),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth > 720
            ? (constraints.maxWidth - 24) / 3
            : constraints.maxWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SignalCard(
              width: width,
              title: '11 services',
              subtitle: 'Rides, food, courier, airport, school, and rentals',
            ),
            _SignalCard(
              width: width,
              title: 'Cash-first',
              subtitle: 'Built for trust and affordability before full wallet rollout',
            ),
            _SignalCard(
              width: width,
              title: 'Fleet-ready',
              subtitle: 'Driver mode and fleet operations share one system',
            ),
          ],
        );
      },
    );
  }
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({
    required this.width,
    required this.title,
    required this.subtitle,
  });

  final double width;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: OnWayPanel(
        padding: const EdgeInsets.all(16),
        backgroundColor: OnWayTheme.slate,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid({
    required this.services,
    required this.onTap,
  });

  final List<OnWayService> services;
  final Future<void> Function([OnWayService? service]) onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth > 780
            ? (constraints.maxWidth - 32) / 3
            : (constraints.maxWidth - 16) / 2;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final service in services)
              SizedBox(
                width: width,
                child: ServiceCard(
                  service: service,
                  onTap: () => onTap(service),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ShowcaseCard extends StatelessWidget {
  const _ShowcaseCard({
    required this.width,
    required this.title,
    required this.subtitle,
    required this.imageAsset,
  });

  final double width;
  final String title;
  final String subtitle;
  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: OnWayPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 1.5,
                child: Image.asset(imageAsset, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
