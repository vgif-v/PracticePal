import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  // ---------------------------------------------------------------------------
  // Email/Password
  // ---------------------------------------------------------------------------

  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> registerWithEmail(
    String email,
    String password,
  ) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // ---------------------------------------------------------------------------
  // Google Sign-In
  // ---------------------------------------------------------------------------

  Future<UserCredential?> signInWithGoogle() async {
    // On the Web, use Firebase Auth's official signInWithPopup to avoid
    // the deprecated google_sign_in.signIn() method on Google Identity Services.
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      return await _auth.signInWithPopup(googleProvider);
    }

    // Native mobile platforms (Android, iOS) use google_sign_in
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // user cancelled

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  // ---------------------------------------------------------------------------
  // Sign Out
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // Firestore — User Document
  // ---------------------------------------------------------------------------

  Future<bool> checkUserExists(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.exists;
  }

  Future<void> createUserDocument(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<UserModel?> getUserModel(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  Future<UserRole?> getUserRole(String uid) async {
    final user = await getUserModel(uid);
    return user?.role;
  }

  // ---------------------------------------------------------------------------
  // Update a user's profile fields (used for student profile completion)
  // ---------------------------------------------------------------------------
  Future<void> updateUserProfile(
    String uid, {
    String? address,
    DateTime? birthdate,
    String? fullName,
  }) async {
    final updates = <String, dynamic>{};
    if (address != null) updates['address'] = address;
    if (fullName != null) updates['fullName'] = fullName;
    if (birthdate != null) {
      updates['birthdate'] =
          Timestamp.fromDate(birthdate);
    }
    if (updates.isEmpty) return;
    await _firestore
        .collection('users')
        .doc(uid)
        .set(updates, SetOptions(merge: true));
  }
}
