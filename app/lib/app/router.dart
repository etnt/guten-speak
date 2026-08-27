import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import '../features/catalog/presentation/screens/book_detail_screen.dart';
import '../features/catalog/presentation/screens/catalog_home_screen.dart';
import '../features/catalog/presentation/screens/search_screen.dart';
import '../features/library/presentation/screens/library_screen.dart';
import '../features/narration/presentation/screens/narration_screen.dart';
import '../features/reader/presentation/screens/reader_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/storage/presentation/screens/storage_screen.dart';
import '../features/voices/presentation/screens/voices_screen.dart';
import 'scaffold_with_nav_bar.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _discoverNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'discoverNav',
);
final _libraryNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'libraryNav',
);
final _settingsNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'settingsNav',
);

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/discover',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ScaffoldWithNavBar(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          navigatorKey: _discoverNavigatorKey,
          routes: [
            GoRoute(
              path: '/discover',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: CatalogHomeScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _libraryNavigatorKey,
          routes: [
            GoRoute(
              path: '/library',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: LibraryScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: _settingsNavigatorKey,
          routes: [
            GoRoute(
              path: '/settings',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: SettingsScreen()),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: AppConstants.routeSearch,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SearchScreen(),
    ),
    GoRoute(
      path: '/book/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '');
        if (id == null) {
          return const Scaffold(body: Center(child: Text('Invalid book id')));
        }
        return BookDetailScreen(bookId: id);
      },
    ),
    GoRoute(
      path: AppConstants.routeReader,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '');
        if (id == null) {
          return const Scaffold(body: Center(child: Text('Invalid book id')));
        }
        return ReaderScreen(bookId: id);
      },
    ),
    GoRoute(
      path: AppConstants.routeListen,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '');
        if (id == null) {
          return const Scaffold(body: Center(child: Text('Invalid book id')));
        }
        return NarrationScreen(bookId: id);
      },
    ),
    GoRoute(
      path: AppConstants.routeVoices,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const VoicesScreen(),
    ),
    GoRoute(
      path: AppConstants.routeStorage,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const StorageScreen(),
    ),
  ],
);
