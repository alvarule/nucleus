/// Supabase Auth adapter. Maps SDK errors to [AuthFailure] with friendlier copy.
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nucleus/core/errors/app_exception.dart';
import 'package:nucleus/core/errors/offline_messages.dart';
import 'package:nucleus/core/network/connectivity_service.dart';
import 'package:nucleus/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._client, this._connectivity);

  final SupabaseClient _client;
  final ConnectivityService _connectivity;

  Future<void> _ensureOnline() async {
    if (!await _connectivity.hasConnection()) {
      throw OfflineException(randomOfflineMessage());
    }
  }
  @override
  Stream<String?> authStateChanges() {
    return _client.auth.onAuthStateChange.map((event) => event.session?.user.id);
  }

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  String? get currentUserEmail => _client.auth.currentUser?.email;

  @override
  String? get currentUserName {
    final meta = _client.auth.currentUser?.userMetadata;
    final name = '${meta?['name'] ?? ''}'.trim();
    return name.isEmpty ? null : name;
  }

  @override
  Future<void> requestSignupLink({
    required String email,
    required String name,
  }) {
    return _sendSignupOtp(email: email, name: name);
  }

  @override
  Future<void> resendSignupLink({
    required String email,
    required String name,
  }) {
    return _sendSignupOtp(email: email, name: name);
  }

  Future<void> _sendSignupOtp({
    required String email,
    required String name,
  }) async {
    await _ensureOnline();
    try {
      await _client.auth.signInWithOtp(
        email: email.trim(),
        emailRedirectTo: nucleusAuthRedirect,
        data: {'name': name.trim()},
        shouldCreateUser: true,
      );
    } on AuthFailure {
      rethrow;
    } on OfflineException {
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
    await _ensureOnline();
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
    } on OfflineException {
      rethrow;
    } catch (e) {
      throw AuthFailure(_friendly(e), cause: e);
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<void> updatePassword(String newPassword) async {
    await _ensureOnline();
    try {
      final response = await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      if (response.user == null) {
        throw const AuthFailure('Could not update master password');
      }
    } on AuthFailure {
      rethrow;
    } on OfflineException {
      rethrow;
    } catch (e) {
      throw AuthFailure(_friendly(e), cause: e);
    }
  }

  /// Maps common Supabase auth errors to short UI strings; otherwise raw text.
  String _friendly(Object e) {
    final text = e.toString();
    final lower = text.toLowerCase();
    if (lower.contains('invalid login')) {
      return 'Invalid email or master password';
    }
    if (lower.contains('same_password') ||
        lower.contains('should be different')) {
      return 'New master password must be different from the current one';
    }
    if (lower.contains('weak') || lower.contains('at least')) {
      return 'New master password is too weak';
    }
    if (lower.contains('already registered') ||
        lower.contains('already been registered')) {
      return 'An account with this email already exists. Log in instead.';
    }
    return text;
  }
}
