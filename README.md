# IBIT Rooms

An Android-first Flutter app with the ITD faculty's official room catalog and room reservations. Browse 18 listed spaces, select arbitrary minute-level times for the 13 general classrooms and computer rooms, and manage your own reservations. Teaching-preparation rooms, the server room, and the Pearson VUE exam room are shown for information only.

The app now has a **live Firebase Spark setup** in project `ibit-rooms-20260914` alongside its local emulator setup. Live Email/Password and Google sign-in are enabled, and the live Realtime Database in Singapore holds the 18 room records. Live booking is currently disabled: the secure reservation Functions cannot be deployed on Spark. No billing plan was enabled.

## Run with live Firebase (no emulators)

Start an Android emulator or connect an Android device, then run:

```powershell
.\scripts\run-cloud-android.ps1
```

If several Android devices are connected, use `-Device <device-id>` from `flutter devices`. This uses the local, git-ignored `firebase.cloud.json` and connects to the live Firebase project. Registration sends a real verification email. Google sign-in uses the real Google provider; the current machine's debug signing SHA-1 and SHA-256 are registered. No Firebase emulator terminal is needed.

To make a shareable debug APK for this live configuration:

```powershell
.\scripts\build-cloud-apk.ps1
```

Install `artifacts/ibit-rooms-live-debug.apk`. Room browsing and sign-in use live Firebase. The reservation button is intentionally hidden until a secure production booking backend is available; the My Bookings list will be empty for new live accounts. The older `artifacts/ibit-rooms-itd-debug.apk` is an emulator build and still needs local services.

## Run locally on Windows

Requirements: Flutter 3.44 or newer with Dart 3.12, Android Studio/SDK, a running Android emulator, Node.js 22, Firebase CLI, and Java 21. The scripts can find Android Studio’s bundled Java. Check your environment with `flutter doctor`.

Install project dependencies once:

```powershell
flutter pub get
npm --prefix functions ci
```

In terminal 1, start the Firebase services and keep this terminal open:

```powershell
.\scripts\start-emulators.ps1
```

In terminal 2, launch an Android emulator if needed, then run the app:

```powershell
flutter emulators
flutter emulators --launch IBIT_Rooms_Test
.\scripts\run-android.ps1
```

`IBIT_Rooms_Test` is the dedicated Android virtual device created on this computer. On another computer, replace it with an AVD name from `flutter emulators`. The run script automatically selects a single connected Android device; when several are connected, use `flutter devices` and pass `-Device <device-id>`. It creates only missing room records and preserves edited room metadata and bookings. Press `Ctrl+C` in the Firebase terminal for a graceful shutdown; its data is exported to `.emulator-data` and restored on the next startup.

