/// Persists that full sign-in still needs App Login MFA (survives process death).
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SignInMfaPendingStore {
  SignInMfaPendingStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
            );

  final FlutterSecureStorage _storage;

  String _key(String userId) => 'sign_in_mfa_pending_$userId';

  Future<bool> isPending(String userId) async {
    final v = await _storage.read(key: _key(userId));
    return v == '1';
  }

  Future<void> setPending(String userId) async {
    await _storage.write(key: _key(userId), value: '1');
  }

  Future<void> clearPending(String userId) async {
    await _storage.delete(key: _key(userId));
  }
}
