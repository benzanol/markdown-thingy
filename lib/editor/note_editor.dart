import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:notes/editor/actions.dart';
import 'package:notes/editor/note_structure_widget.dart';
import 'package:notes/structure/structure.dart';
import 'package:notes/structure/structure_type.dart';
import 'package:notes/structure/text.dart';


const double hMargin = 8;
const double vSpace = 8;
const double textPadding = 8;
const Color borderColor = Colors.grey;


abstract class FocusableElement {
  EditorActionsBar actions();
  void onFocus() {}
  void onUnfocus() {}
  void beforeAction() {}
  void afterAction() {}
}


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

  late final StructureType st = StructureType.fromFile(file.path)!;
  late final Structure struct = (
    !isRaw ? Structure.parse(init, st)
    : Structure(props: {}, headings: [], content: [StructureText(init)])
  );
  late final _bodyWidget = StructureWidget(note: this, structure: struct, st: st);

  String toText() => struct.toText(st);
  void update() => onUpdate?.call(this);


  // Whatever is currently focused
  FocusableElement? _focused;
  void focus(FocusableElement newFocused) {
    _focused?.onUnfocus();
    newFocused.onFocus();
    _focused = newFocused;
    setState(() {});
  }

  Future<void> performAction(FutureOr<dynamic> Function() doAction) async {
    // Retain focus
    _focused?.beforeAction();
    await doAction();
    _focused?.afterAction();
    update();
  }

  EditorActionsBar? actionsBar() => _focused?.actions();


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
          child: _bodyWidget,
        ),
      ),
    );

    return Column(
      children: [
        Expanded(child: noteBody),
        actionsBar()?.widget(this) ?? Container(),
      ],
    );
  }
}
