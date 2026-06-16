import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:heartech/core/di/providers.dart';
import 'package:heartech/core/router/app_router.dart';

enum RegistrationAuthMode {
  createAccount,
  continueProfile,
  wrongRolePending,
}

/// Loaded registration session for a specific role portal.
class RegistrationSessionState {
  final RegistrationAuthMode mode;
  final int resumeStep;
  final String? pendingRole;
  final String? email;

  const RegistrationSessionState({
    this.mode = RegistrationAuthMode.createAccount,
    this.resumeStep = 0,
    this.pendingRole,
    this.email,
  });

  bool get canContinue => mode == RegistrationAuthMode.continueProfile;
  bool get isAuthenticated =>
      mode == RegistrationAuthMode.continueProfile ||
      mode == RegistrationAuthMode.wrongRolePending;
}

class _PendingRegistration {
  final String role;
  final int step;
  final String uid;

  const _PendingRegistration({
    required this.role,
    required this.step,
    required this.uid,
  });

  Map<String, dynamic> toMap() => {
        'role': role,
        'step': step,
        'uid': uid,
      };

  factory _PendingRegistration.fromMap(Map<dynamic, dynamic> map) {
    return _PendingRegistration(
      role: map['role'] as String,
      step: map['step'] as int? ?? 1,
      uid: map['uid'] as String,
    );
  }
}

/// Shared helpers for multi-step registration screens.
class RegistrationFlow {
  RegistrationFlow._();

  static const _boxName = 'registration_box';
  static const _pendingKey = 'pending_registration';

  static Future<Box<dynamic>> _box() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  static String roleLabel(String role) {
    switch (role) {
      case 'hcw':
        return 'Healthcare Worker';
      case 'parent':
        return 'Parent';
      case 'teacher':
        return 'Teacher';
      default:
        return role;
    }
  }

  static String registerRouteForRole(String role) {
    switch (role) {
      case 'hcw':
        return Routes.hcwRegister;
      case 'parent':
        return Routes.parentRegister;
      case 'teacher':
        return Routes.teacherRegister;
      default:
        return Routes.roleSelect;
    }
  }

  static Future<void> markPendingRole({
    required WidgetRef ref,
    required String role,
    int step = 1,
  }) async {
    final uid = ref.read(firebaseAuthServiceProvider).currentUser?.uid;
    if (uid == null) return;
    final box = await _box();
    await box.put(
      _pendingKey,
      _PendingRegistration(role: role, step: step, uid: uid).toMap(),
    );
  }

  static Future<void> saveProgress({
    required WidgetRef ref,
    required String role,
    required int step,
  }) async {
    await markPendingRole(ref: ref, role: role, step: step);
  }

  static Future<void> clearPendingRegistration() async {
    final box = await _box();
    await box.delete(_pendingKey);
  }

  static Future<_PendingRegistration?> _readPending() async {
    final box = await _box();
    final raw = box.get(_pendingKey);
    if (raw is! Map) return null;
    return _PendingRegistration.fromMap(Map<dynamic, dynamic>.from(raw));
  }

  /// Load session for the current role portal.
  static Future<RegistrationSessionState> loadSession({
    required WidgetRef ref,
    required String currentRole,
  }) async {
    final authService = ref.read(firebaseAuthServiceProvider);
    final user = authService.currentUser;

    if (user == null) {
      return const RegistrationSessionState();
    }

    final profile = await ref.read(firestoreServiceProvider).getUser(user.uid);
    if (profile != null) {
      await clearPendingRegistration();
      return RegistrationSessionState(
        mode: RegistrationAuthMode.createAccount,
        email: user.email,
      );
    }

    final email = user.email;
    final pending = await _readPending();

    if (pending == null || pending.uid != user.uid) {
      if (pending != null && pending.uid != user.uid) {
        await clearPendingRegistration();
      }
      return RegistrationSessionState(
        mode: RegistrationAuthMode.wrongRolePending,
        pendingRole: null,
        email: email,
      );
    }

    if (pending.role != currentRole) {
      return RegistrationSessionState(
        mode: RegistrationAuthMode.wrongRolePending,
        pendingRole: pending.role,
        email: email,
      );
    }

    return RegistrationSessionState(
      mode: RegistrationAuthMode.continueProfile,
      resumeStep: pending.step.clamp(1, 99),
      pendingRole: currentRole,
      email: email,
    );
  }

  /// Prefill email and restore step for matching role only.
  static Future<RegistrationSessionState> prepareSession({
    required WidgetRef ref,
    required String currentRole,
    required TextEditingController emailController,
  }) async {
    final session = await loadSession(ref: ref, currentRole: currentRole);
    final email = session.email;
    if (email != null && email.isNotEmpty) {
      emailController.text = email;
    }
    return session;
  }

  static Future<void> signOutAndRestart({
    required WidgetRef ref,
    required TextEditingController emailController,
    required TextEditingController passwordController,
    required TextEditingController confirmPasswordController,
    required VoidCallback onCleared,
  }) async {
    await clearPendingRegistration();
    await ref.read(firebaseAuthServiceProvider).signOut();
    emailController.clear();
    passwordController.clear();
    confirmPasswordController.clear();
    onCleared();
  }
}
