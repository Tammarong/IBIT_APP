# IBIT Rooms

IBIT Rooms is an Android Flutter app for viewing 18 ITD faculty rooms and reserving the 13 general classrooms and computer rooms. The five preparation, server, and exam rooms are shown for information only. Reservations use Asia/Bangkok time, Monday–Friday, within **08:00–12:00** or **13:00–16:00**.

## Start from a new Windows computer

Follow **Steps 1–4** for the first run. This runs everything locally, including Firebase Authentication, Realtime Database, and booking Functions. It needs **no Firebase account, Firebase Console setup, Google Cloud free trial, or billing**. After it works, choose an optional live mode below.

### 1. Install the tools once

- [Git for Windows](https://git-scm.com/install/windows) to download the project. If you download a ZIP instead, Git is optional.
- [Flutter SDK](https://docs.flutter.dev/install/quick) **3.44 or newer**. Add Flutter's `bin` folder to PATH; the project requires Dart 3.12.2 or newer.
- [Android Studio and Android SDK](https://docs.flutter.dev/platform-integration/android/setup). In Android Studio's SDK Manager, install the Android SDK, Command-line Tools, Platform-Tools, and Android Emulator. Create a phone in **Device Manager** with a Google Play system image. Android Studio normally includes the Java runtime used by the project; otherwise install Java 21 or newer.
- [Node.js 22](https://nodejs.org/en/download) for the local booking Functions. Node installation includes `npm`. Install the [Firebase CLI](https://firebase.google.com/docs/cli) in PowerShell with `npm install -g firebase-tools`.

Open a **new PowerShell window** after installing the tools. Check them:

```powershell
flutter --version
node --version
npm --version
firebase --version
flutter doctor
flutter doctor --android-licenses
```

Follow any Android toolchain or license instructions printed by `flutter doctor`. The project is already a Flutter app; open this folder directly in Android Studio or VS Code.

### 2. Download the project and its dependencies

In PowerShell:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\All_Project" | Out-Null
Set-Location "$env:USERPROFILE\All_Project"
git clone https://github.com/Tammarong/IBIT_APP.git
Set-Location .\IBIT_APP
flutter pub get
npm --prefix functions ci
```

If you used **Code → Download ZIP** on GitHub, extract it to a folder, use `Set-Location 'C:\path\to\IBIT_APP'`, then run only the last two dependency commands. In the following steps, open each PowerShell terminal in the folder containing `pubspec.yaml`, `firebase.json`, and `scripts`.

### 3. Start an Android emulator

In Android Studio, open **Device Manager** and press the **Run ▶** button for your virtual phone. Wait until its Android home screen appears. Check the device ID:

```powershell
flutter devices
```

Look for a line such as `emulator-5554 • android-x64`. The ID may differ on your computer. You can also use `flutter emulators` to list virtual devices and `flutter emulators --launch YOUR_AVD_ID` to start one. Use the ID from **`flutter devices`** when running the app; an ADB network address such as `127.0.0.1:5557` is usually not the Flutter device ID.

### 4. Run the complete local reservation app

Open **two PowerShell terminals** in the project folder. In **terminal 1**, run this and leave it open until it prints **All emulators ready**:

```powershell
.\scripts\start-emulators.ps1
```

In **terminal 2**, run:

```powershell
.\scripts\run-android.ps1
```

If Flutter shows more than one Android device, select the ID from `flutter devices`:

```powershell
.\scripts\run-android.ps1 -Device emulator-5554
```

The second script adds the room catalog if needed, builds the app, installs it, and opens it on the Android emulator. The **Android emulator is a separate window**; terminal output saying “Installing” does not make that window appear if the virtual device was never started. The first Android build may take several minutes while Gradle downloads dependencies.

For the fastest booking test, tap **Try simulated Google account** in the local app. This is a labelled, verified test account. Or register with any test email and run the following from the project folder in another PowerShell terminal after registration:

```powershell
.\scripts\verify-local-email.ps1 -Email 'your-test-address@example.com'
```

Return to the app and tap **I’ve verified my email**. Local mode does **not** send a real email; verification and password-reset links appear in the Firebase terminal. Choose a weekday, open a general classroom or computer room, select start/end times, enter a purpose, and confirm. Open **My Bookings** to see or cancel it before it starts.

Open the [local Firebase Emulator UI](http://127.0.0.1:4000/) to inspect Auth users, `appData/rooms`, `appData/reservations`, and `appData/roomDays`. This is **local data on your computer**, not the Firebase Console. Press `q` in terminal 2 to stop `flutter run`; press `Ctrl+C` in terminal 1 to stop Firebase cleanly and save its state to `.emulator-data` for next time. On later runs, repeat Step 3 and the two commands in Step 4. You do not need to reinstall tools or dependencies each time.

To build a local test APK without launching Flutter, run `flutter build apk --debug --dart-define=FIREBASE_MODE=emulator`. The APK appears at `build/app/outputs/flutter-apk/app-debug.apk`. It still needs the local Firebase emulators running whenever it is used.

## Optional: use the live Firebase Console for browsing and sign-in

The existing project `ibit-rooms-20260914` has live Email/Password and Google providers and an 18-room Realtime Database catalog. Its included `android/app/google-services.json` contains client configuration, **not** administrator credentials. From a fresh checkout, create the ignored local config file and run:

```powershell
.\scripts\prepare-cloud-config.ps1
.\scripts\run-cloud-android.ps1
```

Pass `-Device emulator-5554` to the run script if multiple devices are connected. The config generator reads the included Android Firebase file and creates `firebase.cloud.json`; it does not overwrite a different existing config. Email registration sends a **real** verification email. On a new computer, Google sign-in also needs that computer's debug-signing SHA-1 and SHA-256 added to the Android app in Firebase Console; obtain them with `.\android\gradlew.bat -p android signingReport`. The [FlutterFire setup guide](https://firebase.google.com/docs/flutter/setup) explains the Android Firebase configuration.

This **cloud-only** build can browse rooms and sign in, but its Reserve action is disabled because booking Functions have not been deployed. It does not need a running local Firebase emulator. To build its APK, run `.\scripts\build-cloud-apk.ps1`; the result is `artifacts/ibit-rooms-live-debug.apk`.

## Optional: live accounts and rooms with a local booking server

The **hybrid debug mode** uses live Firebase Authentication and Realtime Database, while only the booking Functions run on your computer. It is intended for testing on an Android emulator attached to that computer. It is not a public booking service. A Google account with administrative access to `ibit-rooms-20260914` is required for the local server to write bookings. The server will refuse to start if those credentials cannot read the live room catalog.

1. Run `.\scripts\prepare-cloud-config.ps1`. Install the free [Google Cloud CLI](https://docs.cloud.google.com/sdk/docs/install-sdk), then run `gcloud auth application-default login YOUR_PROJECT_ADMIN_EMAIL --disable-quota-project`. Select the account with access to this Firebase project and grant the requested scope. This local credential setup **does not enable billing**. Ignore a Google Cloud *free-trial* page; it is not part of these steps. Never put credentials or service-account keys in the app or repository.
2. In **terminal 1**, run `.\scripts\start-hybrid-functions.ps1` and keep it open. It builds Functions, checks live database access, and starts **only** the Functions emulator on port `5001`. Do not also run `start-emulators.ps1` in this mode.
3. Once the server reports ready, run `.\scripts\enable-hybrid-booking.ps1` **once** in terminal 2. It changes only the `bookingEnabled` flags of the 13 eligible live rooms. If the server is not healthy, this script stops without changing the flags.
4. Start an Android emulator as in Step 3, then run `.\scripts\run-hybrid-android.ps1` in terminal 2. Pass `-Device YOUR_FLUTTER_DEVICE_ID` if necessary. Live accounts use real email verification or Google sign-in. Booking records and availability will appear in the [live Realtime Database](https://console.firebase.google.com/project/ibit-rooms-20260914/database/ibit-rooms-20260914-default-rtdb/data).

Build a hybrid debug APK with `.\scripts\build-hybrid-apk.ps1`; the result is `artifacts/ibit-rooms-hybrid-debug.apk`. **Installing the APK alone is not enough**: the local server must be running on this computer when the app opens. The Android emulator reaches it through `10.0.2.2:5001`. Keep port `5001` bound to localhost. Direct app writes to reservations and availability remain denied by `database.rules.json`; the local server independently verifies live Firebase ID tokens.

The project remains on the no-cost Spark plan. Local emulation does not require Blaze; [deploying Cloud Functions does](https://firebase.google.com/docs/functions/get-started). No free-trial or billing activation is needed for the local and hybrid instructions above.

## If something does not start

| What you see | What to check |
| --- | --- |
| `No supported devices found` | Start the phone in Android Studio Device Manager, run `flutter devices`, and pass its `emulator-####` ID to `-Device`. |
| Build/install messages but no phone window | Open Android Studio Device Manager and press **Run ▶** for the virtual phone. |
| Firebase port `4000`, `5001`, `9000`, or `9099` is taken | Stop the earlier Firebase terminal with `Ctrl+C`, then run only the server script for the mode you selected. |
| App says the connection is not configured | Local mode needs `start-emulators.ps1`; hybrid mode needs a healthy `start-hybrid-functions.ps1`; cloud mode needs `prepare-cloud-config.ps1`. Then tap **Try again**. |
| No verification email | Local mode uses `verify-local-email.ps1` or the link printed by the emulator. Live modes send real email; check the inbox/spam folder. |
| Hybrid server says live database access failed | Check which Google account Application Default Credentials use. It must have access to `ibit-rooms-20260914`; a Google Cloud free trial is **not** required. |

## Tests and project notes

From the project folder, `flutter analyze` and `flutter test` check the app. With emulators stopped, `.\scripts\test-backend.ps1` starts temporary services and runs backend tests; if the full local emulators are already running, use `.\scripts\test-backend.ps1 -UseRunningEmulators`. See [VERIFICATION.md](VERIFICATION.md) and [backend documentation](functions/README.md) for the tested booking rules and concurrency behavior.

The app uses Material 3 and the official ITD logo/theme. The 18 room names and photo URLs come from the ITD [classroom](https://www.itd.kmutnb.ac.th/class-room.php) and [computer-room](https://www.itd.kmutnb.ac.th/computer-room.php) pages. Unknown capacities and equipment are deliberately omitted. Room photos require internet access. Reservation times use whole-minute precision; past times, weekends, lunch crossings, conflicts, and unverified email accounts are rejected by the server. Adjacent bookings are allowed.

Realtime Database separates editable `appData/rooms/{roomId}`, private `appData/reservations/{id}`, and shared `appData/roomDays/{date}/{roomId}` availability. Shared availability contains only opaque IDs and times, not another user's identity or purpose. The backend uses an atomic transaction and idempotent request IDs; cancellation releases availability. The app has no payment, recurring-booking, notification, or administrator dashboard feature.
