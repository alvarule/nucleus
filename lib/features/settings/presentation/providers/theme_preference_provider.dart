import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultify/features/profile/domain/entities/user_profile.dart';
import 'package:vaultify/features/unlock/presentation/providers/vault_session_provider.dart';

class ThemePreferenceNotifier extends StateNotifier<ThemePreference> {
  ThemePreferenceNotifier(this._ref) : super(ThemePreference.system) {
    final profile = _ref.read(vaultSessionProvider).profile;
    if (profile != null) state = profile.themePreference;
    _ref.listen(vaultSessionProvider, (prev, next) {
      if (next.profile != null) {
        state = next.profile!.themePreference;
      }
    });
  }

  final Ref _ref;

  void setLocal(ThemePreference preference) => state = preference;
}

final themePreferenceProvider =
    StateNotifierProvider<ThemePreferenceNotifier, ThemePreference>((ref) {
  return ThemePreferenceNotifier(ref);
});
