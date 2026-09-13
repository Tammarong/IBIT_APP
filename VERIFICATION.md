# Delivery verification

Verified on 14 September 2026 with Flutter 3.44.4 / Dart 3.12.2, Node.js 22, Java 21, Firebase emulators for `demo-ibit-reservations`, and the dedicated `IBIT_Rooms_Test` Android API 36 emulator.

| Check | Result |
| --- | --- |
| `flutter analyze` | Passed, no issues |
| `flutter test --reporter expanded` | All 20 tests passed |
| Functions domain tests | All 10 tests passed |
| Functions / Firestore emulator integration tests | All 8 tests passed |
| Android end-to-end scenario via Flutter integration driver | Passed, process exit code 0 |
| Normal app debug APK from `lib/main.dart` | Built successfully |

The Android scenario creates an email/password account through the UI, retrieves and applies the local email-verification action, refreshes the verified authentication token, selects Room 01 and the next weekday, reserves 08:10–09:35, checks the confirmation and private Firestore record, opens My Bookings, cancels, and confirms that shared availability is released. It then signs out, signs in with the labelled simulated Google account, and creates and cancels another booking through the real mobile callable client.

Backend coverage includes exact opening boundaries, arbitrary whole minutes, invalid dates, weekends, past starts, lunch overlaps, adjacent bookings, different rooms, eight simultaneous overlapping requests with exactly one successful booking, five concurrent retries with a single reservation, changed retry payloads, cancellation before/after start, ownership, and forbidden private reads/direct writes. Shared availability never includes names, email addresses, or booking purposes.

Flutter widget tests cover authentication, email verification, password reset, retained form input after errors, offline catalog feedback and retry, empty booking states, cancellation, and 320×568 layouts with text enlarged to 200%. The Android run also verifies the native time picker and Firebase client integration.

The Windows debugger transport required a loopback ADB connection and the integration driver with DDS disabled. The successful command was:

```powershell
adb connect 127.0.0.1:5557
flutter drive --driver test_driver/integration_test.dart --target integration_test/app_flow_test.dart -d 127.0.0.1:5557 --no-dds --no-pub
```

The APK delivered in `artifacts/ibit-rooms-debug.apk` is rebuilt from the normal app entry point after the integration run. It requires the local Firebase emulators; see [README.md](README.md) for startup, physical-device forwarding, and later cloud configuration. Emulator state was exported to `.emulator-data` for the next startup.

APK SHA-256: `E866F963CF1ED3E2B603BF964E25B978D015096A5EDC5E46FBB0ADA23D9F7BD2` (211,025,215 bytes). The normal APK was installed and launched separately from the test app, and simulated sign-in and the room browser were visually inspected.

Live Firebase project setup, real Google OAuth testing, actual email delivery, production signing, and cloud deployment are deferred as specified. No live Firebase resources or billing were configured. The six illustrations and room descriptions are placeholders, with no assumed capacities or facilities.
