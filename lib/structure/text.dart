import 'package:flutter/material.dart';
import 'package:notes/editor/actions.dart';
import 'package:notes/editor/builtin_actions.dart';
import 'package:notes/editor/editor_box.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/structure/structure.dart';
import 'package:notes/structure/structure_type.dart';


class StructureText extends StructureElement {
  final _textKey = GlobalKey();

  StructureText(this.text);
  String text;

  @override
  dynamic toJson() => {'type': 'text', 'text': text};

  @override
  String toText(StructureType st) => text;

  @override
  Widget widget(NoteEditor note) => _TextSectionWidget(note, this);
}


class _TextSectionWidget extends StatelessWidget {
  _TextSectionWidget(this.note, this.element);
  final NoteEditor note;
  final StructureText element;

  late final EditorBoxField fieldWidget = EditorBoxField(
    key: element._textKey,
    init: element.text,
    onChange: (newText) {
      element.text = newText;
      note.update();
    },
    onEnter: (c, fn) => note.focus(_FocusableText(c, fn)),
  );

  @override
  Widget build(BuildContext context) => fieldWidget;
}


class _FocusableText extends FocusableElement {
  _FocusableText(this.controller, this.focusNode);
  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  EditorActionsBar actions() => (
    EditorActionsBar<TextEditingController>(textActions, controller)
  );

  @override
  void beforeAction() => focusNode.requestFocus();
}
