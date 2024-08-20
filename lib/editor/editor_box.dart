import 'package:flutter/material.dart';
import 'package:notes/editor/note_editor.dart';


class EditorBox extends StatelessWidget {
  const EditorBox({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: borderColor),
    ),
    padding: const EdgeInsets.all(textPadding),
    alignment: Alignment.topLeft,
    child: child,
  );
}


class EditorBoxField extends StatelessWidget {
  const EditorBoxField({super.key, required this.init, this.onChange, this.style});
  final String init;
  final Function(String)? onChange;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: borderColor),
    ),
    child: TextField(
      controller: TextEditingController(text: init),
      onChanged: onChange,
      style: style,

      maxLines: null,
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.all(textPadding),
      ),
    ),
  );
}
