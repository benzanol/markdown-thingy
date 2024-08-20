import 'package:flutter/material.dart';
import 'package:lua_dardo/lua.dart';
import 'package:notes/components/hscroll.dart';
import 'package:notes/editor/editor_box.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/extensions/lenses.dart';
import 'package:notes/lua/lua_state.dart';
import 'package:notes/lua/lua_ui.dart';
import 'package:notes/lua/utils.dart';
import 'package:notes/structure/structure.dart';


final RegExp lensStartRegexp = RegExp(r'^#\+begin_lens ([a-zA-Z0-9]+)/([a-zA-Z0-9]+)$');
final RegExp lensEndRegexp = RegExp(r'^#\+end_lens$');


class StructureLens extends StructureElement {
  StructureLens({
      required this.lens,
      required this.text,
  });

  final LensExtension lens;
  String text;

  @override
  dynamic toJson() => {'type': 'lens', 'ext': lens.ext, 'name': lens.name, 'text': text};

  @override
  String toText() => '#+begin_lens ${lens.ext}/${lens.name}\n$text\n#+end_lens';

  @override
  Widget widget(NoteEditor note) => _LensRootWidget(note, this);

  static (StructureLens, int)? maybeParse(List<String> lines, int line) {
    final startMatch = lensStartRegexp.firstMatch(lines[line]);
    if (startMatch == null) return null;

    final endLine = lines.indexed.where((tup) => lensEndRegexp.hasMatch(tup.$2)).firstOrNull;
    if (endLine == null) return null;

    final lens = getLens(startMatch.group(1)!, startMatch.group(2)!);
    if (lens == null) return null;

    final content = lines.getRange(line + 1, endLine.$1).join('\n');
    final nextLine = endLine.$1 + 1;
    return (StructureLens(lens: lens, text: content), nextLine);
  }
}


// Its state is whether the widget is raw or not.
// Each time this is rebuilt, a new _LensStateWidget is created (except in raw mode obviously.)
class _LensRootWidget extends StatefulWidget {
  const _LensRootWidget(this.note, this.elem);
  final NoteEditor note;
  final StructureLens elem;

  @override
  State<_LensRootWidget> createState() => _LensRootWidgetState();
}

class _LensRootWidgetState extends State<_LensRootWidget> {
  _LensRootWidgetState();

  bool isUi = true;

  Widget childWidget(BuildContext context) {
    if (!isUi) {
      return EditorBoxField(
        init: widget.elem.text,
        onChange: (newText) => widget.elem.text = newText,
      );
    }

    // Try generating the ui
    try {
      final lua = getGlobalLuaState();
      final stateWidget = _LensStateWidget.generateOrError(widget.note, widget.elem, lua);
      return EditorBox(child: stateWidget);
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
          Text('${widget.elem.lens.ext}/${widget.elem.lens.name}'),
          const Expanded(child: SizedBox()),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(() {})),
          Switch(value: isUi, onChanged: (val) => setState(() => isUi = val)),
        ],
      ),
      childWidget(context),
    ],
  );
}


// Every time this widget is created, generateState is called, creating a new state.
class _LensStateWidget extends StatelessWidget {
  _LensStateWidget.generateOrError(this.note, this.elem, this.lua)
  : _id = elem.lens.generateState(lua, elem.text);
  final LuaState lua;
  final NoteEditor note;
  final StructureLens elem;
  final int _id;

  void performChange(LuaUi component) {
    lua.setTop(0);

    // Load the lua ui component into the stack
    luaPushTableEntry(lua, lensesVariable, ['$_id', lensesUiField]);
    for (final index in component.path) {
      lua.pushInteger(index + 1); // Lua is one indexed
      lua.getTable(-2);
      // Remove the old table
      lua.insert(-2);
      lua.pop(1);
    }

    // Call the component specific change code
    component.performChange(lua);

    // Update the lens element text
    try {
      elem.text = elem.lens.generateText(lua, _id);
    } catch (e) {
      print('Error generating widget text: $e');
    }
  }

  @override
  Widget build(BuildContext context) => StatefulBuilder(
    builder: (context, setState) {
      try {
        final ui = elem.lens.generateUi(lua, _id);
        return Hscroll(
          child: ui.widget((component) {
              setState(() => performChange(component));
              note.update();
          }),
        );
      } catch (e) {
        return Text(
          'Error in $toUiField method: $e',
          style: const TextStyle(color: Colors.red),
        );
      }
    },
  );
}
