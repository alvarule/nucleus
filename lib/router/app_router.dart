/// GoRouter graph, auth/lock redirects, and splash bootstrap.
///
/// Router refresh is limited to vault lock-status and Supabase auth changes so
/// that reveal-grace updates do not drop `extra` on `/vault/edit`.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nucleus/core/di/providers.dart';
import 'package:nucleus/features/auth/presentation/pages/login_page.dart';
import 'package:nucleus/features/auth/presentation/pages/signup_page.dart';
import 'package:nucleus/features/generator/presentation/pages/generator_page.dart';
import 'package:nucleus/features/health/presentation/pages/health_page.dart';
import 'package:nucleus/features/profile/presentation/pages/profile_page.dart';
import 'package:nucleus/features/settings/presentation/pages/change_master_password_page.dart';
import 'package:nucleus/features/settings/presentation/pages/settings_page.dart';
import 'package:nucleus/features/unlock/presentation/pages/unlock_page.dart';
import 'package:nucleus/features/unlock/presentation/providers/vault_session_provider.dart';
import 'package:nucleus/features/vault/domain/entities/vault_item.dart';
import 'package:nucleus/features/vault/presentation/pages/vault_home_page.dart';
import 'package:nucleus/features/vault/presentation/pages/vault_item_detail_page.dart';
import 'package:nucleus/features/vault/presentation/pages/vault_item_form_page.dart';
import 'package:nucleus/shared/widgets/app_shell.dart';
import 'package:nucleus/shared/widgets/vault_loader.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Notifies GoRouter when it must re-run redirects (auth or lock status).
class RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

final routerRefreshProvider = Provider<RouterRefresh>((ref) {
  final refresh = RouterRefresh();
  // Only refresh on lock/unlock transitions. Reveal-grace updates must not
  // rebuild routes — /vault/edit relies on `extra`, which GoRouter drops on refresh.
  ref.listen(vaultSessionProvider, (previous, next) {
    if (previous?.status != next.status) refresh.ping();
  });
  final client = ref.watch(supabaseClientProvider);
  final sub = client.auth.onAuthStateChange.listen((_) => refresh.ping());
  ref.onDispose(sub.cancel);
  return refresh;
});

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(routerRefreshProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authRepositoryProvider);
      final session = ref.read(vaultSessionProvider);
      final loc = state.matchedLocation;
      final loggedIn = auth.currentUserId != null;
      final unlocking = loc == '/unlock' || loc == '/login' || loc == '/signup';

      // Splash decides the first destination itself.
      if (loc == '/splash') return null;

      if (!loggedIn) {
        if (loc == '/login' || loc == '/signup') return null;
        return '/login';
      }

      // Signed in but DEK not in memory → unlock gate, not login.
      if (loggedIn && !session.isUnlocked) {
        if (loc == '/unlock' || loc == '/login' || loc == '/signup') return null;
        return '/unlock';
      }

      if (loggedIn && session.isUnlocked && unlocking) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const _SplashPage(),
      ),
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupPage()),
      GoRoute(path: '/unlock', builder: (_, __) => const UnlockPage()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
      GoRoute(
        path: '/settings/change-master-password',
        builder: (_, __) => const ChangeMasterPasswordPage(),
      ),
      GoRoute(
        path: '/vault/new',
        builder: (context, state) {
          final type = VaultItemTypeX.fromDb(
            state.uri.queryParameters['type'] ?? 'password',
          );
          final prefill = state.extra is Map<String, dynamic>
              ? state.extra! as Map<String, dynamic>
              : null;
          return VaultItemFormPage(type: type, prefill: prefill);
        },
      ),
      GoRoute(
        path: '/vault/edit/:id',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is VaultItem) {
            return VaultItemFormPage(type: extra.type, existing: extra);
          }
          if (extra is Map<String, dynamic>) {
            final item = extra['item'] as VaultItem?;
            final prefill = extra['prefill'] as Map<String, dynamic>?;
            if (item == null) {
              return const Scaffold(body: Center(child: Text('Missing item')));
            }
            return VaultItemFormPage(
              type: item.type,
              existing: item,
              prefill: prefill,
            );
          }
          return const Scaffold(body: Center(child: Text('Missing item')));
        },
      ),
      GoRoute(
        path: '/vault/:id',
        builder: (context, state) => VaultItemDetailPage(
          itemId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/generator/fix',
        builder: (context, state) {
          final item = state.extra as VaultItem?;
          if (item == null) {
            return const Scaffold(
              body: Center(child: Text('Missing item')),
            );
          }
          return GeneratorPage(fixItem: item);
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, __) => const VaultHomePage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/generator',
                builder: (_, __) => const GeneratorPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/health', builder: (_, __) => const HealthPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, __) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// First frame after process start: load profile if a Supabase session exists,
/// then send the user to unlock or login.
class _SplashPage extends ConsumerStatefulWidget {
  const _SplashPage();

  @override
  ConsumerState<_SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<_SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final auth = ref.read(authRepositoryProvider);
      final userId = auth.currentUserId;
      if (userId != null) {
        await ref.read(vaultSessionProvider.notifier).loadProfile(userId);
        if (mounted) context.go('/unlock');
      } else if (mounted) {
        context.go('/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const VaultLoadingScaffold(message: 'Opening Nucleus…');
  }
}
