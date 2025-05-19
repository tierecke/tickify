import 'package:flutter/material.dart';

class EditableTextField extends StatefulWidget {
  final String text;
  final bool isEditable;
  final int maxLength;
  final TextStyle style;
  final ValueChanged<String>? onSubmitted;
  final TextAlign textAlign;
  final bool autofocus;
  final bool shrinkToFit;

  const EditableTextField({
    super.key,
    required this.text,
    this.isEditable = false,
    this.maxLength = 30,
    this.style = const TextStyle(fontWeight: FontWeight.bold, fontSize: 32),
    this.onSubmitted,
    this.textAlign = TextAlign.start,
    this.autofocus = false,
    this.shrinkToFit = false,
  });

  @override
  State<EditableTextField> createState() => _EditableTextFieldState();
}

class _EditableTextFieldState extends State<EditableTextField> {
  bool isEditing = false;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.text);
    if (widget.autofocus) {
      isEditing = true;
    }
  }

  @override
  void didUpdateWidget(covariant EditableTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text && !isEditing) {
      _controller.text = widget.text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim().substring(
        0,
        _controller.text.trim().length > widget.maxLength
            ? widget.maxLength
            : _controller.text.trim().length);
    if (widget.onSubmitted != null) {
      widget.onSubmitted!(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditable) {
      return GestureDetector(
        onTap: () {
          setState(() {
            isEditing = true;
            _controller.text = widget.text;
          });
        },
        child: isEditing
            ? Focus(
                onFocusChange: (hasFocus) {
                  if (!hasFocus) {
                    _submit();
                    setState(() {
                      isEditing = false;
                    });
                  }
                },
                child: TextField(
                  controller: _controller,
                  autofocus: widget.autofocus,
                  maxLength: widget.maxLength,
                  style: widget.style,
                  textAlign: widget.textAlign,
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    counterText: '',
                  ),
                  onSubmitted: (_) {
                    _submit();
                    setState(() {
                      isEditing = false;
                    });
                  },
                  textInputAction: TextInputAction.done,
                ),
              )
            : widget.shrinkToFit
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.text,
                      style: widget.style,
                      textAlign: widget.textAlign,
                    ),
                  )
                : Text(
                    widget.text,
                    style: widget.style,
                    textAlign: widget.textAlign,
                  ),
      );
    } else {
      return widget.shrinkToFit
          ? FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                widget.text,
                style: widget.style,
                textAlign: widget.textAlign,
              ),
            )
          : Text(
              widget.text,
              style: widget.style,
              textAlign: widget.textAlign,
            );
    }
  }
}
