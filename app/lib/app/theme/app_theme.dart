import 'package:flutter/material.dart';
import 'app_colors.dart';

enum AppThemeMode { light, sepia, dark, oled }

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryAmber,
        surface: AppColors.lightSurface,
      ),
      scaffoldBackgroundColor: AppColors.lightBackground,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        elevation: 2,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryAmber,
        brightness: Brightness.dark,
        surface: AppColors.darkSurface,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        elevation: 2,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }

  static ThemeData get sepiaTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primaryAmber,
        onPrimary: Colors.white,
        secondary: AppColors.secondaryWarm,
        onSecondary: Colors.white,
        error: Colors.redAccent,
        onError: Colors.white,
        surface: AppColors.sepiaSurface,
        onSurface: AppColors.sepiaOnSurface,
      ),
      scaffoldBackgroundColor: AppColors.sepiaBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.sepiaSurface,
        foregroundColor: AppColors.sepiaOnSurface,
        centerTitle: false,
        elevation: 0,
      ),
    );
  }
}
