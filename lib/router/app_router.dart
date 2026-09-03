/// GoRouter graph, auth/lock redirects, and splash bootstrap.
///
/// Router refresh is limited to vault lock-status and Supabase auth changes so
/// that reveal-grace updates do not drop `extra` on `/vault/edit`.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nucleus/core/di/providers.dart';
import 'package:nucleus/features/auth/presentation/pages/check_email_page.dart';
import 'package:nucleus/features/auth/presentation/pages/login_page.dart';
import 'package:nucleus/features/auth/presentation/pages/login_totp_page.dart';
import 'package:nucleus/features/auth/presentation/providers/pending_login_provider.dart';
import 'package:nucleus/features/auth/presentation/pages/signup_page.dart';
import 'package:nucleus/features/auth/presentation/pages/vault_setup_page.dart';
import 'package:nucleus/features/generator/presentation/pages/generator_page.dart';
import 'package:nucleus/features/health/presentation/pages/health_page.dart';
import 'package:nucleus/features/profile/presentation/pages/profile_page.dart';
import 'package:nucleus/features/mfa/presentation/pages/mfa_detail_page.dart';
import 'package:nucleus/features/mfa/presentation/pages/mfa_list_page.dart';
import 'package:nucleus/features/mfa/presentation/pages/mfa_new_page.dart';
import 'package:nucleus/features/mfa/presentation/pages/mfa_scan_page.dart';
import 'package:nucleus/features/settings/presentation/pages/change_master_password_page.dart';
import 'package:nucleus/features/settings/presentation/pages/app_login_mfa_pages.dart';
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
    if (previous?.status != next.status ||
        previous?.profileResolved != next.profileResolved ||
        previous?.profile?.id != next.profile?.id ||
        previous?.signInMfaPending != next.signInMfaPending) {
      refresh.ping();
    }
  });
  ref.listen(pendingLoginPasswordProvider, (previous, next) {
    if (previous != next) refresh.ping();
  });
  final client = ref.watch(supabaseClientProvider);
  final sub = client.auth.onAuthStateChange.listen((event) async {
    final uid = event.session?.user.id;
    if (uid != null && !ref.read(vaultSessionProvider).isUnlocked) {
      await ref.read(vaultSessionProvider.notifier).loadProfile(uid);
    }
    refresh.ping();
  });
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
      final publicAuth = loc == '/login' ||
          loc == '/signup' ||
          loc == '/check-email' ||
          loc == '/login-totp';
      final setup = loc == '/vault-setup';

      // Splash decides the first destination itself.
      if (loc == '/splash') return null;

      if (!loggedIn) {
        if (publicAuth) return null;
        return '/login';
      }

      final pendingPassword = ref.read(pendingLoginPasswordProvider) != null;
      final needsSignInMfa = pendingPassword &&
          session.profile?.loginTotpEnabled == true;

      if (needsSignInMfa && loc != '/login-totp' && loc != '/login') {
        return '/login-totp';
      }

      // Session exists but we have not loaded profile yet — stay put until resolved
      // (auth listener calls loadProfile then pings again).
      if (!session.profileResolved) {
        if (loc == '/unlock' || setup || publicAuth) return null;
        return null;
      }

      // Verified Auth user with no vault profile yet → set master password.
      if (session.profile == null) {
        if (setup) return null;
        return '/vault-setup';
      }

      // Signed in but DEK not in memory → unlock gate, or login-totp during sign-in.
      if (!session.isUnlocked) {
        if (needsSignInMfa) {
          if (loc == '/login-totp' || loc == '/login') return null;
          return '/login-totp';
        }
        if (loc == '/unlock' || loc == '/login' || loc == '/signup') return null;
        return '/unlock';
      }

      if (session.isUnlocked &&
          (publicAuth || loc == '/unlock' || setup)) {
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
      GoRoute(path: '/login-totp', builder: (_, __) => const LoginTotpPage()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupPage()),
      GoRoute(
        path: '/check-email',
        builder: (_, state) => CheckEmailPage(
          email: state.uri.queryParameters['email'] ?? '',
          name: state.uri.queryParameters['name'] ?? '',
        ),
      ),
      GoRoute(path: '/vault-setup', builder: (_, __) => const VaultSetupPage()),
      GoRoute(path: '/unlock', builder: (_, __) => const UnlockPage()),
      GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
      GoRoute(
        path: '/settings/change-master-password',
        builder: (_, __) => const ChangeMasterPasswordPage(),
      ),
      GoRoute(
        path: '/settings/app-login-mfa/setup',
        builder: (_, __) => const AppLoginMfaSetupWizardPage(),
      ),
      GoRoute(
        path: '/settings/app-login-mfa',
        builder: (_, __) => const AppLoginMfaManagePage(),
      ),
      GoRoute(
        path: '/mfa/new',
        builder: (context, state) {
          final extra = state.extra;
          String? secret;
          String? vaultItemId;
          String? issuer;
          String? account;
          if (extra is Map) {
            secret = extra['secret'] as String?;
            vaultItemId = extra['vaultItemId'] as String?;
            issuer = extra['issuer'] as String?;
            account = extra['account'] as String?;
          }
          return MfaNewPage(
            initialSecret: secret,
            vaultItemId: vaultItemId,
            initialIssuer: issuer,
            initialAccount: account,
          );
        },
      ),
      GoRoute(path: '/mfa/scan', builder: (_, __) => const MfaScanPage()),
      GoRoute(
        path: '/mfa/:id',
        builder: (_, state) => MfaDetailPage(
          entryId: state.pathParameters['id']!,
        ),
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
              GoRoute(path: '/mfa', builder: (_, __) => const MfaListPage()),
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
        if (!mounted) return;
        final userIdAfter = ref.read(authRepositoryProvider).currentUserId;
        if (userIdAfter == null) {
          context.go('/login');
          return;
        }
        final session = ref.read(vaultSessionProvider);
        final profile = session.profile;
        final pendingMfa = ref.read(pendingLoginPasswordProvider) != null;
        if (profile == null) {
          context.go('/vault-setup');
        } else if (pendingMfa && profile.loginTotpEnabled) {
          context.go('/login-totp');
        } else {
          context.go('/unlock');
        }
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
