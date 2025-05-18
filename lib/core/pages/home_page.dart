import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../widgets/platform_navigation.dart';

/// Main screen of the application with platform-adaptive navigation
/// Renders differently on iOS and Android while maintaining consistent functionality
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    const platformNav = PlatformNavigation();

    if (Platform.isIOS) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('Tickify'),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(CupertinoIcons.line_horizontal_3),
            onPressed: () => platformNav.showPlatformNavigation(context),
          ),
        ),
        child: const SafeArea(
          child: Center(
            child: Text('Welcome to Tickify!'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tickify'),
      ),
      drawer: platformNav,
      body: const Center(
        child: Text('Welcome to Tickify!'),
      ),
    );
  }
}
