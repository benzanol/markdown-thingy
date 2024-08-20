import 'package:flutter/material.dart';
import 'package:notes/editor/editor_box.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/lua/lua_result.dart';
import 'package:notes/lua/lua_state.dart';
import 'package:notes/structure/structure.dart';


class StructureCode extends StructureElement {
  StructureCode(this.content, {required this.language});
  String content;
  final String language;

  @override
  dynamic toJson() => {'type': 'code', 'content': content, 'language': language};

  static (StructureCode, int)? maybeParse(List<String> lines, int line) {
    if (!lines[line].startsWith('```')) return null;
    final language = lines[line].substring(3);

    final endLine = lines.skip(line+1).indexed.where((e) => e.$2 == '```').firstOrNull;
    if (endLine == null) return null;

    final endLineNum = endLine.$1 + (line+1);
    final contents = lines.getRange(line+1, endLineNum).join('\n');
    return (StructureCode(contents, language: language), endLineNum + 1);
  }

  @override
  String toText() => '```$language\n$content\n```';

  @override
  Widget widget(NoteEditor note) => _CodeSectionWidget(note, this);
}


class _CodeSectionWidget extends StatefulWidget {
  const _CodeSectionWidget(this.note, this.element);
  final NoteEditor note;
  final StructureCode element;

  @override
  State<_CodeSectionWidget> createState() => _CodeSectionWidgetState();
}

class _CodeSectionWidgetState extends State<_CodeSectionWidget> {
  _CodeSectionWidgetState();

  String get language => widget.element.language;
  String get content => widget.element.content;

  LuaResult? result;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            language,
            textScaler: const TextScaler.linear(1.2),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          language != 'lua' ? Container() : IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () => setState(() {
                result = luaExecuteFile(getGlobalLuaState(), content, widget.note.file);
            }),
          ),
        ]
      ),
      EditorBoxField(
        init: content,
        onChange: (newText) {
          widget.element.content = newText;
          widget.note.update();
        },
        style: const TextStyle(fontFamily: 'Iosevka'),
      ),
      result?.widget() ?? Container(),
  ]);
}
