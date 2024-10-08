import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:notes/components/foreground_svg.dart';
import 'package:notes/components/with_color.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/structure/structure.dart';


abstract class Focusable {
  List<EditorActionsBar> get actions;
  bool get shouldRefresh;
  void afterAction();
}


class EditorActionProps<Param> {
  EditorActionProps({required this.obj, required this.context});
  final Param obj;
  final BuildContext context;

  bool unfocus = false;
  Focusable? newFocus;
  StructureElement? newFocusedElement;
  StructureHeading? newFocusedHeading;

  EditorActionProps<T> withObj<T>(T newObj) => EditorActionProps(
    obj: newObj,
    context: context,
  );
}

typedef EditorActionFunc<Param> = FutureOr<void> Function(EditorActionProps<Param>);
class EditorAction<Param> {
  const EditorAction({required this.widget, required this.onPress});
  final EditorActionFunc<Param> onPress;
  final Widget widget;

  static const double size = 40;
  Widget buttonWidget(NoteEditor note, BuildContext context, Param param) => MaterialButton(
    padding: EdgeInsets.zero,
    minWidth: 0,
    onPressed: () => note.performAction<Param>(this, param),
    child: WithColor(
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        width: size,
        height: size,
        child: widget,
      ),
    ),
  );
}

class EditorActionsBar<Param> {
  EditorActionsBar(this.actions, this.param);
  final List<EditorAction<Param>> actions;
  final Param param;

  static ifNonNull<T>(List<EditorAction<T>> actions, T? param) {
    if (param == null) return null;
    return EditorActionsBar(actions, param);
  }
}


EditorAction<T> svgAction<T>(File svg, EditorActionFunc<T> onPress) => EditorAction(
  widget: ForegroundSvg(file: svg),
  onPress: onPress,
);

EditorAction<T> iconAction<T>(IconData icon, EditorActionFunc<T> onPress) => EditorAction(
  widget: FittedBox(child: Icon(icon)),
  onPress: onPress,
);

EditorAction<T> textAction<T>(String text, EditorActionFunc<T> onPress) => EditorAction(
  widget: FittedBox(child: Text(text)),
  onPress: onPress,
);
