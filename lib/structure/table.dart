import 'dart:math';

import 'package:flutter/material.dart';
import 'package:notes/components/hscroll.dart';
import 'package:notes/editor/actions.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/structure/structure.dart';
import 'package:notes/structure/structure_type.dart';


class StructureTable extends StructureElement {
  StructureTable(this._table);
  final List<List<String>> _table;

  @override
  dynamic toJson() => {'type': 'table', 'rows': _table};

  static (StructureTable, int)? maybeParse(List<String> lines, int line, StructureType st) {
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
  String toText(StructureType st) => _table.map((line) => '| ${line.join(" | ")} |').join('\n');

  @override
  Widget widget(NoteEditor note) => _TableWidget(note, this);
}


class _TableWidget extends StatefulWidget {
  const _TableWidget(this.note, this.element);
  final NoteEditor note;
  final StructureTable element;

  @override
  State<_TableWidget> createState() => _TableWidgetState();
}

class _TableWidgetState extends State<_TableWidget> {
  (int, int)? cursor;

  @override
  Widget build(BuildContext context) => Container(
    color: Theme.of(context).colorScheme.surface,
    child: Hscroll(child: Table(
        border: TableBorder.all(),
        defaultColumnWidth: const IntrinsicColumnWidth(),
        children: widget.element._table.indexed.map((row) => TableRow(
            children: row.$2.indexed.map((cell) => TableCell(
                child: TextField(
                  controller: TextEditingController(text: cell.$2),
                  onChanged: (content) {
                    widget.element._table[row.$1][cell.$1] = content;
                    widget.note.update();
                  },
                  maxLines: null,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.all(8),
                    border: InputBorder.none,
                  ),

                  onTap: () => widget.note.focus(FocusableTable(
                      rows: widget.element._table,
                      row: row.$1,
                      col: cell.$1,
                      afterActionFn: (row, col) => setState(() => cursor = (row, col)),
                  )),
                  autofocus: (row.$1, cell.$1) == cursor,
                ),
            )).toList(),
        )).toList(),
    )),
  );
}


class FocusableTable extends FocusableElement {
  FocusableTable({
      required this.rows,
      required this.row,
      required this.col,
      required this.afterActionFn,
  });
  final void Function(int row, int col) afterActionFn;
  List<List<String>> rows;
  int row;
  int col;

  @override
  void afterAction() => afterActionFn(row, col);

  @override
  EditorActionsBar actions() => (
    EditorActionsBar<FocusableTable>(_tableActions, this)
  );
}


final List<EditorAction<FocusableTable>> _tableActions = [
  iconAction(Icons.dns, (context, table) {
      table.rows.insert(table.row + 1, List.generate(table.rows[0].length, (_) => ""));
      table.row++;
  }),
  iconAction(Icons.delete, (context, table) {
      table.rows.removeAt(table.row);
      if (table.row >= table.rows.length) table.row--;
  }),
];
