// lib/router.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'screens/dashboard_screen.dart';
import 'screens/spc_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/history_screen.dart';
import 'screens/image_view_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'theme.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (c, s) => const LoginScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => _Shell(child: child),
      routes: [
        GoRoute(path: '/', builder: (c, s) => const DashboardScreen()),
        GoRoute(path: '/spc', builder: (c, s) => const SpcScreen()),
        GoRoute(path: '/camera', builder: (c, s) => const CameraScreen()),
        GoRoute(path: '/history', builder: (c, s) => const HistoryScreen()),
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
    final idx = switch (location) {
      '/' => 0,
      '/spc' => 1,
      '/camera' => 2,
      '/history' => 3,
      _ => 0,
    };

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
                _NavItem(
                  icon: Icons.grid_view_outlined,
                  selectedIcon: Icons.grid_view,
                  label: 'DASHBOARD',
                  isSelected: idx == 0,
                  onTap: () => context.go('/'),
                ),
                _NavItem(
                  icon: Icons.show_chart_outlined,
                  selectedIcon: Icons.show_chart,
                  label: 'SPC',
                  isSelected: idx == 1,
                  onTap: () => context.go('/spc'),
                ),
                _NavItem(
                  icon: Icons.videocam_outlined,
                  selectedIcon: Icons.videocam,
                  label: 'CAMÉRA',
                  isSelected: idx == 2,
                  onTap: () => context.go('/camera'),
                ),
                _NavItem(
                  icon: Icons.access_time_outlined,
                  selectedIcon: Icons.access_time_filled,
                  label: 'HISTORIQUE',
                  isSelected: idx == 3,
                  onTap: () => context.go('/history'),
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
          // Underline indicator
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
