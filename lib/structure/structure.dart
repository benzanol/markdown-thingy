import 'package:flutter/material.dart';
import 'package:notes/editor/note_editor.dart';
import 'package:notes/editor/structure_widget.dart';
import 'package:notes/lua/lua_object.dart';
import 'package:notes/lua/to_lua.dart';
import 'package:notes/structure/code.dart';
import 'package:notes/structure/lens.dart';
import 'package:notes/structure/structure_type.dart';
import 'package:notes/structure/table.dart';
import 'package:notes/structure/text.dart';


abstract class StructureElement implements ToJson {
  String markup(StructureMarkup sm);
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
          body: Structure.fromLua(e.value),
      )).toList(),
    );
  }
}
