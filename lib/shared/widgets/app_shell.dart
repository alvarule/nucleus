import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vaultify/core/theme/app_colors.dart';
import 'package:vaultify/shared/widgets/app_icon.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        backgroundColor: colors.surface,
        indicatorColor: colors.primarySoft,
        onDestinationSelected: navigationShell.goBranch,
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
    );
  }
}
