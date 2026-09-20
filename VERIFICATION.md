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

Live Firebase project setup, real Google OAuth testing, actual email delivery, production signing, and cloud deployment were deferred for the original delivery. Later local setup connected a live Firebase project, but deployed booking Functions still require Blaze billing.

## ITD room catalog update — 2026-09-20

The app now lists 18 named rooms from the official ITD classroom and computer-room pages: nine classrooms, four general computer rooms, three teaching-preparation rooms, one server room, and one Pearson VUE exam room. The 13 general rooms are eligible for app booking; the five specialized rooms are information-only. The pages do not provide capacity or equipment data, so those fields remain unset. Room photos load from their original ITD URLs.

`flutter analyze --no-pub` and `flutter test --no-pub` passed. Backend unit tests and nine Firebase-emulator integration tests passed, including an eligible ITD computer-room reservation and rejection of specialized/disabled rooms. The emulator seed created 18 catalog documents plus six retained legacy demo documents in a fresh emulator. The Android integration test passed registration → verification → Classroom 3A02 reservation → My Bookings → cancellation, plus the simulated Google flow, on `IBIT_Rooms_Test`. The main app was installed on the same emulator, and its room cards displayed the official ITD classroom photos. A screenshot is at `artifacts/itd-rooms-screen.png`. `flutter build apk --debug --no-pub --dart-define=FIREBASE_MODE=emulator` passed.

## ITD visual theme update — 2026-09-20

The app now uses the official ITD header wordmark and emblem from the faculty's logo page, the website's navy/white/orange palette, and the Mitr font. The launcher icon uses the official emblem. Auth, Rooms, My Bookings, Account, room details, and reservation states share the updated theme. `flutter analyze --no-pub`, all 22 Flutter tests, and the Android integration flow passed after the theme change. The emulator screenshot is at `artifacts/ibit-theme-preview.png`. The emulator-mode APK is `artifacts/ibit-rooms-itd-debug.apk`.
