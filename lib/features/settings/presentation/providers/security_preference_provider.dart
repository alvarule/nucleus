import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nucleus/features/settings/domain/security_timeouts.dart';

class SecurityPreferenceNotifier extends StateNotifier<SecurityTimeouts> {
  SecurityPreferenceNotifier() : super(const SecurityTimeouts()) {
    _load();
  }

  static const _autoLockKey = 'security_auto_lock';
  static const _revealGraceKey = 'security_reveal_grace';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final autoLockName = prefs.getString(_autoLockKey);
    final revealName = prefs.getString(_revealGraceKey);

    state = SecurityTimeouts(
      autoLock: VaultAutoLockOption.values.firstWhere(
        (e) => e.name == autoLockName,
        orElse: () => VaultAutoLockOption.fiveMinutes,
      ),
      revealGrace: RevealGraceOption.values.firstWhere(
        (e) => e.name == revealName,
        orElse: () => RevealGraceOption.twoMinutes,
      ),
    );
  }

  Future<void> setAutoLock(VaultAutoLockOption value) async {
    state = state.copyWith(autoLock: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_autoLockKey, value.name);
  }

  Future<void> setRevealGrace(RevealGraceOption value) async {
    state = state.copyWith(revealGrace: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_revealGraceKey, value.name);
  }
}

final securityPreferenceProvider =
    StateNotifierProvider<SecurityPreferenceNotifier, SecurityTimeouts>((ref) {
  return SecurityPreferenceNotifier();
});
