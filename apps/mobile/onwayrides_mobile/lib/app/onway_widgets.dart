import 'package:flutter/material.dart';

import 'onway_models.dart';
import 'onway_theme.dart';

class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    this.trailing,
    this.caption = 'Pakistan mobility super-app',
  });

  final Widget? trailing;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Image.asset('assets/brand/road_pin.png', width: 34, height: 34),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/brand/onwayrides_logo.png',
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    caption,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white54),
                  ),
                ],
              ),
            ],
          ),
        ),
        ...?trailing == null ? null : [trailing!],
      ],
    );
  }
}

class OnWayPanel extends StatelessWidget {
  const OnWayPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.backgroundColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? OnWayTheme.charcoal,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        ...?action == null ? null : [action!],
      ],
    );
  }
}

class ServiceCard extends StatelessWidget {
  const ServiceCard({super.key, required this.service, required this.onTap});

  final OnWayService service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [OnWayTheme.charcoal, Colors.black.withValues(alpha: 0.94)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: 1.2,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(service.imageAsset, fit: BoxFit.cover),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.38),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            service.icon,
                            color: OnWayTheme.yellow,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                service.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                service.subtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Tag(
                    label: service.eta,
                    backgroundColor: Colors.white10,
                    foregroundColor: Colors.white70,
                  ),
                  const SizedBox(width: 8),
                  if (service.negotiable)
                    const _Tag(
                      label: 'Offer fare',
                      backgroundColor: Color(0x29FFC107),
                      foregroundColor: OnWayTheme.yellow,
                    ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white54,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.delta,
  });

  final String label;
  final String value;
  final String delta;

  @override
  Widget build(BuildContext context) {
    return OnWayPanel(
      padding: const EdgeInsets.all(16),
      backgroundColor: OnWayTheme.slate,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            delta,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: OnWayTheme.yellow),
          ),
        ],
      ),
    );
  }
}

class ModeChip extends StatelessWidget {
  const ModeChip({super.key, required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? OnWayTheme.yellow : Colors.white10,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: selected ? OnWayTheme.black : Colors.white70,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
