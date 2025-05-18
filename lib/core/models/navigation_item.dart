import 'package:flutter/material.dart';
import '../widgets/about_dialog.dart';

/// Model representing a navigation menu item with its associated icon and action
class NavigationItem {
  final String title;
  final IconData icon;
  final VoidCallback? onTap;

  const NavigationItem({
    required this.title,
    required this.icon,
    this.onTap,
  });
}

/// Static list of navigation items used across both Android and iOS platforms
List<NavigationItem> getNavigationItems(BuildContext context) => [
      const NavigationItem(
        title: 'New list',
        icon: Icons.add,
      ),
      const NavigationItem(
        title: 'Manage',
        icon: Icons.list,
      ),
      const NavigationItem(
        title: 'Backup / Restore',
        icon: Icons.cloud,
      ),
      const NavigationItem(
        title: 'Settings',
        icon: Icons.settings,
      ),
      const NavigationItem(
        title: 'Login',
        icon: Icons.person_outline,
      ),
      NavigationItem(
        title: 'About',
        icon: Icons.info_outline,
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => const CustomAboutDialog(),
          );
        },
      ),
    ];
