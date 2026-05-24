import 'package:flutter/material.dart';
import 'package:heartech/features/about/screens/about_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'package:heartech/features/dashboard/screens/parent_children_screen.dart';
import 'package:heartech/features/dashboard/screens/teacher_dashboard_screen.dart';
import 'package:heartech/features/screening/screens/hcw_new_screening_screen.dart';
import 'package:heartech/features/screening/screens/hcw_patients_screen.dart';
import 'package:heartech/features/screening/screens/child_profile_screen.dart';
import 'package:heartech/features/screening/screens/teacher_observation_screen.dart';
import 'package:heartech/features/screening/screens/invite_teacher_screen.dart';
import 'package:heartech/features/screening/screens/pending_invites_screen.dart';
import 'package:heartech/features/referral/screens/referral_preview_screen.dart';
import 'package:heartech/features/referral/screens/referral_generation_screen.dart';
import 'package:heartech/features/referral/screens/referral_chat_screen.dart';
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
import 'package:heartech/features/teacher_dashboard/screens/child_profile_teacher_screen.dart';

// ============================================================================
// ROUTE NAMES
// ============================================================================

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
  static const referralPreview = '/referral-preview/:childId/:referralId';
  static const referralGeneration = '/referral-generate/:childId/:screeningId';
  static const referralChat = '/referral-chat/:childId';
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
  static const about = '/about';
}

// ============================================================================
// SLIDE TRANSITION — 280ms left-to-right with slide
// ============================================================================

const _transitionDuration = Duration(milliseconds: 280);

CustomTransitionPage<void> _slidePage({
  required Widget child,
  required GoRouterState state,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: _transitionDuration,
    reverseTransitionDuration: _transitionDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Forward: slide left-to-right (new page from right)
      final slideIn = Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut));

      // Back: slide right-to-left (current page exits to right)
      final slideOut = Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(1.0, 0.0),
      ).animate(
        CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeIn),
      );

      return SlideTransition(
        position: slideIn,
        child: SlideTransition(
          position: slideOut,
          child: child,
        ),
      );
    },
  );
}

/// Helper to create a GoRoute with the slide transition.
GoRoute _route(String path, Widget Function(GoRouterState s) builder) {
  return GoRoute(
    path: path,
    pageBuilder: (context, state) => _slidePage(child: builder(state), state: state),
  );
}

// ============================================================================
// ROUTER PROVIDER
// ============================================================================

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.splash,
    debugLogDiagnostics: true,
    observers: [ref.read(analyticsServiceProvider).getObserver()],
    redirect: (context, state) {
      final isLoggedIn = FirebaseAuth.instance.currentUser != null;
      final loc = state.matchedLocation;

      // Auth pages that don't require login
      final authPaths = [
        Routes.splash, Routes.roleSelect,
        Routes.parentLogin, Routes.hcwLogin, Routes.teacherLogin,
        Routes.parentRegister, Routes.hcwRegister, Routes.teacherRegister,
      ];
      final isAuthPage = authPaths.contains(loc);

      // Not logged in
      if (!isLoggedIn) {
        // Allow auth pages
        if (isAuthPage) return null;
        // Block everything else → splash
        return Routes.splash;
      }

      // Logged in — allow navigation to role-specific pages
      // (Login screen handles manual routing after fetching profile)
      if (isAuthPage && loc != Routes.splash) {
        // Already logged in but on a login/register page
        // This can happen on browser back button etc.
        // Don't redirect — the login screen will handle it
        return null;
      }

      return null;
    },
    routes: [
      // ── Auth ────────────────────────────────────────────────────────────
      GoRoute(path: Routes.splash, builder: (c, s) => const SplashScreen()),
      _route(Routes.roleSelect, (_) => const RoleSelectionScreen()),
      _route(Routes.hcwLogin, (_) => const HcwLoginScreen()),
      _route(Routes.parentLogin, (_) => const ParentLoginScreen()),
      _route(Routes.teacherLogin, (_) => const TeacherLoginScreen()),
      _route(Routes.hcwRegister, (_) => const HcwRegistrationScreen()),
      _route(Routes.parentRegister, (_) => const ParentRegistrationScreen()),
      _route(Routes.teacherRegister, (_) => const TeacherRegistrationScreen()),

      // ── HCW ─────────────────────────────────────────────────────────────
      _route(Routes.hcwDashboard, (_) => const HcwDashboardScreen()),
      _route(Routes.hcwPatients, (_) => const HcwPatientsScreen()),
      _route(Routes.hcwNotifications, (_) => const NotificationsScreen(role: 'hcw')),
      _route(Routes.hcwProfile, (_) => const HcwProfileScreen()),
      _route(Routes.hcwChildProfile, (s) => ChildProfileScreen(
          childId: s.pathParameters['childId']!, viewerRole: 'hcw')),
      _route(Routes.hcwNewScreening, (_) => const HcwNewScreeningScreen()),
      _route(Routes.referralPreview, (s) => ReferralPreviewScreen(
          childId: s.pathParameters['childId']!, referralId: s.pathParameters['referralId']!)),
      _route(Routes.referralGeneration, (s) => ReferralGenerationScreen(
          childId: s.pathParameters['childId']!, screeningId: s.pathParameters['screeningId']!)),
      _route(Routes.referralChat, (s) => ReferralChatScreen(
          childId: s.pathParameters['childId']!)),

      // ── Parent ──────────────────────────────────────────────────────────
      _route(Routes.parentDashboard, (_) => const ParentDashboardScreen()),
      _route(Routes.parentChildren, (_) => const ParentChildrenScreen()),
      _route(Routes.parentSpeechGames, (_) => const SpeechGamesScreen()),
      _route(Routes.parentNotifications, (_) => const NotificationsScreen(role: 'parent')),
      _route(Routes.parentProfile, (_) => const ParentProfileScreen()),
      _route(Routes.parentChildProfile, (s) => ChildProfileScreen(
          childId: s.pathParameters['childId']!, viewerRole: 'parent')),
      _route(Routes.parentClaimProfile, (_) => const ClaimProfileScreen()),
      _route(Routes.parentScreening, (_) => const ParentHomeScreeningScreen()),
      _route(Routes.parentInviteTeacher, (s) => InviteTeacherScreen(
          childId: s.pathParameters['childId']!)),

      // ── Teacher ─────────────────────────────────────────────────────────
      _route(Routes.teacherDashboard, (_) => const TeacherDashboardScreen()),
      _route(Routes.teacherMyClass, (_) => const MyClassScreen()),
      _route(Routes.teacherNotifications, (_) => const NotificationsScreen(role: 'teacher')),
      _route(Routes.teacherProfile, (_) => const TeacherProfileScreen()),
      _route(Routes.teacherInvites, (_) => const PendingInvitesScreen()),
      _route(Routes.teacherChildProfile, (s) => ChildProfileTeacherScreen(
          childId: s.pathParameters['childId']!)),
      _route(Routes.teacherObservation, (_) => const TeacherObservationScreen()),

      // ── Speech ──────────────────────────────────────────────────────────
      _route(Routes.showAndTell, (s) => ShowAndTellScreen(
          childId: s.pathParameters['childId']!)),
      _route(Routes.lingSix, (s) => LingSixScreen(
          childId: s.pathParameters['childId']!)),

      // ── Settings ────────────────────────────────────────────────────────
      _route(Routes.notificationPrefs, (_) => const NotificationPrefsScreen()),
      _route(Routes.about, (_) => const AboutScreen()),
    ],
  );
});
