import 'package:flutter/material.dart';
import 'app_colors.dart';

/// AppTheme provides the theme configuration for the entire application.
/// It includes both light and dark theme definitions following Material 3 guidelines.
class AppTheme {
  /// Light theme configuration
  /// This theme will be automatically applied when the device is in light mode
  static ThemeData get lightTheme {
    return ThemeData(
      // Enable Material 3 design features
      useMaterial3: true,
      brightness: Brightness.light,
      // Define the color scheme for light theme
      colorScheme: const ColorScheme.light(
        background: AppColors.lightBackground,
        surface: AppColors.lightSurface,
        primary: AppColors.lightPrimary,
        onPrimary: AppColors.lightOnPrimary,
      ),
      // Set the main background color for all scaffolds
      scaffoldBackgroundColor: AppColors.lightBackground,
      // Configure text styles with appropriate colors
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.lightText),
        bodyMedium: TextStyle(color: AppColors.lightText),
      ),
      // Configure divider styling
      dividerTheme: const DividerThemeData(
        color: AppColors.lightDivider,
      ),
      // Configure app bar appearance
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightSurface,
        foregroundColor: AppColors.lightText,
        elevation: 0, // Flat design without shadow
      ),
    );
  }

  /// Dark theme configuration
  /// This theme will be automatically applied when the device is in dark mode
  static ThemeData get darkTheme {
    return ThemeData(
      // Enable Material 3 design features
      useMaterial3: true,
      brightness: Brightness.dark,
      // Define the color scheme for dark theme
      colorScheme: const ColorScheme.dark(
        background: AppColors.darkBackground,
        surface: AppColors.darkSurface,
        primary: AppColors.darkPrimary,
        onPrimary: AppColors.darkOnPrimary,
      ),
      // Set the main background color for all scaffolds
      scaffoldBackgroundColor: AppColors.darkBackground,
      // Configure text styles with appropriate colors
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.darkText),
        bodyMedium: TextStyle(color: AppColors.darkText),
      ),
      // Configure divider styling
      dividerTheme: const DividerThemeData(
        color: AppColors.darkDivider,
      ),
      // Configure app bar appearance
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkText,
        elevation: 0, // Flat design without shadow
      ),
    );
  }
}
