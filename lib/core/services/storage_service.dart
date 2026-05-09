import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads [bytes] as a JPEG screenshot and returns the download URL.
  /// Storage path: users/{uid}/screenshots/{tradeId}.jpg
  Future<String> uploadScreenshot(
    String uid,
    String tradeId,
    Uint8List bytes,
  ) async {
    final ref = _storage
        .ref()
        .child('users')
        .child(uid)
        .child('screenshots')
        .child('$tradeId.jpg');

    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return ref.getDownloadURL();
  }

  /// Deletes a screenshot from storage, silently ignoring errors.
  Future<void> deleteScreenshot(String uid, String tradeId) async {
    try {
      await _storage
          .ref()
          .child('users')
          .child(uid)
          .child('screenshots')
          .child('$tradeId.jpg')
          .delete();
    } catch (_) {
      // Ignore — file may not exist.
    }
  }
}
