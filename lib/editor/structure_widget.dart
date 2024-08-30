import 'package:flutter/material.dart';
import 'package:notes/components/global_value_key.dart';
import 'package:notes/components/icon_btn.dart';
import 'package:notes/editor/actions.dart';
import 'package:notes/editor/builtin_actions.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/structure/structure.dart';
import 'package:notes/structure/structure_type.dart';


final focusedDecoration = BoxDecoration(border: Border.all(color: Colors.blueGrey, width: 2));


class StructureWidget extends StatelessWidget {
  const StructureWidget({
      super.key,
      required this.note,
      required this.structure,
      required this.st,
      this.depth = 0,
      this.parent,
  });
  final NoteEditor note;
  final Structure structure;
  final StructureType st;
  final int depth;
  final StructureHeadingWidgetState? parent;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ...List.generate(structure.content.length, (idx) => (
          StructureElementWidget(note: note, parent: this, index: idx)
      )),
      ...List.generate(structure.headings.length, (idx) => (
          StructureHeadingWidget(note: note, parent: this, index: idx, depth: depth)
      )),
    ],
  );
}


class StructureHeadingWidget extends StatefulWidget {
  StructureHeadingWidget({
      required this.note,
      required this.parent,
      required this.index,
      required this.depth,
  })
  : super(key: GlobalValueKey((note, parent.structure.headings[index], 'heading')));
  final NoteEditor note;
  final StructureWidget parent;
  final int index;
  final int depth;

  @override
  State<StructureHeadingWidget> createState() => StructureHeadingWidgetState();
}

class StructureHeadingWidgetState extends State<StructureHeadingWidget> implements Focusable {
  StructureHeadingWidgetState();

  NoteEditor get note => widget.note;
  Structure get parent => widget.parent.structure;
  int get index => widget.index;
  int get depth => widget.depth;
  String get title => parent.headings[index].title;
  Structure get struct => parent.headings[index].body;

  bool isFolded = false;

  @override bool get shouldRefresh => true;
  @override get actions => EditorActionsBar<StructureHeadingWidgetState>(headingActions, this);
  @override void afterAction() {}

  @override
  Widget build(BuildContext context) {
    final headWidget = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => note.focus(this),
      child: Row(
        children: [
          Text(
            widget.depth == 0 ? title
            : '${note.st.headingPrefixChar * widget.depth} $title',
            style: const TextStyle(fontSize: 30)
          ),
          IconBtn(
            icon: isFolded ? Icons.keyboard_arrow_right : Icons.keyboard_arrow_down,
            radius: 5,
            onPressed: () => setState(() {
                isFolded = !isFolded;
                note.focus(this);
            }),
          ),
        ],
      ),
    );

    return Container(
      decoration: (note.focused == this ? focusedDecoration : null),
      child: Column(
        children: [
          headWidget,
          Visibility(
            visible: !isFolded,
            maintainState: true,
            child: StructureWidget(
              note: widget.note,
              structure: struct,
              st: note.st,
              depth: depth + 1,
              parent: this,
            ),
          ),
        ],
      ),
    );
  }
}


class StructureElementWidget extends StatefulWidget {
  StructureElementWidget({
      required this.note,
      required this.parent,
      required this.index,
  })
  : super(key: GlobalValueKey((note, parent.structure.content[index], 'element')));

  final NoteEditor note;
  final StructureWidget parent;
  final int index;

  @override
  State<StructureElementWidget> createState() => StructureElementWidgetState();
}

class StructureElementWidgetState extends State<StructureElementWidget> implements Focusable {
  StructureElementWidgetState();

  NoteEditor get note => widget.note;
  Structure get parent => widget.parent.structure;
  int get index => widget.index;
  StructureElement get element => parent.content[index];

  bool isFolded = false;

  @override bool get shouldRefresh => true;
  @override get actions => EditorActionsBar<StructureElementWidgetState>(elementActions, this);
  @override void afterAction() {}

  @override
  Widget build(BuildContext context) {
    if (element == note.focusedElement) {
      note.focused = this;
      note.focusedElement = null;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => note.focus(this),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: vSpace/2),
        child: Container(
          decoration: (note.focused == this ? focusedDecoration : null),
          child: element.widget(note, this),
        ),
      ),
    );
  }
}
