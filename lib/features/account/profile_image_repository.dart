import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

abstract interface class ProfileImageRepository {
  Future<String> uploadProfileImage({
    required String userId,
    required Uint8List bytes,
    required String contentType,
  });
}

class FirebaseProfileImageRepository implements ProfileImageRepository {
  FirebaseProfileImageRepository({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  @override
  Future<String> uploadProfileImage({
    required String userId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (!contentType.startsWith('image/')) {
      throw const ProfileImageException('Choose a valid image file.');
    }
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      throw const ProfileImageException(
        'The selected image is too large. Choose an image under 5 MB.',
      );
    }
    try {
      final reference = _storage.ref('profilePictures/$userId/avatar');
      await reference.putData(
        bytes,
        SettableMetadata(
          contentType: contentType,
          cacheControl: 'public,max-age=3600',
        ),
      );
      final url = await reference.getDownloadURL();
      final separator = url.contains('?') ? '&' : '?';
      return '$url${separator}v=${DateTime.now().millisecondsSinceEpoch}';
    } on FirebaseException catch (error) {
      final message = switch (error.code) {
        'unauthenticated' => 'Sign in again before changing your photo.',
        'unauthorized' => 'You do not have permission to change this photo.',
        'retry-limit-exceeded' || 'network-request-failed' =>
          'The photo could not upload. Check your connection and try again.',
        _ => 'The photo could not upload. Please try again.',
      };
      throw ProfileImageException(message);
    }
  }
}

class ProfileImageException implements Exception {
  const ProfileImageException(this.message);

  final String message;

  @override
  String toString() => message;
}
