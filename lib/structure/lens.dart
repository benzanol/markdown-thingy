import 'package:flutter/material.dart';
import 'package:lua_dardo/lua.dart';
import 'package:notes/components/hscroll.dart';
import 'package:notes/editor/lua_state.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/extensions/lenses.dart';
import 'package:notes/extensions/lua_utils.dart';
import 'package:notes/lua/lua_ui.dart';
import 'package:notes/structure/structure.dart';


final RegExp lensStartRegexp = RegExp(r'^#\+begin_lens ([a-zA-Z0-9]+)/([a-zA-Z0-9]+)$');
final RegExp lensEndRegexp = RegExp(r'^#\+end_lens$');


abstract class StructureLens extends StructureElement {
  StructureLens({required this.lens, required this.text});
  final LensExtension lens;
  final String text;

  @override
  dynamic toJson() => {'type': 'lens', 'dir': lens.ext, 'name': lens.name, 'text': text};

  String formatContent(String content) => (
    '#+begin_lens ${lens.ext}/${lens.name}\n$content\n#+end_lens'
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
      return (StructureSuccessfulLens.generate(
          lua: getGlobalLuaState(),
          lens: lens,
          text: content,
      ), nextLine);
    } catch (e) {
      return (StructureFailedLens(lens: lens, text: content, error: '$e'), nextLine);
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
  StructureFailedLens({required super.lens, required super.text, required this.error});
  final String error;

  @override
  String toText() => formatContent(text);

  @override
  Widget childWidget(Function() onUpdate) => (
    Text(error, style: const TextStyle(color: Colors.red))
  );
}


class StructureSuccessfulLens extends StructureLens {
  StructureSuccessfulLens.generate({required super.lens, required super.text, required LuaState lua})
  : _lua = lua, _instanceId = lens.generateState(lua, text);

  final LuaState _lua;
  final int _instanceId;

  @override
  String toText() {
    try {
      return formatContent(lens.generateText(_lua, _instanceId));
    } catch (e) {
      return formatContent(text);
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

  LuaState get _lua => widget.lensElem._lua;

  void performChange(LuaUi component) {
    _lua.setTop(0);

    // Load the lua ui component into the stack
    final instanceId = widget.lensElem._instanceId.toString();
    luaPushTableEntry(_lua, lensesVariable, [instanceId, lensesUiField]);
    for (final index in component.path) {
      _lua.pushInteger(index + 1); // Lua is one indexed
      _lua.getTable(-2);
      // Remove the old table
      _lua.insert(-2);
      _lua.pop(1);
    }

    // Call the component specific change code
    component.performChange(_lua);

    // Redisplay
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    try {
      return Hscroll(
        child: widget.lensElem.lens.generateUi(_lua, widget.lensElem._instanceId).widget((component) {
            performChange(component);
            widget.onUpdate();
        }),
      );
    } catch (e) {
      return Text('$e', style: const TextStyle(color: Colors.red));
    }
  }
}
