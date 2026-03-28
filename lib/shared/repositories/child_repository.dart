import 'package:hive/hive.dart';
import '../models/child_model.dart';
import '../../services/firestore_service.dart';

/// Repository for child profiles. Uses Hive for offline caching.
class ChildRepository {
  final FirestoreService _firestore;
  Box? _childBox;

  ChildRepository(this._firestore);

  Future<void> _ensureBox() async {
    _childBox ??= await Hive.openBox('children_cache');
  }

  /// Get children for a specific role.
  Stream<List<ChildModel>> childrenStream({
    required String uid,
    required String role,
  }) {
    switch (role) {
      case 'hcw':
        return _firestore.childrenByHcw(uid).map((list) =>
            list.map((m) => ChildModel.fromMap(m, m['childId'] ?? '')).toList());
      case 'parent':
        return _firestore.childrenByParent(uid).map((list) =>
            list.map((m) => ChildModel.fromMap(m, m['childId'] ?? '')).toList());
      case 'teacher':
        return _firestore.childrenByTeacher(uid).map((list) =>
            list.map((m) => ChildModel.fromMap(m, m['childId'] ?? '')).toList());
      default:
        return const Stream.empty();
    }
  }

  /// Get a single child by ID from Firestore, falling back to Hive cache.
  Future<ChildModel?> getChild(String childId) async {
    final map = await _firestore.getChildProfile(childId);
    if (map != null) {
      // Cache to Hive
      await _ensureBox();
      _childBox?.put(childId, map);
      return ChildModel.fromMap(map, childId);
    }
    // Fallback to Hive
    await _ensureBox();
    final cached = _childBox?.get(childId);
    if (cached != null) {
      return ChildModel.fromMap(Map<String, dynamic>.from(cached), childId);
    }
    return null;
  }

  /// Cache a list of children locally.
  Future<void> cacheChildren(List<ChildModel> children) async {
    await _ensureBox();
    for (final child in children) {
      _childBox?.put(child.childId, child.toMap());
    }
  }

  /// Create a child profile.
  Future<String> createChild(Map<String, dynamic> data) async {
    return _firestore.createChildProfile(data);
  }

  /// Update a child profile.
  Future<void> updateChild(String childId, Map<String, dynamic> data) async {
    return _firestore.updateChild(childId, data);
  }
}
