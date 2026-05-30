import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/onway_auth_service.dart';
import '../auth/onway_auth_session.dart';
import '../auth/onway_firebase_bootstrap.dart';
import '../onway_app.dart';
import '../onway_theme.dart';
import '../onway_widgets.dart';
import 'account_completion_screen.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({
    super.key,
    required this.firebaseBootstrap,
    required this.authService,
  });

  final OnWayFirebaseBootstrap firebaseBootstrap;
  final OnWayAuthService authService;

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  bool _previewMode = false;
  String? _sessionUid;
  Future<OnWayAuthSession>? _sessionFuture;

  Future<OnWayAuthSession> _sessionFor(User user) {
    if (_sessionFuture == null || _sessionUid != user.uid) {
      _sessionUid = user.uid;
      _sessionFuture = widget.authService.syncCurrentUser();
    }

    return _sessionFuture!;
  }

  Future<void> _signOut() async {
    await widget.authService.signOut();

    if (mounted) {
      setState(() {
        _sessionUid = null;
        _sessionFuture = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_previewMode) {
      return OnWayShell(
        authService: widget.authService,
        previewMode: true,
        onSignOut: () async {
          if (mounted) {
            setState(() => _previewMode = false);
          }
        },
      );
    }

    if (!widget.firebaseBootstrap.ready) {
      return _FirebaseSetupScreen(
        bootstrap: widget.firebaseBootstrap,
        onContinuePreview: () => setState(() => _previewMode = true),
      );
    }

    return StreamBuilder<User?>(
      stream: widget.authService.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _AuthLoadingScreen(message: 'Checking your account...');
        }

        final firebaseUser = snapshot.data;
        if (firebaseUser == null) {
          return _EmailAuthScreen(authService: widget.authService);
        }

        return FutureBuilder<OnWayAuthSession>(
          future: _sessionFor(firebaseUser),
          builder: (context, sessionSnapshot) {
            if (sessionSnapshot.connectionState == ConnectionState.waiting) {
              return const _AuthLoadingScreen(message: 'Finishing sign-in...');
            }

            if (sessionSnapshot.hasError) {
              final message = sessionSnapshot.error is OnWayAuthException
                  ? (sessionSnapshot.error as OnWayAuthException).message
                  : 'We could not finish signing you in right now.';

              return _AuthSyncErrorScreen(
                message: message,
                onRetry: () {
                  setState(() {
                    _sessionFuture = widget.authService.syncCurrentUser();
                  });
                },
                onSignOut: _signOut,
              );
            }

            final session = sessionSnapshot.data!;
            if (!session.profileComplete) {
              return AccountCompletionScreen(
                session: session,
                authService: widget.authService,
                onSignOut: _signOut,
                onCompleted: (updatedSession) {
                  if (mounted) {
                    setState(() {
                      _sessionFuture = Future<OnWayAuthSession>.value(
                        updatedSession,
                      );
                    });
                  }
                },
              );
            }

            return OnWayShell(
              authService: widget.authService,
              session: session,
              onSignOut: _signOut,
            );
          },
        );
      },
    );
  }
}

class _EmailAuthScreen extends StatefulWidget {
  const _EmailAuthScreen({required this.authService});

  final OnWayAuthService authService;

  @override
  State<_EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<_EmailAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _introController = PageController(viewportFraction: 0.92);

  bool _registerMode = false;
  bool _loading = false;
  int _introIndex = 0;
  String? _errorMessage;

