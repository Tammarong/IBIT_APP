import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooms/core/theme.dart';
import 'package:rooms/data/models.dart';
import 'package:rooms/features/account/account_screen.dart';
import 'package:rooms/features/account/profile_image_repository.dart';
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

class TestProfileImages implements ProfileImageRepository {
  int uploadCount = 0;
  Uint8List? uploadedBytes;

  @override
  Future<String> uploadProfileImage({
    required String userId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    uploadCount++;
    uploadedBytes = bytes;
    return 'https://example.com/profile.jpg';
  }
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(320, 568),
    double scale = 2,
  }) async {
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
  testWidgets('profile editor updates the display name and photo', (
    tester,
  ) async {
    final repository = TestAuthRepository()..currentUser = AccountUser();
    final images = TestProfileImages();
    final auth = AuthController(repository);
    addTearDown(auth.dispose);
    addTearDown(repository.changes.close);
    await pump(
      tester,
      Scaffold(
        body: AccountScreen(
          auth: auth,
          imageRepository: images,
          pickImage: () async => ProfileImageSelection(
            bytes: Uint8List.fromList(const [1, 2, 3]),
            contentType: 'image/jpeg',
          ),
        ),
      ),
      size: const Size(390, 844),
      scale: 1,
    );
    await tester.tap(find.byKey(const Key('edit_profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('choose_profile_photo')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('profile_name')),
      'Updated Member',
    );
    await tester.ensureVisible(find.byKey(const Key('save_profile')));
    await tester.tap(find.byKey(const Key('save_profile')));
    await tester.pumpAndSettle();
    expect(images.uploadCount, 1);
    expect(repository.updatedDisplayName, 'Updated Member');
    expect(repository.updatedPhotoUrl, 'https://example.com/profile.jpg');
    expect(find.text('Profile updated successfully.'), findsOneWidget);
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
