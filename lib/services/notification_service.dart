import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firestore_service.dart';

/// Riverpod provider for NotificationService.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return NotificationService(firestoreService: firestoreService);
});

class NotificationService {
  final FirebaseMessaging _fcm;
  final FirestoreService _firestoreService;

  NotificationService({
    FirebaseMessaging? fcm,
    required FirestoreService firestoreService,
  })  : _fcm = fcm ?? FirebaseMessaging.instance,
        _firestoreService = firestoreService;

  /// Initializes FCM, requests user permissions politely, and saves the device token
  /// to the user's Firestore document.
  Future<void> initializeForUser(String uid) async {
    try {
      // 1. Request notification permissions (polite on iOS, Android 13+)
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('FCM Notification permission granted.');

        // 2. Fetch FCM device token
        final token = await _fcm.getToken();
        if (token != null) {
          debugPrint('FCM Token acquired: ${token.substring(0, 10)}...');
          // Save on the user's document
          await _firestoreService.saveUserFcmToken(uid, token);
        }

        // 3. Listen for token refresh events
        _fcm.onTokenRefresh.listen((newToken) {
          debugPrint('FCM Token refreshed.');
          _firestoreService.saveUserFcmToken(uid, newToken);
        });

        // 4. Foreground notification handling
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('Received foreground notification: ${message.notification?.title}');
        });
      } else {
        debugPrint('FCM Notification permission declined by user.');
      }
    } catch (e) {
      debugPrint('FCM Initialization error: $e');
    }
  }
}
