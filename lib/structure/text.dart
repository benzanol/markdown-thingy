import 'package:flutter/material.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/structure/structure.dart';


class StructureText extends StructureElement {
  StructureText(this.lines);
  List<String> lines;

  @override
  dynamic toJson() => {'type': 'text', 'text': lines.join('\n')};

  @override
  String toText() => lines.join('\n');

  @override
  Widget widget(NoteEditor note) => _TextWidget(note, this);
}

class _TextWidget extends StatelessWidget {
  const _TextWidget(this.note ,this.element);
  final NoteEditor note;
  final StructureText element;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(border: Border.all(color: borderColor)),
    child: TextField(
      controller: TextEditingController(text: element.toText()),
      onChanged: (newText) {
        element.lines = newText.split('\n');
        note.update();
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
