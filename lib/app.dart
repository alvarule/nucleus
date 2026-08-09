import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vaultify/core/lifecycle/vault_lifecycle_observer.dart';
import 'package:vaultify/core/theme/app_theme.dart';
import 'package:vaultify/features/profile/domain/entities/user_profile.dart';
import 'package:vaultify/features/settings/presentation/providers/theme_preference_provider.dart';
import 'package:vaultify/features/unlock/presentation/providers/vault_session_provider.dart';
import 'package:vaultify/router/app_router.dart';

class VaultifyApp extends ConsumerStatefulWidget {
  const VaultifyApp({super.key});

  @override
  ConsumerState<VaultifyApp> createState() => _VaultifyAppState();
}

class _VaultifyAppState extends ConsumerState<VaultifyApp> {
  late final VaultLifecycleObserver _observer;

  @override
  void initState() {
    super.initState();
    _observer = VaultLifecycleObserver(ref);
    WidgetsBinding.instance.addObserver(_observer);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_observer);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    final themePref = ref.watch(themePreferenceProvider);

    final mode = switch (themePref) {
      ThemePreference.light => ThemeMode.light,
      ThemePreference.dark => ThemeMode.dark,
      ThemePreference.system => ThemeMode.system,
    };

    return MaterialApp.router(
      title: 'Vaultify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      routerConfig: router,
      builder: (context, child) {
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            ref.read(vaultSessionProvider.notifier).touchActivity();
          },
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
