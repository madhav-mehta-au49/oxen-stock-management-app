import 'package:firebase_auth/firebase_auth.dart';

/// Firebase Authentication wrapper.
///
/// Login accepts a **username** (mapped to `<username>@oxenenergies.com`) or a
/// full email address.
class AuthService {
  const AuthService._();

  static const String usernameDomain = 'oxenenergies.com';

  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;

  static Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Maps `Oxenstore` -> `oxenstore@oxenenergies.com`. A value containing `@`
  /// is treated as an email and used as-is.
  static String emailFor(String usernameOrEmail) {
    final value = usernameOrEmail.trim();
    if (value.contains('@')) return value;
    return '${value.toLowerCase()}@$usernameDomain';
  }

  static Future<void> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: emailFor(email),
      password: password,
    );
  }

  static Future<void> signOut() => _auth.signOut();

  static Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: emailFor(email));

  /// Maps a thrown auth error to a friendly, non-revealing message.
  static String messageFor(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'That username is not valid.';
        case 'user-disabled':
          return 'This account has been disabled. Contact your administrator.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Username or password is incorrect.';
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
