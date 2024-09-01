import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:notes/editor/actions.dart';
import 'package:notes/editor/builtin_actions.dart';
import 'package:notes/editor/structure_widget.dart';
import 'package:notes/structure/structure.dart';
import 'package:notes/structure/structure_type.dart';
import 'package:notes/structure/text.dart';


const double hMargin = 8;
const double vSpace = 8;
const double textPadding = 8;
const Color borderColor = Colors.grey;


class NoteEditorWidget extends StatefulWidget {
  const NoteEditorWidget({
      super.key,
      required this.file,
      required this.init,
      this.isRaw = false,
      this.onUpdate
  });
  final File file;
  final String init;
  final bool isRaw;
  final Function(NoteEditor)? onUpdate;

  @override
  State<NoteEditorWidget> createState() => NoteEditor();
}

class NoteEditor extends State<NoteEditorWidget> {
  NoteEditor();

  File get file => widget.file;
  String get init => widget.init;
  bool get isRaw => widget.isRaw;
  Function(NoteEditor)? get onUpdate => widget.onUpdate;

  late final StructureParser sp = StructureParser.fromFileOrDefault(file.path);
  late final Structure struct = (
    !isRaw ? sp.parse(init)
    : Structure(props: {}, headings: [], content: [StructureText(init)])
  );

  String toText() => sp.format(struct);
  void update() => onUpdate?.call(this);


  // Whatever is currently focused
  Focusable? focused;
  StructureElement? focusedElement;
  StructureHeading? focusedHeading;
  void focus(Focusable? newFocus) => setState(() => focused = newFocus);

  Future<void> performAction<T>(EditorAction<T> action, T obj) async {
    final props = EditorActionProps(obj: obj, context: context);
    await action.onPress(props);

    if (props.unfocus) {
      focused = null;
    } else if (props.newFocus != null) {
      focused = props.newFocus;
    } else if (props.newFocusedElement != null) {
      focused = null;
      focusedElement = props.newFocusedElement;
    } else if (props.newFocusedHeading != null) {
      focused = null;
      focusedHeading = props.newFocusedHeading;
    }

    final focusChanged = props.unfocus ||
    (props.newFocus ?? props.newFocusedElement ?? props.newFocusedHeading) != null;

    if (focusChanged || focused?.shouldRefresh == true) {
      setState(() {});
    }

    focused?.afterAction();

    update();
  }

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
          padding: const EdgeInsets.symmetric(horizontal: hMargin, vertical: vSpace),
          controller: scrollController,
          child: StructureWidget(note: this, structure: struct, sp: sp),
        ),
      ),
    );

    return GestureDetector(
      onTap: () => focus(null),
      child: Column(
        children: [
          Expanded(child: noteBody),
          // Wrap in a builder so that the action bar gets created AFTER a
          // focusedElement gets initialized
          Builder(builder: (context) => (
              focused?.actions ?? EditorActionsBar<Structure>(structureActions, struct)
            ).widget(this)),
        ],
      ),
    );
  }
}
