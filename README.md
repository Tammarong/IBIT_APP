# IBIT Rooms

An Android-first Flutter app with the ITD faculty's official room catalog and room reservations. Browse 18 listed spaces, select arbitrary minute-level times for the 13 general classrooms and computer rooms, and manage your own reservations. Teaching-preparation rooms, the server room, and the Pearson VUE exam room are shown for information only.

Local development uses **Firebase emulators**. The workspace is also configured for the live Firebase project `ibit-rooms-20260914`; Email/Password and Google Sign-in are enabled there, with Android and Web OAuth clients provisioned. Cloud Functions deployment remains a separate step that requires Blaze billing.

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

The local project is `demo-ibit-reservations`. Open the [Firebase Emulator UI](http://127.0.0.1:4000) to inspect accounts, room metadata, reservations, and function logs. Ports are Auth `9099`, Firestore `8080`, Functions `5001`, UI `4000`. The app accesses your computer through `10.0.2.2` on Android emulators.

### Sign in and reserve a room

1. Create an email/password account in the app. Open its verification link from the Firebase terminal or Emulator UI logs, then tap **I’ve verified my email**. No real email is sent in emulator mode. Password reset links work the same way.
2. Alternatively, tap **Try simulated Google account** to use a verified local development account immediately.
3. Choose a weekday and one of the 13 reservable classrooms or computer rooms. Select custom start/end times, enter a purpose, and review the reservation.
4. Confirm, then open **My Bookings**. Cancel before the start time to release the room.

Bookings run Monday–Friday within **08:00–12:00** or **13:00–16:00**, in **Asia/Bangkok (UTC+7)** regardless of the phone’s timezone. One booking cannot cross lunch. Adjacent reservations are permitted. Past starts, overlapping reservations, invalid dates, and unverified booking attempts are rejected by the server. Date selection currently supports the next ten calendar years.

### Debug APK and physical phones

Build an APK with `flutter build apk --debug --dart-define=FIREBASE_MODE=emulator`. The output is `build/app/outputs/flutter-apk/app-debug.apk`; the room-catalog build is copied to `artifacts/ibit-rooms-itd-debug.apk`. It is a local development build and needs the running Firebase emulators. The older `artifacts/ibit-rooms-debug.apk` predates the ITD room catalog.

To use an Android phone connected over USB, keep the Firebase services bound to localhost, forward their ports, and build with the device-local host:

```powershell
adb reverse tcp:9099 tcp:9099
adb reverse tcp:8080 tcp:8080
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

Firestore stores `rooms/{roomId}`, private `reservations/{id}`, and shared `roomDays/{roomId}_{date}` availability. Daily availability contains opaque reservation IDs and intervals, never names, email addresses, or purposes. Only the owner can read a private reservation. Direct client writes are denied.

`createReservation({requestId,roomId,date,startMinute,endMinute,purpose})` and `cancelReservation({reservationId})` return `{reservation}`. The backend derives ownership from the authentication token. A transaction locks the deterministic room/day record and writes the booking together, preventing concurrent first bookings from overlapping. The client retains request IDs for unchanged retries after a lost response. Cancellation atomically releases availability and keeps booking history.

The catalog was transcribed from the official [classroom](https://www.itd.kmutnb.ac.th/class-room.php) and [computer-room](https://www.itd.kmutnb.ac.th/computer-room.php) pages. Room cards load their photos from those pages, so the photos need internet access. The pages do not list capacities, equipment, or individual room-booking policies; those details are not invented. The emulator seed creates 18 room documents without overwriting existing metadata or reservations. The older `room-01` through `room-06` demo documents are retained for booking history but hidden from the room browser. Firestore room metadata can be edited after seeding. For a bookable catalog room, the app enables Reserve only when its Firestore document exists with `bookingEnabled: true`; the callable backend also validates the room ID and this flag.

## Tests

See [VERIFICATION.md](VERIFICATION.md) for the completed checks and Android test environment.

```powershell
flutter analyze
flutter test
.\scripts\test-backend.ps1 -UseRunningEmulators
flutter drive --driver test_driver/integration_test.dart --target integration_test/app_flow_test.dart -d emulator-5554 --no-dds --dart-define=FIREBASE_MODE=emulator
```

The backend script without `-UseRunningEmulators` starts and stops temporary emulators; do not use it while another set occupies the same ports. Backend tests cover booking boundaries, concurrent conflicts, repeated request IDs, cancellation, and Firestore access rules. They clean up only their own temporary records. Flutter tests cover date/time rules, auth/verification, preserved form input, network errors, and layouts at 320px width with 200% text.

The Android integration test drives registration → local email verification → custom 08:10–09:35 reservation → confirmation → My Bookings → cancellation, checks Firestore availability, then tests the simulated Google provider with a callable booking. It creates a distinct local email account and cancelled history for inspection. Run the room seed first; this test is restricted to emulator mode.

Replace the device ID with the one reported by `flutter devices`. The driver with `--no-dds` avoids the local Dart Development Service startup issue. Rebuild with `flutter build apk --debug --dart-define=FIREBASE_MODE=emulator -t lib/main.dart` after integration testing because the test uses its own app entry point.

Android may log an optional Firebase Installations `FIS_AUTH_ERROR` for the deliberately fake local API key. Authentication, Firestore, and booking functions still use the configured emulators; the complete booking flow has been verified with this configuration.

## Connect a live Firebase project later

1. Create a dedicated **IBIT Rooms** project in the [Firebase console](https://console.firebase.google.com). Register Android package `com.ibit.rooms` and create a Firestore database in Singapore (`asia-southeast1`) to match the functions.
2. Enable Email/Password and Google in Authentication. Set the Google support email. Register your Android debug SHA-1 and SHA-256 fingerprints, and register the release fingerprints before distribution. Obtain them with `android/gradlew.bat -p android signingReport`.
3. Install and run FlutterFire configuration:

   ```powershell
   dart pub global activate flutterfire_cli
   flutterfire configure --project YOUR_PROJECT_ID --platforms android --android-package-name com.ibit.rooms
   ```

4. Copy `firebase.cloud.example.json` to `firebase.cloud.json`. Fill its Firebase identifiers from the generated Android options/configuration. Set `GOOGLE_SERVER_CLIENT_ID` to the **Web application OAuth client ID**, not the Android client ID. The app initializes from these Dart defines so it also compiles without a generated cloud configuration during local development. Firebase client identifiers are configuration, not administrator credentials; never put service-account private keys in the app.
5. Enable the Blaze plan for deployed Cloud Functions, then deploy to the explicit live project:

   ```powershell
   firebase deploy --project YOUR_PROJECT_ID --only firestore,functions
   flutter run -d YOUR_ANDROID_DEVICE --dart-define-from-file=firebase.cloud.json
   ```

6. Add the 18 room documents from `assets/rooms/itd_catalog.json` to live Firestore, including `bookingEnabled` and the metadata fields. The local seed deliberately cannot write to a live project. Until a room document exists, the app displays its official information but disables booking. Test real email verification and Google account selection on a Google Play-enabled device. Configure production signing before building a release APK or app bundle; the scaffold currently uses debug signing.

Official setup references: [FlutterFire configuration](https://firebase.google.com/docs/flutter/setup), [Google authentication](https://firebase.google.com/docs/auth/flutter/federated-auth), [Firebase emulators](https://firebase.google.com/docs/emulator-suite/connect_auth), and [Cloud Functions deployment](https://firebase.google.com/docs/functions/get-started).

The live project has Firestore, rules/indexes, six older demo room records, Email/Password authentication, Google Sign-in, and Android OAuth configuration. Its new ITD room documents and booking Functions still need to be deployed/configured before live reservations can work. Cloud Functions deployment requires Blaze billing; the emulator can be used without it.
