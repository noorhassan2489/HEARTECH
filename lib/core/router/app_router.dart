import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heartech/core/di/providers.dart';

import 'package:heartech/features/auth/screens/splash_screen.dart';
import 'package:heartech/features/auth/screens/role_selection_screen.dart';
import 'package:heartech/features/auth/screens/hcw_login_screen.dart';
import 'package:heartech/features/auth/screens/parent_login_screen.dart';
import 'package:heartech/features/auth/screens/teacher_login_screen.dart';
import 'package:heartech/features/auth/screens/hcw_registration_screen.dart';
import 'package:heartech/features/auth/screens/parent_registration_screen.dart';
import 'package:heartech/features/auth/screens/teacher_registration_screen.dart';
import 'package:heartech/features/auth/screens/claim_profile_screen.dart';
import 'package:heartech/features/dashboard/screens/hcw_dashboard_screen.dart';
import 'package:heartech/features/dashboard/screens/parent_dashboard_screen.dart';
import 'package:heartech/features/dashboard/screens/teacher_dashboard_screen.dart';
import 'package:heartech/features/screening/screens/hcw_new_screening_screen.dart';
import 'package:heartech/features/screening/screens/hcw_patients_screen.dart';
import 'package:heartech/features/screening/screens/child_profile_screen.dart';
import 'package:heartech/features/screening/screens/teacher_observation_screen.dart';
import 'package:heartech/features/screening/screens/invite_teacher_screen.dart';
import 'package:heartech/features/screening/screens/pending_invites_screen.dart';
import 'package:heartech/features/screening/screens/parent_home_screening_screen.dart';
import 'package:heartech/features/screening/screens/my_class_screen.dart';
import 'package:heartech/features/settings/screens/hcw_profile_screen.dart';
import 'package:heartech/features/settings/screens/parent_profile_screen.dart';
import 'package:heartech/features/settings/screens/teacher_profile_screen.dart';
import 'package:heartech/features/settings/screens/notification_prefs_screen.dart';
import 'package:heartech/features/notifications/screens/notifications_screen.dart';
import 'package:heartech/features/speech/screens/speech_games_screen.dart';
import 'package:heartech/features/speech/screens/show_and_tell_screen.dart';
import 'package:heartech/features/speech/screens/ling_six_screen.dart';

class _Placeholder extends StatelessWidget {
  final String title;
  const _Placeholder(this.title);
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Center(child: Text(title)),
  );
}

