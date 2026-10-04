// Renders every main screen with realistic fake data to PNG files so UI work
// can be reviewed visually without Firebase, an emulator, or a device.
//
// Skipped during a normal `flutter test`. Run it with:
//   .\scripts\design-preview.ps1
// or
//   flutter test test/design_preview_test.dart --dart-define=DESIGN_PREVIEW=true
//
// Output: build/design_preview/<screen>.png (2x device pixel ratio).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooms/app.dart';
import 'package:rooms/core/booking_time.dart';
import 'package:rooms/core/theme.dart';
import 'package:rooms/data/models.dart';
import 'package:rooms/data/repositories.dart';
import 'package:rooms/features/auth/auth_controller.dart';
import 'package:rooms/features/auth/auth_gate.dart';
import 'package:rooms/features/reservations/reservation_screen.dart';
import 'package:rooms/features/rooms/room_detail_screen.dart';

const _enabled = bool.fromEnvironment('DESIGN_PREVIEW');
const _outDir = String.fromEnvironment(
  'DESIGN_PREVIEW_DIR',
  defaultValue: 'build/design_preview',
);
const _frame = Key('design_preview_frame');
const _phone = Size(390, 844);

final _date = BookingTime.nextBookableDate();

class PreviewUser extends Fake implements User {
  PreviewUser({this.emailVerified = true});
  @override
  final bool emailVerified;
  @override
  String get uid => 'preview-user';
  @override
  String get email => 'napat.s@email.kmutnb.ac.th';
  @override
  String get displayName => 'Napat Srisuk';
}

class PreviewAuth implements AuthRepository {
  PreviewAuth(this.currentUser);
  @override
  User? currentUser;
  @override
  Stream<User?> userChanges() => Stream.value(currentUser);
  @override
  Future<void> register(String name, String email, String password) async {}
  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<void> sendVerification() async {}
  @override
  Future<void> refreshUser() async {}
  @override
  Future<void> resetPassword(String email) async {}
  @override
  Future<void> signInGoogle() async {}
  @override
  Future<void> signOut() async {}
}

class PreviewRooms implements RoomRepository {
  PreviewRooms(this.rooms);
  final List<Room> rooms;
  @override
  Stream<List<Room>> watchRooms() => Stream.value(rooms);
  @override
  Stream<Map<String, List<BusyInterval>>> watchAvailability(String date) =>
      Stream.value({
        '3A02': const [
          BusyInterval(reservationId: 'a', startMinute: 540, endMinute: 630),
          BusyInterval(reservationId: 'b', startMinute: 780, endMinute: 840),
        ],
        '3A03': const [
          BusyInterval(reservationId: 'c', startMinute: 480, endMinute: 720),
          BusyInterval(reservationId: 'd', startMinute: 780, endMinute: 960),
        ],
        '4A02': const [
          BusyInterval(reservationId: 'e', startMinute: 480, endMinute: 600),
        ],
        '5A09': const [
          BusyInterval(reservationId: 'f', startMinute: 600, endMinute: 690),
          BusyInterval(reservationId: 'g', startMinute: 870, endMinute: 960),
        ],
      });
}

class PreviewReservations implements ReservationRepository {
  PreviewReservations(this.bookings);
  final List<Reservation> bookings;
  @override
  Stream<List<Reservation>> watchMyReservations(String uid) =>
      Stream.value(bookings);
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
  }) async => throw UnimplementedError();
}

Reservation _booking(
  String id,
  String roomId,
  DateTime day,
  int start,
  int end,
  String purpose, {
  String status = 'confirmed',
}) => Reservation(
  id: '${id}0000000000000000000000000000',
  roomId: roomId,
  userId: 'preview-user',
  date: BookingTime.dateKey(day),
  startMinute: start,
  endMinute: end,
  purpose: purpose,
  status: status,
  createdAt: 0,
);

DateTime _weekdayAfter(DateTime day, int count) {
  var result = day;
  for (var i = 0; i < count; i++) {
    result = result.add(const Duration(days: 1));
    while (!BookingTime.isWeekday(result)) {
      result = result.add(const Duration(days: 1));
    }
  }
  return result;
}

late List<Room> _rooms;
late List<Reservation> _bookings;

