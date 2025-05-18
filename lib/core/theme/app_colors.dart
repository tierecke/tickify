import 'package:flutter/material.dart';

/// AppColors defines the color palette for both light and dark themes.
/// These colors are derived from the design system specifications and
/// maintain consistency across the application.
class AppColors {
  // Light Theme Colors
  /// The main background color for light theme - pure white
  static const lightBackground = Color(0xFFFFFFFF);

  /// Secondary surface color for cards, dialogs etc. in light theme
  static const lightSurface = Color(0xFFF5F5F5);

  /// Primary brand color/accent color - orange
  static const lightPrimary = Color(0xFFFF6B3C);

  /// Color used for text/icons on primary color surfaces
  static const lightOnPrimary = Color(0xFFFFFFFF);

  /// Main text color for light theme
  static const lightText = Color(0xFF1C1C1E);

  /// Color used for dividers and borders in light theme
  static const lightDivider = Color(0xFFE0E0E0);

  // Dark Theme Colors
  /// The main background color for dark theme - material dark
  static const darkBackground = Color(0xFF121212);

  /// Secondary surface color for cards, dialogs etc. in dark theme
  static const darkSurface = Color(0xFF1E1E1E);

  /// Primary brand color/accent color - same as light theme for consistency
  static const darkPrimary = Color(0xFFFF6B3C);

  /// Color used for text/icons on primary color surfaces
  static const darkOnPrimary = Color(0xFFFFFFFF);

  /// Main text color for dark theme - slightly off-white for better contrast
  static const darkText = Color(0xFFEDEDED);

  /// Color used for dividers and borders in dark theme
  static const darkDivider = Color(0xFF2C2C2E);
}
