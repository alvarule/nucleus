/// Client-side crypto for Nucleus: Argon2id KEK, AES-256-GCM DEK wrap, and
/// vault payload encrypt/decrypt. The server never sees plaintext secrets.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Argon2id parameters stored alongside the wrapped DEK so unwrap can match signup.
class KdfParams {
  const KdfParams({
    this.memory = 65536,
    this.iterations = 3,
    this.parallelism = 4,
    this.hashLength = 32,
  });

  final int memory;
  final int iterations;
  final int parallelism;
  final int hashLength;

  Map<String, dynamic> toJson() => {
        'memory': memory,
        'iterations': iterations,
        'parallelism': parallelism,
        'hashLength': hashLength,
        'algorithm': 'argon2id',
      };

  factory KdfParams.fromJson(Map<String, dynamic> json) => KdfParams(
        memory: json['memory'] as int? ?? 65536,
        iterations: json['iterations'] as int? ?? 3,
        parallelism: json['parallelism'] as int? ?? 4,
        hashLength: json['hashLength'] as int? ?? 32,
      );
}

/// Encrypted DEK plus the salt/KDF metadata needed to derive the KEK again.
class WrappedDek {
  const WrappedDek({
    required this.encryptedDekBase64,
    required this.saltBase64,
    required this.kdfParams,
  });

  final String encryptedDekBase64;
  final String saltBase64;
  final KdfParams kdfParams;
}

/// AES-GCM ciphertext+MAC (packed) and nonce for a vault item payload.
class EncryptedBlob {
  const EncryptedBlob({
    required this.ciphertextBase64,
    required this.nonceBase64,
  });

  final String ciphertextBase64;
  final String nonceBase64;
}

/// Argon2id KEK derivation + AES-256-GCM for DEK wrap and vault payloads.
class VaultCryptoService {
  VaultCryptoService({Random? random}) : _random = random ?? Random.secure();

  final Random _random;
  static const _dekLength = 32;
  static const _saltLength = 16;
  static const _nonceLength = 12;
  static const _macLength = 16;

  Uint8List generateDek() => _randomBytes(_dekLength);

  Uint8List generateSalt() => _randomBytes(_saltLength);

  /// Derives the key-encryption-key from the master password; never persisted.
  Future<SecretKey> deriveKek({
    required String masterPassword,
    required Uint8List salt,
    required KdfParams params,
  }) {
    final argon2 = Argon2id(
      parallelism: params.parallelism,
      memory: params.memory,
      iterations: params.iterations,
      hashLength: params.hashLength,
    );
    return argon2.deriveKeyFromPassword(
      password: masterPassword,
      nonce: salt,
    );
  }

  /// Encrypts the DEK with a KEK from [masterPassword]. Packed layout:
  /// `nonce || ciphertext || mac`.
  Future<WrappedDek> wrapDek({
    required Uint8List dek,
    required String masterPassword,
    KdfParams params = const KdfParams(),
  }) async {
    final salt = generateSalt();
    final kek = await deriveKek(
      masterPassword: masterPassword,
      salt: salt,
      params: params,
    );
    final box = await AesGcm.with256bits().encrypt(dek, secretKey: kek);
    final packed = Uint8List.fromList([
      ...box.nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
    return WrappedDek(
      encryptedDekBase64: base64Encode(packed),
      saltBase64: base64Encode(salt),
      kdfParams: params,
    );
  }

  /// Inverse of [wrapDek]. Wrong password or corrupt payload fails AES-GCM MAC.
  Future<Uint8List> unwrapDek({
    required String masterPassword,
    required WrappedDek wrapped,
  }) async {
    final salt = Uint8List.fromList(base64Decode(wrapped.saltBase64));
    final kek = await deriveKek(
      masterPassword: masterPassword,
      salt: salt,
      params: wrapped.kdfParams,
    );
    final packed = base64Decode(wrapped.encryptedDekBase64);
    if (packed.length < _nonceLength + _macLength + 1) {
      throw StateError('Invalid encrypted DEK payload');
    }
    final nonce = packed.sublist(0, _nonceLength);
    final mac = Mac(packed.sublist(packed.length - _macLength));
    final cipherText = packed.sublist(_nonceLength, packed.length - _macLength);
    final clear = await AesGcm.with256bits().decrypt(
      SecretBox(cipherText, nonce: nonce, mac: mac),
      secretKey: kek,
    );
    return Uint8List.fromList(clear);
  }

  /// Encrypts vault field JSON. Optional AAD binds ciphertext to item id+type.
  Future<EncryptedBlob> encryptPayload({
    required Uint8List dek,
    required String plaintextJson,
    List<int>? aad,
  }) async {
    final key = SecretKey(dek);
    final box = await AesGcm.with256bits().encrypt(
      utf8.encode(plaintextJson),
      secretKey: key,
      aad: aad ?? const <int>[],
    );
    final packed = Uint8List.fromList([...box.cipherText, ...box.mac.bytes]);
    return EncryptedBlob(
      ciphertextBase64: base64Encode(packed),
      nonceBase64: base64Encode(box.nonce),
    );
  }

  /// Decrypts a vault payload. Ciphertext packing is `ciphertext || mac`.
  Future<String> decryptPayload({
    required Uint8List dek,
    required EncryptedBlob blob,
    List<int>? aad,
  }) async {
    final key = SecretKey(dek);
    final packed = base64Decode(blob.ciphertextBase64);
    final nonce = base64Decode(blob.nonceBase64);
    if (packed.length < _macLength + 1) {
      throw StateError('Invalid ciphertext');
    }
    final mac = Mac(packed.sublist(packed.length - _macLength));
    final cipherText = packed.sublist(0, packed.length - _macLength);
    final clear = await AesGcm.with256bits().decrypt(
      SecretBox(cipherText, nonce: nonce, mac: mac),
      secretKey: key,
      aad: aad ?? const <int>[],
    );
    return utf8.decode(clear);
  }

  /// Encrypts raw bytes (attachment chunks). Packed: nonce || ciphertext || mac.
  Future<Uint8List> encryptBytes({
    required Uint8List dek,
    required Uint8List plaintext,
    List<int>? aad,
  }) async {
    final key = SecretKey(dek);
    final box = await AesGcm.with256bits().encrypt(
      plaintext,
      secretKey: key,
      aad: aad ?? const <int>[],
    );
    return Uint8List.fromList([
      ...box.nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
  }

  /// Decrypts [encryptBytes] output.
  Future<Uint8List> decryptBytes({
    required Uint8List dek,
    required Uint8List packed,
    List<int>? aad,
  }) async {
    final key = SecretKey(dek);
    if (packed.length < _nonceLength + _macLength + 1) {
      throw StateError('Invalid ciphertext');
    }
    final nonce = packed.sublist(0, _nonceLength);
    final mac = Mac(packed.sublist(packed.length - _macLength));
    final cipherText = packed.sublist(_nonceLength, packed.length - _macLength);
    final clear = await AesGcm.with256bits().decrypt(
      SecretBox(cipherText, nonce: nonce, mac: mac),
      secretKey: key,
      aad: aad ?? const <int>[],
    );
    return Uint8List.fromList(clear);
  }

  /// Wraps the same DEK under a new master password (items stay encrypted as-is).
  Future<WrappedDek> rewrapDek({
    required Uint8List dek,
    required String newMasterPassword,
    KdfParams params = const KdfParams(),
  }) {
    return wrapDek(
      dek: dek,
      masterPassword: newMasterPassword,
      params: params,
    );
  }

  Uint8List _randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }
}
