import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/navigation_item.dart';
import 'search_field.dart';

/// A platform-adaptive navigation widget that renders as a drawer on Android
/// and an action sheet on iOS
class PlatformNavigation extends StatelessWidget {
  const PlatformNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    return Platform.isIOS ? _buildActionSheet(context) : _buildDrawer(context);
  }

  /// Builds Material Design navigation drawer for Android
  Widget _buildDrawer(BuildContext context) {
    final theme = Theme.of(context);
    final navigationItems = getNavigationItems(context);

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
            ),
            child: Row(
              children: [
                Image.asset(
                  'assets/icon/app_icon.png',
                  width: 48,
                  height: 48,
                ),
                const SizedBox(width: 16),
                Text(
                  'Tickify',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SearchField(),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: navigationItems.length + 1, // +1 for the divider
              itemBuilder: (context, index) {
                // Add divider before Login item
                if (index == navigationItems.length - 2) {
                  return const Divider(height: 1);
                }
                // Adjust index for items after divider
                final itemIndex =
                    index > navigationItems.length - 2 ? index - 1 : index;
                final item = navigationItems[itemIndex];
                return ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(vertical: -2),
                  minLeadingWidth: 24,
                  leading: Icon(
                    item.icon,
                    size: 24,
                  ),
                  title: Text(
                    item.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 20,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    item.onTap?.call();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Placeholder widget for iOS - actual sheet is shown via showPlatformNavigation
  Widget _buildActionSheet(BuildContext context) {
    return const SizedBox.shrink();
  }

  /// Shows a bottom action sheet for iOS navigation
  Future<void> showPlatformNavigation(BuildContext context) async {
    if (Platform.isIOS) {
      final navigationItems = getNavigationItems(context);
      await showCupertinoModalPopup<void>(
        context: context,
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: CupertinoColors.systemBackground,
              child: const SafeArea(
                child: SearchField(),
              ),
            ),
            CupertinoActionSheet(
              actions: navigationItems.map((item) {
                return CupertinoActionSheetAction(
                  onPressed: () {
                    Navigator.pop(context);
                    item.onTap?.call();
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.icon),
                      const SizedBox(width: 8),
                      Text(item.title),
                    ],
                  ),
                );
              }).toList(),
              cancelButton: CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      );
    }
  }
}
