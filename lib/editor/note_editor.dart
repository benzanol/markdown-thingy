import 'package:flutter/material.dart';
import 'package:notes/editor/note_handler.dart';
import 'package:notes/structure/structure.dart';
import 'package:notes/structure/structure_parser.dart';
import 'package:notes/structure/structure_widget.dart';


class NoteEditor {
  NoteEditor({required this.handler, required this.file});
  final NoteHandler handler;
  final String file;
  late final StructureParser sp = StructureParser.fromFileOrText(file);
  late Structure struct = sp.parse(handler.fs.readOrErr(file));

  bool unsaved = false;
  bool isRaw = false;

  final Set<StructureHeading> foldedHeadings = {};

  void markUnsaved() {
    if (unsaved) return;
    unsaved = true;
    handler.refreshWidget();
  }

  void save() {
    if (!unsaved) return;
    unsaved = false;
    handler.fs.writeOrErr(file, sp.format(struct));
    handler.refreshWidget();
  }

  void setRaw(newRaw) {
    if (isRaw == newRaw) return;
    isRaw = newRaw;

    if (newRaw) {
      final elem = StructureText(sp.format(struct));
      struct = Structure(props: {}, content: [elem], headings: []);
    } else {
      struct = sp.parse(sp.format(struct));
    }

    handler.refreshWidget();
  }


  void setFocused(Object? newFocus, {bool noRefresh = false}) {
    handler.setFocused(newFocus == null ? null : (this, newFocus), noRefresh: noRefresh);
  }

  Object? get focused {
    final f = handler.focused;
    return (f != null && f.$1 == this) ? f.$2 : null;
  }
}


class NoteEditorWidget extends StatelessWidget {
  NoteEditorWidget({required this.note}) : super(key: GlobalObjectKey(note));
  final NoteEditor note;

  @override
  Widget build(BuildContext context) {
    final scrollController = ScrollController();
    return GestureDetector(
      onTap: () => note.setFocused(null),
      child: Container(
        alignment: Alignment.topCenter,
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Scrollbar(
          thickness: 5,
          thumbVisibility: true,
          controller: scrollController,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: hMargin, vertical: vPad),
            controller: scrollController,
            child: StructureWidget(note: note, struct: note.struct, depth: 0),
          ),
        ),
      ),
    );
  }
}
