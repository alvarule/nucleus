/// Session-scoped password health computed from the decrypted vault list.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleus/features/health/domain/use_cases/evaluate_password_health.dart';
import 'package:nucleus/features/settings/domain/security_timeouts.dart';
import 'package:nucleus/features/settings/presentation/providers/security_preference_provider.dart';
import 'package:nucleus/features/vault/presentation/providers/vault_list_provider.dart';

final _evaluator = EvaluatePasswordHealth();

/// Recomputed when vault items or the password-age threshold changes.
final passwordHealthProvider = Provider<PasswordHealthState>((ref) {
  final vault = ref.watch(vaultListProvider);
  final security = ref.watch(securityPreferenceProvider);
  return _evaluator(
    items: vault.items,
    oldPasswordThresholdDays: security.passwordAgeThreshold.days,
  );
});
