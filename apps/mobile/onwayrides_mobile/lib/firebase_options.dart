import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Replace these placeholder values by running `flutterfire configure`
/// or by pasting the real Firebase app values for the OnWay Rides project.
class DefaultFirebaseOptions {
  static bool get supportsCurrentPlatform =>
      kIsWeb || defaultTargetPlatform == TargetPlatform.android;

  static bool get isConfiguredForCurrentPlatform {
    if (!supportsCurrentPlatform) {
      return false;
    }

    final options = currentPlatform;

    return !options.apiKey.startsWith('replace-') &&
        !options.appId.startsWith('replace-') &&
        !options.projectId.startsWith('replace-');
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'Firebase options are only configured for Android and Web in this repository.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'replace-me-web-api-key',
    appId: 'replace-me-web-app-id',
    messagingSenderId: 'replace-me-sender-id',
    projectId: 'replace-me-project-id',
    authDomain: 'replace-me-project-id.firebaseapp.com',
    storageBucket: 'replace-me-project-id.firebasestorage.app',
    measurementId: 'replace-me-measurement-id',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'replace-me-android-api-key',
    appId: 'replace-me-android-app-id',
    messagingSenderId: 'replace-me-sender-id',
    projectId: 'replace-me-project-id',
    storageBucket: 'replace-me-project-id.firebasestorage.app',
  );
}
