import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Riverpod provider for StorageService.
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

/// Service managing file and image uploads to Firebase Storage.
class StorageService {
  final FirebaseStorage _storage;

  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  /// Uploads up to 3 compressed photos to Firebase Storage and returns their download URLs.
  Future<List<String>> uploadIssuePhotos({
    required String issueId,
    required List<XFile> photos,
  }) async {
    final List<String> downloadUrls = [];

    for (int i = 0; i < photos.length; i++) {
      final photo = photos[i];
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = photo.path.split('.').lastOrNull ?? 'jpg';
      final storagePath = 'issues/$issueId/photo_${timestamp}_$i.$fileExtension';

      final ref = _storage.ref().child(storagePath);
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'issueId': issueId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      UploadTask uploadTask;
      if (kIsWeb) {
        final bytes = await photo.readAsBytes();
        uploadTask = ref.putData(bytes, metadata);
      } else {
        uploadTask = ref.putFile(File(photo.path), metadata);
      }

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      downloadUrls.add(downloadUrl);
    }

    return downloadUrls;
  }

  /// Uploads single resolution photo (after-photo) taken by management.
  Future<String> uploadResolutionPhoto({
    required String issueId,
    required XFile photo,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'issues/$issueId/after_photo_$timestamp.jpg';
    final ref = _storage.ref().child(storagePath);

    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {'issueId': issueId, 'type': 'resolution_photo'},
    );

    UploadTask uploadTask;
    if (kIsWeb) {
      final bytes = await photo.readAsBytes();
      uploadTask = ref.putData(bytes, metadata);
    } else {
      uploadTask = ref.putFile(File(photo.path), metadata);
    }

    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }
}
