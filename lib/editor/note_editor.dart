import 'package:flutter/material.dart';
import 'package:notes/editor/note_handler.dart';
import 'package:notes/structure/structure.dart';
import 'package:notes/structure/structure_parser.dart';
import 'package:notes/structure/structure_widget.dart';
import 'package:notes/utils/icon_btn.dart';


class NoteEditor {
  NoteEditor({required this.handler, required this.file});
  final NoteHandler handler;
  final String file;
  late final StructureParser sp = StructureParser.fromFileOrText(file);
  late Structure struct = sp.parse(handler.fs.readOrErr(file));

  bool unsaved = false;
  bool isRaw = false;

  final Set<StructureHeading> foldedHeadings = {};
  Object? focused; // StructureHeading | StructureElement | TextEdittingController | CodeController

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

  void setFocused(Object? newFocus) {
    print('Focused: $newFocus');
    if (newFocus == focused) return;
    focused = newFocus;
    handler.refreshWidget();
  }
}


class NoteEditorWidget extends StatelessWidget {
  NoteEditorWidget({required this.note}) : super(key: GlobalObjectKey(note));
  final NoteEditor note;

  @override
  Widget build(BuildContext context) {
    final scrollController = ScrollController();
    final noteBody = Container(
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
    );

    return GestureDetector(
      onTap: () => note.setFocused(null),
      child: Column(
        children: [
          Expanded(child: noteBody),
          // Wrap in a builder so that the action bar gets created AFTER a
          // focusedElement gets initialized
          Builder(builder: (context) => Container(
              color: Theme.of(context).colorScheme.secondary,
              child: const Row(
                children: [IconBtn(icon: Icons.abc)],
                // children: (
                //   (focused?.actions ?? [EditorActionsBar<Structure>(structureActions, struct)])
                //   .expand((bar) => bar.actions.map((action) => (
                //         action.buttonWidget(this, context, bar.param)
                //   )))
                //   .toList()
                // )
              ),
          )),
        ],
      ),
    );
  }
}
