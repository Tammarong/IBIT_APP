import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/firebase_config.dart';

abstract interface class AuthRepository {
  User? get currentUser;
  Stream<User?> userChanges();
  Future<void> register(String name, String email, String password);
  Future<void> signIn(String email, String password);
  Future<void> sendVerification();
  Future<void> refreshUser();
  Future<void> resetPassword(String email);
  Future<void> signInGoogle();
  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;
  final FirebaseAuth _auth;
  Future<void>? _googleInitialization;

  @override
  User? get currentUser => _auth.currentUser;
  @override
  Stream<User?> userChanges() => _auth.userChanges();

  @override
  Future<void> register(String name, String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user!.updateDisplayName(name.trim());
    await credential.user!.sendEmailVerification();
  }

  @override
  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> sendVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Sign in to verify your email.');
    await user.sendEmailVerification();
  }

  @override
  Future<void> refreshUser() async {
    await _auth.currentUser?.reload();
    // Rules and callables must receive the new email_verified claim.
    await _auth.currentUser?.getIdToken(true);
  }

  @override
  Future<void> resetPassword(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  @override
  Future<void> signInGoogle() async {
    // A compile-time false branch in profile/release excludes mock credentials.
    if (kDebugMode && EmulatorConfig.enabled) {
      final mockToken = jsonEncode({
        'sub': 'ibit-emulator-google-student',
        'email': 'student@ibit.example',
        'email_verified': true,
        'name': 'IBIT Student',
      });
      await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: mockToken),
      );
      return;
    }
    if (EmulatorConfig.enabled) {
      throw StateError(
        'Simulated Google sign-in is available in debug emulator mode only.',
      );
    }
    final google = GoogleSignIn.instance;
    const serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
    _googleInitialization ??= google.initialize(
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
    );
    await _googleInitialization;
    if (!google.supportsAuthenticate()) {
      throw StateError('Google sign-in is supported in the Android app.');
    }
    final account = await google.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError(
        'Google did not return a sign-in token. Please try again.',
      );
    }
    await _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    if (!EmulatorConfig.enabled && _googleInitialization != null) {
      await GoogleSignIn.instance.signOut();
    }
  }
}

class AuthController extends ChangeNotifier {
  AuthController([AuthRepository? repository])
    : _repository = repository ?? FirebaseAuthRepository() {
    _currentUser = _repository.currentUser;
    _subscription = _repository.userChanges().listen(
      (user) {
        _currentUser = user;
        initialized = true;
        if (!_disposed) notifyListeners();
      },
      onError: (Object _) {
        initialized = true;
        error = 'We could not restore your session. Please sign in again.';
        if (!_disposed) notifyListeners();
      },
    );
  }

  final AuthRepository _repository;
  late final StreamSubscription<User?> _subscription;
  User? _currentUser;
  User? get currentUser => _currentUser;
  bool initialized = false;
  bool loading = false;
  String? error;
  bool _disposed = false;

  Future<bool> register(String name, String email, String password) =>
      _run(() => _repository.register(name, email, password));
  Future<bool> signIn(String email, String password) =>
      _run(() => _repository.signIn(email, password));
  Future<bool> sendVerification() => _run(_repository.sendVerification);
  Future<bool> refreshUser() => _run(() async {
    await _repository.refreshUser();
    _currentUser = _repository.currentUser;
  });
  Future<bool> resetPassword(String email) =>
      _run(() => _repository.resetPassword(email));
  Future<bool> signInGoogle() => _run(_repository.signInGoogle);
  Future<bool> signOut() => _run(_repository.signOut);

  void clearError() {
    error = null;
    if (!_disposed) notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (loading) return false;
    loading = true;
    error = null;
    if (!_disposed) notifyListeners();
    try {
      await action();
      _currentUser = _repository.currentUser;
      return true;
    } on FirebaseAuthException catch (exception) {
      error = switch (exception.code) {
        'invalid-credential' || 'wrong-password' || 'user-not-found' =>
          'That email and password do not match. Please try again.',
        'email-already-in-use' =>
          'An account already uses this email. Please sign in.',
        'invalid-email' => 'Enter a valid email address.',
        'weak-password' => 'Choose a password with at least 6 characters.',
        'network-request-failed' =>
          'Could not connect. Check your connection and try again.',
        'too-many-requests' =>
          'Too many attempts. Please wait a little and try again.',
        'user-disabled' =>
          'This account is disabled. Contact your faculty administrator.',
        _ =>
          exception.message ??
              'We could not complete sign-in. Please try again.',
      };
    } on GoogleSignInException catch (exception) {
      if (exception.code != GoogleSignInExceptionCode.canceled) {
        error =
            'Google sign-in could not finish. Please try again or use email.';
      }
    } catch (_) {
      error =
          'We could not complete this request. Check your connection and try again.';
    } finally {
      loading = false;
      if (!_disposed) notifyListeners();
    }
    return false;
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription.cancel();
    super.dispose();
  }
}
