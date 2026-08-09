import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultify/core/di/providers.dart';
import 'package:vaultify/features/unlock/presentation/providers/vault_session_provider.dart';

/// Locks the vault when the app goes to background.
class VaultLifecycleObserver extends WidgetsBindingObserver {
  VaultLifecycleObserver(this._ref);

  final WidgetRef _ref;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Lock only when fully backgrounded so biometric sheets are not interrupted.
    if (state == AppLifecycleState.paused) {
      if (_ref.read(biometricUnlockStoreProvider).isAuthenticating) return;
      final session = _ref.read(vaultSessionProvider);
      if (session.isUnlocked) {
        _ref.read(vaultSessionProvider.notifier).lock();
      }
    }
  }
}
