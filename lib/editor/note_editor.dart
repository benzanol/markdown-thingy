import 'dart:io';

import 'package:flutter/material.dart';
import 'package:notes/structure/structure.dart';
import 'package:notes/structure/text.dart';


const double hMargin = 8;
const double vSpace = 8;
const double textPadding = 8;
const Color borderColor = Colors.grey;


class NoteEditor extends StatelessWidget {
  NoteEditor({super.key, required this.file, required this.init, this.isRaw = false, this.onUpdate});

  final File file;
  final String init;
  final bool isRaw;
  final Function(NoteEditor)? onUpdate;

  late final _NoteEditorWidget _childEditor = (
    isRaw ? _RawNoteWidget(this, init) : _StructureNoteWidget(this, Structure.parse(init))
  );

  String toText() => _childEditor.toText();

  void update() => onUpdate?.call(this);

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
          padding: const EdgeInsets.symmetric(horizontal: hMargin, vertical: vSpace),
          controller: scrollController,
          child: _childEditor,
        ),
      )
    );
  }
}


abstract class _NoteEditorWidget implements Widget { String toText(); }


class _RawNoteWidget extends StatelessWidget implements _NoteEditorWidget {
  _RawNoteWidget(this.note, String init)
  : text = StructureText(init);

  final NoteEditor note;
  final StructureText text;

  @override
  String toText() => text.toText();

  @override
  Widget build(BuildContext context) => text.widget(note);
}


class _StructureNoteWidget extends StatefulWidget implements _NoteEditorWidget {
  const _StructureNoteWidget(this.note, this.structure);

  final Structure structure;
  final NoteEditor note;

  @override
  String toText() => structure.toText();

  @override
  State<_StructureNoteWidget> createState() => _StructureNoteWidgetState();
}

class _StructureNoteWidgetState extends State<_StructureNoteWidget> {
  Set<String> foldedHeadings = {};

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...widget.structure.content.expand((elem) => [
            const SizedBox(height: vSpace),
            elem.widget(widget.note),
        ]).skip(1),
        ...widget.structure.headings.expand((head) {
            final isFolded = foldedHeadings.contains(head.$1);
            final headWidget = GestureDetector(
              onTap: isFolded
              ? () => setState(() => foldedHeadings.remove(head.$1))
              : () => setState(() => foldedHeadings.add(head.$1)),
              child: Text(head.$1, style: const TextStyle(fontSize: 30)),
            );
            if (isFolded) return [headWidget];
            final contentsWidget = _StructureNoteWidget(widget.note, head.$2);
            return [headWidget, contentsWidget];
        }),
      ],
    );
  }
}
