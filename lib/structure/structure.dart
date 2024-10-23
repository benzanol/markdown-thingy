import 'dart:math';

import 'package:notes/lua/object.dart';
import 'package:notes/structure/structure_parser.dart';


abstract class StructureElement implements ToJson {
  String markup(StructureMarkup sm);
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
  Map<String, String> props;
  List<StructureElement> content;
  List<StructureHeading> headings;

  Structure({required this.props, required this.content, required this.headings});
  Structure.empty() : props = {}, content = [], headings = [];
  static Structure parseFromLua(LuaObject obj) => _parseStructureFromLua(obj);


  @override
  Map<String, dynamic> toJson() => {
    'props': props,
    'content': content,
    'headings': headings,
  };

  List<T> getElements<T extends StructureElement>() => [
    ...content.whereType<T>(),
    ...headings.expand((h) => h.body.getElements<T>()),
  ];

  String getText() => getElements<StructureText>().map((c) => c.content).join('\n\n');
  String getLuaCode() => getCode('lua');
  String getCode(String language) => (
    getElements<StructureCode>()
    .where((c) => c.language == language)
    .map((c) => c.content)
    .join('\n\n')
  );

  Structure? getHeading(String name, {bool noCase = false}) => (
    headings.where((heading) => (
        (noCase ? heading.title.toLowerCase() : heading.title)
        == (noCase ? name.toLowerCase() : name)
    )).firstOrNull?.body
  );


  Structure follow(List<int> path) => (
    path.isEmpty ? this : headings[path[0]].body.follow(path.sublist(1))
  );

  List<int>? search(bool Function(Structure) pred) {
    if (pred(this)) return [];

    for (int i = 0; i < headings.length; i++) {
      final childPath = headings[i].body.search(pred);
      if (childPath != null) return [i, ...childPath];
    }
    return null;
  }

  List<int>? searchStruct(Structure struct) => search((s) => s == struct);
  (List<int>, int)? searchElement(StructureElement elem) {
    final parent = search((s) => s.content.contains(elem));
    return parent == null ? null : (parent, follow(parent).content.indexOf(elem));
  }

  // Structure? searchElementParent(StructureElement elem) => searchElement(elem)?.pipe((path) => follow(path.$1));
  // Structure? searchParent(Structure struct) => searchStruct(struct)
  // ?.pipe((path) => path.isEmpty ? null : path.sublist(1))
  // ?.pipe((path) => follow(path));
  StructureHeading? searchHeading(Structure struct) {
    final path = searchStruct(struct);
    if (path == null || path.isEmpty) return null;
    return follow(path.sublist(0, path.length-1)).headings[path.last];
  }
}


class StructureText extends StructureElement {
  StructureText(this.content);
  String content;

  @override
  dynamic toJson() => {'type': 'text', 'content': content};

  @override
  String markup(StructureMarkup sm) => content;
}

class StructureCode extends StructureElement {
  StructureCode(this.content, {required this.language});
  String content;
  final String language;

  @override
  dynamic toJson() => {'type': 'code', 'language': language, 'content': content};

  @override
  String markup(StructureMarkup sm) => '${sm.beginCode}$language\n$content\n${sm.endCode}';

  static (StructureCode, int)? maybeParse(List<String> lines, int line, StructureMarkup sm) {
    final match = sm.beginCodeRegexp.firstMatch(lines[line]);
    if (match == null) return null;
    final language = match.group(1)!;

    final endLine = lines.indexed.skip(line+1).where((e) => sm.endCodeRegexp.hasMatch(e.$2)).firstOrNull;
    if (endLine == null) return null;

    final contents = lines.getRange(line+1, endLine.$1).join('\n');
    return (StructureCode(contents, language: language), endLine.$1 + 1);
  }
}

class StructureTable extends StructureElement {
  StructureTable(this.table);
  final List<List<String>> table;

  @override
  dynamic toJson() => {'type': 'table', 'rows': table};

  @override
  String markup(StructureMarkup sm) => table.map((line) => '| ${line.join(" | ")} |').join('\n');

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
}

class StructureLens extends StructureElement {
  StructureLens({required this.ext, required this.name, required this.text});
  final String ext;
  final String name;
  String text;

  @override
  dynamic toJson() => {'type': 'lens', 'ext': ext, 'name': name, 'content': text};

  @override
  String markup(StructureMarkup sm) => (
    '${sm.beginLens}$ext/$name\n$text\n${sm.endLens}'
  );

  static (StructureLens, int)? maybeParse(List<String> lines, int line, StructureMarkup sm) {
    final startMatch = sm.beginLensRegexp.firstMatch(lines[line]);
    if (startMatch == null) return null;

    final endLine = lines.indexed.skip(line+1)
    .where((tup) => sm.endLensRegexp.hasMatch(tup.$2)).firstOrNull;
    if (endLine == null) return null;

    final (ext, name) = (startMatch.group(1)!, startMatch.group(2)!);
    final content = lines.getRange(line + 1, endLine.$1).join('\n');
    final nextLine = endLine.$1 + 1;
    return (StructureLens(ext: ext, name: name, text: content), nextLine);
  }
}


Structure _parseStructureFromLua(LuaObject obj) {
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
          case 'code': return StructureCode(field('text'), language: field('language'));
          case 'lens': return StructureLens(ext: field('ext'), name: field('name'), text: field('text'));
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
        body: _parseStructureFromLua(e.value),
    )).toList(),
  );
}
