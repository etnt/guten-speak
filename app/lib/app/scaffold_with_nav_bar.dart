import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/update/update_prompt.dart';
import '../core/update/update_provider.dart';
import '../features/library/presentation/widgets/recently_read_sheet.dart';
import '../features/narration/presentation/widgets/narration_mini_player.dart';

class ScaffoldWithNavBar extends ConsumerStatefulWidget {
  const ScaffoldWithNavBar({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends ConsumerState<ScaffoldWithNavBar> {
  bool _updateCheckStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
  }

  void _checkForUpdate() {
    if (_updateCheckStarted || !mounted) return;
    _updateCheckStarted = true;
    unawaited(
      maybeShowUpdateDialog(
        context,
        checker: ref.read(releaseCheckerProvider),
        onUpdate: (info) async {
          final uri = Uri.tryParse(info.releasePageUrl);
          if (uri == null || uri.scheme != 'https') return;
          try {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (_) {
            // A failed browser launch must not interrupt the app.
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const NarrationMiniPlayer(),
          NavigationBar(
            selectedIndex: widget.navigationShell.currentIndex,
            onDestinationSelected: (int index) {
              if (index == 0 && widget.navigationShell.currentIndex == 0) {
                showRecentlyReadSheet(context);
                return;
              }
              widget.navigationShell.goBranch(
                index,
                initialLocation: index == widget.navigationShell.currentIndex,
              );
            },
            destinations: [
              NavigationDestination(
                icon: Icon(
                  widget.navigationShell.currentIndex == 0
                      ? Icons.history_outlined
                      : Icons.home_outlined,
                ),
                selectedIcon: Icon(
                  widget.navigationShell.currentIndex == 0
                      ? Icons.history
                      : Icons.home,
                ),
                label: widget.navigationShell.currentIndex == 0
                    ? 'Recent'
                    : 'Home',
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
