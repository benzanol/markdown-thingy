import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:notes/components/foreground_svg.dart';
import 'package:notes/components/with_color.dart';
import 'package:notes/editor/note_editor.dart';


typedef EditorActionFunc<Param> = FutureOr<dynamic> Function(BuildContext, Param);
class EditorAction<Param> {
  const EditorAction({required this.widget, required this.onPress});
  final EditorActionFunc<Param> onPress;
  final Widget widget;
}

class EditorActionsBar<Param> {
  EditorActionsBar(this.actions, this.param);
  final List<EditorAction<Param>> actions;
  final Param param;

  static ifNonNull<T>(List<EditorAction<T>> actions, T? param) {
    if (param == null) return null;
    return EditorActionsBar(actions, param);
  }

  static const double size = 40;
  Widget widget(NoteEditor note) => Builder(
    builder: (context) => Container(
      color: Theme.of(context).colorScheme.secondary,
      child: Row(
        children: actions.map((action) => MaterialButton(
            padding: EdgeInsets.zero,
            minWidth: 0,
            onPressed: () => note.performAction(() => action.onPress(context, param)),
            child: WithColor(
              color: Theme.of(context).colorScheme.surface,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                width: size,
                height: size,
                child: action.widget
              ),
            ),
        )).toList(),
      ),
    ),
  );
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
