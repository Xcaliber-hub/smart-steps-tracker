// SPDX-License-Identifier: GPL-3.0-or-later
// Smart Steps Tracker — a free and open-source step counter.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase client configuration supplied by Android's google-services.json or
/// explicit build-time Dart options. Client options are not admin credentials;
/// access is protected by Firebase Authentication and Firestore rules.
class FirebaseService {
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _messagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  static Future<bool>? _initializing;

  static bool get configured =>
      _apiKey.isNotEmpty &&
      _appId.isNotEmpty &&
      _messagingSenderId.isNotEmpty &&
      _projectId.isNotEmpty;

  /// Initializes Firebase once, preferring explicit Dart options when present
  /// and otherwise using the platform's native default options. If no usable
  /// config exists, returns false so local-only tracking continues normally.
  static Future<bool> initialize() => _initializing ??= _initialize();

  static Future<bool> _initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        if (configured) {
          await Firebase.initializeApp(
            options: const FirebaseOptions(
              apiKey: _apiKey,
              appId: _appId,
              messagingSenderId: _messagingSenderId,
              projectId: _projectId,
            ),
          );
        } else {
          // On Android, the Google Services plugin exposes values generated
          // from android/app/google-services.json to Firebase Core.
          await Firebase.initializeApp();
        }
      }
      return true;
    } catch (error, stackTrace) {
      debugPrint('Firebase initialization failed: $error\n$stackTrace');
      return false;
    }
  }
}

/// Small wrapper for the email/password flows used by the groups screen.
class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final name = displayName.trim();
    if (name.isNotEmpty) await credential.user?.updateDisplayName(name);
    return credential;
  }

  Future<void> signOut() => _auth.signOut();
}
