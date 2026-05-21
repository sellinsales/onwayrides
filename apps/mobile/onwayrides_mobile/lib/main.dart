import 'package:flutter/material.dart';

import 'app/auth/onway_auth_service.dart';
import 'app/auth/onway_firebase_bootstrap.dart';
import 'app/onway_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseBootstrap = await OnWayFirebaseBootstrap.initialize();

  runApp(
    OnWayApp(
      firebaseBootstrap: firebaseBootstrap,
      authService: OnWayAuthService(),
    ),
  );
}
