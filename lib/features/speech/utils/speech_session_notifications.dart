import 'package:heartech/services/fastapi_service.dart';
import 'package:heartech/shared/models/child_model.dart';

/// Notify linked parent and HCWs when a speech session is saved.
/// Parent-led sessions go to HCW only. Teacher-led sessions go to parent + HCW.
Future<void> notifySpeechSessionSaved({
  required FastApiService fastApi,
  required ChildModel child,
  required String conductorRole,
  required String gameName,
  required int score,
}) async {
  try {
    if (conductorRole == 'teacher') {
      final parentId = child.parentId;
      if (parentId != null && parentId.isNotEmpty) {
        await fastApi.sendNotification(
          uid: parentId,
          type: 'PAR-08',
          title: 'Speech Session Complete',
          body: '${child.name} scored $score% in $gameName (teacher-led).',
          relatedChildId: child.childId,
          navigationRoute: '/parent/child/${child.childId}',
        );
      }
      for (final hcwId in child.hcwIds) {
        await fastApi.sendNotification(
          uid: hcwId,
          type: 'HCW-08',
          title: 'Speech Session Completed',
          body: 'Teacher completed a $gameName session for ${child.name}.',
          relatedChildId: child.childId,
          navigationRoute: '/hcw/child/${child.childId}',
        );
      }
      return;
    }

    // Parent-led session — HCW only (teachers must not see parent home speech data).
    for (final hcwId in child.hcwIds) {
      await fastApi.sendNotification(
        uid: hcwId,
        type: 'HCW-08',
        title: 'Speech Session Completed',
        body: '${child.name} completed a $gameName session.',
        relatedChildId: child.childId,
        navigationRoute: '/hcw/child/${child.childId}',
      );
    }
  } catch (_) {
    // Non-critical — do not block save flow.
  }
}
