import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/onway_auth_service.dart';
import '../auth/onway_auth_session.dart';
import '../onway_links.dart';
import '../onway_theme.dart';
import '../onway_widgets.dart';

class AccountCompletionScreen extends StatefulWidget {
  const AccountCompletionScreen({
    super.key,
    required this.session,
    required this.authService,
    required this.onCompleted,
    required this.onSignOut,
  });

  final OnWayAuthSession session;
  final OnWayAuthService authService;
  final ValueChanged<OnWayAuthSession> onCompleted;
  final Future<void> Function() onSignOut;

  @override
  State<AccountCompletionScreen> createState() =>
      _AccountCompletionScreenState();
}

class _AccountCompletionScreenState extends State<AccountCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _countryCodeController;
  late final TextEditingController _phoneController;
  late final TextEditingController _smsCodeController;

  bool _acceptPrivacyPolicy = false;
  bool _acceptTerms = false;
  bool _smsMarketingOptIn = false;
  bool _whatsappMarketingOptIn = false;
  bool _submitting = false;
  bool _sendingCode = false;
  bool _verifyingCode = false;
  bool _phoneVerified = false;
  String? _verifiedPhoneNumber;
  OnWayPhoneVerificationChallenge? _verificationChallenge;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.session.fullName);
    _countryCodeController = TextEditingController(
      text: widget.session.countryCode ?? '+92',
    );
    _phoneController = TextEditingController(
      text: _localPhone(widget.session.phone, widget.session.countryCode),
    );
    _smsCodeController = TextEditingController();
    _acceptPrivacyPolicy = widget.session.privacyPolicyAcceptedAt != null;
    _acceptTerms = widget.session.termsOfServiceAcceptedAt != null;
    _smsMarketingOptIn = widget.session.smsMarketingOptIn;
    _whatsappMarketingOptIn = widget.session.whatsappMarketingOptIn;
    _phoneVerified = widget.session.phoneVerified;
    _verifiedPhoneNumber = widget.session.phone;
    _countryCodeController.addListener(_handlePhoneInputsChanged);
    _phoneController.addListener(_handlePhoneInputsChanged);
  }

  @override
  void dispose() {
    _countryCodeController.removeListener(_handlePhoneInputsChanged);
    _phoneController.removeListener(_handlePhoneInputsChanged);
    _fullNameController.dispose();
    _countryCodeController.dispose();
    _phoneController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }

  void _handlePhoneInputsChanged() {
    final normalizedPhone = _normalizedPhoneOrNull();
    final verificationPhone = _verificationChallenge?.phoneNumber;

    if (_phoneVerified &&
        _verifiedPhoneNumber != null &&
        normalizedPhone != _verifiedPhoneNumber) {
      setState(() {
        _phoneVerified = false;
        _verifiedPhoneNumber = null;
        _verificationChallenge = null;
        _smsCodeController.clear();
      });
      return;
    }

    if (verificationPhone != null && normalizedPhone != verificationPhone) {
      setState(() {
        _verificationChallenge = null;
        _smsCodeController.clear();
      });
    }
  }

  Future<void> _sendCode() async {
    if (!_phoneFieldsLookValid()) {
      setState(() {
        _errorMessage = 'Enter a valid country code and phone number first.';
      });
      return;
    }

    setState(() {
      _sendingCode = true;
      _errorMessage = null;
    });

    try {
      final challenge = await widget.authService.startPhoneVerification(
        countryCode: _countryCodeController.text,
        phone: _phoneController.text,
        resendToken: _verificationChallenge?.resendToken,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _verificationChallenge = challenge;
        _phoneVerified = challenge.instantlyVerified;
        _verifiedPhoneNumber = challenge.instantlyVerified
            ? challenge.phoneNumber
            : null;
        if (challenge.instantlyVerified) {
          _smsCodeController.clear();
        }
      });
    } on OnWayAuthException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _sendingCode = false);
      }
    }
  }

  Future<void> _verifyCode() async {
    final challenge = _verificationChallenge;
    if (challenge == null) {
      setState(() {
        _errorMessage = 'Request a verification code first.';
      });
      return;
    }

    if (_smsCodeController.text.trim().length < 6) {
      setState(() {
        _errorMessage = 'Enter the 6-digit code you received.';
      });
      return;
    }

    setState(() {
      _verifyingCode = true;
      _errorMessage = null;
    });

    try {
      await widget.authService.confirmPhoneVerification(
        challenge: challenge,
        smsCode: _smsCodeController.text,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _phoneVerified = true;
        _verifiedPhoneNumber = challenge.phoneNumber;
        _smsCodeController.clear();
      });
    } on OnWayAuthException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _verifyingCode = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (widget.session.phoneVerificationRequired && !_phoneVerified) {
      setState(() {
        _errorMessage =
            'Verify your phone number with the OTP code before continuing.';
      });
      return;
    }

    if (!_acceptPrivacyPolicy || !_acceptTerms) {
      setState(() {
        _errorMessage =
            'You must accept the Privacy Policy and Terms of Service to continue.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final session = await widget.authService.completeProfile(
        fullName: _fullNameController.text,
        countryCode: _countryCodeController.text,
        phone: _phoneController.text,
        acceptPrivacyPolicy: _acceptPrivacyPolicy,
        acceptTerms: _acceptTerms,
        smsMarketingOptIn: _smsMarketingOptIn,
        whatsappMarketingOptIn: _whatsappMarketingOptIn,
      );

      widget.onCompleted(session);
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
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
              children: [
                BrandHeader(
                  caption: widget.session.needsPhoneNumber
                      ? 'Complete rider beta onboarding before entering the app'
                      : 'Confirm your phone and consent settings',
                  trailing: TextButton(
                    onPressed: _submitting ? null : () => widget.onSignOut(),
                    child: const Text('Sign out'),
                  ),
                ),
                const SizedBox(height: 24),
                OnWayPanel(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Complete your rider profile',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.session.phoneVerificationRequired
                              ? 'Google and email/password are the preferred beta login methods. Before you can request rides, OnWay Rides currently requires a verified phone number for operational contact, service updates, and any optional future marketing you explicitly allow.'
                              : 'Google and email/password are the preferred beta login methods. During this beta, add a working phone number for operational contact and future messaging. OTP verification is available, but not required until the full version rollout.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _fullNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                            hintText: 'Enter your full name',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().length < 3) {
                              return 'Enter your full name.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            SizedBox(
                              width: 110,
                              child: TextFormField(
                                controller: _countryCodeController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Code',
                                  hintText: '+92',
                                ),
                                validator: (value) {
                                  final normalized = value?.trim() ?? '';
                                  if (!RegExp(
                                    r'^\+?[0-9]{1,4}$',
                                  ).hasMatch(normalized)) {
                                    return 'Use +92';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Phone number',
                                  hintText: '3001234567',
                                ),
                                validator: (value) {
                                  final digits =
                                      value?.replaceAll(RegExp(r'\D+'), '') ??
                                      '';
                                  if (digits.length < 7 || digits.length > 15) {
                                    return 'Enter a real phone number.';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _phoneVerified
                              ? 'This phone number has been verified with Firebase and can now be saved to your OnWay Rides profile.'
                              : widget.session.phoneVerificationRequired
                              ? 'Send a verification code and confirm the OTP before you can continue.'
                              : 'Phone verification is optional during beta. You can continue without OTP for now and verify later for the full version.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (_phoneVerified)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0x29FFC107),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Phone verified',
                                  style: TextStyle(
                                    color: OnWayTheme.yellow,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            else
                              OutlinedButton.icon(
                                onPressed:
                                    (_sendingCode ||
                                        _verifyingCode ||
                                        _submitting)
                                    ? null
                                    : _sendCode,
                                icon: Icon(
                                  _verificationChallenge == null
                                      ? Icons.sms_outlined
                                      : Icons.refresh_rounded,
                                ),
                                label: Text(
                                  _sendingCode
                                      ? 'Sending...'
                                      : _verificationChallenge == null
                                      ? 'Send code'
                                      : 'Resend code',
                                ),
                              ),
                            if (!_phoneVerified &&
                                _verificationChallenge != null)
                              SizedBox(
                                width: 180,
                                child: TextFormField(
                                  controller: _smsCodeController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'OTP code',
                                    hintText: '6-digit code',
                                  ),
                                ),
                              ),
                            if (!_phoneVerified &&
                                _verificationChallenge != null)
                              FilledButton.tonalIcon(
                                onPressed:
                                    (_verifyingCode ||
                                        _sendingCode ||
                                        _submitting)
                                    ? null
                                    : _verifyCode,
                                icon: const Icon(Icons.verified_rounded),
                                label: Text(
                                  _verifyingCode
                                      ? 'Verifying...'
                                      : 'Verify code',
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _ConsentTile(
                          value: _acceptPrivacyPolicy,
                          title: 'I accept the Privacy Policy',
                          subtitle:
                              'Required. Covers Firebase auth, ride/location usage, support, and data handling.',
                          onChanged: (value) {
                            setState(
                              () => _acceptPrivacyPolicy = value ?? false,
                            );
                          },
                          onOpenLink: () => _openExternalLink(
                            context,
                            OnWayLinks.privacyPolicy,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _ConsentTile(
                          value: _acceptTerms,
                          title: 'I accept the Terms of Service',
                          subtitle:
                              'Required. Includes beta ride limits, account rules, and driver approval conditions.',
                          onChanged: (value) {
                            setState(() => _acceptTerms = value ?? false);
                          },
                          onOpenLink: () => _openExternalLink(
                            context,
                            OnWayLinks.termsOfService,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _ConsentTile(
                          value: _smsMarketingOptIn,
                          title: 'Allow promotional SMS updates',
                          subtitle:
                              'Optional. Service messages can still be sent when necessary for active trips or support.',
                          onChanged: (value) {
                            setState(() => _smsMarketingOptIn = value ?? false);
                          },
                        ),
                        const SizedBox(height: 10),
                        _ConsentTile(
                          value: _whatsappMarketingOptIn,
                          title: 'Allow WhatsApp marketing updates',
                          subtitle:
                              'Optional. Useful for launch offers, city announcements, and beta campaigns if you want them.',
                          onChanged: (value) {
                            setState(
                              () => _whatsappMarketingOptIn = value ?? false,
                            );
                          },
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.red.shade300),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _submitting ? null : _submit,
                          icon: const Icon(Icons.verified_user_outlined),
                          label: Text(
                            _submitting ? 'Saving...' : 'Save and continue',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const OnWayPanel(
                  backgroundColor: OnWayTheme.slate,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Beta access reminder',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Free beta users can currently try up to 3 rides per day.',
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Full operational access for drivers and broader rollout features stays gated behind document approval and later verification steps.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _phoneFieldsLookValid() {
    final countryCode = _countryCodeController.text.trim();
    final phone = _phoneController.text.trim();

    return RegExp(r'^\+?[0-9]{1,4}$').hasMatch(countryCode) &&
        (phone.replaceAll(RegExp(r'\D+'), '').length >= 7);
  }

  String? _normalizedPhoneOrNull() {
    if (!_phoneFieldsLookValid()) {
      return null;
    }

    return widget.authService.normalizePhoneNumber(
      countryCode: _countryCodeController.text,
      phone: _phoneController.text,
    );
  }
}

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.onChanged,
    this.onOpenLink,
  });

  final bool value;
  final String title;
  final String subtitle;
  final ValueChanged<bool?> onChanged;
  final VoidCallback? onOpenLink;

  @override
  Widget build(BuildContext context) {
    return Ink(
      decoration: BoxDecoration(
        color: OnWayTheme.slate,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox.adaptive(value: value, onChanged: onChanged),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  if (onOpenLink != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: onOpenLink,
                      child: const Text('Open policy'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _localPhone(String? fullPhone, String? countryCode) {
  if (fullPhone == null || fullPhone.isEmpty) {
    return '';
  }

  final normalizedCountry = (countryCode ?? '').trim();
  if (normalizedCountry.isNotEmpty && fullPhone.startsWith(normalizedCountry)) {
    return fullPhone.substring(normalizedCountry.length);
  }

  return fullPhone.replaceFirst(RegExp(r'^\+'), '');
}

Future<void> _openExternalLink(BuildContext context, Uri uri) async {
  if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    return;
  }

  if (!context.mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'Unable to open the policy link right now. Please try again later.',
      ),
    ),
  );
}
