import 'package:flutter/material.dart';
import 'package:notes/editor/lua_state.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/extensions/lua_result.dart';
import 'package:notes/extensions/lua_utils.dart';
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
  Widget widget(Function() onUpdate) => _CodeSectionWidget(this, onUpdate);
}


class _CodeSectionWidget extends StatefulWidget {
  const _CodeSectionWidget(this.element, this.onUpdate);
  final StructureCode element;
  final Function() onUpdate;

  @override
  State<_CodeSectionWidget> createState() => __CodeSectionWidgetState();
}

class __CodeSectionWidgetState extends State<_CodeSectionWidget> {
  __CodeSectionWidgetState();

  String get language => widget.element.language;
  String get content => widget.element.content;

  LuaResult? result;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(language),
          language != 'lua' ? Container() : IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () => setState(() {
                result = luaExecuteCode(getGlobalLuaState(), content);
            }),
          ),
        ]
      ),
      Container(
        decoration: BoxDecoration(border: Border.all(color: borderColor)),
        child: TextField(
          controller: TextEditingController(text: content),
          onChanged: (newText) {
            widget.element.content = newText;
            widget.onUpdate();
          },

          maxLines: null,
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.all(textPadding),
          ),
        ),
      ),
      result?.widget() ?? Container(),
  ]);
}
