// lib/router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/dashboard_screen.dart';
import 'screens/spc_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/history_screen.dart';
import 'screens/image_view_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    // Login screen (hors shell - pas de navigation bar)
    GoRoute(
      path: '/login',
      builder: (c, s) => const LoginScreen(),
    ),
    // Main app avec navigation bar
    ShellRoute(
      builder: (context, state, child) => _Shell(child: child),
      routes: [
        GoRoute(path: '/', builder: (c, s) => const DashboardScreen()),
        GoRoute(path: '/spc', builder: (c, s) => const SpcScreen()),
        GoRoute(path: '/camera', builder: (c, s) => const CameraScreen()),
        GoRoute(path: '/history', builder: (c, s) => const HistoryScreen()),
      ],
    ),
    // Image accessible depuis Historique — pas dans la nav
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

class _Shell extends StatelessWidget {
  final Widget child;
  const _Shell({required this.child});

  @override
  Widget build(BuildContext context) {
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/');
            case 1:
              context.go('/spc');
            case 2:
              context.go('/camera');
            case 3:
              context.go('/history');
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart),
            label: 'SPC',
          ),
          NavigationDestination(
            icon: Icon(Icons.videocam_outlined),
            selectedIcon: Icon(Icons.videocam),
            label: 'Caméra',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Historique',
          ),
        ],
      ),
    );
  }
}
