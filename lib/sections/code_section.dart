import 'package:flutter/material.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/extensions/lua.dart';
import 'package:notes/extensions/lua_result.dart';


class CodeSection extends NoteSection {
  CodeSection(String init, {required this.language})
  : _controller = TextEditingController(text: init);

  final String language;
  final TextEditingController _controller;

  static (NoteSection, int)? maybeParse(List<String> lines, int line) {
    if (!lines[line].startsWith('```')) return null;
    final language = lines[line].substring(3);

    final endLine = lines.skip(line+1).indexed.where((e) => e.$2 == '```').firstOrNull;
    if (endLine == null) return null;

    final endLineNum = endLine.$1 + (line+1);
    final contents = lines.getRange(line+1, endLineNum).join('\n');
    return (CodeSection(contents, language: language), endLineNum + 1);
  }

  @override
  String getText() => '```$language\n${_controller.text}\n```';

  @override
  Widget widget(BuildContext context) => _CodeSectionWidget(this);
}


class _CodeSectionWidget extends StatefulWidget {
  const _CodeSectionWidget(this.section);
  final CodeSection section;

  @override
  State<_CodeSectionWidget> createState() => __CodeSectionWidgetState();
}

class __CodeSectionWidgetState extends State<_CodeSectionWidget> {
  __CodeSectionWidgetState();

  String get language => widget.section.language;
  TextEditingController get controller => widget.section._controller;

  LuaResult? result;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(widget.section.language),
          language != 'lua' ? Container() : IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () => setState(() => result = executeLua(controller.text)),
          ),
        ]
      ),
      Container(
        decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
        child: TextField(
          controller: controller,
          onChanged: (_) => widget.section.onUpdate?.call(),

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
