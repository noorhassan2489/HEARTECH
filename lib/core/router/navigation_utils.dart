import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heartech/core/router/app_router.dart';

/// Pop when possible; otherwise navigate to [fallback].
void safePopOrGo(BuildContext context, String fallback) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

/// Child profile route for the given app role.
String childProfileRouteForRole(String role, String childId) {
  switch (role) {
    case 'parent':
      return Routes.parentChildProfile.replaceFirst(':childId', childId);
    case 'teacher':
      return Routes.teacherChildProfile.replaceFirst(':childId', childId);
    default:
      return Routes.hcwChildProfile.replaceFirst(':childId', childId);
  }
}

/// Dashboard route for the given app role.
String dashboardRouteForRole(String role) {
  switch (role) {
    case 'parent':
      return Routes.parentDashboard;
    case 'teacher':
      return Routes.teacherDashboard;
    default:
      return Routes.hcwDashboard;
  }
}

/// Speech games hub route for the given app role.
String speechGamesRouteForRole(String role) {
  switch (role) {
    case 'teacher':
      return Routes.teacherSpeechGames;
    default:
      return Routes.parentSpeechGames;
  }
}

/// Resolve role from signed-in profile first, then optional route query param.
String? resolveViewerRole({String? routeRole, String? userRole}) {
  if (userRole != null && userRole.isNotEmpty) return userRole;
  if (routeRole != null && routeRole.isNotEmpty) return routeRole;
  return null;
}

/// Return from referral screens to the correct child profile for this role.
void closeReferralToChildProfile(
  BuildContext context,
  String childId, {
  String? viewerRole,
  String? userRole,
}) {
  final role = resolveViewerRole(routeRole: viewerRole, userRole: userRole);
  if (role == null) {
    safePopOrGo(context, Routes.roleSelect);
    return;
  }
  safePopOrGo(context, childProfileRouteForRole(role, childId));
}

/// Safely closes a speech screen.
///
/// Speech hub back → dashboard when there is nothing to pop (e.g. bottom nav).
/// Child game screens pop to hub; if pop is unavailable, fall back to hub.
void closeSpeechScreen(
  BuildContext context, {
  String? role,
  String? fallback,
  bool fromGameScreen = false,
}) {
  final resolvedRole = role ?? 'parent';
  final target = fallback ??
      (fromGameScreen
          ? speechGamesRouteForRole(resolvedRole)
          : dashboardRouteForRole(resolvedRole));
  safePopOrGo(context, target);
}
