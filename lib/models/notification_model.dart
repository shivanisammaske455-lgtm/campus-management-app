import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing a campus notification delivered to a user.
class CampusNotification {
  final String id;
  final String issueId;
  final String title;
  final String body;
  final String status;
  final bool isRead;
  final DateTime createdAt;

  const CampusNotification({
    required this.id,
    required this.issueId,
    required this.title,
    required this.body,
    required this.status,
    required this.isRead,
    required this.createdAt,
  });

  factory CampusNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CampusNotification.fromMap(data, doc.id);
  }

  factory CampusNotification.fromMap(Map<String, dynamic> map, String id) {
    return CampusNotification(
      id: id,
      issueId: map['issueId'] as String? ?? '',
      title: map['title'] as String? ?? 'Campus Alert',
      body: map['body'] as String? ?? '',
      status: map['status'] as String? ?? '',
      isRead: map['read'] as bool? ?? (map['isRead'] as bool? ?? false),
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'issueId': issueId,
      'title': title,
      'body': body,
      'status': status,
      'read': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  CampusNotification copyWith({
    String? id,
    String? issueId,
    String? title,
    String? body,
    String? status,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return CampusNotification(
      id: id ?? this.id,
      issueId: issueId ?? this.issueId,
      title: title ?? this.title,
      body: body ?? this.body,
      status: status ?? this.status,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
