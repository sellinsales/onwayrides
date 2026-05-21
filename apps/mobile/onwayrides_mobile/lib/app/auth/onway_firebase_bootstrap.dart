import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

class OnWayFirebaseBootstrap {
  const OnWayFirebaseBootstrap({
    required this.supportedPlatform,
    required this.configured,
    required this.initialized,
    this.message,
  });

  final bool supportedPlatform;
  final bool configured;
  final bool initialized;
  final String? message;

  bool get ready => supportedPlatform && configured && initialized;

  static Future<OnWayFirebaseBootstrap> initialize() async {
    if (!DefaultFirebaseOptions.supportsCurrentPlatform) {
      return const OnWayFirebaseBootstrap(
        supportedPlatform: false,
        configured: false,
        initialized: false,
        message: 'Firebase auth is prepared for Android and Web in this repo.',
      );
    }

    if (!DefaultFirebaseOptions.isConfiguredForCurrentPlatform) {
      return const OnWayFirebaseBootstrap(
        supportedPlatform: true,
        configured: false,
        initialized: false,
        message:
            'Firebase is not configured yet. Run flutterfire configure or replace the placeholder values in lib/firebase_options.dart.',
      );
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      return const OnWayFirebaseBootstrap(
        supportedPlatform: true,
        configured: true,
        initialized: true,
      );
    } catch (error) {
      return OnWayFirebaseBootstrap(
        supportedPlatform: true,
        configured: true,
        initialized: false,
        message: 'Firebase initialization failed: $error',
      );
    }
  }
}
