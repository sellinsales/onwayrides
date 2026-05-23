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
  apiKey: "AIzaSyCtZYFp9a3-Wl_4ykpC-erNuMsFb2EUFvs",
  authDomain: "onwayrides.firebaseapp.com",
  projectId: "onwayrides",
  storageBucket: "onwayrides.firebasestorage.app",
  messagingSenderId: "867042633205",
  appId: "1:867042633205:web:0540cb61e238caf22facbc",
  measurementId: "G-V9T4Y37VCT"
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCvFKRr2UEel4I8AQwlmfCSpGMEoqd7AUU',
    appId: '1:867042633205:android:246d7a2028095a312facbc',
    messagingSenderId: '867042633205',
    projectId: 'onwayrides',
    storageBucket: 'onwayrides.firebasestorage.app',
  );
}
