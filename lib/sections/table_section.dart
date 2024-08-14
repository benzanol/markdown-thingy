import 'dart:math';

import 'package:flutter/material.dart';
import 'package:notes/editor/note_editor.dart';


List<List<String>> _parseTable(List<String> lines) {
  final rows = <List<String>>[];

  for (final line in lines) {
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

  return rows;
}

class TableSection extends NoteSection {
  TableSection(this.table);
  List<List<String>> table;

  static (TableSection, int)? maybeParse(List<String> lines, int line) {
    int nextLine = line;
    while (nextLine < lines.length && lines[nextLine].startsWith('|')) {
      nextLine++;
    }
    if (nextLine == line) return null;
    return (TableSection(_parseTable(lines.sublist(line, nextLine))), nextLine);
  }


  @override
  String getText() => table.map((line) => '| ${line.join(" | ")} |').join('\n');

  @override
  Widget widget(BuildContext context) {
    final tableWidget = Table(
      border: TableBorder.all(),
      defaultColumnWidth: const IntrinsicColumnWidth(),
      children: table.indexed.map((row) => TableRow(
          children: row.$2.indexed.map((cell) => TableCell(
              child: TextField(
                controller: TextEditingController(text: cell.$2),
                onChanged: (content) {
                  table[row.$1][cell.$1] = content;
                  onUpdate?.call();
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
    );

    final scrollController = ScrollController();
    const double scrollThickness = 5;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: hPadding),
      child: Scrollbar(
        thickness: scrollThickness,
        thumbVisibility: true,
        controller: scrollController,
        child: SingleChildScrollView(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: vPadding),
            child: tableWidget
          ),
        ),
      ),
    );
  }
}
