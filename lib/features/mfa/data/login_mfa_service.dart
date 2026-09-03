/// App login MFA: TOTP enrollment, KEK-wrapped secrets, and backup recovery codes.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:otp/otp.dart';
import 'package:nucleus/core/crypto/vault_crypto_service.dart';
import 'package:nucleus/features/profile/domain/entities/user_profile.dart';

/// Plaintext backup payload before KEK encryption.
class LoginBackupPayload {
  const LoginBackupPayload({
    required this.codeHashes,
    required this.usedIndices,
  });

  final List<String> codeHashes;
  final List<int> usedIndices;

  Map<String, dynamic> toJson() => {
        'code_hashes': codeHashes,
        'used_indices': usedIndices,
      };

  factory LoginBackupPayload.fromJson(Map<String, dynamic> json) {
    return LoginBackupPayload(
      codeHashes: (json['code_hashes'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      usedIndices: (json['used_indices'] as List?)
              ?.map((e) => e as int)
              .toList() ??
          [],
    );
  }
}

class LoginMfaService {
  LoginMfaService(this._crypto);

  final VaultCryptoService _crypto;
  static const _backupCodeCount = 10;
  static const _backupCodeLength = 8;
  static const _base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  static const _backupAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Random base32 TOTP secret for enrollment (20 bytes → standard key size).
  String generateEnrollmentSecret() {
    final random = Random.secure();
    final bytes = List<int>.generate(20, (_) => random.nextInt(256));
    return _base32Encode(bytes);
  }

  String buildOtpAuthUri({
    required String email,
    required String secret,
  }) {
    final account = Uri.encodeComponent(email);
    final issuer = Uri.encodeComponent('Nucleus');
    return 'otpauth://totp/$issuer:$account?secret=$secret&issuer=$issuer&algorithm=SHA1&digits=6&period=30';
  }

  static const _totpIntervalSec = 30;
  static const _totpDigits = 6;
  /// Extra steps beyond the submit→verify elapsed range (clock skew).
  static const _totpWindowSteps = 2;

  String generateCode(String secret) {
    return _totpCodeAt(secret, DateTime.now().millisecondsSinceEpoch);
  }

  String _totpCodeAt(String secret, int timeMs) {
    return OTP.generateTOTPCodeString(
      secret,
      timeMs,
      length: _totpDigits,
      interval: _totpIntervalSec,
      algorithm: Algorithm.SHA1,
      isGoogle: true,
    );
  }

  int _stepIndexFromMs(int timeMs) =>
      (timeMs ~/ 1000) ~/ _totpIntervalSec;

  /// Validates a 6-digit code against TOTP steps from [submittedAtMs] through now,
  /// plus [_totpWindowSteps] on each side (covers Argon2 delay and period rollover).
  bool verifyPlaintextTotp({
    required String secret,
    required String sixDigitCode,
    int? submittedAtMs,
  }) {
    final code = sixDigitCode.trim();
    if (code.length != _totpDigits) return false;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final startMs = submittedAtMs ?? nowMs;
    final startStep = _stepIndexFromMs(startMs);
    final endStep = _stepIndexFromMs(nowMs);
    final minStep = (startStep < endStep ? startStep : endStep) - _totpWindowSteps;
    final maxStep = (startStep > endStep ? startStep : endStep) + _totpWindowSteps;

    for (var step = minStep; step <= maxStep; step++) {
      final timeMs = step * _totpIntervalSec * 1000;
      if (OTP.constantTimeVerification(code, _totpCodeAt(secret, timeMs))) {
        return true;
      }
    }
    return false;
  }

  Future<({String ciphertext, String nonce})> wrapTotpSecret({
    required String masterPassword,
    required UserProfile profile,
    required String totpSecret,
  }) async {
    final kekBytes = await _deriveKekBytes(masterPassword, profile);
    final blob = await _crypto.encryptPayload(
      dek: Uint8List.fromList(kekBytes),
      plaintextJson: totpSecret,
      aad: utf8.encode('login_totp'),
    );
    return (ciphertext: blob.ciphertextBase64, nonce: blob.nonceBase64);
  }

  Future<({String ciphertext, String nonce})> wrapBackupPayload({
    required String masterPassword,
    required UserProfile profile,
    required LoginBackupPayload payload,
  }) async {
    final kekBytes = await _deriveKekBytes(masterPassword, profile);
    final blob = await _crypto.encryptPayload(
      dek: Uint8List.fromList(kekBytes),
      plaintextJson: jsonEncode(payload.toJson()),
      aad: utf8.encode('login_backup'),
    );
    return (ciphertext: blob.ciphertextBase64, nonce: blob.nonceBase64);
  }

  Future<String?> decryptTotpSecret({
    required String masterPassword,
    required UserProfile profile,
  }) async {
    if (!profile.loginTotpEnabled ||
        profile.encryptedLoginTotpSecret == null ||
        profile.loginTotpSecretNonce == null) {
      return null;
    }
    final kekBytes = await _deriveKekBytes(masterPassword, profile);
    return await _crypto.decryptPayload(
      dek: Uint8List.fromList(kekBytes),
      blob: EncryptedBlob(
        ciphertextBase64: profile.encryptedLoginTotpSecret!,
        nonceBase64: profile.loginTotpSecretNonce!,
      ),
      aad: utf8.encode('login_totp'),
    );
  }

  Future<LoginBackupPayload?> decryptBackupPayload({
    required String masterPassword,
    required UserProfile profile,
  }) async {
    if (profile.encryptedLoginBackupPayload == null ||
        profile.loginBackupPayloadNonce == null) {
      return null;
    }
    final kekBytes = await _deriveKekBytes(masterPassword, profile);
    final json = await _crypto.decryptPayload(
      dek: Uint8List.fromList(kekBytes),
      blob: EncryptedBlob(
        ciphertextBase64: profile.encryptedLoginBackupPayload!,
        nonceBase64: profile.loginBackupPayloadNonce!,
      ),
      aad: utf8.encode('login_backup'),
    );
    return LoginBackupPayload.fromJson(
      Map<String, dynamic>.from(jsonDecode(json) as Map),
    );
  }

  Future<bool> verifyTotpCode({
    required String masterPassword,
    required UserProfile profile,
    required String sixDigitCode,
    int? submittedAtMs,
  }) async {
    final secret = await decryptTotpSecret(
      masterPassword: masterPassword,
      profile: profile,
    );
    if (secret == null) return false;
    return verifyPlaintextTotp(
      secret: secret,
      sixDigitCode: sixDigitCode,
      submittedAtMs: submittedAtMs,
    );
  }

  /// Generates display codes and hashes for storage.
  ({List<String> codes, LoginBackupPayload payload}) generateBackupCodes() {
    final random = Random.secure();
    final codes = <String>[];
    final hashes = <String>[];
    for (var i = 0; i < _backupCodeCount; i++) {
      final code = List.generate(
        _backupCodeLength,
        (_) => _backupAlphabet[random.nextInt(_backupAlphabet.length)],
      ).join();
      codes.add(code);
      hashes.add(_hashBackupCode(code));
    }
    return (
      codes: codes,
      payload: LoginBackupPayload(codeHashes: hashes, usedIndices: []),
    );
  }

  /// Login: verify backup and return updated wrapped payload if consumed.
  Future<({bool ok, String? ciphertext, String? nonce})> verifyAndConsumeBackupCode({
    required String masterPassword,
    required UserProfile profile,
    required String code,
  }) async {
    final payload = await decryptBackupPayload(
      masterPassword: masterPassword,
      profile: profile,
    );
    if (payload == null) return (ok: false, ciphertext: null, nonce: null);
    final index = _matchBackupIndex(payload, code);
    if (index == null) return (ok: false, ciphertext: null, nonce: null);
    if (payload.usedIndices.contains(index)) {
      return (ok: false, ciphertext: null, nonce: null);
    }
    final updated = LoginBackupPayload(
      codeHashes: payload.codeHashes,
      usedIndices: [...payload.usedIndices, index],
    );
    final wrapped = await wrapBackupPayload(
      masterPassword: masterPassword,
      profile: profile,
      payload: updated,
    );
    return (
      ok: true,
      ciphertext: wrapped.ciphertext,
      nonce: wrapped.nonce,
    );
  }

  /// Disable / regenerate verify: backup must be unused.
  Future<bool> verifyBackupCodeWithoutConsume({
    required String masterPassword,
    required UserProfile profile,
    required String code,
  }) async {
    final payload = await decryptBackupPayload(
      masterPassword: masterPassword,
      profile: profile,
    );
    if (payload == null) return false;
    final index = _matchBackupIndex(payload, code);
    if (index == null) return false;
    return !payload.usedIndices.contains(index);
  }

  Future<({String ciphertext, String nonce})> rewrapTotpSecret({
    required String oldMasterPassword,
    required String newMasterPassword,
    required UserProfile profile,
  }) async {
    final secret = await decryptTotpSecret(
      masterPassword: oldMasterPassword,
      profile: profile,
    );
    if (secret == null) {
      throw StateError('No login TOTP secret to re-wrap');
    }
    return wrapTotpSecret(
      masterPassword: newMasterPassword,
      profile: profile,
      totpSecret: secret,
    );
  }

  Future<({String ciphertext, String nonce})?> rewrapBackupPayload({
    required String oldMasterPassword,
    required String newMasterPassword,
    required UserProfile profile,
  }) async {
    final payload = await decryptBackupPayload(
      masterPassword: oldMasterPassword,
      profile: profile,
    );
    if (payload == null) return null;
    return wrapBackupPayload(
      masterPassword: newMasterPassword,
      profile: profile,
      payload: payload,
    );
  }

  String hashBackupCodeForStorage(String code) => _hashBackupCode(code);

  int? _matchBackupIndex(LoginBackupPayload payload, String code) {
    final normalized = code.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (normalized.isEmpty) return null;
    final hash = _hashBackupCode(normalized);
    for (var i = 0; i < payload.codeHashes.length; i++) {
      if (payload.codeHashes[i] == hash) return i;
    }
    return null;
  }

  String _hashBackupCode(String code) {
    final normalized = code.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
    final bytes = utf8.encode(normalized);
    final digest = sha256.convert(bytes);
    return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<List<int>> _deriveKekBytes(
    String masterPassword,
    UserProfile profile,
  ) async {
    final salt = Uint8List.fromList(base64Decode(profile.kekSalt));
    final kek = await _crypto.deriveKek(
      masterPassword: masterPassword,
      salt: salt,
      params: KdfParams.fromJson(profile.kdfParams),
    );
    return await kek.extractBytes();
  }

  String _base32Encode(List<int> bytes) {
    var buffer = 0;
    var bitsLeft = 0;
    final out = <String>[];
    for (final byte in bytes) {
      buffer = (buffer << 8) | byte;
      bitsLeft += 8;
      while (bitsLeft >= 5) {
        bitsLeft -= 5;
        final index = (buffer >> bitsLeft) & 31;
        out.add(_base32Alphabet[index]);
      }
    }
    if (bitsLeft > 0) {
      final index = (buffer << (5 - bitsLeft)) & 31;
      out.add(_base32Alphabet[index]);
    }
    return out.join();
  }
}

/// Back-compat alias for site MFA list/detail TOTP display.
typedef LoginTotpService = LoginMfaService;
