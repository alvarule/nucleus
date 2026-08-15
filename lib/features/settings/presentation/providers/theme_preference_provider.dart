/// Mirrors `profiles.theme_preference` into [ThemeMode] for [NucleusApp].
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleus/features/profile/domain/entities/user_profile.dart';
import 'package:nucleus/features/unlock/presentation/providers/vault_session_provider.dart';

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

  /// Immediate UI update; persistence happens in Settings via profile update.
  void setLocal(ThemePreference preference) => state = preference;
}

final themePreferenceProvider =
    StateNotifierProvider<ThemePreferenceNotifier, ThemePreference>((ref) {
  return ThemePreferenceNotifier(ref);
});
