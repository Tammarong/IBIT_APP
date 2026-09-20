import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

abstract final class EmulatorConfig {
  static const mode = String.fromEnvironment(
    'FIREBASE_MODE',
    defaultValue: 'emulator',
  );
  static const enabled = mode == 'emulator';
  // Cloud booking remains off on Spark: the reservation callables are not deployed.
  static const cloudBookingsEnabled = bool.fromEnvironment(
    'ENABLE_CLOUD_BOOKINGS',
    defaultValue: false,
  );
  static const bookingsAvailable = enabled || cloudBookingsEnabled;
  static const region = 'asia-southeast1';
  static const canSimulateGoogle = kDebugMode && enabled;
  static String get host =>
      const String.fromEnvironment('FIREBASE_EMULATOR_HOST').isNotEmpty
      ? const String.fromEnvironment('FIREBASE_EMULATOR_HOST')
      : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? '10.0.2.2'
      : '127.0.0.1';

  static Future<void> initialize() async {
    if (mode != 'emulator' && mode != 'cloud') {
      throw StateError('FIREBASE_MODE must be emulator or cloud.');
    }
    if (!kDebugMode && enabled) {
      throw StateError(
        'Release and profile builds require FIREBASE_MODE=cloud.',
      );
    }
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_APP_ID');
    const senderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
    const databaseUrl = String.fromEnvironment('FIREBASE_DATABASE_URL');
    if (!enabled &&
        [
          projectId,
          apiKey,
          appId,
          senderId,
          databaseUrl,
        ].any((value) => value.isEmpty)) {
      throw StateError(
        'Cloud mode needs FIREBASE_PROJECT_ID, FIREBASE_API_KEY, '
        'FIREBASE_APP_ID, FIREBASE_MESSAGING_SENDER_ID and FIREBASE_DATABASE_URL. See README.md.',
      );
    }
    await Firebase.initializeApp(
      options: FirebaseOptions(
        // Android Functions also validates the API-key format locally. This
        // deliberately fake 39-character key works only with our demo project.
        apiKey: enabled ? 'AIza00000000000000000000000000000000000' : apiKey,
        appId: enabled ? '1:1234567890:android:0000000000000000' : appId,
        messagingSenderId: enabled ? '1234567890' : senderId,
        projectId: enabled ? 'demo-ibit-reservations' : projectId,
        authDomain: enabled
            ? 'demo-ibit-reservations.firebaseapp.com'
            : '$projectId.firebaseapp.com',
        storageBucket: enabled ? null : '$projectId.firebasestorage.app',
        databaseURL: enabled
            ? 'https://demo-ibit-reservations-default-rtdb.firebaseio.com'
            : databaseUrl,
      ),
    );
    if (enabled) {
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseDatabase.instance.useDatabaseEmulator(host, 9000);
      FirebaseFunctions.instanceFor(
        region: region,
      ).useFunctionsEmulator(host, 5001);
    }
  }
}
