import 'package:cloud_firestore/cloud_firestore.dart';

/// Categories supported for campus issues.
enum IssueCategory {
  plumbing,
  electrical,
  cleanliness,
  furniture,
  other;

  String get label {
    switch (this) {
      case IssueCategory.plumbing:
        return 'Plumbing';
      case IssueCategory.electrical:
        return 'Electrical';
      case IssueCategory.cleanliness:
        return 'Cleanliness';
      case IssueCategory.furniture:
        return 'Furniture';
      case IssueCategory.other:
        return 'Other';
    }
  }

  String toFirestoreValue() => name;

  static IssueCategory fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'plumbing':
        return IssueCategory.plumbing;
      case 'electrical':
        return IssueCategory.electrical;
      case 'cleanliness':
        return IssueCategory.cleanliness;
      case 'furniture':
        return IssueCategory.furniture;
      case 'other':
      default:
        return IssueCategory.other;
    }
  }
}

/// Severity / priority level of an issue.
enum IssuePriority {
  low,
  medium,
  urgent;

  String get label {
    switch (this) {
      case IssuePriority.low:
        return 'Low';
      case IssuePriority.medium:
        return 'Medium';
      case IssuePriority.urgent:
        return 'Urgent';
    }
  }

  String toFirestoreValue() => name;

  static IssuePriority fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'urgent':
        return IssuePriority.urgent;
      case 'medium':
        return IssuePriority.medium;
      case 'low':
      default:
        return IssuePriority.low;
    }
  }
}

/// Lifecycle status of an issue (Reported -> In progress -> Resolved).
enum IssueStatus {
  reported,
  inProgress,
  resolved;

  String get label {
    switch (this) {
      case IssueStatus.reported:
        return 'Reported';
      case IssueStatus.inProgress:
        return 'In progress';
      case IssueStatus.resolved:
        return 'Resolved';
    }
  }

  String toFirestoreValue() {
    switch (this) {
      case IssueStatus.reported:
        return 'reported';
      case IssueStatus.inProgress:
        return 'in_progress';
      case IssueStatus.resolved:
        return 'resolved';
    }
  }

  static IssueStatus fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'in_progress':
      case 'inprogress':
        return IssueStatus.inProgress;
      case 'resolved':
        return IssueStatus.resolved;
      case 'reported':
      default:
        return IssueStatus.reported;
    }
  }
}

/// Data model representing a Campus Issue.
class Issue {
  final String id;
  final String title;
  final String description;
  final String area;
  final IssueCategory category;
  final IssuePriority priority;
  final IssueStatus status;
  final List<String> photoUrls;
  final String reportedBy;
  final String reporterName;
  final String assignedTo;
  final String? afterPhotoUrl;
  final List<String> meTooBy;
  final Map<String, dynamic>? aiTriage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;

  const Issue({
    required this.id,
    required this.title,
    required this.description,
    required this.area,
    required this.category,
    required this.priority,
    required this.status,
    required this.photoUrls,
    required this.reportedBy,
    required this.reporterName,
    this.assignedTo = '',
    this.afterPhotoUrl,
    this.meTooBy = const [],
    this.aiTriage,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
  });

  /// Total count of community members who also experience this issue.
  int get meTooCount => meTooBy.length;

  /// Check whether a specific user has clicked 'Me Too'.
  bool hasMeToo(String uid) => meTooBy.contains(uid);

  /// Convert to Firestore Map representation.
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'area': area,
      'category': category.toFirestoreValue(),
      'priority': priority.toFirestoreValue(),
      'status': status.toFirestoreValue(),
      'photoUrls': photoUrls,
      'reportedBy': reportedBy,
      'reporterName': reporterName,
      'assignedTo': assignedTo,
      'afterPhotoUrl': afterPhotoUrl,
      'meTooBy': meTooBy,
      'aiTriage': aiTriage,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
    };
  }

  /// Construct from a Firestore Document Snapshot.
  factory Issue.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Issue.fromMap(data, id: doc.id);
  }

  /// Construct from a generic Map and optional ID.
  factory Issue.fromMap(Map<String, dynamic> map, {String? id}) {
    return Issue(
      id: id ?? map['id'] ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      area: map['area'] as String? ?? '',
      category: IssueCategory.fromString(map['category'] as String?),
      priority: IssuePriority.fromString(map['priority'] as String?),
      status: IssueStatus.fromString(map['status'] as String?),
      photoUrls: (map['photoUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      reportedBy: map['reportedBy'] as String? ?? '',
      reporterName: map['reporterName'] as String? ?? '',
      assignedTo: map['assignedTo'] as String? ?? '',
      afterPhotoUrl: map['afterPhotoUrl'] as String?,
      meTooBy: (map['meTooBy'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      aiTriage: map['aiTriage'] as Map<String, dynamic>?,
      createdAt: _parseDateTime(map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(map['updatedAt']) ?? DateTime.now(),
      resolvedAt: _parseDateTime(map['resolvedAt']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Create a copy with modified fields.
  Issue copyWith({
    String? id,
    String? title,
    String? description,
    String? area,
    IssueCategory? category,
    IssuePriority? priority,
    IssueStatus? status,
    List<String>? photoUrls,
    String? reportedBy,
    String? reporterName,
    String? assignedTo,
    String? afterPhotoUrl,
    List<String>? meTooBy,
    Map<String, dynamic>? aiTriage,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? resolvedAt,
  }) {
    return Issue(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      area: area ?? this.area,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      photoUrls: photoUrls ?? this.photoUrls,
      reportedBy: reportedBy ?? this.reportedBy,
      reporterName: reporterName ?? this.reporterName,
      assignedTo: assignedTo ?? this.assignedTo,
      afterPhotoUrl: afterPhotoUrl ?? this.afterPhotoUrl,
      meTooBy: meTooBy ?? this.meTooBy,
      aiTriage: aiTriage ?? this.aiTriage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Issue &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          description == other.description &&
          area == other.area &&
          category == other.category &&
          priority == other.priority &&
          status == other.status &&
          reportedBy == other.reportedBy &&
          assignedTo == other.assignedTo &&
          afterPhotoUrl == other.afterPhotoUrl &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      id.hashCode ^
      title.hashCode ^
      description.hashCode ^
      area.hashCode ^
      category.hashCode ^
      priority.hashCode ^
      status.hashCode ^
      reportedBy.hashCode ^
      assignedTo.hashCode ^
      afterPhotoUrl.hashCode ^
      updatedAt.hashCode;

  @override
  String toString() {
    return 'Issue(id: $id, title: $title, status: ${status.name}, priority: ${priority.name}, category: ${category.name}, reportedBy: $reportedBy)';
  }
}
