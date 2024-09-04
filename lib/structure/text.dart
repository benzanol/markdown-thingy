import 'package:flutter/material.dart';
import 'package:notes/components/fold_button.dart';
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
  Widget widget(note, parent) => _TextSectionWidget(note, this, parent);
}


class _TextSectionWidget extends StatefulWidget {
  _TextSectionWidget(this.note, this.element, this.parent)
  : super(key: GlobalValueKey((note, element, 'text')));
  final NoteEditor note;
  final StructureText element;
  final StructureElementWidgetState parent;

  @override
  State<_TextSectionWidget> createState() => TextSectionWidgetState();
}

class TextSectionWidgetState extends State<_TextSectionWidget> {
  bool isFolded = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Text(
            'Text',
            textScaler: TextScaler.linear(1.2),
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          FoldButton(isFolded: isFolded, setFolded: (val) => setState(() => isFolded = val))
        ],
      ),
      Visibility(
        visible: !isFolded,
        child: EditorBoxField(
          key: GlobalValueKey((widget.note, widget.element, 'box')),
          init: widget.element.content,
          onChange: (newText) {
            widget.element.content = newText;
            widget.note.markModified();
          },
          onEnter: (box) => widget.note.focus(FocusableText(this, box)),
        ),
      ),
    ],
  );
}


// Pleaseeeeeeeeeee don't try merging this with the TextSectionWidget
// Its too hard to get the editing controller and focus node as fields
class FocusableText implements Focusable {
  FocusableText(this.state, this.box);
  final TextSectionWidgetState state;
  final EditorBoxFieldState box;

  @override bool get shouldRefresh => false;
  @override get actions => EditorActionsBar<FocusableText>(textActions, this);
  @override void afterAction() => box.focusNode.requestFocus();
}
