import 'package:flutter/material.dart';
import 'package:notes/editor/editor_box.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/lua/lua_result.dart';
import 'package:notes/lua/lua_state.dart';
import 'package:notes/structure/structure.dart';
import 'package:notes/structure/structure_type.dart';


class StructureCode extends StructureElement {
  StructureCode(this.content, {required this.language});
  String content;
  final String language;

  @override
  dynamic toJson() => {'type': 'code', 'content': content, 'language': language};

  static (StructureCode, int)? maybeParse(List<String> lines, int line, StructureType st) {
    final match = st.beginCodeRegexp.firstMatch(lines[line]);
    if (match == null) return null;
    final language = match.group(1)!;

    final endLine = lines.indexed.skip(line+1).where((e) => st.endCodeRegexp.hasMatch(e.$2)).firstOrNull;
    if (endLine == null) return null;

    final contents = lines.getRange(line+1, endLine.$1).join('\n');
    return (StructureCode(contents, language: language), endLine.$1 + 1);
  }

  @override
  String toText(StructureType st) => '${st.beginCode}$language\n$content\n${st.endCode}';

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
        language: language,
        onChange: (newText) {
          widget.element.content = newText;
          widget.note.update();
        },
        style: const TextStyle(
          fontFamily: 'Iosevka',
          fontFeatures: [FontFeature.fractions()],
        ),
      ),
      result?.widget() ?? Container(),
  ]);
}
