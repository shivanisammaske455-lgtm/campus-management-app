/// User model representing an authenticated campus community member.
class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String role; // student, staff, management
  final String? photoUrl;

  const UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
    this.photoUrl,
  });

  /// True if user possesses administrative / management privileges.
  bool get isManagement => role.trim().toLowerCase() == 'management';

  /// Extracts the first name for friendly greetings (e.g., "Good morning, Shivani").
  String get firstName {
    if (displayName.trim().isEmpty) return 'Student';
    return displayName.trim().split(' ').first;
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      displayName: map['displayName'] as String? ?? 'Campus User',
      email: map['email'] as String? ?? '',
      role: (map['role'] as String? ?? 'student').toLowerCase(),
      photoUrl: map['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'role': role,
      'photoUrl': photoUrl,
    };
  }

  UserModel copyWith({
    String? uid,
    String? displayName,
    String? email,
    String? role,
    String? photoUrl,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
