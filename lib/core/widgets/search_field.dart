import 'package:flutter/material.dart';

/// A search field widget that allows users to input search queries
/// Will be enhanced with search functionality in the future
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    this.onChanged,
    this.onSubmitted,
  });

  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 4.0),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(
              color: theme.colorScheme.outline,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          filled: true,
          fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        ),
        style: theme.textTheme.bodyLarge,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
      ),
    );
  }
}
