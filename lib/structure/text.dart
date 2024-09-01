import 'package:flutter/material.dart';
import 'package:notes/components/global_value_key.dart';
import 'package:notes/editor/actions.dart';
import 'package:notes/editor/builtin_actions.dart';
import 'package:notes/editor/editor_box.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/editor/structure_widget.dart';
import 'package:notes/structure/structure.dart';
import 'package:notes/structure/structure_type.dart';


class StructureText extends StructureElement {
  StructureText(this.content);
  String content;

  @override
  dynamic toJson() => {'type': 'text', 'content': content};

  @override
  String markup(StructureMarkup sm) => content;

  @override
  Widget widget(note, parent) => TextSectionWidget(note, this, parent);
}


class TextSectionWidget extends StatelessWidget {
  TextSectionWidget(this.note, this.element, this.parent)
  : super(key: GlobalValueKey((note, element, 'text')));
  final NoteEditor note;
  final StructureText element;
  final StructureElementWidgetState parent;

  late final EditorBoxField fieldWidget = EditorBoxField(
    key: GlobalValueKey((note, element, 'box')),
    init: element.content,
    onChange: (newText) {
      element.content = newText;
      note.update();
    },
    onEnter: (box) => note.focus(FocusableText(this, box)),
  );

  @override
  Widget build(BuildContext context) => fieldWidget;
}

// Pleaseeeeeeeeeee don't try merging this with the TextSectionWidget
// Its too hard to get the editing controller and focus node as fields
class FocusableText implements Focusable {
  FocusableText(this.widget, this.box);
  final TextSectionWidget widget;
  final EditorBoxFieldState box;

  @override bool get shouldRefresh => false;
  @override get actions => EditorActionsBar<FocusableText>(textActions, this);
  @override void afterAction() => box.focusNode.requestFocus();
}
