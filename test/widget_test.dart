import 'package:flutter_test/flutter_test.dart';
import 'package:vaultify/core/crypto/vault_crypto_service.dart';
import 'package:vaultify/features/generator/domain/password_generator.dart';

void main() {
  test('wrap and unwrap DEK', () async {
    final crypto = VaultCryptoService();
    final dek = crypto.generateDek();
    final wrapped = await crypto.wrapDek(
      dek: dek,
      masterPassword: 'test-master-password',
      params: const KdfParams(memory: 1024, iterations: 1, parallelism: 1),
    );
    final unwrapped = await crypto.unwrapDek(
      masterPassword: 'test-master-password',
      wrapped: wrapped,
    );
    expect(unwrapped, dek);
  });

  test('rewrap DEK with new master password keeps same DEK', () async {
    final crypto = VaultCryptoService();
    final dek = crypto.generateDek();
    const params = KdfParams(memory: 1024, iterations: 1, parallelism: 1);
    final oldWrap = await crypto.wrapDek(
      dek: dek,
      masterPassword: 'old-master-password',
      params: params,
    );
    final unwrapped = await crypto.unwrapDek(
      masterPassword: 'old-master-password',
      wrapped: oldWrap,
    );
    final newWrap = await crypto.rewrapDek(
      dek: unwrapped,
      newMasterPassword: 'new-master-password',
      params: params,
    );
    final afterChange = await crypto.unwrapDek(
      masterPassword: 'new-master-password',
      wrapped: newWrap,
    );
    expect(afterChange, dek);
    await expectLater(
      crypto.unwrapDek(
        masterPassword: 'old-master-password',
        wrapped: newWrap,
      ),
      throwsA(isA<Object>()),
    );
  });

  test('payload decrypt still works after master password rewrap', () async {
    final crypto = VaultCryptoService();
    final dek = crypto.generateDek();
    const params = KdfParams(memory: 1024, iterations: 1, parallelism: 1);
    final blob = await crypto.encryptPayload(
      dek: dek,
      plaintextJson: '{"label":"bank","password":"s3cret"}',
    );
    final newWrap = await crypto.rewrapDek(
      dek: dek,
      newMasterPassword: 'rotated-password',
      params: params,
    );
    final restoredDek = await crypto.unwrapDek(
      masterPassword: 'rotated-password',
      wrapped: newWrap,
    );
    final clear = await crypto.decryptPayload(dek: restoredDek, blob: blob);
    expect(clear, '{"label":"bank","password":"s3cret"}');
  });

  test('encrypt and decrypt payload', () async {
    final crypto = VaultCryptoService();
    final dek = crypto.generateDek();
    final blob = await crypto.encryptPayload(
      dek: dek,
      plaintextJson: '{"label":"x"}',
    );
    final clear = await crypto.decryptPayload(dek: dek, blob: blob);
    expect(clear, '{"label":"x"}');
  });

  test('password generator respects length', () {
    final pwd = PasswordGenerator().generate(length: 20);
    expect(pwd.length, 20);
  });

  test('health checker flags short passwords', () {
    final result = PasswordHealthChecker().evaluate('abc');
    expect(result.strength, PasswordStrength.weak);
  });
}
