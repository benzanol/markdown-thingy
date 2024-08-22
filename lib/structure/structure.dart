import 'package:flutter/material.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/extensions/lenses.dart';
import 'package:notes/lua/lua_object.dart';
import 'package:notes/lua/to_lua.dart';
import 'package:notes/structure/code.dart';
import 'package:notes/structure/lens.dart';
import 'package:notes/structure/table.dart';
import 'package:notes/structure/text.dart';


abstract class StructureElement implements ToJson {
  Widget widget(NoteEditor note);
  String toText();
}

class Structure implements ToJson {
  Structure({required this.props, required this.content, required this.headings});
  Map<String, String> props;
  List<StructureElement> content;
  List<(String, Structure)> headings;

  @override
  Map<String, dynamic> toJson() => {
    'props': props,
    'content': content,
    'headings': headings.map((h) => {'title': h.$1, ...h.$2.toJson()}).toList()
  };

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


  List<T> getElements<T extends StructureElement>() => [
    ...content.whereType<T>(),
    ...headings.expand((h) => h.$2.getElements<T>()),
  ];

  String getLuaCode() => (
    getElements<StructureCode>()
    .where((c) => c.language == 'lua')
    .map((c) => c.content)
    .join('\n\n')
  );

  Structure? getHeading(String name, {bool noCase = false}) => (
    headings.where((heading) => (
        (noCase ? heading.$1.toLowerCase() : heading.$1)
        == (noCase ? name.toLowerCase() : name)
    )).firstOrNull?.$2
  );


  static Structure parse(String string) => _parseStructure(string.split('\n'));

  static Structure fromLua(LuaObject obj) {
    final table = obj as LuaTable;
    return Structure(
      props: Map.fromEntries(
        (table['props'] as LuaTable).value.entries.map((e) => MapEntry(
            (e.key as LuaString).value,
            (e.value as LuaString).value,
        ))
      ),
      content: (table['content'] as LuaTable).value.values.map((val) {
          // Parse the structure element
          final elem = val.value as LuaTable;
          String field(String name) => (elem[name] as LuaString).value;

          switch (field('type')) {
            case 'text': return StructureText(field('text'));
            case 'code': return StructureCode(field('content'), language: field('language'));
            case 'lens': return StructureLens(
              lens: LensExtension(ext: field('ext'), name: field('name')),
              text: field('text'),
            );
            case 'table': return StructureTable(
              (elem['rows'] as LuaTable).value.values.map((row) => (
                  (row as LuaTable).value.values.map((cell) => (cell as LuaString).value).toList()
              )).toList()
            );
            default: throw 'Invalid structure element type: ${field("type")}';
          }
      }).toList(),
      headings: (table['headings'] as LuaTable).value.entries.map((e) => (
          ((e.value as LuaTable)['title'] as LuaString).value,
          Structure.fromLua(e.value),
      )).toList(),
    );
  }
}



(int, Match)? _lineMatch(int start, Iterable<String> lines, RegExp regexp) => (
  lines.indexed
  .skip(start)
  .map((line) {
      final match = regexp.matchAsPrefix(line.$2);
      return match == null ? null : (line.$1, match);
  })
  .where((m) => m != null)
  .firstOrNull
);

Structure _parseStructure(List<String> lines, {int level = 0}) {
  final headingRegexp = RegExp('^${"#" * (1+level)} (.+)\$');
  final propsStartRegexp = RegExp(r'^---$');
  final propsEndRegexp = RegExp(r'^---$');

  // Figure out if there is a property section
  int contentStart = 0;
  Map<String, String> props = {};
  if (lines.isNotEmpty && propsStartRegexp.hasMatch(lines.first)) {
    final propsEnd = _lineMatch(1, lines, propsEndRegexp)?.$1;
    if (propsEnd != null) {
      contentStart = propsEnd + 1;

      // Parse the property lines
      props = Map.fromEntries(
        lines.getRange(1, propsEnd - 1).expand((line) {
            final index = line.indexOf(':');
            if (index == -1) return [];
            return [MapEntry(line.substring(0, index), line.substring(index + 1))];
        })
      );
    }
  }

  // Find the first heading
  (int, Match)? nextHead = _lineMatch(contentStart, lines, headingRegexp);
  final contentEnd = nextHead?.$1 ?? lines.length;

  // Parse the content
  final elements = <StructureElement>[];
  for (int line = contentStart; line < contentEnd;) {
    final specialElement = (
      StructureTable.maybeParse(lines, line)
      ?? StructureCode.maybeParse(lines, line)
      ?? StructureLens.maybeParse(lines, line)
    );

    if (specialElement == null) {
      final last = elements.lastOrNull;
      if (last is StructureText) {
        last.text = '${last.text}\n${lines[line]}';
      } else {
        elements.add(StructureText(lines[line]));
      }
      line++;
    } else {
      elements.add(specialElement.$1);
      line = specialElement.$2;
    }
  }

  // Parse each heading section
  final headings = <(String, Structure)>[];
  while (nextHead != null) {
    final (prevHeadLine, prevHeadMatch) = nextHead;


    nextHead = _lineMatch(prevHeadLine+1, lines, headingRegexp);
    final prevHeadLines = lines.sublist(prevHeadLine+1, nextHead?.$1 ?? lines.length);
    final prevHeadContent = _parseStructure(prevHeadLines, level: level+1);
    headings.add((prevHeadMatch.group(1)!, prevHeadContent));
  }

  return Structure(props: props, content: elements, headings: headings);
}
