import 'package:flutter/material.dart';
import 'package:tickify/core/data/general.dart';
import 'package:tickify/core/data/version_data.dart';
import 'package:url_launcher/url_launcher.dart';

/// A custom about dialog that shows app information and contact options
class CustomAboutDialog extends StatelessWidget {
  const CustomAboutDialog({super.key});

  Future<void> _sendEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'tickify.app@gmail.com',
    );

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 96,
                height: 96,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Tickify',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Version ${VersionData.appVersionString}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Text(
              'Copyright © 2025, Tierecke',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'For comments, suggestions or bug reports\nplease use the contact button or write to',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              General.tiereckeMailAddress,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                // color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _sendEmail,
                  child: const Text('Contact'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
