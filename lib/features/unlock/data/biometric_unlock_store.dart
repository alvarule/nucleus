import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Stores device-wrapped DEK for biometric unlock; never stores master password.
class BiometricUnlockStore {
  BiometricUnlockStore({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuth,
  })  : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
            ),
        _localAuth = localAuth ?? LocalAuthentication();

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  static const _dekKeyPrefix = 'vault_dek_';

  int _authDepth = 0;

  /// True while a biometric / device-credential prompt is showing.
  bool get isAuthenticating => _authDepth > 0;

  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({String reason = 'Unlock Vaultify'}) async {
    _authDepth++;
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    } finally {
      _authDepth--;
    }
  }

  Future<void> saveDek(String userId, Uint8List dek) async {
    final encoded = dek.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await _storage.write(key: '$_dekKeyPrefix$userId', value: encoded);
  }

  Future<Uint8List?> readDek(String userId) async {
    final value = await _storage.read(key: '$_dekKeyPrefix$userId');
    if (value == null || value.isEmpty) return null;
    final bytes = Uint8List(value.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(value.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  Future<void> clearDek(String userId) async {
    await _storage.delete(key: '$_dekKeyPrefix$userId');
  }

  Future<bool> hasStoredDek(String userId) async {
    return (await _storage.containsKey(key: '$_dekKeyPrefix$userId'));
  }
}
