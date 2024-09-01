import 'package:flutter/material.dart';
import 'package:notes/components/global_value_key.dart';
import 'package:notes/components/icon_btn.dart';
import 'package:notes/editor/actions.dart';
import 'package:notes/editor/builtin_actions.dart';
import 'package:notes/editor/editor_box.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/editor/structure_widget.dart';
import 'package:notes/lua/lua_result.dart';
import 'package:notes/lua/lua_state.dart';
import 'package:notes/structure/structure.dart';
import 'package:notes/structure/structure_type.dart';


class StructureCode extends StructureElement {
  StructureCode(this.content, {required this.language});
  String content;
  final String language;

  @override
  dynamic toJson() => {'type': 'code', 'language': language, 'content': content};

  static (StructureCode, int)? maybeParse(List<String> lines, int line, StructureMarkup sm) {
    final match = sm.beginCodeRegexp.firstMatch(lines[line]);
    if (match == null) return null;
    final language = match.group(1)!;

    final endLine = lines.indexed.skip(line+1).where((e) => sm.endCodeRegexp.hasMatch(e.$2)).firstOrNull;
    if (endLine == null) return null;

    final contents = lines.getRange(line+1, endLine.$1).join('\n');
    return (StructureCode(contents, language: language), endLine.$1 + 1);
  }

  @override
  String markup(StructureMarkup sm) => '${sm.beginCode}$language\n$content\n${sm.endCode}';

  @override
  Widget widget(note, parent) => _CodeSectionWidget(note, this, parent);
}


class _CodeSectionWidget extends StatefulWidget {
  _CodeSectionWidget(this.note, this.element, this.parent)
  : super(key: GlobalValueKey((note, element, 'code')));
  final NoteEditor note;
  final StructureCode element;
  final StructureElementWidgetState parent;

  @override
  State<_CodeSectionWidget> createState() => CodeSectionWidgetState();
}

class CodeSectionWidgetState extends State<_CodeSectionWidget> {
  CodeSectionWidgetState();

  String get language => widget.element.language;
  String get content => widget.element.content;

  LuaResult? result;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(children: [
          Text(
            language,
            textScaler: const TextScaler.linear(1.2),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(child: Container()),
          language != 'lua' ? Container() : IconBtn(
            icon: Icons.play_arrow,
            onPressed: () => setState(() {
                result = luaExecuteFile(getGlobalLuaState(), content, widget.note.file);
            }),
          ),
          const SizedBox(width: 5),
      ]),
      EditorBoxCode(
        key: GlobalValueKey((widget.note, widget.element, 'box')),
        init: content,
        language: language,
        style: const TextStyle(
          fontFamily: 'Iosevka',
          fontFeatures: [FontFeature.fractions()],
        ),

        onChange: (newText) {
          widget.element.content = newText;
          widget.note.update();
        },
        onEnter: (box) => widget.note.focus(FocusableCode(this, box)),
      ),
      result?.widget() ?? Container(),
  ]);
}


class FocusableCode implements Focusable {
  FocusableCode(this.state, this.box);
  final CodeSectionWidgetState state;
  final EditorBoxCodeState box;

  @override bool get shouldRefresh => false;
  @override get actions => EditorActionsBar<FocusableCode>(codeActions, this);
  @override void afterAction() => box.focusNode.requestFocus();
}