  @override
  void dispose() {
    _introController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      if (_registerMode) {
        await widget.authService.registerRider(
          fullName: _fullNameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await widget.authService.signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
    } on OnWayAuthException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await widget.authService.signInWithGoogle();
    } on OnWayAuthException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                const BrandHeader(
                  caption: 'Rides, rentals, and delivery in one app',
                ),
                const SizedBox(height: 16),
                _IntroCarousel(
                  controller: _introController,
                  currentIndex: _introIndex,
                  onPageChanged: (value) {
                    setState(() => _introIndex = value);
                  },
                ),
                const SizedBox(height: 16),
                OnWayPanel(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _registerMode
                              ? 'Create your OnWay account'
                              : 'Sign in to OnWay Rides',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _registerMode
                              ? 'Create one account for rides, deliveries, and travel.'
                              : 'Sign in to book trips and manage rides quickly.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        if (_registerMode)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextFormField(
                              controller: _fullNameController,
                              decoration: const InputDecoration(
                                labelText: 'Full name',
                                hintText: 'Enter your full name',
                              ),
                              validator: (value) {
                                if (_registerMode &&
                                    (value == null ||
                                        value.trim().length < 3)) {
                                  return 'Enter the rider full name.';
                                }
                                return null;
                              },
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'you@example.com',
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || !value.contains('@')) {
                                return 'Enter a valid email address.';
                              }
                              return null;
                            },
                          ),
                        ),
                        TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            hintText: 'At least 6 characters',
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.length < 6) {
                              return 'Password must be at least 6 characters.';
                            }
                            return null;
                          },
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.red.shade300),
                          ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton.tonalIcon(
                          onPressed: _loading ? null : _signInWithGoogle,
                          icon: const Icon(Icons.g_mobiledata_rounded),
                          label: const Text('Continue with Google'),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                'or use email',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Colors.white.withValues(alpha: 0.16),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _loading ? null : _submit,
                          icon: Icon(
                            _registerMode
                                ? Icons.person_add_alt_1_rounded
                                : Icons.login_rounded,
                          ),
                          label: Text(
                            _loading
                                ? 'Working...'
                                : _registerMode
                                ? 'Create account'
                                : 'Sign in',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => setState(() {
                                  _registerMode = !_registerMode;
                                  _errorMessage = null;
                                }),
                          child: Text(
                            _registerMode
                                ? 'Already have an account? Sign in'
                                : 'New to OnWay? Create an account',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Use Google or email now. Add your phone number in the next step.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const OnWayPanel(
                  backgroundColor: OnWayTheme.slate,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Why people use OnWay',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Book everyday rides, airport transfers, rentals, and deliveries from one account.',
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Keep pickup details, trip progress, and support in one simple place.',
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
}

class _FirebaseSetupScreen extends StatelessWidget {
  const _FirebaseSetupScreen({
    required this.bootstrap,
    required this.onContinuePreview,
  });

  final OnWayFirebaseBootstrap bootstrap;
  final VoidCallback onContinuePreview;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: OnWayPanel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BrandHeader(
                      caption: 'Sign in to keep rides and support in one place',
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Sign-in is unavailable in this build right now.',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Please try a newer version of the app or continue with the preview experience for now.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.tonal(
                          onPressed: onContinuePreview,
                          child: const Text('Open app preview'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroCarousel extends StatelessWidget {
  const _IntroCarousel({
    required this.controller,
    required this.currentIndex,
    required this.onPageChanged,
  });

  final PageController controller;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    const slides = [
      (
        title: 'Book local rides fast',
        body:
            'Everyday rides, airport trips, and out-of-town travel from one app.',
        icon: Icons.local_taxi_rounded,
      ),
      (
        title: 'More than one kind of trip',
        body:
            'Switch between rentals, courier requests, and city travel with the same account.',
        icon: Icons.inventory_2_rounded,
      ),
      (
        title: 'Stay ready on the move',
        body:
            'Save your details once and come back faster whenever you need your next ride.',
        icon: Icons.route_rounded,
      ),
    ];

    return Column(
      children: [
        SizedBox(
          height: 168,
          child: PageView.builder(
            controller: controller,
            itemCount: slides.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final slide = slides[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index == slides.length - 1 ? 0 : 12,
                ),
                child: OnWayPanel(
                  padding: const EdgeInsets.all(14),
                  backgroundColor: OnWayTheme.slate,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0x29FFC107),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          slide.icon,
                          color: OnWayTheme.yellow,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        slide.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        slide.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            slides.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: currentIndex == index ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: currentIndex == index
                    ? OnWayTheme.yellow
                    : Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: OnWayPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/brand/onwayrides_logo.png',
                height: 28,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 18),
              const CircularProgressIndicator(color: OnWayTheme.yellow),
              const SizedBox(height: 16),
              Text(message),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthSyncErrorScreen extends StatelessWidget {
  const _AuthSyncErrorScreen({
    required this.message,
    required this.onRetry,
    required this.onSignOut,
  });

  final String message;
  final VoidCallback onRetry;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: OnWayPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'We signed you in, but could not load your account.',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text(message),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton(
                        onPressed: onRetry,
                        child: const Text('Try again'),
                      ),
                      FilledButton.tonal(
                        onPressed: () {
                          onSignOut();
                        },
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
