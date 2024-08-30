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
      this.style,
      this.onChange,
      this.onEnter,
  });
  final String init;
  final TextStyle? style;

  final Function(String)? onChange;
  final Function(EditorBoxFieldState state)? onEnter;

  @override
  State<EditorBoxField> createState() => EditorBoxFieldState();
}

class EditorBoxFieldState extends State<EditorBoxField> {
  late final controller = TextEditingController(text: widget.init);
  final focusNode = FocusNode();
  late final field = TextField(
    controller: controller,
    focusNode: focusNode,
    style: widget.style,
    onChanged: widget.onChange,
    onTap: () => widget.onEnter?.call(this),

    maxLines: null,
    decoration: const InputDecoration(
      isDense: true,
      border: InputBorder.none,
      contentPadding: EdgeInsets.all(textPadding),
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: borderColor),
    ),
    child: field,
  );
}


class EditorBoxCode extends StatefulWidget {
  const EditorBoxCode({
      super.key,
      required this.init,
      required this.language,
      this.style,
      this.onChange,
      this.onEnter,
  });
  final String init;
  final String language;
  final TextStyle? style;

  final Function(String)? onChange;
  final Function(EditorBoxCodeState state)? onEnter;

  @override
  State<EditorBoxCode> createState() => EditorBoxCodeState();
}

class EditorBoxCodeState extends State<EditorBoxCode> {
  EditorBoxCodeState();

  late final controller = CodeController(
    text: widget.init,
    language: allLanguages[widget.language],
  );
  final focusNode = FocusNode();
  late final field = CodeTheme(
    data: const CodeThemeData(styles: ideaTheme),
    child: CodeField(
      controller: controller,
      focusNode: focusNode,
      textStyle: widget.style,
      onChanged: widget.onChange,
      onTap: () => widget.onEnter?.call(this),

      // Any less wide and triple digit numbers will wrap to the next line
      lineNumberStyle: const LineNumberStyle(width: 35, margin: 5),
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: borderColor),
      ),
      child: field,
    );
}
