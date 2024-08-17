import 'package:flutter/material.dart';


abstract class StructureElement {
  Widget widget(Function() onUpdate);
  String toText();
}

class NoteStructure {
  NoteStructure({required this.props, required this.content, required this.headings});
  Map<String, String> props;
  List<StructureElement> content;
  List<(String, NoteStructure)> headings;

  NoteStructure? getHeading(String name) => headings.where((tup) => tup.$1 == name).firstOrNull?.$2;

  String toText() {
    final buf = StringBuffer();
    _write(buf);
    return buf.toString();
  }

  void _write(StringBuffer buf, {int level = 0}) {
    // Write the props
    if (props.isNotEmpty) {
      buf.writeln('---');
      for (final entry in props.entries) {
        buf.write(entry.key);
        buf.write(': ');
        buf.writeln(entry.value);
      }
      buf.writeln('---');
    }

    // Write the content
    for (final elem in content) {
      buf.writeln(elem.toText());
    }

    // Write the headings
    for (final (name, body) in headings) {
      buf.write('#' * (level+1));
      buf.write(' ');
      buf.writeln(name);
      body._write(buf, level: level + 1);
    }
  }
}
