import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooms/core/theme.dart';
import 'package:rooms/data/models.dart';
import 'package:rooms/data/repositories.dart';
import 'package:rooms/features/rooms/rooms_screen.dart';
import 'package:rooms/features/rooms/room_detail_screen.dart';
import 'package:rooms/features/reservations/reservation_screen.dart';
import 'package:rooms/features/reservations/reservation_controller.dart';

const room = Room(
  id: 'room-01',
  name: 'IBIT Room 01',
  subtitle: 'Find your focus',
  description: 'A space for study and collaboration.',
  assetPath: 'assets/rooms/room-01.png',
);

class TestRooms implements RoomRepository {
  TestRooms({this.error = false, this.busy = const []});
  final bool error;
  final List<BusyInterval> busy;
  @override
  Stream<List<Room>> watchRooms() =>
      error ? Stream.error(Exception('Offline')) : Stream.value([room]);
  @override
  Stream<Map<String, List<BusyInterval>>> watchAvailability(String date) =>
      Stream.value({'room-01': busy});
}

class TestReservations implements ReservationRepository {
  bool fail = false;
  final List<String> requestIds = [];
  @override
  Stream<List<Reservation>> watchMyReservations(String uid) => Stream.value([]);
  @override
  Future<Reservation> cancelReservation(String id) async =>
      throw UnimplementedError();
  @override
  Future<Reservation> createReservation({
    required String requestId,
    required String roomId,
    required String date,
    required int startMinute,
    required int endMinute,
    required String purpose,
  }) async {
    requestIds.add(requestId);
    if (fail) {
      throw const ReservationException(
        'Connection interrupted. Please retry.',
        'unavailable',
      );
    }
    return Reservation(
      id: 'test-reservation-123456',
      roomId: roomId,
      userId: 'test-user',
      date: date,
      startMinute: startMinute,
      endMinute: endMinute,
      purpose: purpose,
      status: 'confirmed',
      createdAt: 0,
    );
  }
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    double scale = 1,
    Size size = const Size(390, 844),
  }) async {
    final reportError = FlutterError.onError;
    FlutterError.onError = (details) {
      FlutterError.dumpErrorToConsole(details);
      reportError?.call(details);
    };
    addTearDown(() => FlutterError.onError = reportError);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: child,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('room browser remains usable on a small screen with large text', (
    tester,
  ) async {
    await pump(
      tester,
      Scaffold(
        body: RoomsScreen(
          rooms: TestRooms(),
          reservations: TestReservations(),
          onBooked: () {},
        ),
      ),
      size: const Size(320, 568),
      scale: 2,
    );
    await tester.scrollUntilVisible(
      find.text('IBIT Room 01'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('IBIT Room 01'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('room details and availability adapt to large text', (
    tester,
  ) async {
    await pump(
      tester,
      RoomDetailScreen(
        room: room,
        date: DateTime.utc(2027, 1, 4),
        rooms: TestRooms(
          busy: const [
            BusyInterval(
              reservationId: 'busy',
              startMinute: 490,
              endMinute: 530,
            ),
          ],
        ),
        reservations: TestReservations(),
        onBooked: () {},
      ),
      size: const Size(320, 568),
      scale: 2,
    );
    await tester.scrollUntilVisible(
      find.text('Afternoon'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reservation form retains purpose when required times are missing',
    (tester) async {
      await pump(
        tester,
        ReservationScreen(
          room: room,
          date: DateTime.utc(2027, 1, 4),
          rooms: TestRooms(),
          reservations: TestReservations(),
          onBooked: () {},
        ),
      );
      final purpose = find.byKey(const Key('booking_purpose'));
      await tester.scrollUntilVisible(
        purpose,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(purpose, 'Project planning');
      tester.testTextInput.hide();
      await tester.ensureVisible(find.byKey(const Key('review_reservation')));
      await tester.tap(find.byKey(const Key('review_reservation')));
      await tester.pumpAndSettle();
      expect(find.text('Choose a start time and an end time.'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(purpose).controller!.text,
        'Project planning',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reservation form remains scrollable with enlarged text', (
    tester,
  ) async {
    await pump(
      tester,
      ReservationScreen(
        room: room,
        date: DateTime.utc(2027, 1, 4),
        rooms: TestRooms(),
        reservations: TestReservations(),
        onBooked: () {},
      ),
      size: const Size(320, 568),
      scale: 2,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('review_reservation')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline room catalog explains the problem and exposes retry', (
    tester,
  ) async {
    await pump(
      tester,
      Scaffold(
        body: RoomsScreen(
          rooms: TestRooms(error: true),
          reservations: TestReservations(),
          onBooked: () {},
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Try again'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Let’s reconnect'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  test('retrying an unchanged request preserves its idempotency key', () async {
    final repository = TestReservations()..fail = true;
    final controller = ReservationController(repository);
    addTearDown(controller.dispose);
    Future<Reservation?> reserve(String purpose) => controller.reserve(
      roomId: room.id,
      date: '2027-01-04',
      startMinute: 490,
      endMinute: 575,
      purpose: purpose,
    );
    expect(await reserve('Planning'), isNull);
    repository.fail = false;
    expect(await reserve('Planning'), isNotNull);
    expect(repository.requestIds[0], repository.requestIds[1]);
    await reserve('Different purpose');
    expect(repository.requestIds[2], isNot(repository.requestIds[1]));
  });
}