The local project is `demo-ibit-reservations`. Open the [Firebase Emulator UI](http://127.0.0.1:4000/database) to inspect Realtime Database room metadata, reservations, and availability. Accounts are under Auth and function logs under Functions. Ports are Auth `9099`, Realtime Database `9000`, Functions `5001`, UI `4000`. The app accesses your computer through `10.0.2.2` on Android emulators.

### Sign in and reserve a room

1. Create an email/password account in the app. No real email is sent in emulator mode. Open the verification link printed in the Firebase terminal, or run `.\scripts\verify-local-email.ps1 -Email 'your-address@example.com'` from the project folder. Then tap **I’ve verified my email** in the app. If the command finds no pending link, tap **Resend verification email** in the app and retry. Password reset links appear in the emulator terminal.
2. Alternatively, tap **Try simulated Google account** to use a verified local development account immediately.
3. Choose a weekday and one of the 13 reservable classrooms or computer rooms. Select custom start/end times, enter a purpose, and review the reservation.
4. Confirm, then open **My Bookings**. Cancel before the start time to release the room.

Bookings run Monday–Friday within **08:00–12:00** or **13:00–16:00**, in **Asia/Bangkok (UTC+7)** regardless of the phone’s timezone. One booking cannot cross lunch. Adjacent reservations are permitted. Past starts, overlapping reservations, invalid dates, and unverified booking attempts are rejected by the server. Date selection currently supports the next ten calendar years.

### Debug APK and physical phones

Build an APK with `flutter build apk --debug --dart-define=FIREBASE_MODE=emulator`. The output is `build/app/outputs/flutter-apk/app-debug.apk`; the current Realtime Database build is copied to `artifacts/ibit-rooms-itd-debug.apk`. It is a local development build and needs the running Firebase emulators. The older `artifacts/ibit-rooms-debug.apk` predates the ITD room catalog.

To use an Android phone connected over USB, keep the Firebase services bound to localhost, forward their ports, and build with the device-local host:

```powershell
adb reverse tcp:9099 tcp:9099
adb reverse tcp:9000 tcp:9000
adb reverse tcp:5001 tcp:5001
flutter run -d YOUR_DEVICE_ID --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1
```

Profile and release builds refuse emulator mode. Simulated Google credentials are restricted to a compile-time debug-only branch. Debug Android manifests allow local HTTP; the main/release manifest does not enable cleartext traffic.

## Implementation

- `lib/features`: authentication, room browsing, reservation/review/confirmation, booking history, and account screens.
- `lib/data`: repository interfaces, Firebase implementations, and models. Controllers use `ChangeNotifier`.
- `lib/core`: theme, Firebase environment configuration, and shared Bangkok calendar rules.
- `functions`: TypeScript callable backend and tests; see [backend documentation](functions/README.md).
- `assets/rooms/itd_catalog.json`: the 18 official room names, categories, floors, photo URLs, source pages, and booking eligibility. Six older demo illustrations remain in `assets/rooms`; their provenance is in [assets/README.md](assets/README.md).
- `assets/branding`: the official ITD faculty wordmark and emblem, with source details in [branding notes](assets/branding/README.md). The interface uses the website's navy/orange/white palette and bundled Mitr font.

Realtime Database stores `appData/rooms/{roomId}`, private `appData/reservations/{id}`, and shared `appData/roomDays/{date}/{roomId}` availability. Daily availability contains opaque reservation IDs and intervals, never names, email addresses, or purposes. Security Rules permit a user to query only their own reservations. Direct client writes are denied. Firebase Authentication keeps account credentials separately; passwords are never stored in the database.

`createReservation({requestId,roomId,date,startMinute,endMinute,purpose})` and `cancelReservation({reservationId})` return `{reservation}`. The backend derives ownership from the authentication token. A Realtime Database transaction updates the private booking and shared availability together, preventing concurrent first bookings from overlapping. The client retains request IDs for unchanged retries after a lost response. Cancellation atomically releases availability and keeps booking history.

The catalog was transcribed from the official [classroom](https://www.itd.kmutnb.ac.th/class-room.php) and [computer-room](https://www.itd.kmutnb.ac.th/computer-room.php) pages. Room cards load their photos from those pages, so the photos need internet access. The pages do not list capacities, equipment, or individual room-booking policies; those details are not invented. The emulator seed creates 18 room records without overwriting existing metadata or reservations. The older `room-01` through `room-06` demo records are retained for booking history but hidden from the room browser. Realtime Database room metadata can be edited after seeding. For a bookable catalog room, the app enables Reserve only when its database record exists with `bookingEnabled: true` and a booking backend is configured for that build; the callable backend also validates the room ID and this flag.

## Tests

See [VERIFICATION.md](VERIFICATION.md) for the completed checks and Android test environment.

```powershell
flutter analyze
flutter test
.\scripts\test-backend.ps1 -UseRunningEmulators
flutter drive --driver test_driver/integration_test.dart --target integration_test/app_flow_test.dart -d emulator-5554 --no-dds --dart-define=FIREBASE_MODE=emulator
```

The backend script without `-UseRunningEmulators` starts and stops temporary emulators; do not use it while another set occupies the same ports. Backend tests cover booking boundaries, concurrent conflicts, repeated request IDs, cancellation, and Realtime Database access rules. They clean up only their own temporary records. Flutter tests cover date/time rules, auth/verification, preserved form input, network errors, and layouts at 320px width with 200% text.

The Android integration test drives registration → local email verification → custom 08:10–09:35 reservation → confirmation → My Bookings → cancellation, checks Realtime Database availability, then tests the simulated Google provider with a callable booking. It creates a distinct local email account and cancelled history for inspection. Run the room seed first; this test is restricted to emulator mode.

Replace the device ID with the one reported by `flutter devices`. The driver with `--no-dds` avoids the local Dart Development Service startup issue. Rebuild with `flutter build apk --debug --dart-define=FIREBASE_MODE=emulator -t lib/main.dart` after integration testing because the test uses its own app entry point.

Android may log an optional Firebase Installations `FIS_AUTH_ERROR` for the deliberately fake local API key. Authentication, Realtime Database, and booking functions still use the configured emulators; the complete booking flow has been verified with this configuration.

## Live Firebase configuration and later booking deployment

1. The existing [IBIT Rooms project](https://console.firebase.google.com/project/ibit-rooms-20260914/overview) has Android package `com.ibit.rooms`, Email/Password and Google providers, and Realtime Database `ibit-rooms-20260914-default-rtdb` in `asia-southeast1`. Its exact URL is `https://ibit-rooms-20260914-default-rtdb.asia-southeast1.firebasedatabase.app`. Register release signing fingerprints before distribution; obtain them with `android/gradlew.bat -p android signingReport`.
2. The live [database rules](database.rules.json) were deployed with `firebase deploy --project ibit-rooms-20260914 --only database`. The rules deny direct reservation and availability writes. The 18 rooms were seeded with `.\scripts\seed-cloud-rooms.ps1`; this script preserves existing records on later runs. All live room records have `bookingEnabled: false` until the backend is deployed.
3. Install and run FlutterFire configuration:

   ```powershell
   dart pub global activate flutterfire_cli
   flutterfire configure --project YOUR_PROJECT_ID --platforms android --android-package-name com.ibit.rooms
   ```

4. This computer already has `firebase.cloud.json` filled with live client identifiers and the database URL. The file is git-ignored. On another computer, copy `firebase.cloud.example.json` to `firebase.cloud.json` and fill the identifiers. `GOOGLE_SERVER_CLIENT_ID` must be the **Web application OAuth client ID**, not the Android client ID. Firebase client identifiers are configuration, not administrator credentials; never put service-account private keys in the app.
5. If you later choose the Blaze plan, configure the Functions runtime with the same database URL, deploy the booking Functions, enable the 13 eligible room records, and build with `--dart-define=ENABLE_CLOUD_BOOKINGS=true`:

   ```powershell
   firebase deploy --project YOUR_PROJECT_ID --only database,functions
   flutter run -d YOUR_ANDROID_DEVICE --dart-define-from-file=firebase.cloud.json --dart-define=ENABLE_CLOUD_BOOKINGS=true
   ```

6. Test real email verification and Google account selection on a Google Play-enabled device. Configure production signing before building a release APK or app bundle; the scaffold currently uses debug signing.

Official setup references: [FlutterFire configuration](https://firebase.google.com/docs/flutter/setup), [Google authentication](https://firebase.google.com/docs/auth/flutter/federated-auth), [Firebase emulators](https://firebase.google.com/docs/emulator-suite/connect_auth), and [Cloud Functions deployment](https://firebase.google.com/docs/functions/get-started).

The old live Firestore setup remains separate from this Realtime Database build and receives no bookings from it. Live Authentication, Realtime Database, rules, and room records are configured; booking Functions are still local-only. Cloud Functions deployment requires Blaze billing; the local emulators work without it.
