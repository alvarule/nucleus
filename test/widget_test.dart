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
