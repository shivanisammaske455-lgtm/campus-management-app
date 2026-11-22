import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/duplicate_check_result.dart';
import '../models/issue_model.dart';
import '../models/notification_model.dart';

/// Riverpod provider for FirestoreService.
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

/// Riverpod stream provider for all campus issues.
final allIssuesStreamProvider = StreamProvider<List<Issue>>((ref) {
  final service = ref.watch(firestoreServiceProvider);
  return service.getIssuesStream();
});

/// Riverpod stream provider for issues filtered by status.
final issuesByStatusProvider =
    StreamProvider.family<List<Issue>, IssueStatus?>((ref, status) {
  final service = ref.watch(firestoreServiceProvider);
  return service.getIssuesStream(statusFilter: status);
});

/// Riverpod stream provider for the current user's reported issues.
final myIssuesStreamProvider =
    StreamProvider.family<List<Issue>, String>((ref, uid) {
  final service = ref.watch(firestoreServiceProvider);
  return service.getMyIssuesStream(uid);
});

/// Riverpod stream provider for a single issue by ID.
final singleIssueStreamProvider =
    StreamProvider.family<Issue?, String>((ref, issueId) {
  final service = ref.watch(firestoreServiceProvider);
  return service.getIssueStream(issueId);
});

/// Riverpod stream provider for user notifications in real-time.
final userNotificationsStreamProvider =
    StreamProvider.family<List<CampusNotification>, String>((ref, uid) {
  final service = ref.watch(firestoreServiceProvider);
  return service.getUserNotificationsStream(uid);
});

/// Riverpod provider for unread notification count.
final unreadNotificationCountProvider =
    Provider.family<int, String>((ref, uid) {
  final notificationsAsync = ref.watch(userNotificationsStreamProvider(uid));
  return notificationsAsync.value?.where((n) => !n.isRead).length ?? 0;
});

