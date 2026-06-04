

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'services/api_service.dart';
import 'screens/dashboard_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/history_screen.dart';
import 'screens/admin_panel_screen.dart';
import 'screens/image_view_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/create_account_screen.dart';
import 'screens/setup_screen.dart';
import 'theme.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [

    GoRoute(
      path: '/login',
      builder: (c, s) => const LoginScreen(),
    ),
    GoRoute(
      path: '/create-account',
      builder: (c, s) => const CreateAccountScreen(),
    ),
    GoRoute(
      path: '/setup',
      builder: (c, s) => const SetupScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => _Shell(child: child),
      routes: [
        GoRoute(path: '/', builder: (c, s) => const DashboardScreen()),
        GoRoute(path: '/camera', builder: (c, s) => const CameraScreen()),
        GoRoute(path: '/history', builder: (c, s) => const HistoryScreen()),
        GoRoute(
          path: '/admin',
          builder: (c, s) => AdminPanelGate(
            initialUser:
                s.extra is OperatorUser ? s.extra as OperatorUser : null,
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/image',
      builder: (c, s) => const ImageViewScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (c, s) => const SettingsScreen(),
    ),
  ],
);

class _Shell extends ConsumerWidget {
  final Widget child;
  const _Shell({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final user = ref.watch(authUserProvider);
    final isAdmin = user?.isAdmin == true;
    final idx = switch (location) {
      '/' => 0,
      '/camera' => 1,
      '/history' => 2,
      '/admin' when isAdmin => 3,
      _ => 0,
    };
    final navItems = [
      const _NavDestination(
        icon: Icons.grid_view_outlined,
        selectedIcon: Icons.grid_view,
        label: 'DASHBOARD',
        route: '/',
      ),

      const _NavDestination(
        icon: Icons.videocam_outlined,
        selectedIcon: Icons.videocam,
        label: 'CAMÉRA',
        route: '/camera',
      ),
      const _NavDestination(
        icon: Icons.access_time_outlined,
        selectedIcon: Icons.access_time_filled,
        label: 'HISTORIQUE',
        route: '/history',
      ),
      if (isAdmin)
        const _NavDestination(
          icon: Icons.admin_panel_settings_outlined,
          selectedIcon: Icons.admin_panel_settings,
          label: 'COMPTES',
          route: '/admin',
        ),
    ];

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgWhite,
          border: Border(
            top: BorderSide(color: AppTheme.border, width: 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var i = 0; i < navItems.length; i++)
                  _NavItem(
                    icon: navItems[i].icon,
                    selectedIcon: navItems[i].selectedIcon,
                    label: navItems[i].label,
                    isSelected: idx == i,
                    onTap: () => context.go(navItems[i].route),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppTheme.primaryBlue : AppTheme.textSecondary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSelected ? selectedIcon : icon,
            color: color,
            size: 22,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),

          Container(
            width: 20,
            height: 2,
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;

  const _NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
  });
}
