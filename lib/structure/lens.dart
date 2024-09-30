import 'dart:async';

import 'package:flutter/material.dart';
import 'package:notes/components/fold_button.dart';
import 'package:notes/components/global_value_key.dart';
import 'package:notes/components/icon_btn.dart';
import 'package:notes/editor/actions.dart';
import 'package:notes/editor/editor_box.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/editor/structure_widget.dart';
import 'package:notes/extensions/lenses.dart';
import 'package:notes/lua/context.dart';
import 'package:notes/lua/ui.dart';
import 'package:notes/structure/structure.dart';
import 'package:notes/structure/structure_type.dart';


class StructureLens extends StructureElement {
  StructureLens({required this.ext, required this.name, required this.text});
  final String ext;
  final String name;
  String text;

  @override
  dynamic toJson() => {'type': 'lens', 'ext': ext, 'name': name, 'content': text};

  @override
  String markup(StructureMarkup sm) => (
    '${sm.beginLens}$ext/$name\n$text\n${sm.endLens}'
  );

  @override
  Widget widget(note, parent) => _LensRootWidget(note, this, parent);

  static (StructureLens, int)? maybeParse(List<String> lines, int line, StructureMarkup sm) {
    final startMatch = sm.beginLensRegexp.firstMatch(lines[line]);
    if (startMatch == null) return null;

    final endLine = lines.indexed.skip(line+1)
    .where((tup) => sm.endLensRegexp.hasMatch(tup.$2)).firstOrNull;
    if (endLine == null) return null;

    final (ext, name) = (startMatch.group(1)!, startMatch.group(2)!);
    final content = lines.getRange(line + 1, endLine.$1).join('\n');
    final nextLine = endLine.$1 + 1;
    return (StructureLens(ext: ext, name: name, text: content), nextLine);
  }
}


// Its state is whether the widget is raw or not.
// Each time this is rebuilt, a new _LensStateWidget is created (except in raw mode obviously.)
class _LensRootWidget extends StatefulWidget {
  _LensRootWidget(this.note, this.elem, this.parent)
  : super(key: GlobalValueKey((note, elem, 'lens')));
  final NoteEditor note;
  final StructureLens elem;
  final StructureElementWidgetState parent;

  @override
  State<_LensRootWidget> createState() => _LensRootWidgetState();
}

class _LensRootWidgetState extends State<_LensRootWidget> {
  _LensRootWidgetState();

  bool isFolded = false;

  // Null when in raw mode
  late Widget? stateWidget = generateStateWidget();

  Widget generateStateWidget() {
    final lens = getLens(widget.elem.ext, widget.elem.name);
    if (lens == null) {
      return Text('Lens ${widget.elem.ext}/${widget.elem.name} does not exist');
    }

    try {
      final stateWidget = LensStateWidget.generateOrError(
        widget.note, widget.elem, lens, context
      );
      return LayoutBuilder(
        builder: (context, layout) => SizedBox(
          width: layout.maxWidth,
          child: EditorBox(fill: true, child: stateWidget),
        ),
      );
    } catch (e) {
      return EditorBox(
        child: Text(
          'Error in $toStateField method: $e',
          style: const TextStyle(color: Colors.red)
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          Text(
            '${widget.elem.ext}/${widget.elem.name}',
            textScaler: const TextScaler.linear(1.2),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          FoldButton(isFolded: isFolded, setFolded: (val) => setState(() => isFolded = val)),
          const Expanded(child: SizedBox()),
          IconBtn(icon: Icons.refresh, onPressed: () => setState(() => stateWidget = generateStateWidget())),
          Switch(value: stateWidget != null, onChanged: (val) => setState(() {
                stateWidget = stateWidget == null ? generateStateWidget() : null;
          })),
        ],
      ),
      Visibility(
        visible: !isFolded,
        maintainState: true,
        child: stateWidget ?? EditorBoxField(
          init: widget.elem.text,
          onChange: (newText) {
            widget.elem.text = newText;
            widget.note.markModified();
          },
        ),
      ),
    ],
  );
}



typedef LuaAction = FutureOr<void> Function(LuaContext lua);

// Every time this widget is created, generateState is called, creating a new state.
class LensStateWidget extends StatefulWidget {
  LensStateWidget.generateOrError(this.note, this.elem, this.lens, BuildContext context)
  : id = LuaContext.global(note.handler, context).generateLensState(lens, elem.text)
  , super(key: GlobalValueKey((note, elem, 'lens-state')));

  final NoteEditor note;
  final StructureLens elem;
  final LensExtension lens;
  final int id;

  @override
  State<LensStateWidget> createState() => LensStateWidgetState();
}

class LensStateWidgetState extends State<LensStateWidget> {
  static Future<void> buttonAction(EditorActionProps<GlobalKey> ps, int actionIdx) async {
    final state = ps.obj.currentState as LensStateWidgetState?;
    if (state == null) {
      print('Widget not active');
      return;
    }

    // state.performButtonAction(actionIdx);
  }


  Future<void> performAction(LuaContext lua, LuaUi component, LuaAction action) async {
    lua.pushUiComponent(widget.id, component);
    await action(lua);

    // Update the lens element text
    try {
      widget.elem.text = lua.generateLensText(widget.lens, widget.id);
    } catch (e) {
      print('Error generating widget text: $e');
    }
    widget.note.markModified();
    setState(() {});
  }

  void performButtonAction(LuaContext lua, int actionIdx) {
    lua.performLensButtonAction(widget.lens, actionIdx, widget.id);
    widget.elem.text = lua.generateLensText(widget.lens, widget.id);
    widget.note.markModified();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => StatefulBuilder(
    builder: (context, setState) {
      try {
        final lua = LuaContext.global(widget.note.handler, context);
        final ui = lua.generateLensUi(widget.lens, widget.id);
        return ui.innerWidget((component, action) => performAction(lua, component, action));
      } catch (e) {
        return Text(
          'Error in $toUiField method: $e',
          style: const TextStyle(color: Colors.red),
        );
      }
    },
  );
}
