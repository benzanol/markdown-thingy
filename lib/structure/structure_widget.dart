import 'package:flutter/material.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/structure/element_widget.dart';
import 'package:notes/structure/structure.dart';
import 'package:notes/utils/fold_button.dart';


const double hMargin = 8;
const double vPad = 8;
const Color borderColor = Colors.grey;
final BoxBorder focusedBorder = Border.all(color: Colors.blueGrey, width: 2);


class StructureWidget extends StatelessWidget {
  const StructureWidget({super.key, required this.note, required this.struct, required this.depth});
  final NoteEditor note;
  final Structure struct;
  final int depth;

  Widget subheadingWidget(StructureHeading subhead) {
    return StatefulBuilder(builder: (context, setState) {
        final isFocused = note.focused == subhead;
        final isFolded = note.foldedHeadings.contains(subhead);

        final titleWidget = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => note.setFocused(subhead),
          child: Row(
            children: [
              Text(
                depth == 0 ? subhead.title
                : '${"*" * depth} ${subhead.title}',
                style: const TextStyle(fontSize: 30)
              ),
              FoldButton(
                isFolded: isFolded,
                setFolded: (val) => setState(() => (
                    val ? note.foldedHeadings.add(subhead)
                    : note.foldedHeadings.remove(subhead)
                )),
              ),
            ],
          ),
        );

        return Container(
          margin: const EdgeInsets.symmetric(vertical: vPad),
          decoration: BoxDecoration(border: isFocused ? focusedBorder : null),
          child: Column(
            children: [
              titleWidget,
              Container(
                decoration: const BoxDecoration(border: Border(
                    left: BorderSide(width: 1, color: borderColor),
                )),
                padding: const EdgeInsets.only(left: 10),
                margin: const EdgeInsets.only(left: 2),
                child: Visibility(
                  maintainState: true,
                  visible: !isFolded,
                  child: StructureWidget(note: note, struct: subhead.body, depth: depth+1),
                ),
              ),
            ],
          ),
        );
    });
  }

  Widget elementWidget(StructureElement elem) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => note.setFocused(elem),
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: vPad),
      decoration: BoxDecoration(border: note.focused == elem ? focusedBorder : null),
      child: StructureElementWidget(note: note, element: elem),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...struct.content.map(elementWidget),
        ...struct.headings.map(subheadingWidget),
      ],
    );
  }
}
