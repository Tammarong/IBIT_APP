import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rooms/app.dart';
import 'package:rooms/core/booking_time.dart';
import 'package:rooms/core/firebase_config.dart';
import 'package:rooms/data/repositories.dart';
import 'package:rooms/features/rooms/rooms_screen.dart';

Future<Map<String, dynamic>> emulatorRequest(
  String path, {
  Map<String, dynamic>? body,
}) async {
  if (!EmulatorConfig.enabled) {
    throw StateError('This test may only use local Firebase emulators.');
  }
  final client = HttpClient();
  try {
    final uri = Uri.parse('http://${EmulatorConfig.host}:9099/$path');
    final request = body == null
        ? await client.getUrl(uri)
        : await client.postUrl(uri);
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close();
    final data =
        jsonDecode(await utf8.decoder.bind(response).join())
            as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw StateError('Emulator request failed: $data');
    }
    return data;
  } finally {
    client.close();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  setUpAll(() async {
    await EmulatorConfig.initialize();
  });

  testWidgets(
    'Android registration, verification, custom reservation, history, cancellation and Google simulation',
    (tester) async {
      await FirebaseAuth.instance.signOut();
      await tester.pumpWidget(const IbitApp());
      Future<void> waitFor(Finder finder) async {
        for (var i = 0; i < 120 && finder.evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        expect(finder, findsWidgets);
        await tester.pump(const Duration(milliseconds: 400));
      }

      Future<void> tapText(String text) async {
        final finder = find.text(text);
        if (finder.evaluate().isEmpty &&
            find.byType(Scrollable).evaluate().isNotEmpty) {
          await tester.scrollUntilVisible(
            finder,
            180,
            scrollable: find.byType(Scrollable).first,
          );
        }
        await waitFor(finder);
        await tester.ensureVisible(finder.first);
        await tester.pumpAndSettle();
        await tester.tap(finder.first);
        await tester.pump(const Duration(milliseconds: 400));
      }

      Future<void> enterTime(Key key, String hour, String minute) async {
        final finder = find.byKey(key);
        await tester.scrollUntilVisible(
          finder,
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
        final dialog = find.byType(TimePickerDialog);
        final fields = find.descendant(
          of: dialog,
          matching: find.byType(TextFormField),
        );
        await tester.enterText(fields.at(0), hour);
        await tester.enterText(fields.at(1), minute);
        if (find.text('AM').evaluate().isNotEmpty) {
          await tester.tap(find.text('AM').last);
        }
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      }

      final email =
          'ibit.flow.${DateTime.now().millisecondsSinceEpoch}@example.com';
      await tapText('New to IBIT Rooms? Create account');
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'IBIT Test Student',
      );
      await tester.enterText(find.byType(TextFormField).at(1), email);
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'Test-pass-2026',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tapText('Create account');
      await waitFor(find.text('One last step.'));
      expect(find.byType(RoomsScreen), findsNothing);

      // Emulated email delivery exposes the verification action code locally.
      Map<String, dynamic>? action;
      for (var i = 0; i < 30 && action == null; i++) {
        final codes = await emulatorRequest(
          'emulator/v1/projects/demo-ibit-reservations/oobCodes',
        );
        for (final value in codes['oobCodes'] as List? ?? []) {
          final candidate = Map<String, dynamic>.from(value as Map);
          if (candidate['email'] == email &&
              candidate['requestType'] == 'VERIFY_EMAIL') {
            action = candidate;
          }
        }
        if (action == null) {
          await tester.pump(const Duration(milliseconds: 200));
        }
      }
      expect(action, isNotNull);
      await emulatorRequest(
        'identitytoolkit.googleapis.com/v1/accounts:update?key=demo-api-key',
        body: {'oobCode': action!['oobCode']},
      );
      await tapText('I’ve verified my email');
      await waitFor(find.byType(RoomsScreen));
      expect(FirebaseAuth.instance.currentUser!.emailVerified, isTrue);

      // Select the next weekday after today so this scenario also works after 8 AM.
      var date = BookingTime.today().add(const Duration(days: 1));
      while (!BookingTime.isWeekday(date)) {
        date = date.add(const Duration(days: 1));
      }
      // Use the visible horizontal day tile by its day number.
      final tile = find.text('${date.day}');
      await tester.scrollUntilVisible(
        tile.first,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(tile.first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Classroom 3A02'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Classroom 3A02'));
      await tester.pumpAndSettle();
      await tapText('Reserve this room');
      await enterTime(const Key('start_time'), '8', '10');
      await enterTime(const Key('end_time'), '9', '35');
      await tester.scrollUntilVisible(
        find.byKey(const Key('booking_purpose')),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(
        find.byKey(const Key('booking_purpose')),
        'Android integration project discussion',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.ensureVisible(find.byKey(const Key('review_reservation')));
      await tester.tap(find.byKey(const Key('review_reservation')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('confirm_reservation')));
      await tester.tap(find.byKey(const Key('confirm_reservation')));
      await waitFor(find.text('Space secured.\nIdeas welcome.'));

      final uid = FirebaseAuth.instance.currentUser!.uid;
      final snapshot = await FirebaseFirestore.instance
          .collection('reservations')
          .where('userId', isEqualTo: uid)
          .get();
      expect(snapshot.docs.length, 1);
      final booking = snapshot.docs.single;
      expect(booking['startMinute'], 490);
      expect(booking['endMinute'], 575);
      final day = await FirebaseFirestore.instance
          .collection('roomDays')
          .doc('3A02_${BookingTime.dateKey(date)}')
          .get();
      expect(
        (day['intervals'] as List).any((i) => i['reservationId'] == booking.id),
        isTrue,
      );

      await tapText('View my bookings');
      await waitFor(find.text('Confirmed'));
      await tapText('Cancel reservation');
      await tapText('Cancel booking');
      await waitFor(find.text('Your next idea starts here'));
      await tapText('Cancelled');
      await waitFor(find.text('Android integration project discussion'));
      final released = await FirebaseFirestore.instance
          .collection('roomDays')
          .doc(day.id)
          .get();
      expect(
        (released['intervals'] as List).any(
          (i) => i['reservationId'] == booking.id,
        ),
        isFalse,
      );
      expect((await booking.reference.get())['status'], 'cancelled');

      await tapText('Account');
      await tapText('Sign out');
      await tapText('Try simulated Google account');
      await waitFor(find.byType(RoomsScreen));
      expect(
        FirebaseAuth.instance.currentUser!.providerData.any(
          (p) => p.providerId == 'google.com',
        ),
        isTrue,
      );
      expect(FirebaseAuth.instance.currentUser!.emailVerified, isTrue);
      // Exercise the actual mobile callable client one more time after switching provider.
      final repository = FirebaseReservationRepository();
      final googleBooking = await repository.createReservation(
        requestId: 'google-${DateTime.now().microsecondsSinceEpoch}',
        roomId: 'room-06',
        date: BookingTime.dateKey(date),
        startMinute: 780,
        endMinute: 805,
        purpose: 'Google emulator integration',
      );
      expect(
        (await repository.cancelReservation(googleBooking.id)).isCancelled,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
