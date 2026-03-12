import 'package:flutter/material.dart';

import '../../features/auth/screens/role_selection_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/first_time_login_check_screen.dart';
import '../../features/auth/screens/parent_login_screen.dart';
import '../../features/auth/screens/hw_login_screen.dart';
import '../../features/auth/screens/teacher_login_screen.dart';
import '../../features/auth/screens/parent_registration_screen.dart';
import '../../features/auth/screens/hcw_registration_screen.dart';
import '../../features/auth/screens/teacher_registration_screen.dart';
import '../theme/page_transitions.dart';
import '../../features/dashboard/screens/hcw_dashboard_screen.dart';
import '../../features/dashboard/screens/parent_dashboard_screen.dart';
import '../../features/dashboard/screens/teacher_dashboard_screen.dart';
import '../../features/notifications/screens/notification_center_screen.dart';
import '../../features/screening/screens/screening_flow_screen.dart';
import '../../features/child_profile/screens/child_profile_creation_screen.dart';
import '../../features/child_profile/screens/child_profile_dashboard.dart';
import '../../features/screening/screens/screening_result_screen.dart';
import '../../features/speech/screens/speech_module_screen.dart';
import '../../features/speech/screens/show_and_tell_screen.dart';
import '../../features/speech/screens/ling_six_screen.dart';
import '../../features/referral/screens/referral_preview_screen.dart';
/// Centralized named-route navigation for the app.
class AppRouter {
  AppRouter._();

  // ─── Route Names ────────────────────────────────────────────────
  static const String splash          = '/';
  static const String authCheck       = '/auth-check';
  static const String roleSelect      = '/role-select';
  static const String parentLogin     = '/parent/login';
  static const String parentRegister  = '/parent/register';
  static const String parentDashboard = '/parent/dashboard';
  static const String hcwLogin        = '/hcw/login';
  static const String hcwRegister     = '/hcw/register';
  static const String hcwDashboard    = '/hcw/dashboard';
  static const String teacherLogin    = '/teacher/login';
  static const String teacherRegister = '/teacher/register';
  static const String teacherDashboard= '/teacher/dashboard';
  static const String notifications   = '/notifications';
  static const String newScreening    = '/screening/new';
  static const String screeningResult = '/screening/result';
  static const String speechModules = '/speech';
  static const String showAndTell = '/speech/show-and-tell';
  static const String lingSix = '/speech/ling-six';
  static const String referralPreview = '/referral/preview';
  static const String childCreate     = '/child/create';
  static const String childProfile    = '/child/profile';

  /// Generate a [Route] from route settings (used with onGenerateRoute).
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return _fade(const SplashScreen());
      case authCheck:
        final args = settings.arguments as Map<String, dynamic>;
        return _fade(FirstTimeLoginCheckScreen(uid: args['uid']));
      case roleSelect:
        return _fade(const RoleSelectionScreen());

      // ── Auth ──
      case parentLogin:
        return _slide(const ParentLoginScreen());
      case parentRegister:
        return _slide(const ParentRegistrationScreen());
      case hcwLogin:
        return _slide(const HWLoginScreen());
      case hcwRegister:
        return _slide(const HCWRegistrationScreen());
      case teacherLogin:
        return _slide(const TeacherLoginScreen());
      case teacherRegister:
        return _slide(const TeacherRegistrationScreen());

      // ── Dashboards ──
      case parentDashboard:
        return _fade(const ParentDashboardScreen());
      case hcwDashboard:
        return _fade(const HCWDashboardScreen());
      case teacherDashboard:
        return _fade(const TeacherDashboardScreen());

      case notifications:
        // Use cupertino/slide transition for notifications typical of iOS
        return SlideForwardTransition(
          page: const NotificationCenterScreen(),
        );

      // ── Screening ──
      case newScreening:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return _slide(ScreeningFlowScreen(
          role: args['role'] ?? 'Healthcare Worker',
          initialInfo: args['initialInfo'],
        ));
      case screeningResult:
        final args = settings.arguments as Map<String, dynamic>;
        return _slide(ScreeningResultScreen(
          riskScore: args['riskScore'],
          riskLevel: args['riskLevel'],
          sessionData: args['sessionData'],
          role: args['role'],
        ));

      // ── Child Profile ──
      case childCreate:
        final args = settings.arguments as Map<String, dynamic>?;
        return _slide(ChildProfileCreationScreen(
          sessionData: args ?? {},
        ));
      case childProfile:
        final args = settings.arguments as Map<String, dynamic>;
        return _slide(ChildProfileDashboard(
          childId: args['childId'],
          viewerRole: args['viewerRole'],
        ));

      // ── AI & Speech ──
      case speechModules:
        final args = settings.arguments as Map<String, dynamic>;
        return _slide(SpeechModuleScreen(childId: args['childId']));
      case showAndTell:
        final args = settings.arguments as Map<String, dynamic>;
        return _slide(ShowAndTellScreen(childId: args['childId']));
      case lingSix:
        final args = settings.arguments as Map<String, dynamic>;
        return _slide(LingSixScreen(childId: args['childId']));
      case referralPreview:
        final args = settings.arguments as Map<String, dynamic>;
        return _slide(ReferralPreviewScreen(childId: args['childId']));

      // ── Fallback ──
      default:
        return _fade(const RoleSelectionScreen());
    }
  }

  // ─── Transition Helpers ─────────────────────────────────────────
  static PageRouteBuilder _fade(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }

  static PageRouteBuilder _slide(Widget page) => PremiumTransition(page: page);
}
