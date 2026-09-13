import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooms/core/theme.dart';
import 'package:rooms/data/models.dart';
import 'package:rooms/features/account/account_screen.dart';
import 'package:rooms/features/auth/auth_controller.dart';
import 'package:rooms/features/reservations/bookings_screen.dart';
import 'package:rooms/features/reservations/reservation_screen.dart';
import 'auth_screen_test.dart' show TestAuthRepository, TestUser;
import 'rooms_ui_test.dart' show TestRooms, TestReservations, room;

class AccountUser extends TestUser {
  AccountUser() : super(true);
  @override
  String get uid => 'layout-user';
  @override
  String get displayName => 'IBIT Faculty Member';
}

const reservation = Reservation(
  id: '12345678901234567890123456789012',
  roomId: 'room-01',
  userId: 'layout-user',
  date: '2099-03-02',
  startMinute: 490,
  endMinute: 575,
  purpose: 'Planning our academic project together',
  status: 'confirmed',
  createdAt: 0,
);

class BookedRepository extends TestReservations {
  @override
  Stream<List<Reservation>> watchMyReservations(String uid) =>
      Stream.value([reservation]);
}

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: child,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('account supports a small viewport with 200 percent text', (
    tester,
  ) async {
    final repository = TestAuthRepository()..currentUser = AccountUser();
    final auth = AuthController(repository);
    addTearDown(auth.dispose);
    addTearDown(repository.changes.close);
    await pump(tester, Scaffold(body: AccountScreen(auth: auth)));
    await tester.scrollUntilVisible(
      find.text('Sign out'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'booking details and cancellation are reachable with enlarged text',
    (tester) async {
      await pump(
        tester,
        Scaffold(
          body: BookingsScreen(
            uid: 'layout-user',
            rooms: TestRooms(),
            reservations: BookedRepository(),
            onExplore: () {},
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Cancel reservation'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('confirmation supports enlarged text and a small screen', (
    tester,
  ) async {
    await pump(
      tester,
      ReservationSuccessScreen(
        room: room,
        reservation: reservation,
        onBooked: () {},
      ),
    );
    await tester.scrollUntilVisible(
      find.text('View my bookings'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });
}
