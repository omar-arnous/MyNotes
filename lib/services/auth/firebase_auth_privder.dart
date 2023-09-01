import 'package:firebase_core/firebase_core.dart';
import 'package:mynotes/services/auth/auth_user.dart';
import 'package:mynotes/services/auth/auth_provider.dart';
import 'package:mynotes/services/auth/auth_exceptions.dart';

import 'package:firebase_auth/firebase_auth.dart'
    show FirebaseAuth, FirebaseAuthException;

import '../../firebase_options.dart';

class FirebaseAuthProvider implements AuthProvider {
  @override
  Future<AuthUser> createUser({
    required String email,
    required String password,
  }) async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = currentUser;
      if (user != null) {
        return user;
      } else {
        throw UserNotLoggedInAuthException();
      }
    } on FirebaseAuthException catch (err) {
      if (err.code == 'weak-password') {
        throw WeakPasswordAuthException();
      } else if (err.code == 'email-already-in-use') {
        throw EmailAlreadyInUseAuthException();
      } else if (err.code == 'invalid-email') {
        throw InvalidEmailAuthException();
      } else {
        throw GenreicAuthException();
      }
    } catch (_) {
      throw GenreicAuthException();
    }
  }

  @override
  AuthUser? get currentUser {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return AuthUser.fromFirebase(user);
    }

    return null;
  }

  @override
  Future<AuthUser> logIn(
      {required String email, required String password}) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = currentUser;
      if (user != null) {
        return user;
      }

      throw UserNotLoggedInAuthException();
    } on FirebaseAuthException catch (err) {
      if (err.code == 'user-not-found') {
        throw UserNotFoundAuthException();
      } else if (err.code == 'wrong-password') {
        throw WrongPasswordAuthException();
      } else {
        throw GenreicAuthException();
      }
    } catch (_) {
      throw GenreicAuthException();
    }
  }

  @override
  Future<void> logOut() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseAuth.instance.signOut();
    }

    throw UserNotLoggedInAuthException();
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await user.sendEmailVerification();
    }

    throw UserNotFoundAuthException();
  }

  @override
  Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  @override
  Future<void> sendPasswordReset({required String toEmail}) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: toEmail);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'firebase_auth/invalid-email') {
        throw InvalidEmailAuthException();
      } else if (e.code == 'firebase_auth/user_not_found') {
        throw UserNotFoundAuthException();
      } else {
        throw GenreicAuthException();
      }
    } catch (_) {
      throw GenreicAuthException();
    }
  }
}
