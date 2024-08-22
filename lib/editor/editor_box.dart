import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/idea.dart';
import 'package:highlight/languages/all.dart';
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


class EditorBoxField extends StatefulWidget {
  const EditorBoxField({
      super.key,
      required this.init,
      this.onChange,
      this.style,
      this.language,
  });
  final String init;
  final Function(String)? onChange;
  final TextStyle? style;
  final String? language;

  @override
  State<EditorBoxField> createState() => _EditorBoxFieldState();
}

class _EditorBoxFieldState extends State<EditorBoxField> {
  late final TextEditingController _controller = (
    widget.language == null ? TextEditingController(text: widget.init)
    : CodeController(
      text: widget.init,
      language: allLanguages[widget.language],
    )
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final inner = (
      controller is CodeController
      ? CodeTheme(
        data: const CodeThemeData(styles: ideaTheme),
        child: CodeField(
          controller: controller,
          onChanged: widget.onChange,
          textStyle: widget.style,

          // Any less wide and triple digit numbers will wrap to the next line
          lineNumberStyle: const LineNumberStyle(width: 35, margin: 5),
        ),
      )
      : TextField(
        controller: controller,
        onChanged: widget.onChange,
        style: widget.style,

        maxLines: null,
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(textPadding),
        ),
      )
    );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: borderColor),
      ),
      child: inner,
    );
  }
}
