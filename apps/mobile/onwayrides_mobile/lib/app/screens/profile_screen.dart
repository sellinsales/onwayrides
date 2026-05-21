import 'package:flutter/material.dart';

import '../onway_theme.dart';
import '../onway_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.onOpenFleetOwner});

  final VoidCallback onOpenFleetOwner;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
        children: [
          const BrandHeader(caption: 'Account, support and fleet access'),
          const SizedBox(height: 24),
          OnWayPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white10,
                      child: Icon(Icons.person_rounded, size: 32),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Muhammad Ahsan', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text(
                            'Cash-first rider profile with driver mode access',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: const [
                    ModeChip(label: 'Rider', selected: true),
                    ModeChip(label: 'Driver Mode', selected: false),
                    ModeChip(label: 'Fleet Eligible', selected: false),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Account shortcuts',
            subtitle: 'Keep the account area simple and extendable.',
          ),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Wallet',
            subtitle: 'Cash now, wallet and card rails later',
            onTap: () {},
          ),
          _ActionTile(
            icon: Icons.place_outlined,
            title: 'Saved places',
            subtitle: 'Home, office, school and airport shortcuts',
            onTap: () {},
          ),
          _ActionTile(
            icon: Icons.support_agent_rounded,
            title: 'Support',
            subtitle: 'Complaints, lost items and trip help',
            onTap: () {},
          ),
          _ActionTile(
            icon: Icons.groups_rounded,
            title: 'Fleet Owner center',
            subtitle: 'Open fleet dashboard, drivers and vehicles',
            onTap: onOpenFleetOwner,
          ),
          const SizedBox(height: 24),
          const OnWayPanel(
            child: Text(
              'TODO: connect profile, wallet, saved places and support flows to real backend endpoints once the new OnWay API surface is ready.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: OnWayTheme.charcoal,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: OnWayTheme.yellow),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}
