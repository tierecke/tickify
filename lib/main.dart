import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/pages/home_page.dart';
import 'core/theme/app_theme.dart';

/// Entry point of the application
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

/// Root widget of the application that configures global theming and styling
/// Sets up Material 3 design system with support for both light and dark themes
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tickify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      // This will make the app follow the system theme
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}
