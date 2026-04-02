import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:heartech/services/firebase_auth_service.dart';
import 'package:heartech/services/firestore_service.dart';
import 'package:heartech/services/fastapi_service.dart';
import 'package:heartech/services/cloudinary_service.dart';
import 'package:heartech/services/analytics_service.dart';
import 'package:heartech/shared/models/user_model.dart';
import 'package:heartech/shared/models/child_model.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICE PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════════

final firebaseAuthServiceProvider = Provider<FirebaseAuthService>((ref) {
  return FirebaseAuthService();
});

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

final fastApiServiceProvider = Provider<FastApiService>((ref) {
  final authService = ref.read(firebaseAuthServiceProvider);
  return FastApiService(authService);
});

final cloudinaryServiceProvider = Provider<CloudinaryService>((ref) {
  return CloudinaryService();
});

final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});

// ═══════════════════════════════════════════════════════════════════════════════
// AUTH STATE PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Stream of Firebase auth state changes.
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.read(firebaseAuthServiceProvider);
  return authService.authStateChanges;
});

/// Current Firebase user (synchronous).
final currentFirebaseUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
});

// ═══════════════════════════════════════════════════════════════════════════════
// USER PROFILE PROVIDER
// ═══════════════════════════════════════════════════════════════════════════════

/// Stream of the current user's Firestore profile.
final currentUserProfileProvider = StreamProvider<UserModel?>((ref) {
  final firebaseUser = ref.watch(currentFirebaseUserProvider);
  if (firebaseUser == null) return Stream.value(null);

  final firestoreService = ref.read(firestoreServiceProvider);
  return firestoreService.streamUser(firebaseUser.uid);
});

/// Synchronous access to the current user profile.
final userProfileProvider = Provider<UserModel?>((ref) {
  return ref.watch(currentUserProfileProvider).value;
});

/// Current user's role.
final userRoleProvider = Provider<String?>((ref) {
  return ref.watch(userProfileProvider)?.role;
});

// ═══════════════════════════════════════════════════════════════════════════════
// CHILDREN PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════════

/// Children for the current HCW.
final hcwChildrenProvider = StreamProvider<List<ChildModel>>((ref) {
  final user = ref.watch(currentFirebaseUserProvider);
  if (user == null) return Stream.value([]);
  final firestoreService = ref.read(firestoreServiceProvider);
  return firestoreService.streamChildrenByHcw(user.uid);
});

/// Children for the current Parent.
final parentChildrenProvider = StreamProvider<List<ChildModel>>((ref) {
  final user = ref.watch(currentFirebaseUserProvider);
  if (user == null) return Stream.value([]);
  final firestoreService = ref.read(firestoreServiceProvider);
  return firestoreService.streamChildrenByParent(user.uid);
});

/// Children for the current Teacher.
final teacherChildrenProvider = StreamProvider<List<ChildModel>>((ref) {
  final user = ref.watch(currentFirebaseUserProvider);
  if (user == null) return Stream.value([]);
  final firestoreService = ref.read(firestoreServiceProvider);
  return firestoreService.streamChildrenByTeacher(user.uid);
});
