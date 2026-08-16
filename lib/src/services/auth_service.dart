import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

/// Authentication boundary so screens can be tested with a fake.
abstract class AuthService {
  Stream<User?> authStateChanges();

  User? get currentUser;

  Future<void> signInWithEmail(String email, String password);

  Future<void> registerWithEmail(String email, String password);

  /// Returns silently if the user cancels the Google flow.
  Future<void> signInWithGoogle();

  Future<void> signOut();

  /// Provider ids for the signed-in user, e.g. `password` or `google.com`.
  /// Used to pick the right re-authentication flow before deleting the
  /// account.
  List<String> get providerIds;

  /// Profile picture of the signed-in user, when the provider supplies one
  /// (Google does; email/password does not). Null means "show a fallback".
  String? get photoUrl;

  /// Re-proves identity with the account's password. Throws
  /// [FirebaseAuthException] (e.g. `wrong-password`) on failure.
  Future<void> reauthenticateWithPassword(String password);

  /// Re-proves identity via the Google flow. Throws if the user cancels it.
  Future<void> reauthenticateWithGoogle();

  /// Permanently deletes the signed-in Firebase Auth account.
  ///
  /// Firebase requires a *recent* sign-in for this; call a `reauthenticate*`
  /// method first or this throws `FirebaseAuthException(requires-recent-login)`.
  Future<void> deleteAccount();
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: const ['email']);

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  @override
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<void> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> registerWithEmail(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> signInWithGoogle() async {
    if (kIsWeb) {
      await _auth.signInWithPopup(GoogleAuthProvider());
      return;
    }
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return; // User cancelled the picker.
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await _auth.signInWithCredential(credential);
  }

  @override
  Future<void> signOut() async {
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }

  @override
  List<String> get providerIds =>
      _auth.currentUser?.providerData.map((p) => p.providerId).toList() ??
      const [];

  @override
  String? get photoUrl {
    final user = _auth.currentUser;
    // The top-level photoURL can be null even when a federated provider has
    // one, so fall back to the provider entries.
    return user?.photoURL ??
        user?.providerData
            .map((p) => p.photoURL)
            .firstWhere((url) => url != null, orElse: () => null);
  }

  @override
  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw StateError('No password-based account is signed in.');
    }
    final credential =
        EmailAuthProvider.credential(email: email, password: password);
    await user.reauthenticateWithCredential(credential);
  }

  @override
  Future<void> reauthenticateWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (kIsWeb) {
      await user.reauthenticateWithPopup(GoogleAuthProvider());
      return;
    }
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'reauthentication-cancelled',
        message: 'Google re-authentication was cancelled.',
      );
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await user.reauthenticateWithCredential(credential);
  }

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
    await user.delete();
  }
}
