import 'package:flutter/material.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/structure/structure.dart';


class StructureText extends StructureElement {
  StructureText(this.lines);
  List<String> lines;

  @override
  String toText() => lines.join('\n');

  @override
  Widget widget(Function() onUpdate) => _TextWidget(this, onUpdate);
}

class _TextWidget extends StatelessWidget {
  const _TextWidget(this.element, this.onUpdate);
  final StructureText element;
  final Function() onUpdate;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
    child: TextField(
      controller: TextEditingController(text: element.toText()),
      onChanged: (newText) {
        element.lines = newText.split('\n');
        onUpdate();
      },

      maxLines: null,
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
        contentPadding: EdgeInsets.all(textPadding),
      ),
    ),
  );
}
