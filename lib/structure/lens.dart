import 'package:flutter/material.dart';
import 'package:notes/components/hscroll.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/extensions/lenses.dart';
import 'package:notes/extensions/lua.dart';
import 'package:notes/extensions/lua_ui.dart';
import 'package:notes/structure/structure.dart';


final RegExp lensStartRegexp = RegExp(r'^#\+begin_lens ([a-zA-Z0-9]+)/([a-zA-Z0-9]+)$');
final RegExp lensEndRegexp = RegExp(r'^#\+end_lens$');


abstract class StructureLens extends StructureElement {
  StructureLens({required this.lens, required this.init});
  final LensExtension lens;
  final String init;

  String formatContent(String content) => (
    '#+begin_lens ${lens.dir}/${lens.name}\n$content\n#+end_lens'
  );

  static (StructureLens, int)? maybeParse(List<String> lines, int line) {
    final startMatch = lensStartRegexp.firstMatch(lines[line]);
    if (startMatch == null) return null;

    final endLine = lines.indexed.where((tup) => lensEndRegexp.hasMatch(tup.$2)).firstOrNull;
    if (endLine == null) return null;

    final lens = getLens(startMatch.group(1)!, startMatch.group(2)!);
    if (lens == null) return null;

    final content = lines.getRange(line + 1, endLine.$1).join('\n');
    final nextLine = endLine.$1 + 1;
    try {
      return (StructureSuccessfulLens.generate(lens: lens, init: content), nextLine);
    } catch (e) {
      return (StructureFailedLens(lens: lens, init: content, error: '$e'), nextLine);
    }
  }


  Widget childWidget(Function() onUpdate);
  @override
  Widget widget(Function() onUpdate) => Container(
    decoration: BoxDecoration(border: Border.all(color: borderColor)),
    padding: const EdgeInsets.all(textPadding),
    alignment: Alignment.topLeft,
    child: childWidget(onUpdate),
  );
}


class StructureFailedLens extends StructureLens {
  StructureFailedLens({required super.lens, required super.init, required this.error});
  final String error;

  @override
  String toText() => formatContent(init);

  @override
  Widget childWidget(Function() onUpdate) => (
    Text(error, style: const TextStyle(color: Colors.red))
  );
}


class StructureSuccessfulLens extends StructureLens {
  StructureSuccessfulLens.generate({required super.lens, required super.init})
  : _instanceId = lens.generateState(init);
  final int _instanceId;

  @override
  String toText() {
    try {
      return formatContent(lens.generateText(_instanceId));
    } catch (e) {
      return formatContent(init);
    }
  }

  @override
  Widget childWidget(Function() onUpdate) => _SuccessfulLensWidget(this, onUpdate);
}

class _SuccessfulLensWidget extends StatefulWidget {
  const _SuccessfulLensWidget(this.lensElem, this.onUpdate);
  final StructureSuccessfulLens lensElem;
  final Function() onUpdate;

  @override
  State<_SuccessfulLensWidget> createState() => __SuccessfulLensWidgetState();
}

class __SuccessfulLensWidgetState extends State<_SuccessfulLensWidget> {
  __SuccessfulLensWidgetState();

  void performChange(LuaUi component) {
    luaState.setTop(0);

    // Load the lua ui component into the stack
    luaLoadTableEntry(instancesVariable, [widget.lensElem._instanceId.toString(), instanceUiField]);
    for (final index in component.path) {
      luaState.pushInteger(index + 1); // Lua is one indexed
      luaState.getTable(-2);
      // Remove the old table
      luaState.insert(-2);
      luaState.pop(1);
    }

    // Call the component specific change code
    component.performChange(luaState);

    // Redisplay
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    try {
      return Hscroll(
        child: widget.lensElem.lens.generateUi(widget.lensElem._instanceId).widget((component) {
            performChange(component);
            widget.onUpdate();
        }),
      );
    } catch (e) {
      return Text('$e', style: const TextStyle(color: Colors.red));
    }
  }
}
