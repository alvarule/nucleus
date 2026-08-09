import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:vaultify/core/theme/app_colors.dart';
import 'package:vaultify/shared/widgets/app_icon.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  DateTime? _lastBackAt;
  bool _handlingBack = false;

  bool get _isOnHome => widget.navigationShell.currentIndex == 0;

  Future<void> _handleShellBack() async {
    if (_handlingBack) return;
    _handlingBack = true;
    try {
      // Other tabs: return to Home instead of exiting.
      if (!_isOnHome) {
        _lastBackAt = null;
        widget.navigationShell.goBranch(0);
        return;
      }

      // Home only: require back twice to close the app.
      final now = DateTime.now();
      final shouldExit = _lastBackAt != null &&
          now.difference(_lastBackAt!) < const Duration(seconds: 2);
      if (shouldExit) {
        await SystemNavigator.pop();
        return;
      }
      _lastBackAt = now;
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Press back again to exit'),
            duration: Duration(seconds: 2),
          ),
        );
    } finally {
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        _handlingBack = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // PopScope only applies while this shell route is the top route.
    // Pushed pages (/vault/:id, /profile, etc.) keep normal stack back.
    // No BackButtonListener here — it would steal back events from those pages.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleShellBack();
      },
      child: Scaffold(
        body: widget.navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: widget.navigationShell.currentIndex,
          backgroundColor: colors.surface,
          indicatorColor: colors.primarySoft,
          onDestinationSelected: (index) {
            _lastBackAt = null;
            widget.navigationShell.goBranch(index);
          },
          destinations: [
            NavigationDestination(
              icon: AppIcon('home', color: colors.textTertiary),
              selectedIcon: AppIcon('home', color: colors.primary),
              label: 'Home',
            ),
            NavigationDestination(
              icon: AppIcon('generator', color: colors.textTertiary),
              selectedIcon: AppIcon('generator', color: colors.primary),
              label: 'Generator',
            ),
            NavigationDestination(
              icon: AppIcon('health', color: colors.textTertiary),
              selectedIcon: AppIcon('health', color: colors.primary),
              label: 'Health',
            ),
            NavigationDestination(
              icon: AppIcon('settings', color: colors.textTertiary),
              selectedIcon: AppIcon('settings', color: colors.primary),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
