import 'package:flutter_test/flutter_test.dart';
import 'package:nucleus/core/crypto/vault_crypto_service.dart';
import 'package:nucleus/features/generator/domain/password_generator.dart';
import 'package:nucleus/features/health/domain/password_health_checker.dart';
import 'package:nucleus/features/health/domain/use_cases/evaluate_password_health.dart';
import 'package:nucleus/features/vault/domain/entities/vault_item.dart';

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

  test('reuse detection only flags duplicate passwords', () {
    final now = DateTime.now();
    final items = [
      VaultItem(
        id: '1',
        userId: 'u',
        type: VaultItemType.password,
        fields: {'label': 'A', 'password': 'same-secret'},
        createdAt: now,
        updatedAt: now,
      ),
      VaultItem(
        id: '2',
        userId: 'u',
        type: VaultItemType.password,
        fields: {'label': 'B', 'password': 'same-secret'},
        createdAt: now,
        updatedAt: now,
      ),
      VaultItem(
        id: '3',
        userId: 'u',
        type: VaultItemType.password,
        fields: {'label': 'C', 'password': 'unique-secret'},
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final health = EvaluatePasswordHealth()(items: items, oldPasswordThresholdDays: 90);

    expect(health.forItem('1')!.isReused, isTrue);
    expect(health.forItem('2')!.isReused, isTrue);
    expect(health.forItem('3')!.isReused, isFalse);
  });
}
