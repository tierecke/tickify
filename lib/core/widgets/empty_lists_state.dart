import 'package:flutter/material.dart';

class EmptyListsState extends StatelessWidget {
  final VoidCallback onCreateList;

  const EmptyListsState({
    super.key,
    required this.onCreateList,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cute illustration
            Image.asset(
              'assets/illustrations/empty_lists.png',
              width: 180,
              height: 180,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 32),
            // Bold headline
            Text(
              'No lists yet',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Friendly subtitle
            Text(
              'Stay organized and on top of things!\nCreate your first list to get started.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            // Large, rounded orange button
            SizedBox(
              width: 220,
              height: 52,
              child: FilledButton(
                onPressed: onCreateList,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  textStyle: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                child: const Text('Create list'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