/// Service layer managing Cloud Firestore operations for Campus Issues.
class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Root collection reference for issues.
  CollectionReference<Map<String, dynamic>> get _issuesCollection =>
      _firestore.collection('issues');

  /// 1. Create a new campus issue in the 'issues' collection.
  Future<String> createIssue(Issue issue) async {
    final docRef = _issuesCollection.doc();
    final issueData = issue.toMap();

    // Use server timestamp for reliable creation and update tracking
    issueData['createdAt'] = FieldValue.serverTimestamp();
    issueData['updatedAt'] = FieldValue.serverTimestamp();

    await docRef.set(issueData);
    return docRef.id;
  }

  /// 2. Stream a single issue by ID.
  Stream<Issue?> getIssueStream(String issueId) {
    return _issuesCollection.doc(issueId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Issue.fromFirestore(doc);
    });
  }

  /// 3. Fetch a single issue once by ID.
  Future<Issue?> getIssueById(String issueId) async {
    final doc = await _issuesCollection.doc(issueId).get();
    if (!doc.exists) return null;
    return Issue.fromFirestore(doc);
  }

  /// 4. Stream all issues with optional status or category filter.
  Stream<List<Issue>> getIssuesStream({
    IssueStatus? statusFilter,
    IssueCategory? categoryFilter,
  }) {
    Query<Map<String, dynamic>> query = _issuesCollection;

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter.toFirestoreValue());
    }

    if (categoryFilter != null) {
      query = query.where(
        'category',
        isEqualTo: categoryFilter.toFirestoreValue(),
      );
    }

    query = query.orderBy('createdAt', descending: true);

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Issue.fromFirestore(doc)).toList();
    });
  }

  /// 5. Stream issues submitted by a specific user.
  Stream<List<Issue>> getMyIssuesStream(String uid) {
    return _issuesCollection
        .where('reportedBy', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Issue.fromFirestore(doc)).toList();
    });
  }

  /// 6. Reporter edit: Updates ONLY the issue description.
  /// Enforced by Firestore Security Rules: reporter can only modify description.
  Future<void> updateIssueDescription({
    required String issueId,
    required String newDescription,
  }) async {
    await _issuesCollection.doc(issueId).update({
      'description': newDescription.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 7. Management edit: Updates status, assigned team, and resolution details.
  /// Enforced by Firestore Security Rules: restricted to role == 'management'.
  Future<void> updateManagementFields({
    required String issueId,
    required IssueStatus status,
    String? assignedTo,
    String? afterPhotoUrl,
    DateTime? resolvedAt,
  }) async {
    final Map<String, dynamic> updates = {
      'status': status.toFirestoreValue(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (assignedTo != null) {
      updates['assignedTo'] = assignedTo.trim();
    }

    if (afterPhotoUrl != null) {
      updates['afterPhotoUrl'] = afterPhotoUrl.trim();
    }

    if (status == IssueStatus.resolved) {
      updates['resolvedAt'] = resolvedAt != null
          ? Timestamp.fromDate(resolvedAt)
          : FieldValue.serverTimestamp();
    } else {
      updates['resolvedAt'] = null;
    }

    await _issuesCollection.doc(issueId).update(updates);
  }

  /// 8. Toggle Me Too: Add or remove current user UID from `meTooBy` list.
  /// Enforced by Firestore Security Rules: any user can add/remove only their own UID.
  Future<void> toggleMeToo({
    required String issueId,
    required String uid,
    required bool isCurrentlyAdded,
  }) async {
    final docRef = _issuesCollection.doc(issueId);

    if (isCurrentlyAdded) {
      // Remove user's UID
      await docRef.update({
        'meTooBy': FieldValue.arrayRemove([uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Add user's UID
      await docRef.update({
        'meTooBy': FieldValue.arrayUnion([uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// 9. Reopen issue: Reporter marks that the issue is not fixed;
  /// resets status to 'reported' and clears resolution timestamp.
  Future<void> reopenIssue(String issueId) async {
    await _issuesCollection.doc(issueId).update({
      'status': IssueStatus.reported.toFirestoreValue(),
      'resolvedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 10. Confirm issue is fixed: Reporter confirms management resolution.
  Future<void> confirmFixed(String issueId) async {
    await _issuesCollection.doc(issueId).update({
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 11. Save or update user FCM push notification token.
  Future<void> saveUserFcmToken(String uid, String token) async {
    await _firestore.collection('users').doc(uid).set({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 12. Stream live notifications from `users/{uid}/notifications`.
  Stream<List<CampusNotification>> getUserNotificationsStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CampusNotification.fromFirestore(doc))
            .toList());
  }

  /// 13. Mark a single notification as read.
  Future<void> markNotificationAsRead(String uid, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  /// 14. Mark all notifications as read for a user.
  Future<void> markAllNotificationsAsRead(String uid) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  /// 15. Check for duplicate open issues in the same area from the last 7 days.
  /// Calls the secure 2nd Gen Cloud Function using Gemini API.
  Future<DuplicateCheckResult> checkForDuplicateIssue({
    required String area,
    required String title,
    required String description,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('checkDuplicateIssue');
      final response = await callable.call<Map<dynamic, dynamic>>({
        'area': area,
        'title': title,
        'description': description,
      });

      final data = response.data;
      if (data['isDuplicate'] == true && data['matchedIssueId'] != null) {
        Issue? matchedIssue;
        if (data['matchedIssue'] != null) {
          final matchedMap = Map<String, dynamic>.from(data['matchedIssue']);
          matchedIssue = Issue.fromMap(matchedMap, id: data['matchedIssueId']);
        }

        return DuplicateCheckResult(
          isDuplicate: true,
          matchedIssueId: data['matchedIssueId'] as String,
          reason: data['reason'] as String? ??
              'This problem appears to have already been reported in this area.',
          matchedIssue: matchedIssue,
        );
      }
    } catch (e) {
      debugPrint('Cloud Function duplicate check error, checking Firestore fallback: $e');

      // Local Firestore query fallback: check open issues in the same area from last 7 days
      try {
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        final snapshot = await _issuesCollection
            .where('area', isEqualTo: area)
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
            .get();

        final openCandidates = snapshot.docs
            .map((d) => Issue.fromFirestore(d))
            .where((i) => i.status != IssueStatus.resolved)
            .toList();

        if (openCandidates.isNotEmpty) {
          // Check for similar title/description keywords
          final newDescLower = description.toLowerCase();
          for (final candidate in openCandidates) {
            final candDesc = candidate.description.toLowerCase();
            final candTitle = candidate.title.toLowerCase();

            // Simple semantic overlap check if offline
            final words = newDescLower.split(' ').where((w) => w.length > 4);
            int matches = 0;
            for (final word in words) {
              if (candDesc.contains(word) || candTitle.contains(word)) {
                matches++;
              }
            }

            if (matches >= 2 || candTitle == title.toLowerCase()) {
              return DuplicateCheckResult(
                isDuplicate: true,
                matchedIssueId: candidate.id,
                reason: 'An open issue with matching keywords was reported recently in $area.',
                matchedIssue: candidate,
              );
            }
          }
        }
      } catch (fallbackErr) {
        debugPrint('Firestore duplicate check fallback error: $fallbackErr');
      }
    }

    return const DuplicateCheckResult(isDuplicate: false);
  }
}
