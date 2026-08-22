/// Per-item password health flags computed from decrypted vault data.
import 'package:nucleus/features/health/domain/password_health_checker.dart';

/// High-level health flag for badges and filters (one primary flag per item).
enum ItemHealthFlag { fine, weak, reused, old }

/// Full health evaluation for one password-type vault item.
class ItemHealthSnapshot {
  const ItemHealthSnapshot({
    required this.strength,
    required this.isReused,
    required this.isOld,
  });

  final PasswordHealthResult strength;
  final bool isReused;
  final bool isOld;

  bool get isWeak =>
      strength.strength == PasswordStrength.weak ||
      strength.strength == PasswordStrength.fair;

  /// Weak/reused items are eligible for the Fix now flow.
  bool get needsFix => isWeak || isReused;

  /// Single badge color priority when multiple issues apply.
  ItemHealthFlag get primaryFlag {
    if (isReused) return ItemHealthFlag.reused;
    if (isWeak) return ItemHealthFlag.weak;
    if (isOld) return ItemHealthFlag.old;
    return ItemHealthFlag.fine;
  }
}
