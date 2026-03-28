import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../services/firebase_auth_service.dart';
import '../../shared/repositories/user_repository.dart';
import '../../shared/repositories/child_repository.dart';
import '../../shared/repositories/screening_repository.dart';
import '../../shared/repositories/notification_repository.dart';
import '../../shared/models/user_model.dart';
import '../../shared/models/child_model.dart';
import '../../shared/models/notification_model.dart';

// ═══════════════════════════════════════════════════════════════
//  SERVICES
// ═══════════════════════════════════════════════════════════════

final firestoreServiceProvider = Provider((ref) => FirestoreService());
final authServiceProvider = Provider((ref) => FirebaseAuthService());
// FastApiService uses static methods only — no provider needed.
// Call FastApiService.calculateRiskScore(...) etc. directly.

// ═══════════════════════════════════════════════════════════════
//  REPOSITORIES
// ═══════════════════════════════════════════════════════════════

final userRepositoryProvider = Provider((ref) {
  return UserRepository(ref.read(firestoreServiceProvider));
});

final childRepositoryProvider = Provider((ref) {
  return ChildRepository(ref.read(firestoreServiceProvider));
});

final screeningRepositoryProvider = Provider((ref) {
  return ScreeningRepository(ref.read(firestoreServiceProvider));
});

final notificationRepositoryProvider = Provider((ref) {
  return NotificationRepository(ref.read(firestoreServiceProvider));
});

// ═══════════════════════════════════════════════════════════════
//  AUTH STATE
// ═══════════════════════════════════════════════════════════════

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// ═══════════════════════════════════════════════════════════════
//  CURRENT USER PROFILE
// ═══════════════════════════════════════════════════════════════

final currentUserProfileProvider = FutureProvider<UserModel?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;
  if (user == null) return null;
  return ref.read(userRepositoryProvider).getUser(user.uid);
});

// ═══════════════════════════════════════════════════════════════
//  CHILDREN LIST (role-aware)
// ═══════════════════════════════════════════════════════════════

final childrenStreamProvider =
    StreamProvider.family<List<ChildModel>, ({String uid, String role})>((
      ref,
      params,
    ) {
      return ref
          .read(childRepositoryProvider)
          .childrenStream(uid: params.uid, role: params.role);
    });

// ═══════════════════════════════════════════════════════════════
//  NOTIFICATIONS
// ═══════════════════════════════════════════════════════════════

final notificationsStreamProvider =
    StreamProvider.family<List<NotificationModel>, String>((ref, uid) {
      return ref.read(notificationRepositoryProvider).notificationsStream(uid);
    });

final unreadNotificationCountProvider = Provider.family<int, String>((
  ref,
  uid,
) {
  final notifs = ref.watch(notificationsStreamProvider(uid));
  return notifs.when(
    data: (list) => list.where((n) => !n.read).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});
