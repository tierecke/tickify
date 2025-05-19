import 'package:flutter/material.dart';

class AddItemTile extends StatelessWidget {
  final VoidCallback onTap;
  final bool isWriteMode;

  const AddItemTile({
    super.key,
    required this.onTap,
    required this.isWriteMode,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.add_circle_outline),
      title: const Text('+ Add item'),
      onTap: isWriteMode ? onTap : null,
      enabled: isWriteMode,
    );
  }
}