Future<void> _loadFonts() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font in (entry['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

Future<List<Room>> _loadRooms() async {
  final catalog =
      jsonDecode(await rootBundle.loadString('assets/rooms/itd_catalog.json'))
          as List;
  var index = 0;
  return catalog.cast<Map<String, dynamic>>().map((entry) {
    index++;
    return Room.fromMap(entry['id'] as String, {
      ...entry,
      'subtitle': 'Floor ${entry['floor']} · ITD, KMUTNB',
      'description': '',
      // Network photos are unavailable in tests; rotate bundled artwork.
      'imageUrl': null,
      'assetPath': 'assets/rooms/room-0${(index - 1) % 6 + 1}.png',
    });
  }).toList()..sort((a, b) => a.name.compareTo(b.name));
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  Size size = _phone,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _frame,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: home,
      ),
    ),
  );
  await tester.runAsync(() async {
    final context = tester.element(find.byType(Navigator).first);
    for (final path in [
      'assets/branding/itd-header.png',
      for (var i = 1; i <= 6; i++) 'assets/rooms/room-0$i.png',
    ]) {
      await precacheImage(AssetImage(path), context);
    }
  });
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  await _settle(tester);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_frame),
  );
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    return image.toByteData(format: ui.ImageByteFormat.png);
  });
  File('$_outDir/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

Widget _shell({List<Reservation>? bookings}) {
  final repository = PreviewAuth(PreviewUser());
  final auth = AuthController(repository);
  addTearDown(auth.dispose);
  return AppShell(
    auth: auth,
    rooms: PreviewRooms(_rooms),
    reservations: PreviewReservations(bookings ?? _bookings),
  );
}

Room _room(String id) => _rooms.firstWhere((room) => room.id == id);

void main() {
  setUpAll(() async {
    if (!_enabled) return;
    await _loadFonts();
    _rooms = await _loadRooms();
    final later = _weekdayAfter(_date, 2);
    final past = BookingTime.today().subtract(const Duration(days: 3));
    _bookings = [
      _booking('a1b2c3d4', '3A02', _date, 490, 575, 'Final-year project'),
      _booking('e5f6a7b8', '5A09', later, 780, 900, 'Lab practice session'),
      _booking('c9d0e1f2', '4A02', later, 600, 660, 'Club meeting'),
      _booking(
        'a3b4c5d6',
        '3A13',
        past,
        540,
        600,
        'Study group',
        status: 'cancelled',
      ),
    ];
  });

  final skip = !_enabled;

  testWidgets('sign in', skip: skip, (tester) async {
    final auth = AuthController(PreviewAuth(null));
    addTearDown(auth.dispose);
    await _pump(tester, AuthGate(controller: auth, child: const SizedBox()));
    await _shot(tester, '01_sign_in');
    await _tearDown(tester);
  });

  testWidgets('verify email', skip: skip, (tester) async {
    final auth = AuthController(PreviewAuth(PreviewUser(emailVerified: false)));
    addTearDown(auth.dispose);
    await _pump(tester, AuthGate(controller: auth, child: const SizedBox()));
    await _shot(tester, '02_verify_email');
    await _tearDown(tester);
  });

  testWidgets('rooms', skip: skip, (tester) async {
    await _pump(tester, _shell());
    await _shot(tester, '03_rooms');
    await _tearDown(tester);
  });

  testWidgets('rooms full page', skip: skip, (tester) async {
    await _pump(tester, _shell(), size: const Size(390, 2200));
    await _shot(tester, '04_rooms_full');
    await _tearDown(tester);
  });

  testWidgets('room detail', skip: skip, (tester) async {
    await _pump(
      tester,
      RoomDetailScreen(
        room: _room('3A02'),
        date: _date,
        rooms: PreviewRooms(_rooms),
        reservations: PreviewReservations(_bookings),
        onBooked: () {},
      ),
      size: const Size(390, 1300),
    );
    await _shot(tester, '05_room_detail');
    await _tearDown(tester);
  });

  testWidgets('room detail information only', skip: skip, (tester) async {
    final special = _rooms.firstWhere((room) => !room.bookingEnabled);
    await _pump(
      tester,
      RoomDetailScreen(
        room: special,
        date: _date,
        rooms: PreviewRooms(_rooms),
        reservations: PreviewReservations(_bookings),
        onBooked: () {},
      ),
    );
    await _shot(tester, '06_room_info_only');
    await _tearDown(tester);
  });

  Widget reservation() => ReservationScreen(
    room: _room('3A02'),
    date: _date,
    rooms: PreviewRooms(_rooms),
    reservations: PreviewReservations(_bookings),
    onBooked: () {},
  );

  testWidgets('reservation form', skip: skip, (tester) async {
    await _pump(tester, reservation(), size: const Size(390, 1500));
    await _shot(tester, '07_reservation');
    await _tearDown(tester);
  });

  testWidgets('reservation filled and review', skip: skip, (tester) async {
    await _pump(tester, reservation());
    Future<void> reveal(Finder finder) async {
      for (var i = 0; i < 20 && finder.evaluate().isEmpty; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
        await tester.pump();
      }
      await tester.ensureVisible(finder.first);
      await _settle(tester);
    }

    final chips = find.byType(ChoiceChip);
    await reveal(chips);
    await tester.tap(chips.first);
    await _settle(tester);
    final purpose = find.byKey(const Key('booking_purpose'));
    await reveal(purpose);
    await tester.enterText(purpose, 'Final-year project discussion');
    tester.testTextInput.hide();
    await _settle(tester);
    await _shot(tester, '08_reservation_filled');
    final review = find.byKey(const Key('review_reservation'));
    await reveal(review);
    await tester.tap(review);
    await _settle(tester);
    await _shot(tester, '09_review_sheet');
    await _tearDown(tester);
  });

  testWidgets('success', skip: skip, (tester) async {
    await _pump(
      tester,
      ReservationSuccessScreen(
        room: _room('3A02'),
        reservation: _bookings.first,
        onBooked: () {},
      ),
    );
    await _shot(tester, '10_success');
    await _tearDown(tester);
  });

  testWidgets('bookings', skip: skip, (tester) async {
    await _pump(tester, _shell());
    await tester.tap(find.byType(NavigationDestination).at(1));
    await _shot(tester, '11_bookings');
    await _tearDown(tester);
  });

  testWidgets('bookings empty', skip: skip, (tester) async {
    await _pump(tester, _shell(bookings: const []));
    await tester.tap(find.byType(NavigationDestination).at(1));
    await _shot(tester, '12_bookings_empty');
    await _tearDown(tester);
  });

  testWidgets('account', skip: skip, (tester) async {
    await _pump(tester, _shell(), size: const Size(390, 1000));
    await tester.tap(find.byType(NavigationDestination).at(2));
    await _shot(tester, '13_account');
    await _tearDown(tester);
  });

  testWidgets('rooms on a small phone with 200% text', skip: skip, (
    tester,
  ) async {
    await _pump(tester, _shell(), size: const Size(320, 568), textScale: 2);
    await _shot(tester, '14_rooms_small_large_text');
    await _tearDown(tester);
  });
}
