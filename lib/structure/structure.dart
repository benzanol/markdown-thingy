import 'package:flutter/material.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/editor/structure_widget.dart';
import 'package:notes/extensions/lenses.dart';
import 'package:notes/lua/lua_object.dart';
import 'package:notes/lua/to_lua.dart';
import 'package:notes/structure/code.dart';
import 'package:notes/structure/lens.dart';
import 'package:notes/structure/structure_type.dart';
import 'package:notes/structure/table.dart';
import 'package:notes/structure/text.dart';


abstract class StructureElement implements ToJson {
  String toText(StructureType st);
  Widget widget(NoteEditor note, StructureElementWidgetState parent);
}

class StructureHeading implements ToJson {
  StructureHeading({required this.title, required this.body});
  String title;
  Structure body;

  @override
  dynamic toJson() => {
    'title': title,
    ...body.toJson(),
  };
}

class Structure implements ToJson {
  Structure({required this.props, required this.content, required this.headings});
  Structure.empty() : props = {}, content = [], headings = [];
  Map<String, String> props;
  List<StructureElement> content;
  List<StructureHeading> headings;

  @override
  Map<String, dynamic> toJson() => {
    'props': props,
    'content': content,
    'headings': headings,
  };

  String toText(StructureType st) {
    final buf = StringBuffer();
    _write(buf, st);
    return buf.toString();
  }

  void _write(StringBuffer buf, StructureType st, {int level = 0}) {
    // Write the props
    if (props.isNotEmpty) {
      buf.writeln(st.beginProps);
      for (final entry in props.entries) {
        buf.write(entry.key);
        buf.write(': ');
        buf.writeln(entry.value);
      }
      buf.writeln(st.endProps);
    }

    // Write the content
    for (final elem in content) {
      buf.writeln(elem.toText(st));
    }

    // Write the headings
    for (final head in headings) {
      buf.write(st.headingPrefixChar * (level+1));
      buf.write(' ');
      buf.write(head.title);
      buf.write('\n');
      head.body._write(buf, st, level: level + 1);
    }
  }


  List<T> getElements<T extends StructureElement>() => [
    ...content.whereType<T>(),
    ...headings.expand((h) => h.body.getElements<T>()),
  ];

  String getLuaCode() => (
    getElements<StructureCode>()
    .where((c) => c.language == 'lua')
    .map((c) => c.content)
    .join('\n\n')
  );

  Structure? getHeading(String name, {bool noCase = false}) => (
    headings.where((heading) => (
        (noCase ? heading.title.toLowerCase() : heading.title)
        == (noCase ? name.toLowerCase() : name)
    )).firstOrNull?.body
  );


  static Structure parse(String string, StructureType st) => _parseStructure(string.split('\n'), st);

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
      headings: (table['headings'] as LuaTable).value.entries.map((e) => StructureHeading(
          title: ((e.value as LuaTable)['title'] as LuaString).value,
          body: Structure.fromLua(e.value),
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

Structure _parseStructure(List<String> lines, StructureType st, {int level = 0}) {
  // Figure out if there is a property section
  int contentStart = 0;
  Map<String, String> props = {};
  if (lines.isNotEmpty && st.beginPropsRegexp.hasMatch(lines.first)) {
    final propsEnd = _lineMatch(1, lines, st.endPropsRegexp)?.$1;
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
  (int, Match)? nextHead = _lineMatch(contentStart, lines, st.headingRegexp(level + 1));
  final contentEnd = nextHead?.$1 ?? lines.length;

  // Parse the content
  final elements = <StructureElement>[];
  for (int line = contentStart; line < contentEnd;) {
    final specialElement = (
      StructureTable.maybeParse(lines, line, st)
      ?? StructureCode.maybeParse(lines, line, st)
      ?? StructureLens.maybeParse(lines, line, st)
    );

    if (specialElement == null) {
      final last = elements.lastOrNull;
      if (last is StructureText) {
        last.text = '${last.text}\n${lines[line]}';
      } else if (lines[line].isNotEmpty) { // Trim the beginning of texts
        elements.add(StructureText(lines[line]));
      }
      line++;
    } else {
      elements.add(specialElement.$1);
      line = specialElement.$2;
    }
  }
  // Trim texts
  for (final elem in elements.whereType<StructureText>()) {
    elem.text= elem.text.trim();
  }

  // Parse each heading section
  final headings = <StructureHeading>[];
  while (nextHead != null) {
    final (prevHeadLine, prevHeadMatch) = nextHead;


    nextHead = _lineMatch(prevHeadLine+1, lines, st.headingRegexp(level + 1));
    final prevHeadLines = lines.sublist(prevHeadLine+1, nextHead?.$1 ?? lines.length);
    final prevHeadContent = _parseStructure(prevHeadLines, st, level: level+1);
    headings.add(StructureHeading(title: prevHeadMatch.group(1)!, body: prevHeadContent));
  }

  return Structure(props: props, content: elements, headings: headings);
}
