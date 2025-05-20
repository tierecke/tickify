import 'package:flutter/material.dart';
import '../widgets/about_dialog.dart';
import '../widgets/login_dialog.dart';
import '../repositories/firebase_repository.dart';
import '../pages/home_page.dart';
import '../pages/manage_lists_page.dart';
import '../models/user_list.dart';

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
List<NavigationItem> getNavigationItems(BuildContext context) {
  final firebaseRepository = FirebaseRepository();
  final isLoggedIn = firebaseRepository.currentUser != null;

  return [
    const NavigationItem(
      title: 'New list',
      icon: Icons.add,
    ),
    NavigationItem(
      title: 'Manage',
      icon: Icons.list,
      onTap: () async {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ManageListsPage()),
        );
        if (result != null && context.mounted) {
          final homePage = context.findAncestorStateOfType<HomePageState>();
          if (homePage != null && result is UserList) {
            homePage.updateRecentList(result);
          }
        }
      },
    ),
    const NavigationItem(
      title: 'Backup / Restore',
      icon: Icons.cloud,
    ),
    const NavigationItem(
      title: 'Settings',
      icon: Icons.settings,
    ),
    NavigationItem(
      title: isLoggedIn ? 'Logout' : 'Login',
      icon: isLoggedIn ? Icons.logout : Icons.login,
      onTap: () async {
        if (isLoggedIn) {
          await firebaseRepository.signOut();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Logged out successfully')),
            );
          }
        } else {
          if (context.mounted) {
            final homePage = context.findAncestorStateOfType<HomePageState>();
            if (homePage != null) {
              await homePage.handleLogin();
            }
          }
        }
      },
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
}
