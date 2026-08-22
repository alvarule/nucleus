/// Batch password health evaluation over decrypted vault items (domain only).
import 'package:nucleus/features/health/domain/entities/item_health_snapshot.dart';
import 'package:nucleus/features/health/domain/password_health_checker.dart';
import 'package:nucleus/features/vault/domain/entities/vault_item.dart';
import 'package:nucleus/features/vault/domain/password_field_helpers.dart';

/// Aggregated health state for the current vault session.
class PasswordHealthState {
  const PasswordHealthState({
    this.byItemId = const {},
    this.passwordCounts = const {},
  });

  final Map<String, ItemHealthSnapshot> byItemId;
  final Map<String, int> passwordCounts;

  ItemHealthSnapshot? forItem(String id) => byItemId[id];

  int get weakCount => byItemId.values.where((s) => s.isWeak).length;

  int get reusedCount => byItemId.values.where((s) => s.isReused).length;

  int get oldCount => byItemId.values.where((s) => s.isOld).length;

  int get checkedCount => byItemId.length;
}

/// Evaluates weak/reused/old flags for all password items in one pass.
class EvaluatePasswordHealth {
  EvaluatePasswordHealth({PasswordHealthChecker? checker})
      : _checker = checker ?? PasswordHealthChecker();

  final PasswordHealthChecker _checker;

  PasswordHealthState call({
    required List<VaultItem> items,
    required int oldPasswordThresholdDays,
  }) {
    final passwordItems =
        items.where((i) => i.type == VaultItemType.password).toList();

    final passwordCounts = <String, int>{};
    for (final item in passwordItems) {
      final pwd = '${item.fields['password'] ?? ''}';
      if (pwd.isEmpty) continue;
      passwordCounts[pwd] = (passwordCounts[pwd] ?? 0) + 1;
    }

    final now = DateTime.now();
    final threshold = Duration(days: oldPasswordThresholdDays);
    final byItemId = <String, ItemHealthSnapshot>{};

    for (final item in passwordItems) {
      final pwd = '${item.fields['password'] ?? ''}';
      if (pwd.isEmpty) continue;

      final reused = (passwordCounts[pwd] ?? 0) > 1;
      final changedAt = parsePasswordChangedAt(item) ?? item.updatedAt;
      final isOld = now.difference(changedAt) > threshold;

      byItemId[item.id] = ItemHealthSnapshot(
        strength: _checker.evaluate(pwd, reused: reused),
        isReused: reused,
        isOld: isOld,
      );
    }

    return PasswordHealthState(
      byItemId: byItemId,
      passwordCounts: passwordCounts,
    );
  }
}
