import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

class EmojiIcon extends StatelessWidget {
  final String emoji;
  final double size;
  final bool editable;
  final Function(String) onEmojiSelected;

  const EmojiIcon({
    super.key,
    required this.emoji,
    this.size = 40,
    this.editable = false,
    required this.onEmojiSelected,
  });

  void _showEmojiPicker(BuildContext context) {
    if (!editable) return;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return EmojiPicker(
          onEmojiSelected: (category, emoji) {
            onEmojiSelected(emoji.emoji);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: editable ? () => _showEmojiPicker(context) : null,
      child: Text(
        emoji,
        style: TextStyle(fontSize: size),
      ),
    );
  }
}
