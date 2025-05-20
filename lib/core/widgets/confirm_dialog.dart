import 'package:flutter/material.dart';

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String yesTitle;
  final String noTitle;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.yesTitle = 'Yes',
    this.noTitle = 'No',
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(noTitle),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(yesTitle),
        ),
      ],
    );
  }
}
