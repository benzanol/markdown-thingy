import 'dart:math';

import 'package:flutter/material.dart';
import 'package:notes/components/hscroll.dart';
import 'package:notes/structure/structure.dart';


class StructureTable extends StructureElement {
  StructureTable(this._table);
  final List<List<String>> _table;

  static (StructureTable, int)? maybeParse(List<String> lines, int line) {
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
  String toText() => _table.map((line) => '| ${line.join(" | ")} |').join('\n');

  @override
  Widget widget(Function() onUpdate) => _TableWidget(this, onUpdate);
}


class _TableWidget extends StatelessWidget {
  const _TableWidget(this.element, this.onUpdate);
  final StructureTable element;
  final Function() onUpdate;

  @override
  Widget build(BuildContext context) => Hscroll(child: Table(
      border: TableBorder.all(),
      defaultColumnWidth: const IntrinsicColumnWidth(),
      children: element._table.indexed.map((row) => TableRow(
          children: row.$2.indexed.map((cell) => TableCell(
              child: TextField(
                controller: TextEditingController(text: cell.$2),
                onChanged: (content) {
                  element._table[row.$1][cell.$1] = content;
                  onUpdate();
                },
                maxLines: null,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.all(8),
                  border: InputBorder.none,
                ),
              )
          )).toList(),
      )).toList(),
  ));
}
