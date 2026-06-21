import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/layout/main_layout_page.dart';
import '../../features/home/pages/time_machine_page.dart';
import '../../features/home/pages/pet_status_page.dart';
import '../../features/home/pages/account_page.dart';
import '../../features/home/pages/inventory/inventory_page.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: ref.read(initialLocationProvider),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainLayoutPage(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/time-machine',
                builder: (context, state) => const TimeMachinePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/pet-status',
                builder: (context, state) => const PetStatusPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                builder: (context, state) => const AccountPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inventory',
                builder: (context, state) => const InventoryPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

final initialLocationProvider = StateProvider<String>((ref) => '/pet-status');
