import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';

/// Riverpod provider for active Firebase Auth instance.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Riverpod stream provider for Firebase Auth user state.
final authStateStreamProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Optional role override for instant UI testing (e.g. from Profile screen).
final userRoleOverrideProvider = StateProvider<String?>((ref) => null);

/// Real-time stream of the current user's profile document from Firestore (`users/{uid}`).
final userProfileStreamProvider = StreamProvider<UserModel?>((ref) {
  final authUser = ref.watch(authStateStreamProvider).value;
  if (authUser == null) {
    return Stream.value(null);
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(authUser.uid)
      .snapshots()
      .map((doc) {
    if (!doc.exists || doc.data() == null) {
      return UserModel(
        uid: authUser.uid,
        displayName: authUser.displayName ?? 'Student',
        email: authUser.email ?? 'student@college.edu',
        role: 'student', // default fallback
        photoUrl: authUser.photoURL,
      );
    }
    return UserModel.fromMap(doc.data()!, doc.id);
  });
});

/// Riverpod provider for current UserModel with Firestore stream & role override support.
final currentUserProvider = Provider<UserModel>((ref) {
  final overrideRole = ref.watch(userRoleOverrideProvider);
  final profileAsync = ref.watch(userProfileStreamProvider);
  final authUser = ref.watch(authStateStreamProvider).value;

  UserModel baseUser;

  if (profileAsync.value != null) {
    baseUser = profileAsync.value!;
  } else if (authUser != null) {
    baseUser = UserModel(
      uid: authUser.uid,
      displayName: authUser.displayName ?? 'Campus User',
      email: authUser.email ?? 'user@college.edu',
      role: 'student',
      photoUrl: authUser.photoURL,
    );
  } else {
    // Sensible mock user for local testing
    baseUser = const UserModel(
      uid: 'student_current_user',
      displayName: 'Shivani',
      email: 'shivani@college.edu',
      role: 'student',
    );
  }

  if (overrideRole != null) {
    return baseUser.copyWith(role: overrideRole);
  }

  return baseUser;
});

/// Dynamic time-of-day greeting helper ("Good morning", "Good afternoon", etc.).
final timeGreetingProvider = Provider<String>((ref) {
  final hour = DateTime.now().hour;
  if (hour < 12) {
    return 'Good morning';
  } else if (hour < 17) {
    return 'Good afternoon';
  } else {
    return 'Good evening';
  }
});
