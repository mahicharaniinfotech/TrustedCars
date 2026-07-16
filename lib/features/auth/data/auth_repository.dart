import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper over Firebase Phone Auth. Screens and providers talk to
/// this, never to FirebaseAuth directly — keeps every auth call in one
/// place. Supabase itself trusts the Firebase-issued ID token via its
/// Third-Party Auth integration (see supabase_config.dart) rather than
/// issuing its own separate session.
class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  String? get currentUserId => _auth.currentUser?.uid;

  bool get isLoggedIn => currentUser != null;

  Future<void> signOut() => _auth.signOut();

  /// Sends a 6-digit OTP via SMS to [phone] (must be E.164, e.g. +91XXXXXXXXXX).
  /// Resolves with the verificationId needed to actually check the code —
  /// pass this along to verifyPhoneOtp.
  Future<String> signInWithOtp({required String phone}) {
    final completer = Completer<String>();
    _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Android auto-retrieval can complete instantly, without the user
        // ever typing a code. Sign in right away when that happens.
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        // Only matters if codeSent never fired first — rare, but covers it.
        if (!completer.isCompleted) completer.complete(verificationId);
      },
    );
    return completer.future;
  }

  /// Verifies the 6-digit [token] against [verificationId]. Returns the
  /// signed-in user's Firebase uid on success.
  ///
  /// Force-refreshes the ID token afterwards so the `role: authenticated`
  /// custom claim (set by our addAuthenticatedClaim Cloud Function) is
  /// picked up immediately, rather than waiting for the token's natural
  /// refresh cycle — the Cloud Function runs asynchronously right after
  /// signup, so without this, the very first Supabase request could still
  /// carry a claim-less token.
  Future<String> verifyPhoneOtp({
    required String verificationId,
    required String token,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: token,
    );
    final result = await _auth.signInWithCredential(credential);
    await result.user?.getIdToken(true);
    return result.user!.uid;
  }
}
