import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/onway_auth_service.dart';
import '../auth/onway_auth_session.dart';
import '../auth/onway_firebase_bootstrap.dart';
import '../onway_app.dart';
import '../onway_theme.dart';
import '../onway_widgets.dart';

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
          return const _AuthLoadingScreen(
            message: 'Checking Firebase session...',
          );
        }

        final firebaseUser = snapshot.data;
        if (firebaseUser == null) {
          return _EmailAuthScreen(authService: widget.authService);
        }

        return FutureBuilder<OnWayAuthSession>(
          future: _sessionFor(firebaseUser),
          builder: (context, sessionSnapshot) {
            if (sessionSnapshot.connectionState == ConnectionState.waiting) {
              return const _AuthLoadingScreen(
                message: 'Syncing account with backend...',
              );
            }

            if (sessionSnapshot.hasError) {
              final message = sessionSnapshot.error is OnWayAuthException
                  ? (sessionSnapshot.error as OnWayAuthException).message
                  : 'Unable to sync the signed-in Firebase user with the backend.';

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

            return OnWayShell(
              session: sessionSnapshot.data,
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

  bool _registerMode = false;
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
              children: [
                const BrandHeader(
                  caption: 'Firebase auth for rider beta access',
                ),
                const SizedBox(height: 28),
                OnWayPanel(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _registerMode
                              ? 'Create rider beta account'
                              : 'Sign in to OnWay Rides',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _registerMode
                              ? 'Create a Firebase account, then the backend will sync your rider profile automatically.'
                              : 'Use your Firebase email and password. The app will sync your user record with Laravel after sign-in.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        if (_registerMode)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
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
                          padding: const EdgeInsets.only(bottom: 14),
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
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.red.shade300),
                          ),
                        ],
                        const SizedBox(height: 20),
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
                        const SizedBox(height: 14),
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
                                : 'Need rider beta access? Create an account',
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
                        'Beta access policy',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Free beta users can currently test the rider app with a maximum of 3 rides per day.',
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Drivers and operational users require document approval before broader access is enabled.',
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
                      caption: 'Firebase setup required for sign-in',
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Firebase auth is not active in this local build.',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      bootstrap.message ??
                          'Add your real Firebase values to lib/firebase_options.dart or run flutterfire configure for this app.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 18),
                    const Text('What to do next:'),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Run flutterfire configure inside apps/mobile/onwayrides_mobile',
                    ),
                    const Text(
                      '2. Make sure Web and Android apps use the real OnWay Rides Firebase project',
                    ),
                    const Text(
                      '3. Point the mobile app backend URL to the Laravel API',
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.tonal(
                          onPressed: onContinuePreview,
                          child: const Text('Continue preview mode'),
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
                    'Signed in to Firebase, but backend sync failed.',
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
                        child: const Text('Retry sync'),
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
