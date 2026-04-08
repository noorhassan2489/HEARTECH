import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:heartech/services/notification_service.dart';

/// Firebase Authentication service — handles login, register, sign out.
class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Current Firebase user (null if not logged in).
  User? get currentUser => _auth.currentUser;

  /// Current user UID.
  String? get uid => _auth.currentUser?.uid;

  /// Stream of auth state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password.
  Future<UserCredential> signInWithEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential;
  }

  /// Create account with email and password.
  Future<UserCredential> createAccountWithEmail(
      String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential;
  }

  /// Sign in with Google.
  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // User cancelled

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final result = await _auth.signInWithCredential(credential);
    return result;
  }

  /// Send password reset email.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Register OneSignal after sign in (call after Firestore profile is found/created).
  Future<void> registerOneSignal(String uid, String role) async {
    try {
      await NotificationService.onLogin(uid, role);
    } catch (_) {
      // OneSignal registration is non-critical — don't block auth flow
    }
  }

  /// Sign out from Firebase, Google, and OneSignal.
  Future<void> signOut() async {
    try {
      await NotificationService.onLogout();
    } catch (_) {
      // Non-critical
    }
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Get Firebase ID token for API calls.
  Future<String?> getIdToken() async {
    return await _auth.currentUser?.getIdToken();
  }
}
