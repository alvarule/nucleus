import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vaultify/core/errors/app_exception.dart';
import 'package:vaultify/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Stream<String?> authStateChanges() {
    return _client.auth.onAuthStateChange.map((event) => event.session?.user.id);
  }

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  Future<String> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'name': name.trim()},
      );
      final user = response.user;
      if (user == null) {
        throw const AuthFailure(
          'Sign up failed. Check email confirmation settings in Supabase.',
        );
      }
      return user.id;
    } on AuthFailure {
      rethrow;
    } catch (e) {
      throw AuthFailure(_friendly(e), cause: e);
    }
  }

  @override
  Future<String> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthFailure('Sign in failed');
      }
      return user.id;
    } on AuthFailure {
      rethrow;
    } catch (e) {
      throw AuthFailure(_friendly(e), cause: e);
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  String _friendly(Object e) {
    final text = e.toString();
    if (text.toLowerCase().contains('invalid login')) {
      return 'Invalid email or master password';
    }
    return text;
  }
}
