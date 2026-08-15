/// Root MaterialApp: theme, routing, background lock, and auto-lock activity.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleus/core/lifecycle/vault_lifecycle_observer.dart';
import 'package:nucleus/core/theme/app_theme.dart';
import 'package:nucleus/features/profile/domain/entities/user_profile.dart';
import 'package:nucleus/features/settings/presentation/providers/theme_preference_provider.dart';
import 'package:nucleus/features/unlock/presentation/providers/vault_session_provider.dart';
import 'package:nucleus/router/app_router.dart';

class NucleusApp extends ConsumerStatefulWidget {
  const NucleusApp({super.key});

  @override
  ConsumerState<NucleusApp> createState() => _NucleusAppState();
}

class _NucleusAppState extends ConsumerState<NucleusApp> {
  /// Locks the in-memory DEK when the process is backgrounded.
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
      title: 'Nucleus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      routerConfig: router,
      builder: (context, child) {
        // Any pointer down counts as foreground activity for auto-lock timers.
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
