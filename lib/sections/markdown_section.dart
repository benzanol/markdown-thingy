import 'package:flutter/material.dart';
import 'package:notes/editor/note_editor.dart';

class MarkdownSection extends NoteSection {
  MarkdownSection(String init)
  : _controller = TextEditingController(text: init);

  final TextEditingController _controller;

  @override
  String getText() => _controller.text;

  @override
  Widget widget(BuildContext context) => Container(
    decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
    child: TextField(
      controller: _controller,
      onChanged: (_) => onUpdate?.call(),

      maxLines: null,
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.all(textPadding),
      ),
    ),
  );
}