class Routes {
  Routes._();
  static const splash = '/splash';
  static const roleSelect = '/role-select';
  static const parentLogin = '/login/parent';
  static const hcwLogin = '/login/hcw';
  static const teacherLogin = '/login/teacher';
  static const parentRegister = '/register/parent';
  static const hcwRegister = '/register/hcw';
  static const teacherRegister = '/register/teacher';
  static const hcwDashboard = '/hcw/dashboard';
  static const hcwPatients = '/hcw/patients';
  static const hcwNotifications = '/hcw/notifications';
  static const hcwProfile = '/hcw/profile';
  static const hcwChildProfile = '/hcw/child/:childId';
  static const hcwNewScreening = '/hcw/screening/new';
  static const hcwReferralPreview = '/hcw/referral-preview/:childId/:referralId';
  static const parentDashboard = '/parent/dashboard';
  static const parentChildren = '/parent/children';
  static const parentSpeechGames = '/parent/speech-games';
  static const parentNotifications = '/parent/notifications';
  static const parentProfile = '/parent/profile';
  static const parentChildProfile = '/parent/child/:childId';
  static const parentClaimProfile = '/parent/claim-profile';
  static const parentScreening = '/parent/screening';
  static const parentInviteTeacher = '/parent/invite-teacher/:childId';
  static const teacherDashboard = '/teacher/dashboard';
  static const teacherMyClass = '/teacher/my-class';
  static const teacherNotifications = '/teacher/notifications';
  static const teacherProfile = '/teacher/profile';
  static const teacherInvites = '/teacher/invites';
  static const teacherChildProfile = '/teacher/child/:childId';
  static const teacherObservation = '/teacher/observation';
  static const showAndTell = '/speech/show-and-tell/:childId';
  static const lingSix = '/speech/ling-six/:childId';
  static const notificationPrefs = '/settings/notification-prefs';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final authPaths = [
        Routes.splash, Routes.roleSelect,
        Routes.parentLogin, Routes.hcwLogin, Routes.teacherLogin,
        Routes.parentRegister, Routes.hcwRegister, Routes.teacherRegister,
      ];
      if (authPaths.contains(state.matchedLocation)) return null;
      if (ref.read(currentFirebaseUserProvider) == null) return Routes.splash;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (c, s) => const SplashScreen()),
      GoRoute(path: Routes.roleSelect, builder: (c, s) => const RoleSelectionScreen()),
      GoRoute(path: Routes.hcwLogin, builder: (c, s) => const HcwLoginScreen()),
      GoRoute(path: Routes.parentLogin, builder: (c, s) => const ParentLoginScreen()),
      GoRoute(path: Routes.teacherLogin, builder: (c, s) => const TeacherLoginScreen()),
      GoRoute(path: Routes.hcwRegister, builder: (c, s) => const HcwRegistrationScreen()),
      GoRoute(path: Routes.parentRegister, builder: (c, s) => const ParentRegistrationScreen()),
      GoRoute(path: Routes.teacherRegister, builder: (c, s) => const TeacherRegistrationScreen()),
      GoRoute(path: Routes.hcwDashboard, builder: (c, s) => const HcwDashboardScreen()),
      GoRoute(path: Routes.hcwPatients, builder: (c, s) => const HcwPatientsScreen()),
      GoRoute(path: Routes.hcwNotifications, builder: (c, s) => const NotificationsScreen(role: 'hcw')),
      GoRoute(path: Routes.hcwProfile, builder: (c, s) => const HcwProfileScreen()),
      GoRoute(path: Routes.hcwChildProfile, builder: (c, s) => ChildProfileScreen(
          childId: s.pathParameters['childId']!, viewerRole: 'hcw')),
      GoRoute(path: Routes.hcwNewScreening, builder: (c, s) => const HcwNewScreeningScreen()),
      GoRoute(path: Routes.hcwReferralPreview, builder: (c, s) => const _Placeholder('Referral Preview')),
      GoRoute(path: Routes.parentDashboard, builder: (c, s) => const ParentDashboardScreen()),
      GoRoute(path: Routes.parentChildren, builder: (c, s) => const _Placeholder('My Children')),
      GoRoute(path: Routes.parentSpeechGames, builder: (c, s) => const SpeechGamesScreen()),
      GoRoute(path: Routes.parentNotifications, builder: (c, s) => const NotificationsScreen(role: 'parent')),
      GoRoute(path: Routes.parentProfile, builder: (c, s) => const ParentProfileScreen()),
      GoRoute(path: Routes.parentChildProfile, builder: (c, s) => ChildProfileScreen(
          childId: s.pathParameters['childId']!, viewerRole: 'parent')),
      GoRoute(path: Routes.parentClaimProfile, builder: (c, s) => const ClaimProfileScreen()),
      GoRoute(path: Routes.parentScreening, builder: (c, s) => const ParentHomeScreeningScreen()),
      GoRoute(path: Routes.parentInviteTeacher, builder: (c, s) => InviteTeacherScreen(
          childId: s.pathParameters['childId']!)),
      GoRoute(path: Routes.teacherDashboard, builder: (c, s) => const TeacherDashboardScreen()),
      GoRoute(path: Routes.teacherMyClass, builder: (c, s) => const MyClassScreen()),
      GoRoute(path: Routes.teacherNotifications, builder: (c, s) => const NotificationsScreen(role: 'teacher')),
      GoRoute(path: Routes.teacherProfile, builder: (c, s) => const TeacherProfileScreen()),
      GoRoute(path: Routes.teacherInvites, builder: (c, s) => const PendingInvitesScreen()),
      GoRoute(path: Routes.teacherChildProfile, builder: (c, s) => ChildProfileScreen(
          childId: s.pathParameters['childId']!, viewerRole: 'teacher')),
      GoRoute(path: Routes.teacherObservation, builder: (c, s) => const TeacherObservationScreen()),
      GoRoute(path: Routes.showAndTell, builder: (c, s) => ShowAndTellScreen(
          childId: s.pathParameters['childId']!)),
      GoRoute(path: Routes.lingSix, builder: (c, s) => LingSixScreen(
          childId: s.pathParameters['childId']!)),
      GoRoute(path: Routes.notificationPrefs, builder: (c, s) => const NotificationPrefsScreen()),
    ],
  );
});
