import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooms/features/auth/auth_controller.dart';
import 'package:rooms/features/auth/auth_gate.dart';

class TestAuthRepository implements AuthRepository {
  final changes = StreamController<User?>.broadcast();
  @override
  User? currentUser;
  bool failSignIn = false;
  int signInCount = 0;
  int resetCount = 0;
  @override
  Stream<User?> userChanges() => changes.stream;
  @override
  Future<void> register(String name, String email, String password) async {}
  @override
  Future<void> signIn(String email, String password) async {
    signInCount++;
    if (failSignIn) throw FirebaseAuthException(code: 'invalid-credential');
  }

  @override
  Future<void> refreshUser() async {}
  @override
  Future<void> resetPassword(String email) async {
    resetCount++;
  }

  @override
  Future<void> sendVerification() async {}
  @override
  Future<void> signInGoogle() async {}
  @override
  Future<void> signOut() async {}
}

class TestUser extends Fake implements User {
  TestUser(this.emailVerified);
  @override
  final bool emailVerified;
  @override
  String get email => 'student@ibit.example';
}

void main() {
  Future<AuthController> pumpAuth(
    WidgetTester tester,
    TestAuthRepository repository, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    final reportError = FlutterError.onError;
    FlutterError.onError = (details) {
      FlutterError.dumpErrorToConsole(details);
      reportError?.call(details);
    };
    addTearDown(() => FlutterError.onError = reportError);
    tester.view.reset();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = AuthController(repository);
    addTearDown(controller.dispose);
    addTearDown(repository.changes.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: AuthGate(
          controller: controller,
          child: const Scaffold(body: Text('Room catalog')),
        ),
      ),
    );
    repository.changes.add(repository.currentUser);
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets(
    'failed sign-in preserves email and password and explains the error',
    (tester) async {
      final repository = TestAuthRepository()..failSignIn = true;
      await pumpAuth(tester, repository);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'student@ibit.example',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'wrongpassword');
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(repository.signInCount, 1);
      expect(
        find.text('That email and password do not match. Please try again.'),
        findsOneWidget,
      );
      final fields = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .toList();
      expect(fields[0].controller!.text, 'student@ibit.example');
      expect(fields[1].controller!.text, 'wrongpassword');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'small screen with enlarged text remains scrollable and has no overflow',
    (tester) async {
      await pumpAuth(
        tester,
        TestAuthRepository(),
        size: const Size(320, 568),
        scale: 2,
      );
      await tester.ensureVisible(find.text('Try simulated Google account'));
      await tester.pumpAndSettle();
      expect(find.text('Try simulated Google account'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('email verification gate protects the room catalog', (
    tester,
  ) async {
    final repository = TestAuthRepository()..currentUser = TestUser(false);
    final controller = await pumpAuth(tester, repository);
    expect(find.text('One last step.'), findsOneWidget);
    expect(find.text('Room catalog'), findsNothing);
    repository.currentUser = TestUser(true);
    await controller.refreshUser();
    await tester.pumpAndSettle();
    expect(find.text('Room catalog'), findsOneWidget);
  });

  testWidgets(
    'password reset keeps the entered email and reports local link delivery',
    (tester) async {
      final repository = TestAuthRepository();
      await pumpAuth(tester, repository);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'student@ibit.example',
      );
      await tester.ensureVisible(find.text('Forgot password?'));
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      final field = tester.widget<TextFormField>(
        find.descendant(of: dialog, matching: find.byType(TextFormField)),
      );
      expect(field.controller!.text, 'student@ibit.example');
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();
      expect(repository.resetCount, 1);
      expect(find.text('Check your email'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
