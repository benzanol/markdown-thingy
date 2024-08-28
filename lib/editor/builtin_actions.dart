import 'dart:math';

import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';
import 'package:notes/components/prompts.dart';
import 'package:notes/editor/actions.dart';
import 'package:notes/editor/note_structure_widget.dart';
import 'package:notes/structure/structure.dart';


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

final List<EditorAction<TextEditingController>> textActions = [
  iconAction(Icons.format_italic,    (context, c) => _surroundSelection(c, '*', '*')),
  iconAction(Icons.format_bold,      (context, c) => _surroundSelection(c, '**', '**')),
  iconAction(Icons.format_underline, (context, c) => _surroundSelection(c, '__', '__')),
];

final List<EditorAction<CodeController>> codeActions = [
  iconAction(Icons.circle_outlined, (context, c) => _surroundSelection(c, '(', ')')),
  iconAction(Icons.data_array,      (context, c) => _surroundSelection(c, '[', ']')),
  iconAction(Icons.data_object,     (context, c) => _surroundSelection(c, '{', '}')),
  iconAction(Icons.code,            (context, c) => _surroundSelection(c, '<', '>')),
];


(String, Structure) newHeading() => ('${Random().nextInt(10000)}', Structure.empty());

final List<EditorAction<StructureHeadingWidgetState>> headingActions = [
  iconAction(Icons.delete, (context, head) async {
      if (await promptConfirmation(context, 'Delete ${head.title}?')) {
        head.struct.headings.removeAt(head.index);
      }
  }),
  iconAction(Icons.edit, (context, head) async {
      final newName = await promptString(context, 'Rename ${head.title} to:');
      if (newName != null) {
        head.parent.headings[head.index] = (newName, head.struct);
      }
  }),
  iconAction(Icons.title, (context, e) {
      e.struct.headings.insert(e.index + 1, newHeading());
  }),
  iconAction(
    Icons.format_indent_increase,
    (context, head) {
      head.struct.headings.insert(0, newHeading());
    },
  ),
];
