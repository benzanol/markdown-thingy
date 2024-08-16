import 'package:flutter/material.dart';
import 'package:notes/structure/parse_structure.dart';
import 'package:notes/structure/structure.dart';
import 'package:notes/structure/text.dart';


const double hMargin = 8;
const double vMargin = 4;
const double textPadding = 8;


class NoteEditor extends StatelessWidget {
  NoteEditor({super.key, required this.init, this.raw = false, this.onUpdate});

  final String init;
  final bool raw;
  final Function(NoteEditor)? onUpdate;

  void _update() => onUpdate?.call(this);
  late final _NoteEditorChild _childEditor = (
    raw
    ? _RawNoteEditor(init: init, onUpdate: _update)
    : _StructureNoteEditor(structure: parseStructure(init.split('\n')), onUpdate: _update)
  );
  String toText() => _childEditor.toText();

  @override
  Widget build(BuildContext context) {
    final scrollController = ScrollController();
    return Container(
      alignment: Alignment.topCenter,
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Scrollbar(
        thickness: 5,
        thumbVisibility: true,
        controller: scrollController,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: hMargin, vertical: vMargin),
          controller: scrollController,
          child: _childEditor,
        ),
      )
    );
  }
}


abstract class _NoteEditorChild implements Widget {
  String toText();
}

class _RawNoteEditor extends StatelessWidget implements _NoteEditorChild {
  _RawNoteEditor({required String init, required this.onUpdate})
  : text = StructureText(init.split('\n'));

  final Function() onUpdate;
  final StructureText text;

  @override
  String toText() => text.toText();

  @override
  Widget build(BuildContext context) => text.widget(onUpdate);
}


class _StructureNoteEditor extends StatefulWidget implements _NoteEditorChild {
  const _StructureNoteEditor({required this.structure, required this.onUpdate});

  final Function() onUpdate;
  final NoteStructure structure;

  @override
  String toText() => structure.toText();

  @override
  State<_StructureNoteEditor> createState() => _StructureNoteEditorState();
}

class _StructureNoteEditorState extends State<_StructureNoteEditor> {
  Set<String> foldedHeadings = {};

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...widget.structure.content.map((elem) => Container(
            margin: const EdgeInsets.symmetric(vertical: vMargin),
            color: Theme.of(context).colorScheme.surface,
            child: elem.widget(widget.onUpdate)
        )),
        ...widget.structure.headings.expand((head) {
            final isFolded = foldedHeadings.contains(head.$1);
            final headWidget = GestureDetector(
              onTap: isFolded
              ? () => setState(() => foldedHeadings.remove(head.$1))
              : () => setState(() => foldedHeadings.add(head.$1)),
              child: Text(head.$1, style: const TextStyle(fontSize: 30)),
            );
            if (isFolded) return [headWidget];
            final contentsWidget = _StructureNoteEditor(structure: head.$2, onUpdate: widget.onUpdate);
            return [headWidget, contentsWidget];
        }),
      ],
    );
  }
}
