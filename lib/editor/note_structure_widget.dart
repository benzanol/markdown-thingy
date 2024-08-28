import 'package:flutter/material.dart';
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
  });
  final NoteEditor note;
  final Structure structure;
  final StructureType st;
  final int depth;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ...List.generate(structure.content.length, (idx) => (
          StructureElementWidget(note: note, parent: structure, index: idx)
      )),
      ...List.generate(structure.headings.length, (idx) => (
          StructureHeadingWidget(note: note, parent: structure, index: idx, depth: depth)
      )),
    ],
  );
}


class StructureHeadingWidget extends StatefulWidget {
  const StructureHeadingWidget({
      super.key,
      required this.note,
      required this.parent,
      required this.index,
      required this.depth,
  });
  final NoteEditor note;
  final Structure parent;
  final int index;
  final int depth;

  @override
  State<StructureHeadingWidget> createState() => StructureHeadingWidgetState();
}

class StructureHeadingWidgetState extends State<StructureHeadingWidget> implements FocusableElement {
  StructureHeadingWidgetState();

  NoteEditor get note => widget.note;
  Structure get parent => widget.parent;
  int get index => widget.index;
  int get depth => widget.depth;
  String get title => parent.headings[index].$1;
  Structure get struct => parent.headings[index].$2;

  bool isFolded = false;

  bool _isFocused = false;
  @override void onFocus() => setState(() => _isFocused = true);
  @override void onUnfocus() => setState(() => _isFocused = false);
  @override void beforeAction() {}
  @override void afterAction() => setState(() {});

  @override
  EditorActionsBar actions() => (
    EditorActionsBar<StructureHeadingWidgetState>(headingActions, this)
  );

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
          )
        ],
      ),
    );

    return Container(
      decoration: (_isFocused ? focusedDecoration : null),
      child: Column(
        children: [
          headWidget,
          isFolded ? Container() : StructureWidget(
            note: widget.note,
            structure: struct,
            st: note.st,
            depth: depth + 1,
          ),
        ]
      ),
    );
  }
}


class StructureElementWidget extends StatefulWidget {
  const StructureElementWidget({
      super.key,
      required this.note,
      required this.parent,
      required this.index,
  });

  final NoteEditor note;
  final Structure parent;
  final int index;

  @override
  State<StructureElementWidget> createState() => StructureElementWidgetState();
}

class StructureElementWidgetState extends State<StructureElementWidget> implements FocusableElement {
  StructureElementWidgetState();

  NoteEditor get note => widget.note;
  Structure get parent => widget.parent;
  int get index => widget.index;
  StructureElement get element => parent.content[index];

  bool isFolded = false;

  bool _isFocused = false;
  @override void onFocus() => setState(() => _isFocused = true);
  @override void onUnfocus() {
    setState(() => _isFocused = false);
  }
  @override void beforeAction() {}
  @override void afterAction() => setState(() {});

  @override
  EditorActionsBar actions() => (
    EditorActionsBar<StructureElementWidgetState>([], this)
  );

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => note.focus(this),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: vSpace/2),
      child: Container(
        decoration: (_isFocused ? focusedDecoration : null),
        child: element.widget(note),
      ),
    ),
  );
}
