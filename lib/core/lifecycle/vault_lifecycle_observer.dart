/// Re-checks auto-lock when the app returns to foreground (timers may stall while paused).
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleus/features/unlock/presentation/providers/vault_session_provider.dart';

/// Applies wall-clock auto-lock on resume; does not lock on background or screen off.
class VaultLifecycleObserver extends WidgetsBindingObserver {
  VaultLifecycleObserver(this._ref);

  final WidgetRef _ref;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ref.read(vaultSessionProvider.notifier).onAppResumed();
    }
  }
}
