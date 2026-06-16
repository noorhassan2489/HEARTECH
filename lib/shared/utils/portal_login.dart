import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/core/router/app_router.dart';
import 'package:heartech/shared/utils/registration_flow.dart';

/// Result of a role-portal sign-in attempt.
sealed class PortalLoginResult {
  const PortalLoginResult();

  const factory PortalLoginResult.success(String dashboardRoute) =
      PortalLoginSuccess;
  const factory PortalLoginResult.resumeRegistration(String registerRoute) =
      PortalLoginResumeRegistration;
  const factory PortalLoginResult.wrongRole(String actualRole) =
      PortalLoginWrongRole;
}

class PortalLoginSuccess extends PortalLoginResult {
  final String dashboardRoute;
  const PortalLoginSuccess(this.dashboardRoute);
}

class PortalLoginResumeRegistration extends PortalLoginResult {
  final String registerRoute;
  const PortalLoginResumeRegistration(this.registerRoute);
}

class PortalLoginWrongRole extends PortalLoginResult {
  final String actualRole;
  const PortalLoginWrongRole(this.actualRole);
}

/// Enforces HCW / parent / teacher portal separation at login.
class PortalLogin {
  PortalLogin._();

  static String dashboardRouteFor(String role) {
    switch (role) {
      case 'hcw':
        return Routes.hcwDashboard;
      case 'parent':
        return Routes.parentDashboard;
      case 'teacher':
        return Routes.teacherDashboard;
      default:
        return Routes.roleSelect;
    }
  }

  static String registerRouteFor(String role) =>
      RegistrationFlow.registerRouteForRole(role);

  static String loginRouteFor(String role) {
    switch (role) {
      case 'hcw':
        return Routes.hcwLogin;
      case 'parent':
        return Routes.parentLogin;
      case 'teacher':
        return Routes.teacherLogin;
      default:
        return Routes.roleSelect;
    }
  }

  /// Router: only skip login screen when portal matches profile role.
  static String? dashboardRedirectForLoginPath(String path, String? role) {
    if (role == null) return null;
    if (path == Routes.hcwLogin && role == 'hcw') {
      return Routes.hcwDashboard;
    }
    if (path == Routes.parentLogin && role == 'parent') {
      return Routes.parentDashboard;
    }
    if (path == Routes.teacherLogin && role == 'teacher') {
      return Routes.teacherDashboard;
    }
    return null;
  }

  /// After Firebase auth, validate Firestore role matches this login portal.
  static Future<PortalLoginResult> completeSignIn({
    required WidgetRef ref,
    required String expectedRole,
  }) async {
    final authService = ref.read(firebaseAuthServiceProvider);
    final user = authService.currentUser;
    if (user == null) {
      return PortalLoginResumeRegistration(registerRouteFor(expectedRole));
    }

    final profile = await ref.read(firestoreServiceProvider).getUser(user.uid);

    if (profile == null) {
      return PortalLoginResumeRegistration(registerRouteFor(expectedRole));
    }

    if (profile.role != expectedRole) {
      await authService.signOut();
      return PortalLoginWrongRole(profile.role);
    }

    await authService.registerOneSignal(user.uid, profile.role);
    return PortalLoginSuccess(dashboardRouteFor(expectedRole));
  }
}
