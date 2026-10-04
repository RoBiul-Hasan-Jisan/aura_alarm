import 'package:firebase_auth/firebase_auth.dart';
import 'alarm_scheduler.dart';
import 'api_service.dart';

/// Thin wrapper around Firebase Authentication (Email/Password).
class AuthService {
  static final _auth = FirebaseAuth.instance;

  static Stream<User?> get changes => _auth.authStateChanges();
  static User? get currentUser => _auth.currentUser;

  static bool get isGuest => _auth.currentUser?.isAnonymous ?? false;

  static Future<void> register(String name, String email, String password) async {
    final current = _auth.currentUser;
    if (current != null && current.isAnonymous) {
      // Demo visitor upgrading: keep the same account (and all their data) by linking an email/password.
      await current.linkWithCredential(EmailAuthProvider.credential(email: email, password: password));
      await current.updateDisplayName(name);
      await current.getIdToken(true); // refresh so the backend sees a real (non-guest) account
    } else {
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await cred.user?.updateDisplayName(name);
    }
    await ApiService.syncUser(name: name); // creates/updates the profile document in MongoDB
  }

  /// "Try the demo": anonymous Firebase sign-in + a private sandbox filled with sample data.
  static Future<void> loginAsGuest() async {
    await _auth.signInAnonymously();
    await ApiService.syncUser();
    await ApiService.demoSeed();
  }

  static Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    await ApiService.syncUser();
  }

  static Future<void> logout() async {
    await AlarmScheduler.cancelAll(); // this phone stops ringing for the signed-out user
    await _auth.signOut();
  }

  /// Turns Firebase error codes into messages a person can act on.
  static String message(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'admin-restricted-operation':
        case 'operation-not-allowed': return 'Demo mode isn’t switched on yet. Enable Anonymous sign-in in Firebase Console > Authentication.';
        case 'credential-already-in-use': return 'That email is already used by another account. Log in with it instead.';
        case 'invalid-email': return 'That email address looks wrong.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential': return 'Email or password is incorrect.';
        case 'email-already-in-use': return 'An account with this email already exists. Try logging in.';
        case 'weak-password': return 'Choose a password with at least 6 characters.';
        case 'network-request-failed': return 'No internet connection. Check your network and retry.';
        case 'too-many-requests': return 'Too many attempts. Wait a moment and try again.';
        default: return e.message ?? 'Authentication failed.';
      }
    }
    if (e is ApiException) return e.message;
    return 'Something went wrong. Please try again.';
  }
}
