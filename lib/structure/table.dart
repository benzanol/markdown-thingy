import 'dart:math';

import 'package:flutter/material.dart';
import 'package:notes/components/global_value_key.dart';
import 'package:notes/components/hscroll.dart';
import 'package:notes/editor/actions.dart';
import 'package:notes/editor/builtin_actions.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/editor/structure_widget.dart';
import 'package:notes/structure/structure.dart';
import 'package:notes/structure/structure_type.dart';


class StructureTable extends StructureElement {
  StructureTable(this._table);
  final List<List<String>> _table;

  @override
  dynamic toJson() => {'type': 'table', 'rows': _table};

  static (StructureTable, int)? maybeParse(List<String> lines, int line, StructureMarkup sm) {
    int nextLine = line;
    while (nextLine < lines.length && lines[nextLine].startsWith('|')) {
      nextLine++;
    }
    if (nextLine == line) return null;

    final rows = <List<String>>[];
    for (final line in lines.getRange(line, nextLine)) {
      if (!line.contains('|')) continue; // Skip lines without '|'
      final cells = line.split('|').map((cell) => cell.trim()).toList();
      rows.add(cells.sublist(1, cells.length - 1)); // Remove empty first and last items
    }

    final width = rows.map((r) => r.length).reduce(max);
    for (final row in rows) {
      if (row.length < width) {
        row.addAll(List.generate(width - row.length, (_) => ''));
      }
    }

    return (StructureTable(rows), nextLine);
  }

  @override
  String markup(StructureMarkup sm) => _table.map((line) => '| ${line.join(" | ")} |').join('\n');

  @override
  Widget widget(note, parent) => _TableWidget(note, this, parent);
}


class _TableWidget extends StatefulWidget {
  _TableWidget(this.note, this.element, this.parent)
  : super(key: GlobalValueKey((note, element, 'table')));
  final NoteEditor note;
  final StructureTable element;
  final StructureElementWidgetState parent;

  @override
  State<_TableWidget> createState() => TableWidgetState();
}

class TableWidgetState extends State<_TableWidget> {
  void focusCell(int row, int col) => setState(() {
      fields = _createTableWidget();
      fields[row][col].focusNode?.requestFocus();
  });

  late List<List<TextField>> fields = _createTableWidget();
  List<List<TextField>> _createTableWidget() => (
    widget.element._table.indexed.map((row) => (
        row.$2.indexed.map((cell) => TextField(
            controller: TextEditingController(text: cell.$2),
            focusNode: FocusNode(),
            onChanged: (content) {
              widget.element._table[row.$1][cell.$1] = content;
              widget.note.markModified();
            },
            maxLines: null,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.all(8),
              border: InputBorder.none,
            ),

            onTap: () => widget.note.focus(
              FocusableTable(state: this, row: row.$1, col: cell.$1)
            ),
        )).toList()
    )).toList()
  );

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: Container(
      color: Theme.of(context).colorScheme.surface,
      child: Hscroll(child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(),
          children: fields.map((fields) => TableRow(
              children: fields.map((field) => TableCell(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 70),
                    child: field,
                  ),
              )).toList(),
          )).toList(),
      )),
    ),
  );
}


class FocusableTable extends Focusable {
  FocusableTable({required this.state, required this.row, required this.col});
  TableWidgetState state;
  int row;
  int col;
  get rows => state.widget.element._table;

  @override bool get shouldRefresh => true;
  @override get actions => [EditorActionsBar<FocusableTable>(tableActions, this)];
  @override void afterAction() => state.focusCell(row, col);
}
