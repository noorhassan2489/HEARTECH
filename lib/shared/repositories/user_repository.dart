import '../models/user_model.dart';
import '../../services/firestore_service.dart';

/// Repository for user profiles.
class UserRepository {
  final FirestoreService _firestore;

  UserRepository(this._firestore);

  /// Get a user profile by UID.
  Future<UserModel?> getUser(String uid) async {
    final map = await _firestore.getUserProfile(uid);
    if (map == null) return null;
    return UserModel.fromMap(map, uid);
  }

  /// Create or update a user profile.
  Future<void> setUser(String uid, Map<String, dynamic> data) async {
    return _firestore.setUserProfile(uid, data);
  }

  /// Search users by email.
  Future<List<UserModel>> searchByEmail(String email) async {
    final results = await _firestore.searchUsersByEmail(email);
    return results.map((m) => UserModel.fromMap(m, m['uid'] ?? '')).toList();
  }

  /// Search users by name.
  Future<List<UserModel>> searchByName(String name) async {
    final results = await _firestore.searchUsersByName(name);
    return results.map((m) => UserModel.fromMap(m, m['uid'] ?? '')).toList();
  }
}
