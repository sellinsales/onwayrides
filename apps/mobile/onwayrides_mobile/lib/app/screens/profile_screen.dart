import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/onway_auth_session.dart';
import '../onway_links.dart';
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
    final accountPhone = session?.phone;
    final accountSubtitle = previewMode
        ? 'Preview account'
        : '${session?.roleLabel ?? 'Rider'} account';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
        children: [
          const BrandHeader(
            caption: 'Your account, support, and saved details',
          ),
          const SizedBox(height: 20),
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
                          if (accountPhone != null &&
                              accountPhone.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              accountPhone,
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
                      label: session?.phoneVerified == true
                          ? 'Phone verified'
                          : 'Phone not verified',
                      selected: false,
                    ),
                    ModeChip(
                      label: session?.statusLabel ?? 'Active',
                      selected: false,
                    ),
                  ],
                ),
                if (session != null) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Contact details',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    accountEmail ?? 'No email added',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    accountPhone ?? 'No phone number added',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Quick shortcuts',
            subtitle: 'The things you may need most often.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ShortcutCard(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Wallet',
                subtitle: 'Cash now, cards later',
                onTap: () {},
              ),
              _ShortcutCard(
                icon: Icons.place_outlined,
                title: 'Saved places',
                subtitle: 'Home, office, airport',
                onTap: () {},
              ),
              _ShortcutCard(
                icon: Icons.support_agent_rounded,
                title: 'Support',
                subtitle: 'Help and complaints',
                onTap: () => _openExternalLink(
                  context,
                  OnWayLinks.supportCenter,
                  fallback: OnWayLinks.supportEmail,
                ),
              ),
              _ShortcutCard(
                icon: Icons.groups_rounded,
                title: 'Fleet center',
                subtitle: 'Business and fleet access',
                onTap: onOpenFleetOwner,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SectionHeading(
            title: 'Trust and policies',
            subtitle: 'Important account information and support links.',
          ),
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.policy_outlined,
            title: 'Privacy policy',
            subtitle:
                'Learn how your account and trip information are handled.',
            onTap: () => _openExternalLink(context, OnWayLinks.privacyPolicy),
          ),
          _ActionTile(
            icon: Icons.gavel_rounded,
            title: 'Terms of service',
            subtitle: 'Read the rules for using OnWay services.',
            onTap: () => _openExternalLink(context, OnWayLinks.termsOfService),
          ),
          _ActionTile(
            icon: Icons.delete_outline_rounded,
            title: 'Delete account and data',
            subtitle: 'Request account deletion or data removal.',
            onTap: () => _openExternalLink(
              context,
              OnWayLinks.deleteAccount,
              fallback: OnWayLinks.deleteAccountEmail,
            ),
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
                  ? 'Use this preview to explore the account layout and shortcuts.'
                  : 'Keep your phone number current so drivers and support can reach you when needed.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
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
    return SizedBox(
      width: MediaQuery.sizeOf(context).width > 560 ? 180 : 158,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: OnWayTheme.charcoal,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: OnWayTheme.yellow),
              ),
              const SizedBox(height: 14),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _openExternalLink(
  BuildContext context,
  Uri uri, {
  Uri? fallback,
}) async {
  final messenger = ScaffoldMessenger.of(context);

  if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    return;
  }

  if (fallback != null &&
      await launchUrl(fallback, mode: LaunchMode.externalApplication)) {
    return;
  }

  messenger.showSnackBar(
    const SnackBar(
      content: Text(
        'Unable to open the link right now. Please try again later.',
      ),
    ),
  );
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
