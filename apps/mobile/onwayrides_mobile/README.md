# OnWay Rides Mobile

Flutter mobile app for OnWay Rides with:

- rider-facing booking UI
- driver mode and fleet preview flows
- Firebase email/password auth
- Laravel backend user sync using Firebase ID tokens

## Current auth flow

1. user signs in or creates an account with Firebase Auth
2. app requests a Firebase ID token
3. app sends that token to Laravel `POST /api/auth/login`
4. Laravel verifies the token and syncs the local `users` record
5. app receives the synced local user payload and opens the main shell

## Required local setup

Inside `apps/mobile/onwayrides_mobile`:

1. install Flutter dependencies

   ```bash
   flutter pub get
   ```

2. generate real Firebase options

   ```bash
   flutterfire configure
   ```

   or replace the placeholder values in `lib/firebase_options.dart`

3. point the app to your backend API

   ```bash
   flutter run --dart-define=ONWAYRIDES_API_BASE_URL=http://10.0.2.2:8000/api
   ```

   Example production value:

   ```bash
   flutter run --dart-define=ONWAYRIDES_API_BASE_URL=https://api.onwayrides.com/api
   ```

4. if Google sign-in is enabled on Android, register your signing
   certificates in Firebase before testing it

   - Open Firebase Console for project `onwayrides`
   - Go to `Project settings` -> `Your apps` -> Android app `com.onway.rides`
   - Add the SHA-1 and SHA-256 fingerprints for every key you use:
     debug keystore, upload keystore, and Play App Signing key if Play signs
     release builds
   - Download the refreshed `google-services.json`
   - Replace `android/app/google-services.json`

   Example debug keystore command:

   ```bash
   keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore
   ```

   If Google login shows a package certificate error, the Android app is
   missing one of those SHA fingerprints in Firebase.

## Notes

- Android and Web are the Firebase-configured target platforms in this repo
- preview mode still exists when Firebase config is missing, so UI review is not blocked
- driver and fleet onboarding still require additional backend endpoints after auth

## Shared demo driver

The backend seed now includes a shared approved driver profile:

- email: `demo.driver@onwayrides.com`
- role: `driver`
- city: `Lahore`
- status: `active`
- onboarding: `approved`

Important:

- This account is intended for QA demos, not production operations.
- If the matching Firebase Auth user does not exist yet, create it once with the same email using the app register flow or Firebase Console.
- On first sign-in, Laravel will bind that Firebase identity to the seeded approved driver record automatically.
- Multiple testers can use it, but they will share the same live driver state, current booking state, and push notifications.
