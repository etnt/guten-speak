import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/library/presentation/widgets/recently_read_sheet.dart';
import '../features/narration/presentation/widgets/narration_mini_player.dart';

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const NarrationMiniPlayer(),
          NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (int index) {
              if (index == 0 && navigationShell.currentIndex == 0) {
                showRecentlyReadSheet(context);
                return;
              }
              navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              );
            },
            destinations: [
              NavigationDestination(
                icon: Icon(
                  navigationShell.currentIndex == 0
                      ? Icons.history_outlined
                      : Icons.home_outlined,
                ),
                selectedIcon: Icon(
                  navigationShell.currentIndex == 0
                      ? Icons.history
                      : Icons.home,
                ),
                label: navigationShell.currentIndex == 0 ? 'Recent' : 'Home',
              ),
              const NavigationDestination(
                icon: Icon(Icons.local_library_outlined),
                selectedIcon: Icon(Icons.local_library),
                label: 'Library',
              ),
              const NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
