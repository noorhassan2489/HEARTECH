import '../models/screening_model.dart';
import '../../services/firestore_service.dart';

/// Repository for screenings (child-linked and standalone HCW).
class ScreeningRepository {
  final FirestoreService _firestore;

  ScreeningRepository(this._firestore);

  /// Stream of screenings for a specific child.
  Stream<List<ScreeningModel>> childScreenings(String childId) {
    return _firestore.childScreenings(childId).map((list) =>
        list.map((m) => ScreeningModel.fromMap(m, m['screeningId'] ?? '')).toList());
  }

  /// Stream of standalone HCW screenings (no child profile created).
  Stream<List<ScreeningModel>> hcwStandaloneScreenings(String hcwId) {
    return _firestore.hcwScreenings(hcwId).map((list) =>
        list.map((m) => ScreeningModel.fromMap(m, m['screeningId'] ?? '')).toList());
  }

  /// Save a screening under a child profile.
  Future<String> addChildScreening(String childId, Map<String, dynamic> data) {
    return _firestore.addChildScreening(childId, data);
  }

  /// Save a standalone HCW screening.
  Future<String> addHcwScreening(Map<String, dynamic> data) {
    return _firestore.addHcwScreening(data);
  }
}
