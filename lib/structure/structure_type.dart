import 'package:notes/structure/code.dart';
import 'package:notes/structure/lens.dart';
import 'package:notes/structure/structure.dart';
import 'package:notes/structure/table.dart';
import 'package:notes/structure/text.dart';

const languageFileExtensions = {
  'dart': 'dart',
  'hs': 'haskell',
  'java': 'java',
  'js': 'javascript',
  'lua': 'lua',
  'py': 'python',
  'scala': 'scala',
};


abstract class StructureParser {
  const StructureParser();

  static StructureParser? fromFile(String path) => (
    path.endsWith('.md') ? const MarkdownStructureMarkup()
    : path.endsWith('.org') ? const OrgStructureMarkup()
    : path.endsWith('.txt') ? const OrgStructureMarkup()
    : CodeStructureParser.fromFile(path)
  );
  static StructureParser fromFileOrDefault(String path) => (
    StructureParser.fromFile(path) ?? const TextStructureParser()
  );


  Structure parse(String str);
  void write(StringBuffer buf, Structure struct);

  String format(Structure struct) {
    final buf = StringBuffer();
    write(buf, struct);
    return buf.toString();
  }
}

class CodeStructureParser extends StructureParser {
  const CodeStructureParser(this.language);
  final String language;

  static CodeStructureParser? fromFile(String path) => (
    languageFileExtensions.entries
    .where((e) => path.endsWith(e.key))
    .map((e) => CodeStructureParser(e.value))
    .firstOrNull
  );

  @override
  Structure parse(String str) => Structure(
    props: {},
    content: [StructureCode(str, language: language)],
    headings: [],
  );

  @override
  void write(StringBuffer buf, Structure struct) {
    buf.write(struct.getCode(language));
  }
}

class TextStructureParser extends StructureParser {
  const TextStructureParser();

  @override
  Structure parse(String str) => Structure(
    props: {},
    content: [StructureText(str)],
    headings: [],
  );

  @override
  void write(StringBuffer buf, Structure struct) {
    buf.write(struct.getText());
  }
}


abstract class StructureMarkup extends StructureParser {
  const StructureMarkup();

  @override
  Structure parse(String str) => _parseStructure(str.split('\n'), this);

  @override void write(StringBuffer buf, Structure struct) => _writeLevel(buf, struct);
  void _writeLevel(StringBuffer buf, Structure struct, {int level = 0}) {
    // Write the props
    if (struct.props.isNotEmpty) {
      buf.writeln(beginProps);
      for (final entry in struct.props.entries) {
        buf.write(entry.key);
        buf.write(': ');
        buf.writeln(entry.value);
      }
      buf.writeln(endProps);
    }

    // Write the content
    for (final elem in struct.content) {
      buf.writeln(elem.markup(this));
    }

    // Write the headings
    for (final head in struct.headings) {
      buf.write(headingPrefixChar * (level+1));
      buf.write(' ');
      buf.write(head.title);
      buf.write('\n');
      _writeLevel(buf, head.body, level: level + 1);
    }
  }


  String get headingPrefixChar;

  String get beginProps;
  String get endProps;

  String get beginCode;
  String get endCode;

  String get beginLens;
  String get endLens;


  RegExp headingRegexp(int level) => RegExp('^${RegExp.escape(headingPrefixChar) * level} (.+)\$');

  RegExp get beginPropsRegexp => RegExp('^${RegExp.escape(beginProps)}\$');
  RegExp get endPropsRegexp => RegExp('^${RegExp.escape(endProps)}\$');

  RegExp get beginCodeRegexp => RegExp('^${RegExp.escape(beginCode)}([a-zA-Z0-9-_]+)\$');
  RegExp get endCodeRegexp => RegExp('^${RegExp.escape(endCode)}\$');

  RegExp get beginLensRegexp => RegExp('^${RegExp.escape(beginLens)}([a-zA-Z0-9]+)/([a-zA-Z0-9]+)\$');
  RegExp get endLensRegexp => RegExp('^${RegExp.escape(endLens)}\$');
}

class MarkdownStructureMarkup extends StructureMarkup {
  const MarkdownStructureMarkup();

  @override String get headingPrefixChar => '#';

  @override String get beginProps => '---';
  @override String get endProps => '---';

  @override String get beginCode => '```';
  @override String get endCode => '```';

  @override String get beginLens => '```';
  @override String get endLens => '```';
}

class OrgStructureMarkup extends StructureMarkup {
  const OrgStructureMarkup();

  @override String get headingPrefixChar => '*';

  @override String get beginProps => ':PROPERTIES:';
  @override String get endProps => ':END:';

  @override String get beginCode => '#+begin_src ';
  @override String get endCode => '#+end_src';

  @override String get beginLens => '#+begin_lens ';
  @override String get endLens => '#+end_lens';
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

Structure _parseStructure(List<String> lines, StructureMarkup sm, {int level = 0}) {
  // Figure out if there is a property section
  int contentStart = 0;
  Map<String, String> props = {};
  if (lines.isNotEmpty && sm.beginPropsRegexp.hasMatch(lines.first)) {
    final propsEnd = _lineMatch(1, lines, sm.endPropsRegexp)?.$1;
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
  (int, Match)? nextHead = _lineMatch(contentStart, lines, sm.headingRegexp(level + 1));
  final contentEnd = nextHead?.$1 ?? lines.length;

  // Parse the content
  final elements = <StructureElement>[];
  for (int line = contentStart; line < contentEnd;) {
    final specialElement = (
      StructureTable.maybeParse(lines, line, sm)
      ?? StructureCode.maybeParse(lines, line, sm)
      ?? StructureLens.maybeParse(lines, line, sm)
    );

    if (specialElement == null) {
      final last = elements.lastOrNull;
      if (last is StructureText) {
        last.content = '${last.content}\n${lines[line]}';
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
    elem.content= elem.content.trim();
  }

  // Parse each heading section
  final headings = <StructureHeading>[];
  while (nextHead != null) {
    final (prevHeadLine, prevHeadMatch) = nextHead;


    nextHead = _lineMatch(prevHeadLine+1, lines, sm.headingRegexp(level + 1));
    final prevHeadLines = lines.sublist(prevHeadLine+1, nextHead?.$1 ?? lines.length);
    final prevHeadContent = _parseStructure(prevHeadLines, sm, level: level+1);
    headings.add(StructureHeading(title: prevHeadMatch.group(1)!, body: prevHeadContent));
  }

  return Structure(props: props, content: elements, headings: headings);
}
