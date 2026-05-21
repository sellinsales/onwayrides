import 'package:flutter/material.dart';

import '../auth/onway_auth_session.dart';
import '../onway_theme.dart';
import '../onway_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.onOpenFleetOwner,
    this.session,
    this.onSignOut,
    this.previewMode = false,
  });

  final VoidCallback onOpenFleetOwner;
  final OnWayAuthSession? session;
  final Future<void> Function()? onSignOut;
  final bool previewMode;

  @override
  Widget build(BuildContext context) {
    final accountName = session?.fullName ?? 'Preview User';
    final accountEmail = session?.email;
    final accountSubtitle = previewMode
        ? 'Preview mode with mock rider and driver views'
        : '${session?.roleLabel ?? 'Rider'} account synced from Firebase and Laravel';

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
                          Text(
                            accountName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            accountSubtitle,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (accountEmail != null &&
                              accountEmail.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              accountEmail,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ModeChip(
                      label: session?.primaryModeLabel ?? 'Rider',
                      selected: true,
                    ),
                    ModeChip(
                      label: previewMode ? 'Preview' : 'Firebase Auth',
                      selected: false,
                    ),
                    ModeChip(
                      label: session?.statusLabel ?? 'Beta',
                      selected: false,
                    ),
                  ],
                ),
                if (session != null) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Beta access: ${session!.betaModeLabel} | ${session!.dailyRideLimitLabel}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
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
          if (onSignOut != null) ...[
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () {
                onSignOut!.call();
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
            ),
          ],
          const SizedBox(height: 24),
          OnWayPanel(
            child: Text(
              previewMode
                  ? 'Preview mode stays available for design review even when Firebase is not configured locally.'
                  : 'Firebase identity is now synced to the Laravel backend. Wallet, saved places, and support endpoints are the next mobile integration layer.',
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
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
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
