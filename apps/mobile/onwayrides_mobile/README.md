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

## Notes

- Android and Web are the Firebase-configured target platforms in this repo
- preview mode still exists when Firebase config is missing, so UI review is not blocked
- driver and fleet onboarding still require additional backend endpoints after auth
