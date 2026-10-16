import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Authentication wrapper.
///
/// All credential handling lives in Firebase Auth — no secrets are stored in
/// the app. Sign-in/sign-out drive the app-wide auth gate
/// ([authStateChanges]).
class AuthService {
  const AuthService._();

  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;

  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  static Future<void> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<void> signOut() => _auth.signOut();

  static Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  /// Maps a thrown auth error to a friendly, non-revealing message.
  static String messageFor(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'That email address is not valid.';
        case 'user-disabled':
          return 'This account has been disabled. Contact your administrator.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email or password is incorrect.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again in a moment.';
        case 'network-request-failed':
          return 'Network error. Check your connection and try again.';
        case 'operation-not-allowed':
          return 'Email sign-in is not enabled for this project yet.';
        default:
          return 'Sign in failed. Please try again.';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}
