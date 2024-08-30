import 'dart:math';

import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
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

  iconAction(MdiIcons.tableRowPlusBefore, (ps) {
      ps.obj.rows.insert(ps.obj.row, List.generate(ps.obj.rows[0].length, (_) => ""));
  }),
  iconAction(MdiIcons.tableRowPlusAfter, (ps) {
      ps.obj.rows.insert(ps.obj.row + 1, List.generate(ps.obj.rows[0].length, (_) => ""));
      ps.obj.row++;
  }),
  iconAction(MdiIcons.tableRowRemove, (ps) {
      if (ps.obj.rows.length == 1) return;
      ps.obj.rows.removeAt(ps.obj.row);
      if (ps.obj.row >= ps.obj.rows.length) ps.obj.row--;
  }),

  iconAction(MdiIcons.tableColumnPlusBefore, (ps) {
      for (final row in ps.obj.rows) {
        row.insert(ps.obj.col, "");
      }
  }),
  iconAction(MdiIcons.tableColumnPlusAfter, (ps) {
      for (final row in ps.obj.rows) {
        row.insert(ps.obj.col+1, "");
      }
      ps.obj.col++;
  }),
  iconAction(MdiIcons.tableColumnRemove, (ps) {
      if (ps.obj.rows[0].length == 1) return;
      for (final row in ps.obj.rows) {
        row.removeAt(ps.obj.col);
      }
      if (ps.obj.col >= ps.obj.rows[0].length) ps.obj.col--;
  }),
];


final List<EditorAction<Function(StructureElement)>> elementBuilders = [
  iconAction(Icons.code, (ps) => ps.obj(StructureCode('', language: 'lua'))),
  iconAction(Icons.description, (ps) => ps.obj(StructureText(''))),
  iconAction(MdiIcons.table, (ps) => ps.obj(StructureTable([['', ''], ['', '']]))),
];


StructureHeading createHeading() => StructureHeading(
  title: 'Untitled Heading',
  body: Structure.empty(),
);

final List<EditorAction<StructureHeadingWidgetState>> headingActions = [
  iconAction(Icons.delete, (ps) async {
      if (await promptConfirmation(ps.context, 'Delete ${ps.obj.title}?')) {
        final headings = ps.obj.parent.headings;
        headings.removeAt(ps.obj.index);
        // Select the next heading
        if (headings.isNotEmpty) {
          ps.newFocusedHeading = headings[min(headings.length-1, ps.obj.index)];
        }
      }
  }),
  iconAction(Icons.edit, (ps) async {
      final newName = await promptString(ps.context, 'Rename ${ps.obj.title} to:');
      if (newName != null) {
        ps.obj.parent.headings[ps.obj.index].title = newName;
      }
  }),
  iconAction(Icons.title, (ps) {
      final heading = createHeading();
      ps.obj.parent.headings.insert(ps.obj.index + 1, heading);
      ps.newFocusedHeading = heading;
  }),
  iconAction(
    Icons.format_indent_increase,
    (ps) => ps.obj.struct.headings.insert(0, createHeading()),
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
        if (content.isEmpty) {
          // Go to the heading (if it exists)
          ps.newFocusedHeading = ps.obj.widget.parent.parent?.heading;
        } else {
          // Go to the previous element
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
