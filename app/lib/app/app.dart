import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../features/narration/presentation/providers/sleep_timer_provider.dart';
import '../features/settings/presentation/providers/theme_provider.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class GutenSpeakApp extends ConsumerWidget {
  const GutenSpeakApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    // Keep the timer's playback listener alive even when no reader/player
    // screen is currently mounted.
    ref.watch(sleepTimerControllerProvider);
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
