import 'package:flutter/material.dart';
import 'package:notes/editor/editor_box.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/structure/structure.dart';


class StructureText extends StructureElement {
  StructureText(this.text);
  String text;

  @override
  dynamic toJson() => {'type': 'text', 'text': text};

  @override
  String toText() => text;

  @override
  Widget widget(NoteEditor note) => EditorBoxField(
    init: text,
    onChange: (newText) {
      text = newText;
      note.update();
    },
  );
}
