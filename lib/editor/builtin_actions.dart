import 'dart:math';

import 'package:flutter/material.dart';
import 'package:notes/components/prompts.dart';
import 'package:notes/editor/actions.dart';
import 'package:notes/editor/structure_widget.dart';
import 'package:notes/structure/code.dart';
import 'package:notes/structure/structure.dart';
import 'package:notes/structure/table.dart';
import 'package:notes/structure/text.dart';


void _surroundSelection(
  TextEditingController controller,
  String startTag,
  String endTag
) {
  final selection = controller.selection;
  final text = controller.text;
  final start = selection.start;
  final end = selection.end;

  final before = text.substring(0, start);
  final selectedText = text.substring(start, end);
  final after = text.substring(end);

  final newText = '$before$startTag$selectedText$endTag$after';
  controller.text = newText;
  controller.selection = TextSelection.collapsed(offset: end + startTag.length);
}

final List<EditorAction<FocusableText>> textActions = [
  textAction('ESC', (ps) => ps.newFocus = ps.obj.widget.parent),
  iconAction(Icons.format_italic,    (ps) => _surroundSelection(ps.obj.box.controller, '*', '*')),
  iconAction(Icons.format_bold,      (ps) => _surroundSelection(ps.obj.box.controller, '**', '**')),
  iconAction(Icons.format_underline, (ps) => _surroundSelection(ps.obj.box.controller, '__', '__')),
];

final List<EditorAction<FocusableCode>> codeActions = [
  textAction('ESC', (ps) => ps.newFocus = ps.obj.state.widget.parent),
  iconAction(Icons.circle_outlined, (ps) => _surroundSelection(ps.obj.box.controller, '(', ')')),
  iconAction(Icons.data_array,      (ps) => _surroundSelection(ps.obj.box.controller, '[', ']')),
  iconAction(Icons.data_object,     (ps) => _surroundSelection(ps.obj.box.controller, '{', '}')),
  iconAction(Icons.code,            (ps) => _surroundSelection(ps.obj.box.controller, '<', '>')),
];

final List<EditorAction<FocusableTable>> tableActions = [
  textAction('ESC', (ps) => ps.newFocus = ps.obj.state.widget.parent),
  iconAction(Icons.dns, (ps) {
      ps.obj.rows.insert(ps.obj.row + 1, List.generate(ps.obj.rows[0].length, (_) => ""));
      ps.obj.row++;
  }),
  iconAction(Icons.delete, (ps) {
      ps.obj.rows.removeAt(ps.obj.row);
      if (ps.obj.row >= ps.obj.rows.length) ps.obj.row--;
  }),
];


final List<EditorAction<Function(StructureElement)>> elementBuilders = [
  iconAction(Icons.code, (ps) => ps.obj(StructureCode('', language: 'lua'))),
  iconAction(Icons.description, (ps) => ps.obj(StructureText(''))),
  iconAction(Icons.calendar_month, (ps) => ps.obj(StructureTable([['', ''], ['', '']]))),
];


StructureHeading newHeading() => StructureHeading(
  title: '${Random().nextInt(10000)}',
  body: Structure.empty(),
);

final List<EditorAction<StructureHeadingWidgetState>> headingActions = [
  iconAction(Icons.delete, (ps) async {
      if (await promptConfirmation(ps.context, 'Delete ${ps.obj.title}?')) {
        ps.obj.parent.headings.removeAt(ps.obj.index);
      }
  }),
  iconAction(Icons.edit, (ps) async {
      final newName = await promptString(ps.context, 'Rename ${ps.obj.title} to:');
      if (newName != null) {
        ps.obj.parent.headings[ps.obj.index].title = newName;
      }
  }),
  iconAction(Icons.title, (ps) {
      ps.obj.parent.headings.insert(ps.obj.index + 1, newHeading());
  }),
  iconAction(
    Icons.format_indent_increase,
    (ps) => ps.obj.struct.headings.insert(0, newHeading()),
  ),
  ...elementBuilders.map((action) => EditorAction(
      widget: action.widget,
      onPress: (ps) => action.onPress(ps.withObj((newElem) {
            ps.obj.struct.content.insert(0, newElem);
            ps.newFocusedElement = newElem;
      })),
  )),
];

final List<EditorAction<StructureElementWidgetState>> elementActions = [
  iconAction(Icons.delete, (ps) async {
      if (await promptConfirmation(ps.context, 'Delete element?')) {
        final content = ps.obj.parent.content;
        content.removeAt(ps.obj.index);
        if (content.isNotEmpty) {
          ps.newFocusedElement = content[min(content.length-1, ps.obj.index)];
        }
      }
  }),
  ...elementBuilders.map((action) => EditorAction(
      widget: action.widget,
      onPress: (ps) => action.onPress(ps.withObj((newElem) {
            ps.obj.parent.content.insert(ps.obj.index+1, newElem);
            ps.newFocusedElement = newElem;
      })),
  )),
];
